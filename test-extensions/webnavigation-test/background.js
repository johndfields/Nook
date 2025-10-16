// WebNavigation API Test Suite - Background Script
// This script listens to all webNavigation events and stores results

console.log('🧪 [WebNavigation Test] Background script loaded');

// Test results storage
const testResults = {
  events: [],
  frames: [],
  errors: [],
  startTime: null,
  testRunning: false
};

// Event listeners for all webNavigation events
const eventListeners = {
  onBeforeNavigate: (details) => {
    console.log('✅ onBeforeNavigate:', details);
    testResults.events.push({
      event: 'onBeforeNavigate',
      timestamp: Date.now(),
      details: details,
      status: 'success'
    });
    updateBadge();
  },

  onCommitted: (details) => {
    console.log('✅ onCommitted:', details);
    testResults.events.push({
      event: 'onCommitted',
      timestamp: Date.now(),
      details: details,
      status: 'success'
    });
    updateBadge();
  },

  onDOMContentLoaded: (details) => {
    console.log('✅ onDOMContentLoaded:', details);
    testResults.events.push({
      event: 'onDOMContentLoaded',
      timestamp: Date.now(),
      details: details,
      status: 'success'
    });
    updateBadge();
  },

  onCompleted: (details) => {
    console.log('✅ onCompleted:', details);
    testResults.events.push({
      event: 'onCompleted',
      timestamp: Date.now(),
      details: details,
      status: 'success'
    });
    updateBadge();
    
    // After navigation completes, test getFrame and getAllFrames
    if (testResults.testRunning) {
      testFrameMethods(details.tabId);
    }
  },

  onErrorOccurred: (details) => {
    console.log('❌ onErrorOccurred:', details);
    testResults.events.push({
      event: 'onErrorOccurred',
      timestamp: Date.now(),
      details: details,
      status: 'error'
    });
    updateBadge();
  },

  onReferenceFragmentUpdated: (details) => {
    console.log('✅ onReferenceFragmentUpdated:', details);
    testResults.events.push({
      event: 'onReferenceFragmentUpdated',
      timestamp: Date.now(),
      details: details,
      status: 'success'
    });
    updateBadge();
  },

  onHistoryStateUpdated: (details) => {
    console.log('✅ onHistoryStateUpdated:', details);
    testResults.events.push({
      event: 'onHistoryStateUpdated',
      timestamp: Date.now(),
      details: details,
      status: 'success'
    });
    updateBadge();
  },

  onCreatedNavigationTarget: (details) => {
    console.log('✅ onCreatedNavigationTarget:', details);
    testResults.events.push({
      event: 'onCreatedNavigationTarget',
      timestamp: Date.now(),
      details: details,
      status: 'success'
    });
    updateBadge();
  },

  onTabReplaced: (details) => {
    console.log('✅ onTabReplaced:', details);
    testResults.events.push({
      event: 'onTabReplaced',
      timestamp: Date.now(),
      details: details,
      status: 'success'
    });
    updateBadge();
  }
};

// Register all event listeners
function registerEventListeners() {
  console.log('🧪 [WebNavigation Test] Registering event listeners...');
  
  if (chrome.webNavigation) {
    chrome.webNavigation.onBeforeNavigate.addListener(eventListeners.onBeforeNavigate);
    chrome.webNavigation.onCommitted.addListener(eventListeners.onCommitted);
    chrome.webNavigation.onDOMContentLoaded.addListener(eventListeners.onDOMContentLoaded);
    chrome.webNavigation.onCompleted.addListener(eventListeners.onCompleted);
    chrome.webNavigation.onErrorOccurred.addListener(eventListeners.onErrorOccurred);
    chrome.webNavigation.onReferenceFragmentUpdated.addListener(eventListeners.onReferenceFragmentUpdated);
    chrome.webNavigation.onHistoryStateUpdated.addListener(eventListeners.onHistoryStateUpdated);
    chrome.webNavigation.onCreatedNavigationTarget.addListener(eventListeners.onCreatedNavigationTarget);
    chrome.webNavigation.onTabReplaced.addListener(eventListeners.onTabReplaced);
    
    console.log('✅ All event listeners registered successfully');
  } else {
    console.error('❌ chrome.webNavigation is not available!');
    testResults.errors.push({
      error: 'chrome.webNavigation is not available',
      timestamp: Date.now()
    });
  }
}

// Test getFrame and getAllFrames methods
function testFrameMethods(tabId) {
  console.log('🧪 [WebNavigation Test] Testing frame methods for tab:', tabId);
  
  // Test getFrame for main frame (frameId: 0)
  chrome.webNavigation.getFrame({ tabId: tabId, frameId: 0 }, (frame) => {
    console.log('✅ getFrame result:', frame);
    testResults.frames.push({
      method: 'getFrame',
      tabId: tabId,
      frameId: 0,
      result: frame,
      timestamp: Date.now(),
      status: frame ? 'success' : 'no_frame'
    });
    updateBadge();
  });
  
  // Test getAllFrames
  chrome.webNavigation.getAllFrames({ tabId: tabId }, (frames) => {
    console.log('✅ getAllFrames result:', frames);
    testResults.frames.push({
      method: 'getAllFrames',
      tabId: tabId,
      result: frames,
      count: frames ? frames.length : 0,
      timestamp: Date.now(),
      status: 'success'
    });
    updateBadge();
  });
}

// Update extension badge with event count
function updateBadge() {
  const count = testResults.events.length;
  chrome.action.setBadgeText({ text: count > 0 ? count.toString() : '' });
  chrome.action.setBadgeBackgroundColor({ color: '#4CAF50' });
}

// Clear test results
function clearResults() {
  testResults.events = [];
  testResults.frames = [];
  testResults.errors = [];
  testResults.startTime = null;
  testResults.testRunning = false;
  chrome.action.setBadgeText({ text: '' });
  console.log('🧪 [WebNavigation Test] Results cleared');
}

// Message handler from popup
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  console.log('📬 [WebNavigation Test] Received message:', message);
  
  switch (message.action) {
    case 'getResults':
      sendResponse({ success: true, results: testResults });
      break;
      
    case 'clearResults':
      clearResults();
      sendResponse({ success: true, message: 'Results cleared' });
      break;
      
    case 'startTest':
      testResults.testRunning = true;
      testResults.startTime = Date.now();
      clearResults();
      testResults.testRunning = true;
      testResults.startTime = Date.now();
      sendResponse({ success: true, message: 'Test started' });
      break;
      
    case 'stopTest':
      testResults.testRunning = false;
      sendResponse({ success: true, message: 'Test stopped' });
      break;
      
    case 'testFrameMethods':
      if (message.tabId) {
        testFrameMethods(message.tabId);
        sendResponse({ success: true, message: 'Frame methods tested' });
      } else {
        sendResponse({ success: false, error: 'No tabId provided' });
      }
      break;
      
    default:
      sendResponse({ success: false, error: 'Unknown action' });
  }
  
  return true; // Keep message channel open for async response
});

// Initialize
registerEventListeners();
console.log('🧪 [WebNavigation Test] Background script ready');

