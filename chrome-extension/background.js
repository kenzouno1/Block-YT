/**
 * YouTube Blocker Extension - Background Service Worker
 */

const API_BASE = 'http://127.0.0.1:9876/api';
const PROXY_HOST = '127.0.0.1';
const PROXY_PORT = 8888;

// Initialize extension - Auto-enable on install
chrome.runtime.onInstalled.addListener(async (details) => {
  console.log('YouTube Blocker Extension installed/updated');

  // Check if we have existing token
  const existingToken = await getStoredValue('whitelistToken');

  if (existingToken) {
    // Already whitelisted, verify token is still valid
    console.log('Existing token found, verifying...');
    const isValid = await checkWhitelistStatus();

    if (!isValid) {
      // Token invalid, re-enable
      console.log('Token invalid, re-enabling...');
      try {
        const result = await addToWhitelist();
        if (result.success) {
          console.log('✅ Re-enabled successfully!');
        }
      } catch (error) {
        console.error('Failed to re-enable:', error);
      }
    } else {
      console.log('✅ Token valid, already enabled!');
    }
  } else {
    // No token, auto-enable
    console.log('No token found, auto-enabling YouTube access...');
    try {
      const result = await addToWhitelist();
      if (result.success) {
        console.log('✅ Auto-enabled successfully!');
      }
    } catch (error) {
      console.error('Failed to auto-enable:', error);
    }
  }
});

// Check if profile is whitelisted on startup
chrome.runtime.onStartup.addListener(() => {
  console.log('Chrome started, checking whitelist status');
  checkWhitelistStatus();
});

/**
 * Generate a unique profile ID based on Chrome profile
 */
async function getProfileId() {
  // Use Chrome's profile directory path as unique identifier
  // This is stored in localStorage and persists across sessions
  let profileId = await getStoredValue('profileId');

  if (!profileId) {
    // Generate a unique ID for this profile
    profileId = 'profile_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
    await setStoredValue('profileId', profileId);
  }

  return profileId;
}

/**
 * Get profile name (directory name)
 */
async function getProfileName() {
  // Try to get profile name from Chrome API
  try {
    // Profile path is not directly accessible, use a default name
    const profileId = await getProfileId();
    return `Chrome Profile ${profileId.split('_')[1]}`;
  } catch (e) {
    return 'Default Profile';
  }
}

/**
 * Check if current profile is whitelisted
 */
async function checkWhitelistStatus() {
  const token = await getStoredValue('whitelistToken');

  if (!token) {
    console.log('No whitelist token found');
    await setStoredValue('isWhitelisted', false);
    await clearProxy();
    return false;
  }

  try {
    const response = await fetch(`${API_BASE}/validate/${token}`);
    const data = await response.json();

    if (data.valid) {
      console.log('Profile is whitelisted');
      await setStoredValue('isWhitelisted', true);
      await configureProxy(token);
      return true;
    } else {
      console.log('Token is invalid');
      await setStoredValue('isWhitelisted', false);
      await setStoredValue('whitelistToken', null);
      await clearProxy();
      return false;
    }
  } catch (error) {
    console.error('Error checking whitelist status:', error);
    await setStoredValue('isWhitelisted', false);
    await clearProxy();
    return false;
  }
}

/**
 * Add current profile to whitelist
 */
async function addToWhitelist() {
  try {
    const profileId = await getProfileId();
    const profileName = await getProfileName();

    const response = await fetch(`${API_BASE}/whitelist/add`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        profile_id: profileId,
        profile_name: profileName,
      }),
    });

    if (!response.ok) {
      throw new Error('Failed to add to whitelist');
    }

    const data = await response.json();

    if (data.success) {
      await setStoredValue('whitelistToken', data.token);
      await setStoredValue('isWhitelisted', true);
      await configureProxy(data.token);
      console.log('Successfully added to whitelist');
      return { success: true, message: 'Profile whitelisted successfully!' };
    } else {
      throw new Error(data.error || 'Unknown error');
    }
  } catch (error) {
    console.error('Error adding to whitelist:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Remove current profile from whitelist
 */
async function removeFromWhitelist() {
  try {
    const token = await getStoredValue('whitelistToken');

    if (!token) {
      return { success: false, error: 'No whitelist token found' };
    }

    const response = await fetch(`${API_BASE}/whitelist/remove`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        token: token,
      }),
    });

    if (!response.ok) {
      throw new Error('Failed to remove from whitelist');
    }

    const data = await response.json();

    if (data.success) {
      await setStoredValue('whitelistToken', null);
      await setStoredValue('isWhitelisted', false);
      await clearProxy();
      console.log('Successfully removed from whitelist');
      return { success: true, message: 'Profile removed from whitelist' };
    } else {
      throw new Error(data.error || 'Unknown error');
    }
  } catch (error) {
    console.error('Error removing from whitelist:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Configure proxy for this profile
 * IMPORTANT: Only proxy YouTube domains, let other traffic go direct
 */
async function configureProxy(token) {
  // PAC script to only proxy YouTube domains
  // NOTE: Must use string concatenation for PROXY_HOST and PROXY_PORT
  const pacScript = `
    function FindProxyForURL(url, host) {
      // Only proxy YouTube-related domains
      // Must check both exact match and subdomain match
      if (host == "youtube.com" ||
          shExpMatch(host, "*.youtube.com") ||
          host == "youtu.be" ||
          shExpMatch(host, "*.youtu.be") ||
          host == "googlevideo.com" ||
          shExpMatch(host, "*.googlevideo.com") ||
          host == "ytimg.com" ||
          shExpMatch(host, "*.ytimg.com") ||
          host == "youtube-nocookie.com" ||
          shExpMatch(host, "*.youtube-nocookie.com") ||
          host == "youtubei.googleapis.com" ||
          shExpMatch(host, "*.youtubei.googleapis.com") ||
          host == "youtube-ui.l.google.com") {
        return "PROXY ` + PROXY_HOST + `:` + PROXY_PORT + `";
      }

      // All other traffic goes direct (no proxy)
      return "DIRECT";
    }
  `;

  const config = {
    mode: "pac_script",
    pacScript: {
      data: pacScript
    }
  };

  try {
    await chrome.proxy.settings.set({
      value: config,
      scope: 'regular'
    });

    // Store token for proxy requests
    await setStoredValue('proxyToken', token);

    // Update header modification rules
    await updateHeaderRules();

    console.log('Proxy configured successfully (YouTube domains only)');
  } catch (error) {
    console.error('Error configuring proxy:', error);
  }
}

/**
 * Clear proxy configuration
 */
async function clearProxy() {
  try {
    await chrome.proxy.settings.clear({
      scope: 'regular'
    });

    await setStoredValue('proxyToken', null);

    // Clear header modification rules
    await updateHeaderRules();

    console.log('Proxy cleared successfully');
  } catch (error) {
    console.error('Error clearing proxy:', error);
  }
}

/**
 * Add token to proxy requests using declarativeNetRequest
 */
async function updateHeaderRules() {
  const token = await getStoredValue('proxyToken');

  // Remove existing rules
  const existingRules = await chrome.declarativeNetRequest.getDynamicRules();
  const ruleIds = existingRules.map(rule => rule.id);

  if (ruleIds.length > 0) {
    await chrome.declarativeNetRequest.updateDynamicRules({
      removeRuleIds: ruleIds
    });
  }

  // Add new rule with token if available
  if (token) {
    await chrome.declarativeNetRequest.updateDynamicRules({
      addRules: [{
        id: 1,
        priority: 1,
        action: {
          type: 'modifyHeaders',
          requestHeaders: [{
            header: 'X-YT-Blocker-Token',
            operation: 'set',
            value: token
          }]
        },
        condition: {
          urlFilter: '*youtube.com*',
          resourceTypes: ['main_frame', 'sub_frame', 'xmlhttprequest']
        }
      }]
    });
    console.log('Header modification rule added');
  }
}

/**
 * Handle messages from popup
 */
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === 'getStatus') {
    checkWhitelistStatus().then(isWhitelisted => {
      sendResponse({ isWhitelisted });
    });
    return true; // Keep channel open for async response
  }

  if (request.action === 'addToWhitelist') {
    addToWhitelist().then(result => {
      sendResponse(result);
    });
    return true;
  }

  if (request.action === 'removeFromWhitelist') {
    removeFromWhitelist().then(result => {
      sendResponse(result);
    });
    return true;
  }
});

/**
 * Storage helpers
 */
async function getStoredValue(key) {
  return new Promise((resolve) => {
    chrome.storage.local.get([key], (result) => {
      resolve(result[key]);
    });
  });
}

async function setStoredValue(key, value) {
  return new Promise((resolve) => {
    chrome.storage.local.set({ [key]: value }, () => {
      resolve();
    });
  });
}
