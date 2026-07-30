/* GMT PWA — عامل الخدمة | التطبيق: أدمن نقاط البيع | الإصدار: v9 (إصلاحات الفحص العميق 2026-07-12)
   ⚠️ سياسة التحديث: مع كل تسليم يلمس ملفات هذه الصفحة، أسلّمك sw.js بإصدار
   مرفوع بنفس المجلد — ارفعه معها والتحديث يصل للأجهزة تلقائياً بالفتح التالي.
   البيانات (supabase) لا تُلمس أبداً — دائماً من الشبكة. */
const CACHE = 'gmt-admin--v20260728';
const PRECACHE = [
  '../_shared/gmt-core.js',
  '../_shared/gmt-staff.js',"./admin-final.html", "./gmt-theme.css", "./logo.jpg", "./manifest.json", "./gmt-icon-192.png", "./gmt-icon-512.png",];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(PRECACHE)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((ks) => Promise.all(ks.filter((k) => k.startsWith('gmt-admin-') && k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.hostname.includes('supabase.co')) return; // البيانات دائماً حية من الشبكة

  if (url.origin === location.origin) {
    // ملفات الصفحة: الشبكة أولاً (أحدث نسخة دائماً) + كاش احتياطي عند انقطاع النت
    e.respondWith(caches.open(CACHE).then(async (c) => {
      try {
        const res = await fetch(req);
        if (res && res.ok) { c.put(req, res.clone()); return res; }
        const cached = await c.match(req);
        return cached || res || Response.error();
      } catch (_) {
        const cached = await c.match(req);
        return cached || Response.error();
      }
    }));
  } else {
    // خطوط/مكتبات CDN: كاش أولاً ثم شبكة
    e.respondWith(caches.open(CACHE).then(async (c) => {
      const cached = await c.match(req);
      if (cached) return cached;
      try { const res = await fetch(req); if (res) c.put(req, res.clone()); return res; }
      catch (_) { return Response.error(); }
    }));
  }
});
