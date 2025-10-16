//
//  ExtensionManager+WebNavigation.swift
//  Nook
//
//  Chrome WebNavigation API Bridge for WKWebExtension support
//  Implements chrome.webNavigation.* APIs for navigation tracking
//

import Foundation
import WebKit
import AppKit

// MARK: - WebNavigation Data Structures

@available(macOS 15.4, *)
struct NavigationFrame: Codable {
    let frameId: Int
    let parentFrameId: Int
    let processId: Int?
    let documentId: String
    let documentLifecycle: String
    let frameType: String
    let url: String
    let errorOccurred: Bool
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "frameId": frameId,
            "parentFrameId": parentFrameId,
            "documentId": documentId,
            "documentLifecycle": documentLifecycle,
            "frameType": frameType,
            "url": url,
            "errorOccurred": errorOccurred
        ]
        if let processId = processId {
            dict["processId"] = processId
        }
        return dict
    }
}

@available(macOS 15.4, *)
struct NavigationDetails: Codable {
    let tabId: String
    let url: String
    let processId: Int?
    let frameId: Int
    let parentFrameId: Int?
    let timeStamp: TimeInterval
    let transitionType: String?
    let transitionQualifiers: [String]?
    let documentId: String?
    let documentLifecycle: String?
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "tabId": tabId,
            "url": url,
            "frameId": frameId,
            "timeStamp": timeStamp
        ]
        if let processId = processId {
            dict["processId"] = processId
        }
        if let parentFrameId = parentFrameId {
            dict["parentFrameId"] = parentFrameId
        }
        if let transitionType = transitionType {
            dict["transitionType"] = transitionType
        }
        if let transitionQualifiers = transitionQualifiers {
            dict["transitionQualifiers"] = transitionQualifiers
        }
        if let documentId = documentId {
            dict["documentId"] = documentId
        }
        if let documentLifecycle = documentLifecycle {
            dict["documentLifecycle"] = documentLifecycle
        }
        return dict
    }
}

@available(macOS 15.4, *)
struct NavigationErrorDetails {
    let tabId: String
    let url: String
    let frameId: Int
    let error: String
    let timeStamp: TimeInterval
    
    var dictionary: [String: Any] {
        return [
            "tabId": tabId,
            "url": url,
            "frameId": frameId,
            "error": error,
            "timeStamp": timeStamp
        ]
    }
}

// MARK: - Chrome WebNavigation API Bridge
@available(macOS 15.4, *)
extension ExtensionManager {
    
    // Storage for navigation tracking per tab
    private static var navigationFrames: [String: [Int: NavigationFrame]] = [:]  // tabId -> frameId -> frame
    private static var navigationLock = NSLock()
    
    // MARK: - WebNavigation API Implementation
    
    /// Handles chrome.webNavigation API calls from extension contexts
    func handleWebNavigationMessage(message: [String: Any], from context: WKWebExtensionContext, replyHandler: @escaping (Any?) -> Void) {
        print("🧭 [ExtensionManager+WebNavigation] === CHROME WEBNAVIGATION API CALL ===")
        print("🧭 [ExtensionManager+WebNavigation] Message keys: \(message.keys)")
        
        guard let extensionId = getExtensionId(for: context) else {
            print("❌ [ExtensionManager+WebNavigation] Extension ID not found")
            replyHandler(["error": "Extension ID not found"])
            return
        }
        
        guard let action = message["action"] as? String else {
            print("❌ [ExtensionManager+WebNavigation] No action specified")
            replyHandler(["error": "No action specified"])
            return
        }
        
        print("🧭 [ExtensionManager+WebNavigation] Action: \(action), Extension: \(extensionId)")
        
        switch action {
        case "getFrame":
            handleGetFrame(message: message, replyHandler: replyHandler)
        case "getAllFrames":
            handleGetAllFrames(message: message, replyHandler: replyHandler)
        default:
            print("❌ [ExtensionManager+WebNavigation] Unknown action: \(action)")
            replyHandler(["error": "Unknown webNavigation action: \(action)"])
        }
    }
    
    // MARK: - chrome.webNavigation.getFrame()
    
    private func handleGetFrame(message: [String: Any], replyHandler: @escaping (Any?) -> Void) {
        guard let details = message["details"] as? [String: Any],
              let tabId = details["tabId"] as? String,
              let frameId = details["frameId"] as? Int else {
            print("❌ [ExtensionManager+WebNavigation] Invalid getFrame parameters")
            replyHandler(["error": "Invalid parameters for getFrame"])
            return
        }
        
        print("🧭 [ExtensionManager+WebNavigation] Getting frame \(frameId) for tab \(tabId)")
        
        Self.navigationLock.lock()
        let frame = Self.navigationFrames[tabId]?[frameId]
        Self.navigationLock.unlock()
        
        if let frame = frame {
            replyHandler(["success": true, "frame": frame.dictionary])
        } else {
            replyHandler(["success": true, "frame": NSNull()])
        }
    }
    
    // MARK: - chrome.webNavigation.getAllFrames()
    
    private func handleGetAllFrames(message: [String: Any], replyHandler: @escaping (Any?) -> Void) {
        guard let details = message["details"] as? [String: Any],
              let tabId = details["tabId"] as? String else {
            print("❌ [ExtensionManager+WebNavigation] Invalid getAllFrames parameters")
            replyHandler(["error": "Invalid parameters for getAllFrames"])
            return
        }
        
        print("🧭 [ExtensionManager+WebNavigation] Getting all frames for tab \(tabId)")
        
        Self.navigationLock.lock()
        let frames = Self.navigationFrames[tabId]?.values.map { $0.dictionary } ?? []
        Self.navigationLock.unlock()
        
        replyHandler(["success": true, "frames": frames])
    }
    
    // MARK: - Navigation Event Firing
    
    /// Fire onBeforeNavigate event to extensions
    func fireWebNavigationOnBeforeNavigate(tabId: String, url: String, frameId: Int = 0, parentFrameId: Int = -1, processId: Int? = nil) {
        let timeStamp = Date().timeIntervalSince1970 * 1000  // milliseconds
        
        let details = NavigationDetails(
            tabId: tabId,
            url: url,
            processId: processId,
            frameId: frameId,
            parentFrameId: parentFrameId >= 0 ? parentFrameId : nil,
            timeStamp: timeStamp,
            transitionType: nil,
            transitionQualifiers: nil,
            documentId: nil,
            documentLifecycle: nil
        )
        
        print("🧭 [ExtensionManager+WebNavigation] onBeforeNavigate: \(url) (tab: \(tabId), frame: \(frameId))")
        fireWebNavigationEvent(eventName: "onBeforeNavigate", details: details.dictionary)
    }
    
    /// Fire onCommitted event to extensions
    func fireWebNavigationOnCommitted(tabId: String, url: String, frameId: Int = 0, transitionType: String = "link", transitionQualifiers: [String] = [], documentId: String? = nil) {
        let timeStamp = Date().timeIntervalSince1970 * 1000  // milliseconds
        
        let details = NavigationDetails(
            tabId: tabId,
            url: url,
            processId: nil,
            frameId: frameId,
            parentFrameId: frameId == 0 ? nil : -1,
            timeStamp: timeStamp,
            transitionType: transitionType,
            transitionQualifiers: transitionQualifiers.isEmpty ? nil : transitionQualifiers,
            documentId: documentId ?? UUID().uuidString,
            documentLifecycle: "active"
        )
        
        print("🧭 [ExtensionManager+WebNavigation] onCommitted: \(url) (tab: \(tabId), frame: \(frameId))")
        
        // Store frame information
        if let documentId = documentId ?? details.documentId {
            let frame = NavigationFrame(
                frameId: frameId,
                parentFrameId: frameId == 0 ? -1 : 0,
                processId: nil,
                documentId: documentId,
                documentLifecycle: "active",
                frameType: frameId == 0 ? "outermost_frame" : "sub_frame",
                url: url,
                errorOccurred: false
            )
            
            Self.navigationLock.lock()
            if Self.navigationFrames[tabId] == nil {
                Self.navigationFrames[tabId] = [:]
            }
            Self.navigationFrames[tabId]?[frameId] = frame
            Self.navigationLock.unlock()
        }
        
        fireWebNavigationEvent(eventName: "onCommitted", details: details.dictionary)
    }
    
    /// Fire onDOMContentLoaded event to extensions
    func fireWebNavigationOnDOMContentLoaded(tabId: String, url: String, frameId: Int = 0, documentId: String? = nil) {
        let timeStamp = Date().timeIntervalSince1970 * 1000  // milliseconds
        
        let details = NavigationDetails(
            tabId: tabId,
            url: url,
            processId: nil,
            frameId: frameId,
            parentFrameId: frameId == 0 ? nil : -1,
            timeStamp: timeStamp,
            transitionType: nil,
            transitionQualifiers: nil,
            documentId: documentId,
            documentLifecycle: nil
        )
        
        print("🧭 [ExtensionManager+WebNavigation] onDOMContentLoaded: \(url) (tab: \(tabId), frame: \(frameId))")
        fireWebNavigationEvent(eventName: "onDOMContentLoaded", details: details.dictionary)
    }
    
    /// Fire onCompleted event to extensions
    func fireWebNavigationOnCompleted(tabId: String, url: String, frameId: Int = 0, documentId: String? = nil) {
        let timeStamp = Date().timeIntervalSince1970 * 1000  // milliseconds
        
        let details = NavigationDetails(
            tabId: tabId,
            url: url,
            processId: nil,
            frameId: frameId,
            parentFrameId: frameId == 0 ? nil : -1,
            timeStamp: timeStamp,
            transitionType: nil,
            transitionQualifiers: nil,
            documentId: documentId,
            documentLifecycle: nil
        )
        
        print("🧭 [ExtensionManager+WebNavigation] onCompleted: \(url) (tab: \(tabId), frame: \(frameId))")
        fireWebNavigationEvent(eventName: "onCompleted", details: details.dictionary)
    }
    
    /// Fire onErrorOccurred event to extensions
    func fireWebNavigationOnErrorOccurred(tabId: String, url: String, frameId: Int = 0, error: String) {
        let timeStamp = Date().timeIntervalSince1970 * 1000  // milliseconds
        
        let details = NavigationErrorDetails(
            tabId: tabId,
            url: url,
            frameId: frameId,
            error: error,
            timeStamp: timeStamp
        )
        
        print("🧭 [ExtensionManager+WebNavigation] onErrorOccurred: \(error) for \(url) (tab: \(tabId), frame: \(frameId))")
        fireWebNavigationEvent(eventName: "onErrorOccurred", details: details.dictionary)
        
        // Mark frame as errored
        Self.navigationLock.lock()
        if var frame = Self.navigationFrames[tabId]?[frameId] {
            let updatedFrame = NavigationFrame(
                frameId: frame.frameId,
                parentFrameId: frame.parentFrameId,
                processId: frame.processId,
                documentId: frame.documentId,
                documentLifecycle: frame.documentLifecycle,
                frameType: frame.frameType,
                url: frame.url,
                errorOccurred: true
            )
            Self.navigationFrames[tabId]?[frameId] = updatedFrame
        }
        Self.navigationLock.unlock()
    }
    
    /// Fire onReferenceFragmentUpdated event to extensions (hash change)
    func fireWebNavigationOnReferenceFragmentUpdated(tabId: String, url: String, frameId: Int = 0, transitionType: String = "link", transitionQualifiers: [String] = []) {
        let timeStamp = Date().timeIntervalSince1970 * 1000  // milliseconds
        
        let details = NavigationDetails(
            tabId: tabId,
            url: url,
            processId: nil,
            frameId: frameId,
            parentFrameId: frameId == 0 ? nil : -1,
            timeStamp: timeStamp,
            transitionType: transitionType,
            transitionQualifiers: transitionQualifiers.isEmpty ? nil : transitionQualifiers,
            documentId: nil,
            documentLifecycle: nil
        )
        
        print("🧭 [ExtensionManager+WebNavigation] onReferenceFragmentUpdated: \(url) (tab: \(tabId), frame: \(frameId))")
        fireWebNavigationEvent(eventName: "onReferenceFragmentUpdated", details: details.dictionary)
    }
    
    /// Fire onHistoryStateUpdated event to extensions (history.pushState/replaceState)
    func fireWebNavigationOnHistoryStateUpdated(tabId: String, url: String, frameId: Int = 0, transitionType: String = "link", transitionQualifiers: [String] = []) {
        let timeStamp = Date().timeIntervalSince1970 * 1000  // milliseconds
        
        let details = NavigationDetails(
            tabId: tabId,
            url: url,
            processId: nil,
            frameId: frameId,
            parentFrameId: frameId == 0 ? nil : -1,
            timeStamp: timeStamp,
            transitionType: transitionType,
            transitionQualifiers: transitionQualifiers.isEmpty ? nil : transitionQualifiers,
            documentId: nil,
            documentLifecycle: nil
        )
        
        print("🧭 [ExtensionManager+WebNavigation] onHistoryStateUpdated: \(url) (tab: \(tabId), frame: \(frameId))")
        fireWebNavigationEvent(eventName: "onHistoryStateUpdated", details: details.dictionary)
    }
    
    /// Fire onCreatedNavigationTarget event to extensions (new tab/window)
    func fireWebNavigationOnCreatedNavigationTarget(sourceTabId: String, sourceFrameId: Int, url: String, tabId: String, timeStamp: TimeInterval? = nil) {
        let eventTimeStamp = timeStamp ?? (Date().timeIntervalSince1970 * 1000)
        
        let details: [String: Any] = [
            "sourceTabId": sourceTabId,
            "sourceFrameId": sourceFrameId,
            "url": url,
            "tabId": tabId,
            "timeStamp": eventTimeStamp
        ]
        
        print("🧭 [ExtensionManager+WebNavigation] onCreatedNavigationTarget: \(url) (source tab: \(sourceTabId), new tab: \(tabId))")
        fireWebNavigationEvent(eventName: "onCreatedNavigationTarget", details: details)
    }
    
    /// Fire onTabReplaced event to extensions (instant pages, prerendering)
    func fireWebNavigationOnTabReplaced(replacedTabId: String, tabId: String, timeStamp: TimeInterval? = nil) {
        let eventTimeStamp = timeStamp ?? (Date().timeIntervalSince1970 * 1000)
        
        let details: [String: Any] = [
            "replacedTabId": replacedTabId,
            "tabId": tabId,
            "timeStamp": eventTimeStamp
        ]
        
        print("🧭 [ExtensionManager+WebNavigation] onTabReplaced: \(replacedTabId) -> \(tabId)")
        fireWebNavigationEvent(eventName: "onTabReplaced", details: details)
        
        // Transfer frame data to new tab
        Self.navigationLock.lock()
        if let frames = Self.navigationFrames[replacedTabId] {
            Self.navigationFrames[tabId] = frames
            Self.navigationFrames.removeValue(forKey: replacedTabId)
        }
        Self.navigationLock.unlock()
    }
    
    // MARK: - Helper: Fire Event to All Extensions
    
    private func fireWebNavigationEvent(eventName: String, details: [String: Any]) {
        print("🧭 [ExtensionManager+WebNavigation] Firing \(eventName) to all extensions")
        
        for context in extensionContexts.values {
            guard let extensionId = getExtensionId(for: context) else { continue }
            
            // Check if extension has webNavigation permission
            if !hasWebNavigationPermission(extensionId: extensionId) {
                continue
            }
            
            // Fire event to background script
            let script = """
            (function() {
                if (typeof chrome !== 'undefined' && chrome.webNavigation && chrome.webNavigation.\(eventName)) {
                    const details = \(toJSONString(details) ?? "{}");
                    console.log('🧭 [WebNavigation Event] \(eventName):', details);
                    chrome.webNavigation.\(eventName).dispatch(details);
                }
            })();
            """
            
            executeScriptInBackground(script: script, for: context)
        }
    }
    
    // MARK: - Helper: Check WebNavigation Permission
    
    private func hasWebNavigationPermission(extensionId: String) -> Bool {
        // Check manifest permissions
        guard let context = extensionContexts.values.first(where: { getExtensionId(for: $0) == extensionId }),
              let manifest = getManifest(for: context),
              let permissions = manifest["permissions"] as? [String] else {
            return false
        }
        
        return permissions.contains("webNavigation")
    }
    
    // MARK: - Helper: Clean Up Navigation Data
    
    /// Clean up navigation data for a closed tab
    func cleanUpNavigationData(forTabId tabId: String) {
        Self.navigationLock.lock()
        Self.navigationFrames.removeValue(forKey: tabId)
        Self.navigationLock.unlock()
        print("🧭 [ExtensionManager+WebNavigation] Cleaned up navigation data for tab \(tabId)")
    }
    
    // MARK: - Helper: JSON Conversion
    
    private func toJSONString(_ dict: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
}

