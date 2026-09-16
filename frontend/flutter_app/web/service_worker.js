const CACHE_NAME = 'reuma-static-v3';
const OFFLINE_URLS = [
  '/',
  'index.html',
  'flutter_bootstrap.js',
  'assets/AssetManifest.json',
  'assets/FontManifest.json',
  'assets/NOTICES',
  'assets/assets/images/logo_reuma_nutri.png'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(async cache => {
      for (const url of OFFLINE_URLS) {
        try {
          await cache.add(url);
        } catch (e) {
          console.warn('Failed to cache:', url, e);
        }
      }
    })
  );
  self.skipWaiting();
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys => Promise.all(
      keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k))
    )).then(() => clients.claim())
  );
});

self.addEventListener('fetch', event => {
  // Navigation requests: network-first then fallback to cache
  if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request).catch(() => caches.match('index.html'))
    );
    return;
  }

  // For other requests: try cache, then network and cache the response
  event.respondWith(
    caches.match(event.request).then(response => {
      if (response) return response;
      return fetch(event.request).then(networkResponse => {
        if (!networkResponse || networkResponse.status !== 200 || networkResponse.type !== 'basic') {
          return networkResponse;
        }
        const cloned = networkResponse.clone();
        caches.open(CACHE_NAME).then(cache => cache.put(event.request, cloned));
        return networkResponse;
      }).catch(() => response);
    })
  );
});
