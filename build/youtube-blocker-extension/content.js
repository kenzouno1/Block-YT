/**
 * YouTube Studio - Whitelist Approach
 * 1. Only allows access to whitelisted pages (Videos)
 * 2. Removes all menu items except whitelisted ones
 */

(function() {
  'use strict';

  // Configuration: WHITELIST - Only these items are allowed
  const ALLOWED_ITEMS = [
    {
      name: 'Content',  // This is the "Content" menu (Videos page)
      urlPattern: 'videos',
      isDefaultPage: false
    }
  ];

  /**
   * Check if current URL is allowed, otherwise redirect to Videos
   */
  function enforceWhitelist() {
    const currentUrl = window.location.href;

    // Check if URL ends with just channel ID (default is dashboard - not allowed)
    if (/\/channel\/[^\/]+\/?$/.test(currentUrl)) {
      console.log('[YT Blocker] Default page (dashboard) blocked, redirecting to videos...');
      redirectToVideos();
      return;
    }

    // Check if this is a video detail page (/video/VIDEO_ID/...)
    const videoMatch = currentUrl.match(/\/video\/[^\/]+\/([^\/\?#]+)/);
    if (videoMatch) {
      const videoSection = videoMatch[1];

      // Only allow 'edit' section in video detail page
      // Block: analytics, comments, etc.
      if (videoSection !== 'edit') {
        console.log(`[YT Blocker] Video page section "${videoSection}" blocked, redirecting to edit...`);
        redirectToVideoEdit();
        return;
      }
      // 'edit' is allowed, continue
      return;
    }

    // Check if current path is in whitelist (for channel pages)
    let isAllowed = false;
    for (const item of ALLOWED_ITEMS) {
      if (currentUrl.includes(`/${item.urlPattern}`)) {
        isAllowed = true;
        break;
      }
    }

    // If not in whitelist, redirect to videos
    if (!isAllowed) {
      // Extract what page user tried to access
      const pathMatch = currentUrl.match(/\/channel\/[^\/]+\/([^\/\?#]+)/);
      const attemptedPage = pathMatch ? pathMatch[1] : 'unknown';

      console.log(`[YT Blocker] Page "${attemptedPage}" not whitelisted, redirecting to videos...`);
      redirectToVideos();
    }
  }

  /**
   * Redirect to Videos page
   */
  function redirectToVideos() {
    const channelMatch = window.location.href.match(/\/channel\/([^\/]+)/);
    if (channelMatch && channelMatch[1]) {
      const channelId = channelMatch[1];
      const newUrl = `https://studio.youtube.com/channel/${channelId}/videos`;
      window.location.replace(newUrl);
    }
  }

  /**
   * Redirect to Video Edit page
   */
  function redirectToVideoEdit() {
    const videoMatch = window.location.href.match(/\/video\/([^\/]+)/);
    if (videoMatch && videoMatch[1]) {
      const videoId = videoMatch[1];
      const newUrl = `https://studio.youtube.com/video/${videoId}/edit`;
      window.location.replace(newUrl);
    }
  }

  /**
   * Remove all menu elements except whitelisted ones
   */
  function removeNonWhitelistedMenus() {
    // Find all menu links
    const menuLinks = document.querySelectorAll('a.menu-item-link');

    menuLinks.forEach(link => {
      const textElement = link.querySelector('.nav-item-text');
      if (textElement) {
        const menuText = textElement.textContent.trim();

        // Check if this menu item is in whitelist
        let isAllowed = false;
        for (const item of ALLOWED_ITEMS) {
          if (menuText === item.name) {
            isAllowed = true;
            break;
          }
        }

        // If not in whitelist, remove it
        if (!isAllowed) {
          const listItem = link.closest('li[role="presentation"]');
          if (listItem) {
            console.log(`[YT Blocker] Removing non-whitelisted menu: ${menuText}`);
            listItem.remove();
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
        console.log('[YT Blocker] URL changed, enforcing whitelist...');
        enforceWhitelist();
      }
    }, 500);

    // Also monitor history pushState/replaceState
    const originalPushState = history.pushState;
    const originalReplaceState = history.replaceState;

    history.pushState = function() {
      originalPushState.apply(this, arguments);
      setTimeout(enforceWhitelist, 100);
    };

    history.replaceState = function() {
      originalReplaceState.apply(this, arguments);
      setTimeout(enforceWhitelist, 100);
    };

    // Monitor popstate (back/forward buttons)
    window.addEventListener('popstate', () => {
      setTimeout(enforceWhitelist, 100);
    });
  }

  /**
   * Initialize
   */
  function init() {
    console.log('[YT Blocker] Content script initialized for YouTube Studio');
    console.log(`[YT Blocker] Whitelist mode: Only allowing ${ALLOWED_ITEMS.map(i => i.name).join(', ')}`);

    // Immediately enforce whitelist
    enforceWhitelist();

    // Monitor URL changes for SPA navigation
    monitorUrlChanges();

    // Remove non-whitelisted menu elements
    removeNonWhitelistedMenus();

    // Watch for DOM changes to remove non-whitelisted menus if they reappear
    const observer = new MutationObserver(() => {
      removeNonWhitelistedMenus();
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
