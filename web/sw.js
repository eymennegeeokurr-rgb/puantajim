// Puantajım çevrimdışı servis çalışanı
//
// - İlk açılışta (internet varken) uygulamanın TÜM dosyalarını önbelleğe alır.
// - Sonraki açılışlarda önce önbellekten açar -> internet yokken de çalışır.
// - İnternet varsa arka planda yeni sürümü indirir; bir sonraki açılışta güncellenir.
//
// SURUM ve DOSYALAR değerlerini derlemeden sonra `dart run tool/pwa_hazirla.dart`
// otomatik doldurur. Elle değiştirmeyin.

const SURUM = 'gelistirme';
const DOSYALAR = [];

const ONBELLEK = 'puantajim-' + SURUM;

self.addEventListener('install', (olay) => {
  olay.waitUntil((async () => {
    const onbellek = await caches.open(ONBELLEK);
    const liste = ['./', ...DOSYALAR];
    // Tek tek ekle: biri başarısız olursa diğerleri yine önbelleğe girsin
    await Promise.all(liste.map(async (yol) => {
      try {
        const yanit = await fetch(new Request(yol, { cache: 'reload' }));
        if (yanit.ok) await onbellek.put(yol, yanit);
      } catch (e) { /* çevrimdışıysa sonra denenir */ }
    }));
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (olay) => {
  olay.waitUntil((async () => {
    // Eski sürümlerin önbelleğini temizle
    const adlar = await caches.keys();
    await Promise.all(adlar
      .filter((ad) => ad.startsWith('puantajim-') && ad !== ONBELLEK)
      .map((ad) => caches.delete(ad)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (olay) => {
  const istek = olay.request;
  if (istek.method !== 'GET') return;
  const url = new URL(istek.url);
  if (url.origin !== self.location.origin) return;

  olay.respondWith((async () => {
    const onbellek = await caches.open(ONBELLEK);

    // Sayfa açılışı: index.html'i önbellekten ver
    if (istek.mode === 'navigate') {
      const ag = fetch(istek).then((y) => {
        if (y.ok) onbellek.put('./', y.clone());
        return y;
      }).catch(() => null);
      const kayitli = await onbellek.match('./') || await onbellek.match('index.html');
      if (kayitli) { olay.waitUntil(ag); return kayitli; }
      return (await ag) || new Response('Çevrimdışı', { status: 503 });
    }

    // Diğer dosyalar: önce önbellek, arkada güncelle
    const kayitli = await onbellek.match(istek, { ignoreSearch: true });
    const ag = fetch(istek).then((y) => {
      if (y.ok) onbellek.put(istek, y.clone());
      return y;
    }).catch(() => null);
    if (kayitli) { olay.waitUntil(ag); return kayitli; }
    return (await ag) || new Response('', { status: 504 });
  })());
});
