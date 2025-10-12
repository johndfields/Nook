//
//  ContentBlockingManager.swift
//  Nook
//
//  Unified content blocking manager handling ads, tracking, and malware.
//  Inspired by uBlock Origin's unified filtering engine architecture.
//  
//  ARCHITECTURE: Single WKContentRuleList with multiple filter categories
//  - Combines ad blocking + tracking protection into one efficient pass
//  - Users can toggle categories independently via UI
//  - Single source of truth for content blocking rules
//

import Foundation
import WebKit

@MainActor
final class ContentBlockingManager {
    weak var browserManager: BrowserManager?
    
    // MARK: - Filter Categories (can be toggled independently)
    enum FilterCategory: String, CaseIterable {
        case ads = "Ads"
        case tracking = "Tracking"
        case annoyances = "Annoyances"
        
        var storageKey: String {
            return "ContentBlocking_\(rawValue)_Enabled"
        }
    }
    
    // MARK: - Settings
    private(set) var isEnabled: Bool = true  // Master switch
    private(set) var aggressiveMode: Bool = false
    private var enabledCategories: Set<FilterCategory> = [.ads, .tracking]
    
    // Rule lists
    private var contentRuleList: WKContentRuleList?
    private let ruleListIdentifier = "NookContentBlocking"
    
    // Statistics
    private var blockedCountsByTab: [UUID: Int] = [:]
    
    // Exceptions (per-site)
    private var allowedDomains: Set<String> = []
    private let allowedDomainsKey = "ContentBlockingAllowedDomains"
    
    // Temporary disabling (for debugging sites)
    private var temporarilyDisabledTabs: [UUID: Date] = [:]
    
    // Third-party cookie blocking script
    private var thirdPartyCookieScript: WKUserScript {
        let js = """
        (function() {
          try {
            if (window.top === window) return;
            var ref = document.referrer || "";
            var thirdParty = false;
            try {
              var refHost = ref ? new URL(ref).hostname : null;
              thirdParty = !!refHost && refHost !== window.location.hostname;
            } catch (e) { thirdParty = false; }
            if (!thirdParty) return;

            Object.defineProperty(document, 'cookie', {
              configurable: false,
              enumerable: false,
              get: function() { return ''; },
              set: function(_) { return true; }
            });
            try {
              document.requestStorageAccess = function() { 
                return Promise.reject(new DOMException('Blocked by Nook', 'NotAllowedError')); 
              };
            } catch (e) {}
          } catch (e) {}
        })();
        """
        return WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }
    
    init() {
        loadSettings()
    }
    
    func attach(browserManager: BrowserManager) {
        self.browserManager = browserManager
    }
    
    // MARK: - Settings Persistence
    
    private func loadSettings() {
        // Master switch
        if UserDefaults.standard.object(forKey: "ContentBlockingEnabled") == nil {
            isEnabled = true  // Default ON
            UserDefaults.standard.set(true, forKey: "ContentBlockingEnabled")
        } else {
            isEnabled = UserDefaults.standard.bool(forKey: "ContentBlockingEnabled")
        }
        
        aggressiveMode = UserDefaults.standard.bool(forKey: "ContentBlockingAggressiveMode")
        
        // Load category toggles
        var categories = Set<FilterCategory>()
        for category in FilterCategory.allCases {
            // Default: ads and tracking enabled
            let defaultEnabled = (category == .ads || category == .tracking)
            let key = category.storageKey
            if UserDefaults.standard.object(forKey: key) == nil {
                UserDefaults.standard.set(defaultEnabled, forKey: key)
                if defaultEnabled { categories.insert(category) }
            } else if UserDefaults.standard.bool(forKey: key) {
                categories.insert(category)
            }
        }
        enabledCategories = categories
        
        // Load allowed domains
        if let domains = UserDefaults.standard.array(forKey: allowedDomainsKey) as? [String] {
            allowedDomains = Set(domains)
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(isEnabled, forKey: "ContentBlockingEnabled")
        UserDefaults.standard.set(aggressiveMode, forKey: "ContentBlockingAggressiveMode")
        
        for category in FilterCategory.allCases {
            UserDefaults.standard.set(
                enabledCategories.contains(category),
                forKey: category.storageKey
            )
        }
        
        UserDefaults.standard.set(Array(allowedDomains), forKey: allowedDomainsKey)
    }
    
    // MARK: - Master Controls
    
    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        saveSettings()
        
        Task {
            if enabled {
                await installRuleListIfNeeded()
            }
            await updateAllWebViews()
        }
    }
    
    func setAggressiveMode(_ aggressive: Bool) {
        guard aggressive != aggressiveMode else { return }
        aggressiveMode = aggressive
        saveSettings()
        
        Task {
            await installRuleListIfNeeded()
            await updateAllWebViews()
        }
    }
    
    // MARK: - Category Controls
    
    func isCategoryEnabled(_ category: FilterCategory) -> Bool {
        return enabledCategories.contains(category)
    }
    
    func setCategoryEnabled(_ category: FilterCategory, enabled: Bool) {
        let wasEnabled = enabledCategories.contains(category)
        if enabled {
            enabledCategories.insert(category)
        } else {
            enabledCategories.remove(category)
        }
        
        guard wasEnabled != enabled else { return }
        saveSettings()
        
        Task {
            await installRuleListIfNeeded()
            await updateAllWebViews()
        }
    }
    
    // MARK: - Rule List Installation
    
    func installRuleListIfNeeded() async {
        guard let store = WKContentRuleListStore.default() else { return }
        
        let identifier = makeIdentifier()
        
        // Check cache first
        if let existing = await withCheckedContinuation({ (cont: CheckedContinuation<WKContentRuleList?, Never>) in
            store.lookUpContentRuleList(forIdentifier: identifier) { list, _ in
                cont.resume(returning: list)
            }
        }) {
            self.contentRuleList = existing
            print("✅ [ContentBlocking] Using cached rule list: \(identifier)")
            return
        }
        
        // Compile new unified rule list
        let rules = makeUnifiedRules()
        let compiled = await withCheckedContinuation { (cont: CheckedContinuation<WKContentRuleList?, Never>) in
            store.compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: rules) { list, error in
                if let error {
                    print("⚠️ [ContentBlocking] Compilation error: \(error)")
                }
                cont.resume(returning: list)
            }
        }
        
        if let compiled {
            self.contentRuleList = compiled
            print("✅ [ContentBlocking] Compiled new rule list: \(identifier)")
        }
    }
    
    private func makeIdentifier() -> String {
        var parts = ["NookContentBlocking"]
        if aggressiveMode { parts.append("Aggressive") }
        for category in FilterCategory.allCases.sorted(by: { $0.rawValue < $1.rawValue }) {
            if enabledCategories.contains(category) {
                parts.append(category.rawValue)
            }
        }
        return parts.joined(separator: "_")
    }
    
    // MARK: - Unified Rule Generation
    
    private func makeUnifiedRules() -> String {
        var rules: [[String: Any]] = []
        
        // Add rules from enabled categories
        if enabledCategories.contains(.ads) {
            rules.append(contentsOf: makeAdBlockingRules())
        }
        
        if enabledCategories.contains(.tracking) {
            rules.append(contentsOf: makeTrackingProtectionRules())
        }
        
        if enabledCategories.contains(.annoyances) {
            rules.append(contentsOf: makeAnnoyanceRules())
        }
        
        // Block third-party cookies (if any category is enabled)
        if !enabledCategories.isEmpty {
            rules.append([
                "trigger": [
                    "url-filter": ".*",
                    "load-type": ["third-party"]
                ],
                "action": ["type": "block-cookies"]
            ])
        }
        
        // Encode to JSON
        if let data = try? JSONSerialization.data(withJSONObject: rules, options: []),
           let json = String(data: data, encoding: .utf8) {
            print("📊 [ContentBlocking] Generated \(rules.count) blocking rules")
            print("   - Ad blocking: \(enabledCategories.contains(.ads) ? "ON" : "OFF")")
            print("   - Tracking protection: \(enabledCategories.contains(.tracking) ? "ON" : "OFF")")
            print("   - Aggressive mode: \(aggressiveMode ? "ON" : "OFF")")
            return json
        }
        
        return "[]"
    }
    
    // MARK: - Ad Blocking Rules
    
    private func makeAdBlockingRules() -> [[String: Any]] {
        var rules: [[String: Any]] = []
        let domains = aggressiveMode ? allAdDomains : standardAdDomains
        
        for domain in domains {
            rules.append([
                "trigger": [
                    "url-filter": domain,
                    "resource-type": ["image", "style-sheet", "script", "font", "media", "raw"]
                ],
                "action": ["type": "block"]
            ])
        }
        
        // Block common ad paths
        let adPaths = ["/ads/", "/adv/", "/banner", "/sponsor", "/tracking/", "/metrics/"]
        for path in adPaths {
            rules.append([
                "trigger": [
                    "url-filter": ".*\(NSRegularExpression.escapedPattern(for: path)).*",
                    "resource-type": ["image", "style-sheet", "script"]
                ],
                "action": ["type": "block"]
            ])
        }
        
        return rules
    }
    
    private var standardAdDomains: [String] {
        return [
            // Google Ads
            "googlesyndication\\.com",
            "googleadservices\\.com",
            "googletagservices\\.com",
            "pagead2\\.googlesyndication\\.com",
            "tpc\\.googlesyndication\\.com",
            
            // Facebook Ads
            "facebook\\.com/tr",
            "facebook\\.com/plugins",
            
            // Major Ad Networks
            "amazon-adsystem\\.com",
            "advertising\\.com",
            "media\\.net",
            
            // Video Ads
            "imasdk\\.googleapis\\.com",
            "pubads\\.g\\.doubleclick\\.net",
            
            // Pop-ups
            "popads\\.net",
            "popcash\\.net",
        ]
    }
    
    private var allAdDomains: [String] {
        return standardAdDomains + [
            // Content Recommendation
            "taboola\\.com",
            "outbrain\\.com",
            "revcontent\\.com",
            "mgid\\.com",
            
            // Programmatic Ad Exchanges
            "adnxs\\.com",
            "criteo\\.com",
            "pubmatic\\.com",
            "rubiconproject\\.com",
            "openx\\.net",
            "contextweb\\.com",
            "casalemedia\\.com",
            "indexexchange\\.com",
            
            // Social Media Ads
            "twitter\\.com/i/adsct",
            "linkedin\\.com/px",
            "reddit\\.com/api/v1/pixel",
            "pinterest\\.com/ct",
            "tiktok\\.com/i18n/pixel",
            
            // Native Advertising
            "nativo\\.com",
            "triplelift\\.com",
        ]
    }
    
    // MARK: - Tracking Protection Rules
    
    private func makeTrackingProtectionRules() -> [[String: Any]] {
        var rules: [[String: Any]] = []
        let domains = aggressiveMode ? allTrackingDomains : standardTrackingDomains
        
        for domain in domains {
            rules.append([
                "trigger": ["url-filter": domain],
                "action": ["type": "block"]
            ])
        }
        
        return rules
    }
    
    private var standardTrackingDomains: [String] {
        return [
            // Analytics
            "google-analytics\\.com",
            "analytics\\.google\\.com",
            "googletagmanager\\.com",
            "doubleclick\\.net",
            
            // Social Tracking
            "facebook\\.net",
            "connect\\.facebook\\.net",
            
            // Common Trackers
            "hotjar\\.com",
            "segment\\.io",
            "cdn\\.segment\\.com",
            "mixpanel\\.com",
            "optimizely\\.com",
            "clarity\\.ms",
        ]
    }
    
    private var allTrackingDomains: [String] {
        return standardTrackingDomains + [
            // Advanced Analytics
            "amplitude\\.com",
            "heap\\.io",
            "fullstory\\.com",
            "logrocket\\.com",
            "mouseflow\\.com",
            
            // Attribution & Retargeting
            "branch\\.io",
            "adjust\\.com",
            "quantserve\\.com",
            "scorecardresearch\\.com",
            
            // Error Tracking
            "sentry\\.io",
            "newrelic\\.com",
        ]
    }
    
    // MARK: - Annoyance Rules
    
    private func makeAnnoyanceRules() -> [[String: Any]] {
        // Placeholder for future: cookie consent banners, social widgets, etc.
        return []
    }
    
    // MARK: - Apply to WebViews
    
    private func updateAllWebViews() async {
        guard let browserManager else { return }
        
        for tab in browserManager.tabManager.allTabs() {
            guard let webView = tab.webView else { continue }
            if shouldApplyBlocking(to: tab) {
                applyToWebView(webView)
            } else {
                removeFromWebView(webView)
            }
        }
    }
    
    func applyToWebView(_ webView: WKWebView) {
        guard isEnabled, let ruleList = contentRuleList else { return }
        
        let ucc = webView.configuration.userContentController
        ucc.add(ruleList)
        
        // Add third-party cookie script
        if !ucc.userScripts.contains(where: { $0.source.contains("document.referrer") }) {
            ucc.addUserScript(thirdPartyCookieScript)
        }
    }
    
    private func removeFromWebView(_ webView: WKWebView) {
        let ucc = webView.configuration.userContentController
        // Note: This will remove ALL rule lists, which is fine if this is the only manager
        ucc.removeAllContentRuleLists()
        
        // Remove cookie script
        let remaining = ucc.userScripts.filter { !$0.source.contains("document.referrer") }
        ucc.removeAllUserScripts()
        remaining.forEach { ucc.addUserScript($0) }
    }
    
    // MARK: - Per-Site Control
    
    func isDomainAllowed(_ domain: String?) -> Bool {
        guard let domain = domain?.lowercased() else { return false }
        return allowedDomains.contains(domain)
    }
    
    func allowDomain(_ domain: String) {
        let normalized = domain.lowercased()
        allowedDomains.insert(normalized)
        saveSettings()
        reloadTabsForDomain(normalized)
    }
    
    func blockDomain(_ domain: String) {
        let normalized = domain.lowercased()
        allowedDomains.remove(normalized)
        saveSettings()
        reloadTabsForDomain(normalized)
    }
    
    private func reloadTabsForDomain(_ domain: String) {
        guard let browserManager else { return }
        
        for tab in browserManager.tabManager.allTabs() {
            if let host = tab.webView?.url?.host?.lowercased(), host == domain {
                tab.webView?.reloadFromOrigin()
            }
        }
    }
    
    // MARK: - Temporary Disabling
    
    func isTemporarilyDisabled(tabId: UUID) -> Bool {
        if let until = temporarilyDisabledTabs[tabId] {
            if until > Date() { return true }
            temporarilyDisabledTabs.removeValue(forKey: tabId)
        }
        return false
    }
    
    func disableTemporarily(for tab: Tab, duration: TimeInterval) {
        let until = Date().addingTimeInterval(duration)
        temporarilyDisabledTabs[tab.id] = until
        
        if let wv = tab.webView {
            removeFromWebView(wv)
            wv.reloadFromOrigin()
        }
        
        // Schedule re-apply after expiration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self, weak tab] in
            guard let self, let tab else { return }
            if let exp = self.temporarilyDisabledTabs[tab.id], exp <= Date() {
                self.temporarilyDisabledTabs.removeValue(forKey: tab.id)
                if self.shouldApplyBlocking(to: tab), let wv = tab.webView {
                    self.applyToWebView(wv)
                    wv.reloadFromOrigin()
                }
            }
        }
    }
    
    private func shouldApplyBlocking(to tab: Tab) -> Bool {
        if !isEnabled { return false }
        if isTemporarilyDisabled(tabId: tab.id) { return false }
        if isDomainAllowed(tab.webView?.url?.host) { return false }
        return true
    }
    
    func refreshFor(tab: Tab) {
        guard let wv = tab.webView else { return }
        if shouldApplyBlocking(to: tab) {
            applyToWebView(wv)
        } else {
            removeFromWebView(wv)
        }
        wv.reloadFromOrigin()
    }
    
    // MARK: - Statistics
    
    func getBlockedCount(for tab: Tab) -> Int {
        return blockedCountsByTab[tab.id] ?? 0
    }
    
    func incrementBlockedCount(for tab: Tab) {
        blockedCountsByTab[tab.id, default: 0] += 1
    }
    
    func resetBlockedCount(for tab: Tab) {
        blockedCountsByTab[tab.id] = 0
    }
    
    func getTotalBlockedCount() -> Int {
        return blockedCountsByTab.values.reduce(0, +)
    }
}

