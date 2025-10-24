//
//  ExtensionManager+FontSettings.swift
//  Nook
//
//  Implements chrome.fontSettings.* API stub for web extension compatibility
//  Dark Reader and other extensions require this API to function properly
//

import Foundation
import WebKit

extension ExtensionManager {
    
    // MARK: - chrome.fontSettings API (Stub Implementation)
    
    /// Generates the JavaScript for the chrome.fontSettings API stub
    /// This is a minimal implementation to prevent extension crashes when fontSettings is accessed
    /// The actual font settings are not persisted or applied - this is just for compatibility
    func generateFontSettingsAPIScript(extensionId: String) -> String {
        return """
        // chrome.fontSettings API Implementation (Stub)
        console.log('🔧 [FontSettings] Initializing chrome.fontSettings API for extension: \(extensionId)');
        
        if (!chrome.fontSettings) {
            chrome.fontSettings = {
                // Get list of available fonts
                getFontList: function(details, callback) {
                    // Handle both (details, callback) and (callback) signatures
                    const cb = typeof details === 'function' ? details : callback;
                    
                    // Return a list of common system fonts
                    const fonts = [
                        {fontId: 'system-ui', displayName: 'System Font'},
                        {fontId: 'Arial', displayName: 'Arial'},
                        {fontId: 'Helvetica', displayName: 'Helvetica'},
                        {fontId: 'Times New Roman', displayName: 'Times New Roman'},
                        {fontId: 'Courier New', displayName: 'Courier New'},
                        {fontId: 'Verdana', displayName: 'Verdana'},
                        {fontId: 'Georgia', displayName: 'Georgia'},
                        {fontId: 'Palatino', displayName: 'Palatino'},
                        {fontId: 'Garamond', displayName: 'Garamond'},
                        {fontId: 'Comic Sans MS', displayName: 'Comic Sans MS'},
                        {fontId: 'Trebuchet MS', displayName: 'Trebuchet MS'},
                        {fontId: 'Arial Black', displayName: 'Arial Black'},
                        {fontId: 'Impact', displayName: 'Impact'}
                    ];
                    
                    if (cb) {
                        setTimeout(() => cb(fonts), 0);
                    }
                    return Promise.resolve(fonts);
                },
                
                // Clear font setting
                clearFont: function(details, callback) {
                    console.log('[FontSettings] clearFont called:', details);
                    if (callback) {
                        setTimeout(callback, 0);
                    }
                    return Promise.resolve();
                },
                
                // Get font setting
                getFont: function(details, callback) {
                    console.log('[FontSettings] getFont called:', details);
                    
                    // Return a default font based on the generic family
                    const defaultFonts = {
                        'standard': 'Times New Roman',
                        'serif': 'Times New Roman',
                        'sansserif': 'Arial',
                        'fixed': 'Courier New',
                        'cursive': 'Comic Sans MS',
                        'fantasy': 'Impact'
                    };
                    
                    const genericFamily = details?.genericFamily || 'standard';
                    const fontId = defaultFonts[genericFamily] || 'Arial';
                    
                    const result = {
                        fontId: fontId,
                        levelOfControl: 'controllable_by_this_extension'
                    };
                    
                    if (callback) {
                        setTimeout(() => callback(result), 0);
                    }
                    return Promise.resolve(result);
                },
                
                // Set font
                setFont: function(details, callback) {
                    console.log('[FontSettings] setFont called:', details);
                    if (callback) {
                        setTimeout(callback, 0);
                    }
                    return Promise.resolve();
                },
                
                // Clear default font size
                clearDefaultFontSize: function(details, callback) {
                    console.log('[FontSettings] clearDefaultFontSize called:', details);
                    if (callback) {
                        setTimeout(callback, 0);
                    }
                    return Promise.resolve();
                },
                
                // Get default font size
                getDefaultFontSize: function(details, callback) {
                    console.log('[FontSettings] getDefaultFontSize called:', details);
                    
                    const result = {
                        pixelSize: 16,
                        levelOfControl: 'controllable_by_this_extension'
                    };
                    
                    if (callback) {
                        setTimeout(() => callback(result), 0);
                    }
                    return Promise.resolve(result);
                },
                
                // Set default font size
                setDefaultFontSize: function(details, callback) {
                    console.log('[FontSettings] setDefaultFontSize called:', details);
                    if (callback) {
                        setTimeout(callback, 0);
                    }
                    return Promise.resolve();
                },
                
                // Clear minimum font size
                clearMinimumFontSize: function(details, callback) {
                    console.log('[FontSettings] clearMinimumFontSize called:', details);
                    if (callback) {
                        setTimeout(callback, 0);
                    }
                    return Promise.resolve();
                },
                
                // Get minimum font size
                getMinimumFontSize: function(details, callback) {
                    console.log('[FontSettings] getMinimumFontSize called:', details);
                    
                    const result = {
                        pixelSize: 6,
                        levelOfControl: 'controllable_by_this_extension'
                    };
                    
                    if (callback) {
                        setTimeout(() => callback(result), 0);
                    }
                    return Promise.resolve(result);
                },
                
                // Set minimum font size
                setMinimumFontSize: function(details, callback) {
                    console.log('[FontSettings] setMinimumFontSize called:', details);
                    if (callback) {
                        setTimeout(callback, 0);
                    }
                    return Promise.resolve();
                },
                
                // Event stub for font settings changes
                onFontChanged: {
                    addListener: function(listener) {
                        console.log('[FontSettings] onFontChanged.addListener called');
                        // Store listener but never fire it since we don't actually change fonts
                    },
                    removeListener: function(listener) {
                        console.log('[FontSettings] onFontChanged.removeListener called');
                    },
                    hasListener: function(listener) {
                        return false;
                    }
                },
                
                onDefaultFontSizeChanged: {
                    addListener: function(listener) {
                        console.log('[FontSettings] onDefaultFontSizeChanged.addListener called');
                    },
                    removeListener: function(listener) {
                        console.log('[FontSettings] onDefaultFontSizeChanged.removeListener called');
                    },
                    hasListener: function(listener) {
                        return false;
                    }
                },
                
                onMinimumFontSizeChanged: {
                    addListener: function(listener) {
                        console.log('[FontSettings] onMinimumFontSizeChanged.addListener called');
                    },
                    removeListener: function(listener) {
                        console.log('[FontSettings] onMinimumFontSizeChanged.removeListener called');
                    },
                    hasListener: function(listener) {
                        return false;
                    }
                }
            };
            
            console.log('✅ [Nook] chrome.fontSettings stub initialized');
            console.log('   Note: This is a stub implementation for compatibility');
            console.log('   Font settings are not persisted or applied to the browser');
        }
        """
    }
}

