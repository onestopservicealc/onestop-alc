/* -----------------------------------------------------------------
   Service worker — ศูนย์รวมระบบ
   ★ เปลี่ยนเลข CACHE ทุกครั้งที่แก้ไฟล์ในลิสต์ หรือเพิ่ม/เปลี่ยนไอคอน
     (ไอคอนใช้แบบ cache-first ถ้าไม่เปลี่ยนเลข เครื่องเดิมจะยังเห็นไฟล์เก่า)
   ----------------------------------------------------------------- */
const CACHE = 'alc-hub-v7';

const SHELL = [
  './', './manifest.json',
  './icons/logo.png', './icons/icon-192.png', './icons/icon-512.png', './icons/icon-maskable-512.png'
];

/* ไอคอนการ์ดระบบ — สร้างด้วย  bash tools/build-icons.sh  (สคริปต์พิมพ์บล็อกนี้ให้คัดลอก) */
const ICONS = [
  './icons/sys/1310-nas-server.gif',
  './icons/sys/229-arrow-exchange.gif',
  './icons/sys/2450-invoice-general.gif',
  './icons/sys/28-calendar.gif',
  './icons/sys/2873-megaphone.gif',
  './icons/sys/748-notebook-laptop-ok-approved.gif',
  './icons/sys/861-car-site-4.gif'
];

const ASSETS = SHELL.concat(ICONS);

/* เก็บทีละไฟล์: ถ้าไฟล์ใดพลาด ไฟล์อื่นยังถูกเก็บครบ
   (addAll เดิมล้มทั้งชุดถ้าพลาดแค่ไฟล์เดียว แล้ว .catch() ก็กลืนไปเงียบ ๆ) */
function precache(){
  return caches.open(CACHE).then(function(c){
    const missed = [];
    return Promise.all(ASSETS.map(function(u){
      return c.add(new Request(u, { cache: 'reload' })).catch(function(){ missed.push(u); });
    })).then(function(){
      if (missed.length) console.warn('[sw] precache incomplete:', missed);
    });
  });
}

self.addEventListener('install', e => {
  e.waitUntil(precache().catch(() => {}).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== location.origin) return;

  /* รูปภาพ/ไอคอน: cache-first — เปลี่ยนเมื่อเปลี่ยนเลข CACHE เท่านั้น
     ทำให้ไอคอนขึ้นทันทีและใช้ได้แม้เน็ตล่ม/อยู่ในเครือข่ายภายใน */
  if (url.pathname.indexOf('/icons/') > -1) {
    e.respondWith(
      caches.match(req).then(hit => hit || fetch(req).then(res => {
        if (res.ok) { const copy = res.clone(); caches.open(CACHE).then(c => c.put(req, copy)).catch(() => {}); }
        return res;
      }))
    );
    return;
  }

  /* อื่น ๆ: network-first เพื่อให้ได้เนื้อหาใหม่เสมอ แล้วสำรองลง cache */
  e.respondWith(
    fetch(req).then(res => {
      if (res.ok) { const copy = res.clone(); caches.open(CACHE).then(c => c.put(req, copy)).catch(() => {}); }
      return res;
    }).catch(() => caches.match(req).then(r => r || caches.match('./')))
  );
});
