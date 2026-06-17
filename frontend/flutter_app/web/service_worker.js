const CACHE_NAME = 'reuma-static-v1';
const OFFLINE_URLS = [
  '/',
  'index.html',
  'main.dart.js',
  'flutter_bootstrap.js',
  'assets/AssetManifest.json',
  'assets/FontManifest.json',
  'assets/NOTICES',
  'assets/images/logo 1.webp',
  'assets/images/nutri_clinic_hero.webp'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => cache.addAll(OFFLINE_URLS))
  );
  self.skipWaiting();
});

self.addEventListener('activate', event => {
  event.waitUntil(clients.claim());
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
