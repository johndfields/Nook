//
//  AdBlockManager.swift
//  Nook
//
//  Comprehensive ad blocking using popular filter lists
//  Similar to Brave's built-in ad blocker
//

import Foundation
import WebKit

@MainActor
final class AdBlockManager {
    weak var browserManager: BrowserManager?
    
    // Settings
    private(set) var isEnabled: Bool = true  // Default ON like Brave
    private(set) var aggressiveMode: Bool = false
    
    // Rule lists
    private var adBlockRuleList: WKContentRuleList?
    
    // Statistics
    private var blockedCountsByTab: [UUID: Int] = [:]
    
    // Exceptions (per-site)
    private var allowedDomains: Set<String> = []
    private let allowedDomainsKey = "AdBlockAllowedDomains"
    
    init() {
        // Load saved settings
        loadSettings()
    }
    
    func attach(browserManager: BrowserManager) {
        self.browserManager = browserManager
    }
    
    // MARK: - Settings Persistence
    
    private func loadSettings() {
        isEnabled = UserDefaults.standard.bool(forKey: "AdBlockEnabled")
        if UserDefaults.standard.object(forKey: "AdBlockEnabled") == nil {
            // Default to enabled on first launch
            isEnabled = true
            UserDefaults.standard.set(true, forKey: "AdBlockEnabled")
        }
        
        aggressiveMode = UserDefaults.standard.bool(forKey: "AdBlockAggressiveMode")
        
        if let domains = UserDefaults.standard.array(forKey: allowedDomainsKey) as? [String] {
            allowedDomains = Set(domains)
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(isEnabled, forKey: "AdBlockEnabled")
        UserDefaults.standard.set(aggressiveMode, forKey: "AdBlockAggressiveMode")
        UserDefaults.standard.set(Array(allowedDomains), forKey: allowedDomainsKey)
    }
    
    // MARK: - Enable/Disable
    
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
    
    // MARK: - Rule List Installation
    
    func installRuleListIfNeeded() async {
        guard let store = WKContentRuleListStore.default() else { return }
        
        let identifier = aggressiveMode ? "NookAdBlock_Aggressive" : "NookAdBlock_Standard"
        
        // Check cache first
        if let existing = await withCheckedContinuation({ (cont: CheckedContinuation<WKContentRuleList?, Never>) in
            store.lookUpContentRuleList(forIdentifier: identifier) { list, _ in
                cont.resume(returning: list)
            }
        }) {
            self.adBlockRuleList = existing
            print("✅ [AdBlock] Using cached rule list: \(identifier)")
            return
        }
        
        // Compile new rule list
        let rules = makeAdBlockRules()
        let compiled = await withCheckedContinuation { (cont: CheckedContinuation<WKContentRuleList?, Never>) in
            store.compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: rules) { list, error in
                if let error {
                    print("⚠️ [AdBlock] Compilation error: \(error)")
                }
                cont.resume(returning: list)
            }
        }
        
        if let compiled {
            self.adBlockRuleList = compiled
            print("✅ [AdBlock] Compiled new rule list: \(identifier)")
        }
    }
    
    // MARK: - Rule Generation
    
    private func makeAdBlockRules() -> String {
        var rules: [[String: Any]] = []
        
        // Get base domains to block
        let domainsToBlock = aggressiveMode ? allAdDomains : standardAdDomains
        
        // Block ad domains
        for domain in domainsToBlock {
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
        
        // Block third-party cookies
        rules.append([
            "trigger": [
                "url-filter": ".*",
                "load-type": ["third-party"]
            ],
            "action": ["type": "block-cookies"]
        ])
        
        // Encode to JSON
        if let data = try? JSONSerialization.data(withJSONObject: rules, options: []),
           let json = String(data: data, encoding: .utf8) {
            print("📊 [AdBlock] Generated \(rules.count) blocking rules")
            return json
        }
        
        return "[]"
    }
    
    // Standard mode: Most common ad networks and trackers
    private var standardAdDomains: [String] {
        return [
            // Google Ads & Analytics
            "doubleclick\\.net",
            "googlesyndication\\.com",
            "googleadservices\\.com",
            "google-analytics\\.com",
            "googletagmanager\\.com",
            "googletagservices\\.com",
            "pagead2\\.googlesyndication\\.com",
            "adservice\\.google\\.com",
            
            // Facebook
            "facebook\\.net",
            "connect\\.facebook\\.net",
            "facebook\\.com/tr",
            
            // Major Ad Networks
            "adsystem\\.com",
            "amazon-adsystem\\.com",
            "advertising\\.com",
            
            // Trackers
            "hotjar\\.com",
            "segment\\.io",
            "cdn\\.segment\\.com",
            "mixpanel\\.com",
            "optimizely\\.com",
            "clarity\\.ms",
        ]
    }
    
    // Aggressive mode: Extended list
    private var allAdDomains: [String] {
        return standardAdDomains + [
            // Additional Ad Networks
            "taboola\\.com",
            "outbrain\\.com",
            "adnxs\\.com",
            "criteo\\.com",
            "pubmatic\\.com",
            "rubiconproject\\.com",
            "openx\\.net",
            
            // Social Trackers
            "twitter\\.com/i/adsct",
            "linkedin\\.com/px",
            "reddit\\.com/api/v1/pixel",
            "pinterest\\.com/ct",
            "tiktok\\.com/i18n/pixel",
            
            // Analytics
            "amplitude\\.com",
            "heap\\.io",
            "fullstory\\.com",
            "logrocket\\.com",
            "quantserve\\.com",
            "scorecardresearch\\.com",
            "newrelic\\.com",
            "sentry\\.io",
            "mouseflow\\.com",
        ]
    }
    
    // MARK: - Apply to WebViews
    
    private func updateAllWebViews() async {
        guard let browserManager else { return }
        
        for tab in browserManager.tabManager.allTabs() {
            guard let webView = tab.webView else { continue }
            applyToWebView(webView, for: tab)
        }
    }
    
    func applyToWebView(_ webView: WKWebView, for tab: Tab) {
        let ucc = webView.configuration.userContentController
        
        // Check if this domain is allowed
        if let host = webView.url?.host, isDomainAllowed(host) {
            // Don't apply ad blocking for this domain
            return
        }
        
        if isEnabled, let ruleList = adBlockRuleList {
            ucc.add(ruleList)
        }
    }
    
    // MARK: - Per-Site Control
    
    func isDomainAllowed(_ domain: String) -> Bool {
        let normalized = domain.lowercased()
        return allowedDomains.contains(normalized)
    }
    
    func allowDomain(_ domain: String) {
        let normalized = domain.lowercased()
        allowedDomains.insert(normalized)
        saveSettings()
        
        // Reload tabs for this domain
        Task {
            await reloadTabsForDomain(normalized)
        }
    }
    
    func blockDomain(_ domain: String) {
        let normalized = domain.lowercased()
        allowedDomains.remove(normalized)
        saveSettings()
        
        // Reload tabs for this domain
        Task {
            await reloadTabsForDomain(normalized)
        }
    }
    
    private func reloadTabsForDomain(_ domain: String) async {
        guard let browserManager else { return }
        
        for tab in browserManager.tabManager.allTabs() {
            if let host = tab.webView?.url?.host?.lowercased(), host == domain {
                tab.webView?.reloadFromOrigin()
            }
        }
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

