-- ═══════════════════════════════════════════════════════════════════════════
-- GMT_00_BASE_WARRANTY · 2026-07-17
-- ⚠️ الأساس لقاعدة الكفالة (DB3): يعرّف الجداول التي يحتاجها نظام الكفالة.
-- كانت الملفات الأخرى تفترض وجودها (alter table if exists) دون تعريفها.
-- 🔢 شغّل هذا الملف **أولاً** على قاعدة الكفالة قبل باقي ملفات DB3.
-- آمن للتكرار (كله if not exists).
-- ═══════════════════════════════════════════════════════════════════════════

-- ① الكفالات
create table if not exists warranties (
  id             bigserial primary key,
  warranty_number text,
  serial_number  text,
  serial         text,
  customer_name  text,
  customer_phone text,
  product        text,
  products_json  jsonb,
  sale_price     numeric default 0,
  branch         text,
  status         text default 'active',
  activated      boolean default false,
  activated_at   timestamptz,
  birth_date     date,
  internal_no    text,
  created_at     timestamptz default now()
);

-- ② سجلّ التفعيلات
create table if not exists activation_logs (
  id           bigserial primary key,
  warranty_id  bigint,
  serial       text,
  action       text,
  actor        text,
  note         text,
  created_at   timestamptz default now()
);

-- ③ الشحنات (التتبّع)
create table if not exists shipments (
  id           bigserial primary key,
  internal_no  text,
  tracking_no  text,
  customer_name text,
  customer_phone text,
  status       text default 'pending',
  origin       text,
  destination  text,
  created_at   timestamptz default now()
);

-- ═══════════════════════════════════════════════════════════════════════════
-- بعد هذا الملف، شغّل: GMT_WARRANTY_TRACKING · GMT_BIRTHDATE · GMT_CONTRACTS · GMT_CONTRACTS_V2
-- (تضيف أعمدة وفهارس ودوال إضافية بأمان).
-- ═══════════════════════════════════════════════════════════════════════════
