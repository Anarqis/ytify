/// <reference lib="webworker" />
import { precacheAndRoute, cleanupOutdatedCaches } from 'workbox-precaching';
import { registerRoute, NavigationRoute, Route } from 'workbox-routing';
import { CacheFirst, StaleWhileRevalidate, NetworkFirst } from 'workbox-strategies';
import { ExpirationPlugin } from 'workbox-expiration';
import { CacheableResponsePlugin } from 'workbox-cacheable-response';
import { RangeRequestsPlugin } from 'workbox-range-requests';
import { BackgroundSyncPlugin } from 'workbox-background-sync';

declare const self: ServiceWorkerGlobalScope;

// =============================================================================
// 🔑 CACHE NAMES — Versioned for purge-on-deploy
// =============================================================================
const CACHE_VERSION = 'v2';
const CACHE_NAMES = {
  audio: `audio-cache-${CACHE_VERSION}`,
  images: `images-cache-${CACHE_VERSION}`,
  api: `api-cache-${CACHE_VERSION}`,
  navigation: `navigation-cache-${CACHE_VERSION}`,
  // User data caches — NEVER auto-purged
  library: 'library-cache-v1',
} as const;

// Caches to PRESERVE across deploys (user data only)
const PRESERVED_CACHES = new Set<string>([CACHE_NAMES.library]);

// Clean up old caches
cleanupOutdatedCaches();

// Precache static assets from build
precacheAndRoute(self.__WB_MANIFEST);

// =============================================================================
// 🎵 AUDIO STREAMING CACHE
// =============================================================================
const audioRoute = new Route(
  ({ url }) => {
    if (url.hostname.includes('googlevideo.com')) return true;
    if (url.hostname.includes('saavncdn.com')) return true;
    if (url.hostname.includes('sndcdn.com')) return true;
    if (url.pathname.includes('/audio/')) return true;
    return false;
  },
  new CacheFirst({
    cacheName: CACHE_NAMES.audio,
    plugins: [
      new CacheableResponsePlugin({ statuses: [200, 206] }),
      new RangeRequestsPlugin(),
      new ExpirationPlugin({
        maxEntries: 100,
        maxAgeSeconds: 7 * 24 * 60 * 60,
        purgeOnQuotaError: true,
      }),
    ],
  })
);
registerRoute(audioRoute);

// =============================================================================
// 🖼️ IMAGE CACHE
// =============================================================================
const imageRoute = new Route(
  ({ request, url }) => {
    if (request.destination === 'image') return true;
    if (url.hostname.includes('ytimg.com')) return true;
    if (url.hostname.includes('ggpht.com')) return true;
    if (url.hostname.includes('scdn.co')) return true;
    return false;
  },
  new CacheFirst({
    cacheName: CACHE_NAMES.images,
    plugins: [
      new CacheableResponsePlugin({ statuses: [0, 200] }),
      new ExpirationPlugin({
        maxEntries: 500,
        maxAgeSeconds: 30 * 24 * 60 * 60,
      }),
    ],
  })
);
registerRoute(imageRoute);

// =============================================================================
// 📚 LIBRARY DATA — User data, PRESERVED across deploys
// =============================================================================
const libraryRoute = new Route(
  ({ url }) => {
    return url.pathname.startsWith('/library/') || 
           url.pathname.startsWith('/sync/');
  },
  new NetworkFirst({
    cacheName: CACHE_NAMES.library,
    networkTimeoutSeconds: 3,
    plugins: [
      new CacheableResponsePlugin({ statuses: [200] }),
      new ExpirationPlugin({ maxAgeSeconds: 24 * 60 * 60 }),
    ],
  })
);
registerRoute(libraryRoute);

// =============================================================================
// 🔄 BACKGROUND SYNC
// =============================================================================
const bgSyncPlugin = new BackgroundSyncPlugin('library-sync-queue', {
  maxRetentionTime: 24 * 60,
  onSync: async ({ queue }) => {
    let entry;
    while ((entry = await queue.shiftRequest())) {
      try {
        await fetch(entry.request.clone());
        console.log('[SW] Background sync successful for:', entry.request.url);
      } catch (error) {
        console.error('[SW] Background sync failed:', error);
        await queue.unshiftRequest(entry);
        throw error;
      }
    }
  },
});

registerRoute(
  ({ url, request }) => {
    return (url.pathname.startsWith('/sync/') || url.pathname.startsWith('/library/')) &&
           (request.method === 'POST' || request.method === 'PUT');
  },
  new NetworkFirst({ plugins: [bgSyncPlugin] }),
  'POST'
);

registerRoute(
  ({ url, request }) => {
    return (url.pathname.startsWith('/sync/') || url.pathname.startsWith('/library/')) &&
           request.method === 'PUT';
  },
  new NetworkFirst({ plugins: [bgSyncPlugin] }),
  'PUT'
);

// =============================================================================
// 🎯 API RESPONSES — Short-lived cache
// =============================================================================
const apiRoute = new Route(
  ({ url }) => {
    return url.pathname.startsWith('/api/') ||
           url.hostname.includes('invidious') ||
           url.pathname.includes('/api/v1/videos/');
  },
  new StaleWhileRevalidate({
    cacheName: CACHE_NAMES.api,
    plugins: [
      new CacheableResponsePlugin({ statuses: [200] }),
      new ExpirationPlugin({
        maxEntries: 200,
        maxAgeSeconds: 60 * 60,
      }),
    ],
  })
);
registerRoute(apiRoute);

// =============================================================================
// 📄 NAVIGATION — SPA fallback
// =============================================================================
const navigationRoute = new NavigationRoute(
  new NetworkFirst({
    cacheName: CACHE_NAMES.navigation,
    networkTimeoutSeconds: 3,
    plugins: [
      new CacheableResponsePlugin({ statuses: [200] }),
    ],
  }),
  { denylist: [/\/callback\//] }
);
registerRoute(navigationRoute);

// =============================================================================
// 🔔 SERVICE WORKER LIFECYCLE — Auto-purge stale caches on deploy
// =============================================================================
self.addEventListener('install', () => {
  console.log('[SW] Installing...');
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  console.log('[SW] Activating — purging stale caches...');
  event.waitUntil(
    caches.keys().then(cacheNames => {
      const currentCaches: Set<string> = new Set(Object.values(CACHE_NAMES));
      const deletions = cacheNames
        .filter(name => !currentCaches.has(name) && !PRESERVED_CACHES.has(name))
        .map(name => {
          console.log(`[SW] Purging stale cache: ${name}`);
          return caches.delete(name);
        });
      return Promise.all(deletions);
    })
    .then(() => self.clients.claim())
    .then(() => {
      if ('storage' in navigator && 'estimate' in navigator.storage) {
        return navigator.storage.estimate().then(estimate => {
          const percentUsed = ((estimate.usage || 0) / (estimate.quota || 1) * 100).toFixed(2);
          console.log(`[SW] Storage: ${percentUsed}% used (${Math.round((estimate.usage || 0) / 1024 / 1024)}MB)`);
        });
      }
    })
  );
});

// =============================================================================
// 📨 MESSAGE HANDLERS
// =============================================================================
self.addEventListener('message', (event) => {
  if (!event.data) return;

  switch (event.data.type) {
    case 'SKIP_WAITING':
      self.skipWaiting();
      break;

    case 'CLEAR_AUDIO_CACHE':
      caches.delete(CACHE_NAMES.audio).then(() => {
        console.log('[SW] Audio cache cleared');
      });
      break;

    case 'PURGE_APP_CACHES':
      // Purge everything except user library data
      caches.keys().then(names => {
        const deletions = names
          .filter(name => !PRESERVED_CACHES.has(name))
          .map(name => caches.delete(name));
        return Promise.all(deletions);
      }).then(() => {
        console.log('[SW] All app caches purged (library preserved)');
        event.ports?.[0]?.postMessage({ success: true });
      });
      break;

    case 'GET_CACHE_SIZE':
      if ('storage' in navigator && 'estimate' in navigator.storage) {
        navigator.storage.estimate().then(estimate => {
          event.ports?.[0]?.postMessage({ size: estimate.usage || 0 });
        });
      }
      break;
  }
});
