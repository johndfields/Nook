// WebNavigation API Test Suite - Popup Script

console.log('🧪 [WebNavigation Test] Popup script loaded');

let isTestRunning = false;

// Get elements
const runTestsBtn = document.getElementById('runTestsBtn');
const refreshBtn = document.getElementById('refreshBtn');
const clearBtn = document.getElementById('clearBtn');
const resultsContainer = document.getElementById('resultsContainer');
const eventCountEl = document.getElementById('eventCount');
const frameCountEl = document.getElementById('frameCount');
const errorCountEl = document.getElementById('errorCount');
const statusBadge = document.getElementById('statusBadge');

// Format timestamp
function formatTime(timestamp) {
  const date = new Date(timestamp);
  return date.toLocaleTimeString('en-US', { 
    hour12: false, 
    hour: '2-digit', 
    minute: '2-digit', 
    second: '2-digit',
    fractionalSecondDigits: 3
  });
}

// Render event item
function renderEventItem(eventData) {
  const div = document.createElement('div');
  div.className = `event-item ${eventData.status === 'error' ? 'error' : ''}`;
  
  const statusClass = eventData.status === 'error' ? 'status-error' : 'status-success';
  const badge = eventData.status === 'error' ? 
    '<span class="badge badge-error">Error</span>' : 
    '<span class="badge badge-success">Success</span>';
  
  const details = eventData.details || eventData.result || {};
  const detailsStr = JSON.stringify(details, null, 2);
  
  div.innerHTML = `
    <div class="event-header">
      <div>
        <span class="status-indicator ${statusClass}"></span>
        <span class="event-name">${eventData.event || eventData.method}</span>
        ${badge}
      </div>
      <div class="event-time">${formatTime(eventData.timestamp)}</div>
    </div>
    <div class="event-details">${detailsStr}</div>
  `;
  
  return div;
}

// Render frame test item
function renderFrameItem(frameData) {
  const div = document.createElement('div');
  div.className = 'event-item';
  
  const badge = '<span class="badge badge-info">Frame Test</span>';
  const detailsStr = JSON.stringify(frameData.result, null, 2);
  
  div.innerHTML = `
    <div class="event-header">
      <div>
        <span class="status-indicator status-success"></span>
        <span class="event-name">${frameData.method}</span>
        ${badge}
        ${frameData.count !== undefined ? `<span class="badge badge-success">${frameData.count} frames</span>` : ''}
      </div>
      <div class="event-time">${formatTime(frameData.timestamp)}</div>
    </div>
    <div class="event-details">${detailsStr}</div>
  `;
  
  return div;
}

// Update UI with results
function updateUI(results) {
  console.log('🔄 [WebNavigation Test] Updating UI with results:', results);
  
  // Update stats
  eventCountEl.textContent = results.events.length;
  frameCountEl.textContent = results.frames.length;
  errorCountEl.textContent = results.errors.length;
  
  // Update status badge
  if (results.testRunning) {
    statusBadge.textContent = 'Running';
    statusBadge.className = 'badge badge-success';
  } else if (results.events.length > 0) {
    statusBadge.textContent = 'Completed';
    statusBadge.className = 'badge badge-info';
  } else {
    statusBadge.textContent = 'Idle';
    statusBadge.className = 'badge badge-info';
  }
  
  // Clear results container
  resultsContainer.innerHTML = '';
  
  // Show empty state if no results
  if (results.events.length === 0 && results.frames.length === 0 && results.errors.length === 0) {
    resultsContainer.innerHTML = `
      <div class="empty-state">
        <div class="empty-state-icon">🎯</div>
        <div>Click "Run All Tests" to start monitoring navigation events</div>
      </div>
    `;
    return;
  }
  
  // Combine events and frames, sort by timestamp
  const allItems = [
    ...results.events.map(e => ({ ...e, type: 'event' })),
    ...results.frames.map(f => ({ ...f, type: 'frame' })),
    ...results.errors.map(e => ({ ...e, type: 'error', event: 'Error', status: 'error' }))
  ].sort((a, b) => b.timestamp - a.timestamp);
  
  // Render all items
  allItems.forEach(item => {
    if (item.type === 'event' || item.type === 'error') {
      resultsContainer.appendChild(renderEventItem(item));
    } else if (item.type === 'frame') {
      resultsContainer.appendChild(renderFrameItem(item));
    }
  });
}

// Load results from background
function loadResults() {
  chrome.runtime.sendMessage({ action: 'getResults' }, (response) => {
    if (response && response.success) {
      updateUI(response.results);
    } else {
      console.error('❌ Failed to load results:', response);
    }
  });
}

// Run all tests
async function runAllTests() {
  console.log('🧪 [WebNavigation Test] Starting all tests...');
  
  // Start test mode
  chrome.runtime.sendMessage({ action: 'startTest' }, (response) => {
    if (response && response.success) {
      console.log('✅ Test mode started');
      isTestRunning = true;
      runTestsBtn.innerHTML = '<span>⏸️</span><span>Testing...</span>';
      runTestsBtn.disabled = true;
      statusBadge.textContent = 'Running';
      statusBadge.className = 'badge badge-success';
      
      // Show instructions
      alert(`🧪 Test Suite Started!\n\nNow:\n1. Navigate to any website (e.g., https://example.com)\n2. Click links with # (hash changes)\n3. Test history API on SPAs\n4. Watch events appear in real-time!\n\nThis popup will auto-refresh to show results.`);
      
      // Auto-refresh every 2 seconds while testing
      const refreshInterval = setInterval(() => {
        loadResults();
      }, 2000);
      
      // Stop after 60 seconds
      setTimeout(() => {
        clearInterval(refreshInterval);
        chrome.runtime.sendMessage({ action: 'stopTest' }, () => {
          isTestRunning = false;
          runTestsBtn.innerHTML = '<span>▶️</span><span>Run All Tests</span>';
          runTestsBtn.disabled = false;
          loadResults();
          console.log('🏁 Test completed');
        });
      }, 60000);
    }
  });
}

// Clear results
function clearResults() {
  chrome.runtime.sendMessage({ action: 'clearResults' }, (response) => {
    if (response && response.success) {
      console.log('✅ Results cleared');
      loadResults();
    }
  });
}

// Event listeners
runTestsBtn.addEventListener('click', runAllTests);
refreshBtn.addEventListener('click', loadResults);
clearBtn.addEventListener('click', () => {
  if (confirm('Clear all test results?')) {
    clearResults();
  }
});

// Test frame methods for current tab
function testCurrentTabFrames() {
  chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
    if (tabs && tabs.length > 0) {
      const tabId = tabs[0].id.toString();
      chrome.runtime.sendMessage({ 
        action: 'testFrameMethods', 
        tabId: tabId 
      }, (response) => {
        if (response && response.success) {
          console.log('✅ Frame methods tested for current tab');
          setTimeout(loadResults, 500);
        }
      });
    }
  });
}

// Add keyboard shortcut
document.addEventListener('keydown', (e) => {
  if (e.key === 'r' && e.metaKey) {
    e.preventDefault();
    loadResults();
  } else if (e.key === 't' && e.metaKey) {
    e.preventDefault();
    testCurrentTabFrames();
  }
});

// Initial load
loadResults();

console.log('✅ [WebNavigation Test] Popup ready');
console.log('💡 Keyboard shortcuts:');
console.log('  - Cmd+R: Refresh results');
console.log('  - Cmd+T: Test frame methods on current tab');

