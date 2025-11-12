/**
 * YouTube Blocker Extension - Popup UI
 */

// DOM elements
const statusEl = document.getElementById('status');
const statusIconEl = document.getElementById('statusIcon');
const statusTextEl = document.getElementById('statusText');
const statusSubtextEl = document.getElementById('statusSubtext');
const loadingEl = document.getElementById('loading');
const controlsEl = document.getElementById('controls');
const btnEnable = document.getElementById('btnEnable');
const btnDisable = document.getElementById('btnDisable');
const btnRefresh = document.getElementById('btnRefresh');
const messageEl = document.getElementById('message');

// Initialize popup
document.addEventListener('DOMContentLoaded', () => {
  checkStatus();

  // Event listeners
  btnEnable.addEventListener('click', enableAccess);
  btnDisable.addEventListener('click', disableAccess);
  btnRefresh.addEventListener('click', checkStatus);
});

/**
 * Check whitelist status
 */
async function checkStatus() {
  showLoading(true);
  hideMessage();

  try {
    const response = await chrome.runtime.sendMessage({ action: 'getStatus' });

    if (response.isWhitelisted) {
      showWhitelistedStatus();
    } else {
      showBlockedStatus();
    }
  } catch (error) {
    console.error('Error checking status:', error);
    showError('Failed to check status. Is the service running?');
    showBlockedStatus();
  } finally {
    showLoading(false);
  }
}

/**
 * Enable YouTube access for this profile
 */
async function enableAccess() {
  showLoading(true);
  hideMessage();

  try {
    const response = await chrome.runtime.sendMessage({ action: 'addToWhitelist' });

    if (response.success) {
      showMessage(response.message || 'YouTube access enabled!', 'success');
      setTimeout(() => {
        checkStatus();
      }, 1000);
    } else {
      showError(response.error || 'Failed to enable access');
      showLoading(false);
    }
  } catch (error) {
    console.error('Error enabling access:', error);
    showError('Failed to enable access. Is the service running?');
    showLoading(false);
  }
}

/**
 * Disable YouTube access for this profile
 */
async function disableAccess() {
  showLoading(true);
  hideMessage();

  try {
    const response = await chrome.runtime.sendMessage({ action: 'removeFromWhitelist' });

    if (response.success) {
      showMessage(response.message || 'YouTube access disabled!', 'success');
      setTimeout(() => {
        checkStatus();
      }, 1000);
    } else {
      showError(response.error || 'Failed to disable access');
      showLoading(false);
    }
  } catch (error) {
    console.error('Error disabling access:', error);
    showError('Failed to disable access. Is the service running?');
    showLoading(false);
  }
}

/**
 * Show whitelisted status
 */
function showWhitelistedStatus() {
  statusEl.className = 'status whitelisted';
  statusIconEl.textContent = '✅';
  statusTextEl.textContent = 'YouTube Access Enabled';
  statusSubtextEl.textContent = 'This profile can access YouTube';

  btnEnable.style.display = 'none';
  btnDisable.style.display = 'block';
}

/**
 * Show blocked status
 */
function showBlockedStatus() {
  statusEl.className = 'status blocked';
  statusIconEl.textContent = '🚫';
  statusTextEl.textContent = 'YouTube Access Blocked';
  statusSubtextEl.textContent = 'Click below to enable access';

  btnEnable.style.display = 'block';
  btnDisable.style.display = 'none';
}

/**
 * Show/hide loading state
 */
function showLoading(show) {
  if (show) {
    loadingEl.classList.add('show');
    controlsEl.style.opacity = '0.5';
    controlsEl.style.pointerEvents = 'none';
  } else {
    loadingEl.classList.remove('show');
    controlsEl.style.opacity = '1';
    controlsEl.style.pointerEvents = 'auto';
  }
}

/**
 * Show message
 */
function showMessage(text, type = 'success') {
  messageEl.textContent = text;
  messageEl.className = `message ${type} show`;
}

/**
 * Show error message
 */
function showError(text) {
  showMessage(text, 'error');
}

/**
 * Hide message
 */
function hideMessage() {
  messageEl.classList.remove('show');
}
