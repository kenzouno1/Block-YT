/**
 * YouTube Studio - Block Access to Specific Pages
 * 1. Blocks access to specified URLs (redirect to Videos page)
 * 2. Removes specified menu items from navigation
 */

(function() {
  'use strict';

  // Configuration: Add menu items to block here
  const BLOCKED_ITEMS = [
    {
      name: 'Dashboard',
      urlPattern: 'dashboard',
      // Also block when URL ends with channel ID only (default is dashboard)
      isDefaultPage: true
    },
    {
      name: 'Community',
      urlPattern: 'community',
      isDefaultPage: false
    },
    {
      name: 'Comments',
      urlPattern: 'comments',
      isDefaultPage: false
    }
  ];

  /**
   * Check if current URL matches blocked pages and redirect
   */
  function blockPageAccess() {
    const currentUrl = window.location.href;

    // Check each blocked item
    for (const item of BLOCKED_ITEMS) {
      let isBlocked = false;

      // Check if URL contains the blocked path
      if (currentUrl.includes(`/${item.urlPattern}`)) {
        isBlocked = true;
      }

      // Check if it's a default page (channel ID only)
      if (item.isDefaultPage && /\/channel\/[^\/]+\/?$/.test(currentUrl)) {
        isBlocked = true;
      }

      if (isBlocked) {
        console.log(`[YT Blocker] ${item.name} access blocked, redirecting...`);

        // Extract channel ID from URL
        const channelMatch = currentUrl.match(/\/channel\/([^\/]+)/);
        if (channelMatch && channelMatch[1]) {
          const channelId = channelMatch[1];
          // Redirect to Videos page instead
          const newUrl = `https://studio.youtube.com/channel/${channelId}/videos`;

          // Use replace to prevent back button returning to blocked page
          window.location.replace(newUrl);
          return; // Stop checking other items
        }
      }
    }
  }

  /**
   * Remove blocked menu elements from navigation
   */
  function removeBlockedElements() {
    // Find all menu links
    const menuLinks = document.querySelectorAll('a.menu-item-link');

    menuLinks.forEach(link => {
      // Check if this is a blocked menu item
      const textElement = link.querySelector('.nav-item-text');
      if (textElement) {
        const menuText = textElement.textContent.trim();

        // Check against all blocked items
        for (const item of BLOCKED_ITEMS) {
          if (menuText === item.name) {
            // Remove the parent <li> element
            const listItem = link.closest('li[role="presentation"]');
            if (listItem) {
              console.log(`[YT Blocker] Removing ${item.name} menu element`);
              listItem.remove();
            }
            break;
          }
        }
      }
    });
  }

  /**
   * Monitor URL changes (YouTube Studio is a SPA)
   */
  function monitorUrlChanges() {
    let lastUrl = window.location.href;

    // Check URL periodically
    setInterval(() => {
      const currentUrl = window.location.href;
      if (currentUrl !== lastUrl) {
        lastUrl = currentUrl;
        console.log('[YT Blocker] URL changed, checking for blocked pages...');
        blockPageAccess();
      }
    }, 500);

    // Also monitor history pushState/replaceState
    const originalPushState = history.pushState;
    const originalReplaceState = history.replaceState;

    history.pushState = function() {
      originalPushState.apply(this, arguments);
      setTimeout(blockPageAccess, 100);
    };

    history.replaceState = function() {
      originalReplaceState.apply(this, arguments);
      setTimeout(blockPageAccess, 100);
    };

    // Monitor popstate (back/forward buttons)
    window.addEventListener('popstate', () => {
      setTimeout(blockPageAccess, 100);
    });
  }

  /**
   * Initialize
   */
  function init() {
    console.log('[YT Blocker] Content script initialized for YouTube Studio');
    console.log(`[YT Blocker] Blocking ${BLOCKED_ITEMS.length} pages: ${BLOCKED_ITEMS.map(i => i.name).join(', ')}`);

    // Immediately check and block page access
    blockPageAccess();

    // Monitor URL changes for SPA navigation
    monitorUrlChanges();

    // Remove blocked menu elements
    removeBlockedElements();

    // Watch for DOM changes to remove blocked elements if they reappear
    const observer = new MutationObserver(() => {
      removeBlockedElements();
    });

    // Observe navigation changes
    observer.observe(document.body, {
      childList: true,
      subtree: true
    });
  }

  // Wait for DOM to be ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
