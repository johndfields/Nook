# 🧪 WebNavigation API Test Suite

A comprehensive test extension for the chrome.webNavigation API implementation in Nook.

## 📋 Features

### Event Monitoring
- ✅ **onBeforeNavigate** - Fires before navigation starts
- ✅ **onCommitted** - Fires when navigation is committed
- ✅ **onDOMContentLoaded** - Fires when DOM content loaded
- ✅ **onCompleted** - Fires when page fully loads
- ✅ **onErrorOccurred** - Fires on navigation errors
- ✅ **onReferenceFragmentUpdated** - Fires on hash (#fragment) changes
- ✅ **onHistoryStateUpdated** - Fires on history.pushState/replaceState
- ✅ **onCreatedNavigationTarget** - Fires when new tab/window created
- ✅ **onTabReplaced** - Fires for instant pages/prerendering

### Method Testing
- ✅ **chrome.webNavigation.getFrame()** - Get frame information
- ✅ **chrome.webNavigation.getAllFrames()** - Get all frames for a tab

### UI Features
- 🎨 Beautiful gradient UI with real-time updates
- 📊 Live statistics (events, frames, errors)
- 🔄 Auto-refresh during test runs
- 📝 Detailed event logs with timestamps
- 🎯 Single-button test execution
- ⌨️ Keyboard shortcuts

## 🚀 Installation

1. **Open Nook**
2. **Load Extension:**
   - Go to Nook's extension settings
   - Click "Load Extension"
   - Select the `test-extensions/webnavigation-test` folder
3. **Done!** The extension icon should appear in your toolbar

## 🧪 How to Run Tests

### Automated Test Suite

1. **Click the extension icon** in Nook's toolbar
2. **Click "Run All Tests"** button
3. **Follow the test steps:**
   - Navigate to any website (e.g., https://example.com)
   - Click links with hash fragments (e.g., #section)
   - Test history API on single-page apps
   - Try error pages (e.g., https://thisurldoesnotexist.com)
4. **Watch results** appear in real-time!

The test suite will run for 60 seconds, then automatically stop and display results.

### Manual Testing

#### Test Navigation Events
```javascript
// Open any website
window.location.href = 'https://example.com';

// Expected events:
// 1. onBeforeNavigate
// 2. onCommitted
// 3. onDOMContentLoaded (maybe)
// 4. onCompleted
```

#### Test Hash Changes
```javascript
// Navigate to a hash
window.location.hash = '#test';

// Expected event:
// - onReferenceFragmentUpdated
```

#### Test History API
```javascript
// Push state
history.pushState({}, '', '/new-url');

// Expected event:
// - onHistoryStateUpdated
```

#### Test Frame Methods
```javascript
// In popup console or background
chrome.webNavigation.getFrame({ tabId: 'YOUR_TAB_ID', frameId: 0 }, (frame) => {
  console.log('Frame:', frame);
});

chrome.webNavigation.getAllFrames({ tabId: 'YOUR_TAB_ID' }, (frames) => {
  console.log('All frames:', frames);
});
```

#### Test Error Handling
```javascript
// Navigate to invalid URL
window.location.href = 'https://thisurldoesnotexist.com';

// Expected events:
// 1. onBeforeNavigate
// 2. onErrorOccurred (with error details)
```

## ⌨️ Keyboard Shortcuts

- **Cmd+R** - Refresh results
- **Cmd+T** - Test frame methods on current tab

## 📊 Understanding Results

### Event Log
Each event displays:
- **Event name** (e.g., onBeforeNavigate)
- **Status badge** (Success/Error/Info)
- **Timestamp** (precise timing)
- **Full details** (JSON payload)

### Statistics
- **Events** - Total navigation events fired
- **Frames** - Total frame method calls
- **Errors** - Total error events

### Status Badge
- **Idle** - No tests running
- **Running** - Test suite active
- **Completed** - Test suite finished

## 🐛 Debugging

### Enable Verbose Logging

**In Background Script:**
Open browser console and check for:
```
🧪 [WebNavigation Test] Background script loaded
✅ All event listeners registered successfully
✅ onBeforeNavigate: https://example.com (tab: ..., frame: 0)
```

**In Popup:**
Right-click popup → Inspect → Console:
```
🧪 [WebNavigation Test] Popup script loaded
🔄 [WebNavigation Test] Updating UI with results: ...
```

### Common Issues

**No events firing:**
- Check that extension has `webNavigation` permission
- Verify webNavigation API is implemented in Nook
- Check browser console for errors

**Frame methods returning null:**
- Navigate to a page first (frames are created on navigation)
- Wait for onCompleted event before testing frame methods
- Check that tab ID is correct

**Events missing:**
- Some events (onDOMContentLoaded) may not fire on all pages
- Check timing - events fire in specific order
- Verify event listeners are registered (check background console)

## 📁 File Structure

```
webnavigation-test/
├── manifest.json          # Extension configuration
├── background.js          # Event listeners and test logic
├── popup.html            # UI layout
├── popup.js              # UI interactions
├── icon16.png           # Extension icons
├── icon48.png
├── icon128.png
└── README.md            # This file
```

## 🧑‍💻 Development

### Modify Event Handlers

Edit `background.js` and update the `eventListeners` object:

```javascript
const eventListeners = {
  onBeforeNavigate: (details) => {
    console.log('✅ onBeforeNavigate:', details);
    // Add custom logic here
  },
  // ... other events
};
```

### Customize UI

Edit `popup.html` and `popup.js` to change:
- Colors and styling
- Layout and components
- Statistics and metrics
- Result formatting

### Add New Tests

In `background.js`, add to message handler:

```javascript
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  switch (message.action) {
    case 'myCustomTest':
      // Run your test
      sendResponse({ success: true });
      break;
  }
});
```

## 🎯 Expected Test Results

### Basic Navigation Test
```
Events captured:
1. onBeforeNavigate (url: https://example.com)
2. onCommitted (url: https://example.com)
3. onCompleted (url: https://example.com)

Frame data:
- getFrame: { frameId: 0, url: "https://example.com", ... }
- getAllFrames: [{ frameId: 0, ... }]
```

### Hash Change Test
```
Events captured:
1. onReferenceFragmentUpdated (url: https://example.com#section)
```

### History API Test
```
Events captured:
1. onHistoryStateUpdated (url: https://example.com/new-path)
```

### Error Test
```
Events captured:
1. onBeforeNavigate (url: https://invalid.com)
2. onErrorOccurred (error: "net::ERR_NAME_NOT_RESOLVED")
```

## 📝 Notes

- Extension badge shows event count
- Results persist until cleared
- Test mode auto-stops after 60 seconds
- All events logged to background console
- Frame data stored per tab

## 🤝 Contributing

Found a bug? Want to add features?

1. Modify the extension code
2. Test thoroughly in Nook
3. Submit your changes

## 📄 License

This test extension is part of the Nook webNavigation API implementation.

