-- ═══════════════════════════════════════════════════════════════════════════
-- GMT_00_BASE_TABLES · 2026-07-17
-- ⚠️ الأساس: يعرّف الجداول الأساسية التي يحتاجها النظام.
-- كانت الملفات الأخرى تفترض وجودها (alter table if exists) لكن لم يعرّفها أحد.
-- هذا يسبب أخطاء «relation does not exist» على قاعدة جديدة.
-- 🔢 شغّل هذا الملف **أولاً قبل كل شيء** على القاعدة الرئيسية.
-- آمن للتكرار (كله if not exists) — لن يمسّ بياناتك إن كانت الجداول موجودة.
-- ═══════════════════════════════════════════════════════════════════════════

-- ① المنتجات (المخزون)
create table if not exists products (
  id             bigserial primary key,
  name           text,
  barcode        text,
  price          numeric default 0,
  wholesale_price numeric default 0,
  cost_price     numeric default 0,
  net_cost       numeric default 0,
  group_name     text,
  short          text,
  count          integer default 0,
  in_transit     integer default 0,
  created_at     timestamptz default now()
);

-- ② أعمدة الفروع الديناميكية (كل فرع عمود)
create table if not exists inv_columns (
  id          bigserial primary key,
  key_name    text unique,
  display_name text,
  icon        text,
  is_branch   boolean default true,
  sort_order  integer default 0
);

-- ③ الفواتير
create table if not exists invoices (
  id                bigserial primary key,
  inv_number        text,
  invoice_number    text,
  customer_name     text,
  customer_phone    text,
  cashier_name      text,
  branch_key        text,
  branch_name       text,
  total             numeric default 0,
  items_count       integer default 0,
  items_json        jsonb,
  payment_status    text default 'paid',
  paid_amount       numeric default 0,
  remaining_amount  numeric default 0,
  original_invoice_id text,
  is_refund         boolean default false,
  sale_type         text,
  refund_reason     text,
  created_at        timestamptz default now()
);

-- ④ بنود الفاتورة
create table if not exists invoice_items (
  id            bigserial primary key,
  invoice_id    bigint,
  product_id    bigint,
  product_name  text,
  qty           integer default 1,
  unit_price    numeric default 0,
  sale_price    numeric default 0,
  actual_price  numeric default 0,
  wholesale_price numeric default 0,
  purchase_price  numeric default 0,
  commission    numeric default 0,
  total         numeric default 0,
  created_at    timestamptz default now()
);

-- ⑤ عمولات الفواتير
create table if not exists invoice_commissions (
  id          bigserial primary key,
  invoice_id  bigint,
  branch_key  text,
  amount      numeric default 0,
  approved    boolean default false,
  approved_at timestamptz,
  paid        boolean default false,
  paid_at     timestamptz,
  zeroed      boolean default false,
  zeroed_by   text,
  zeroed_at   timestamptz,
  zeroed_reason text,
  settlement_id bigint,
  cashier_name  text,
  note        text,
  created_at  timestamptz default now()
);

-- ⑥ المستخدمون
create table if not exists gmt_users (
  id         bigserial primary key,
  username   text unique,
  password   text,
  role       text default 'cashier',
  branch_key text,
  created_at timestamptz default now()
);

-- ⑦ الأوردرات (الطلبات)
create table if not exists gmt_orders (
  id               bigserial primary key,
  serial_code      text,
  name             text,
  phone            text,
  address          text,
  branch           text,
  product          text,
  price            numeric default 0,
  status           text default 'pending',
  shipping_company text,
  invoice_id       bigint,
  invoice_number   text,
  is_locked        boolean default false,
  coupon           jsonb,
  items            jsonb,
  notes            text,
  created_by       text,
  deleted_at       timestamptz,
  created_at       timestamptz default now()
);

-- ⑧ سجل الاستيراد (المشتريات)
create table if not exists import_log (
  id             bigserial primary key,
  inv_number     text,
  supplier       text,
  dest_branch    text,
  status         text default 'transit',
  items_snapshot jsonb,
  transfer_moved jsonb,
  created_at     timestamptz default now()
);

-- ⑨ تحويلات المخزون بين الفروع
create table if not exists branch_stock_transfers (
  id              bigserial primary key,
  transfer_number text,
  from_branch     text,
  from_branch_name text,
  to_branch       text,
  to_branch_name  text,
  status          text default 'pending',
  created_at      timestamptz default now()
);

-- ⑩ بنود تحويل المخزون
create table if not exists stock_transfer_items (
  id           bigserial primary key,
  transfer_id  bigint,
  product_id   bigint,
  product_name text,
  qty          integer default 0,
  created_at   timestamptz default now()
);

-- ⑪ الكوبونات
create table if not exists gmt_coupons (
  id            bigserial primary key,
  code          text unique,
  discount_type text default 'fixed',       -- fixed | percent
  discount_value numeric default 0,
  min_purchase  numeric default 0,
  max_discount  numeric default 0,
  is_used       boolean default false,
  used_at       timestamptz,
  used_invoice  bigint,
  expires_at    timestamptz,
  created_at    timestamptz default now()
);

-- ⑫ المصاريف
create table if not exists gmt_expenses (
  id         bigserial primary key,
  amount     numeric default 0,
  category   text,
  note       text,
  branch_key text,
  created_by text,
  created_at timestamptz default now()
);

-- ⑬ العملاء
create table if not exists gmt_customers (
  id         bigserial primary key,
  name       text,
  phone      text,
  address    text,
  is_blocked boolean default false,
  note       text,
  created_at timestamptz default now()
);

-- ⑭ الديون اليدوية
create table if not exists gmt_manual_debts (
  id         bigserial primary key,
  customer_name text,
  phone      text,
  amount     numeric default 0,
  note       text,
  paid       boolean default false,
  created_by text,
  created_at timestamptz default now()
);

-- ⑮ إشعارات الفروع
create table if not exists branch_notifications (
  id         bigserial primary key,
  type       text,
  message    text,
  branch_key text,
  is_read    boolean default false,
  created_at timestamptz default now()
);

-- ⑯ إعدادات عامة (gmt_settings): تُعرّف حصراً في GMT_MASTER_SCHEMA (بعمود key+value+counter)
-- لتفادي تعارض تعريف. لا تُعرّف هنا. تأكّد أن MASTER يُشغّل بعد هذا الملف مباشرة.

-- ⑰ الفروع المخزنية (بعض النسخ تستعمل inventory بدل products بالفرع)
create table if not exists inventory (
  id       bigserial primary key,
  name     text,
  barcode  text,
  qty      integer default 0,
  price    numeric default 0,
  cost     numeric default 0,
  created_at timestamptz default now()
);

-- ═══════════════════════════════════════════════════════════════════════════
-- ملاحظة: هذه بنية أساسية كافية لتشغيل النظام على قاعدة جديدة. الملفات التالية
-- (MASTER · ORDERS_FIXES · ...) تضيف أعمدة وفهارس ودوال إضافية بأمان (if exists).
-- إن كانت جداولك موجودة مسبقاً ببنية أوسع، لن يضرّها هذا الملف (if not exists).
-- ═══════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════
-- دوال المخزون الأساسية + جدول التتبّع (يستعملها الكود عبر RPC)
-- كانت مفقودة فتفشل التحويلات المخزنية بخطأ «function does not exist».
-- ═══════════════════════════════════════════════════════════════════════════

-- ⑱ جدول التتبّع (كل خطأ يُرسل إليه ليراه الأدمن)
create table if not exists gmt_telemetry (
  id         bigserial primary key,
  kind       text,
  message    text,
  url        text,
  page       text,
  detail     jsonb,
  created_at timestamptz default now()
);

-- إضافة كمية لفرع (الإرجاع/الاستلام)
create or replace function add_branch_stock(
  p_product_id text,
  p_branch_key text,
  p_qty        numeric
) returns numeric
language plpgsql security definer as $gmt$
declare v_new numeric;
begin
  execute format(
    'update products set %I = coalesce(%I,0) + $1 where id::text = $2 returning %I',
    p_branch_key, p_branch_key, p_branch_key
  ) into v_new using p_qty, p_product_id;
  if v_new is null then raise exception 'المنتج % غير موجود', p_product_id; end if;
  return v_new;
end;
$gmt$;

-- خصم كمية من فرع (التحويل) — يرجع false إن لم تكفِ الكمية
create or replace function deduct_branch_stock(
  p_product_id text,
  p_branch_key text,
  p_qty        numeric
) returns boolean
language plpgsql security definer as $gmt$
declare v_cur numeric; v_new numeric;
begin
  execute format('select coalesce(%I,0) from products where id::text = $1', p_branch_key)
    into v_cur using p_product_id;
  if v_cur is null then return false; end if;      -- المنتج غير موجود
  if v_cur < p_qty then return false; end if;      -- الكمية لا تكفي
  execute format(
    'update products set %I = %I - $1 where id::text = $2 returning %I',
    p_branch_key, p_branch_key, p_branch_key
  ) into v_new using p_qty, p_product_id;
  return true;
end;
$gmt$;

-- مولّد رقم تحويل متسلسل
create or replace function next_stock_transfer_number()
returns text
language plpgsql security definer as $gmt$
declare v_num integer;
begin
  insert into gmt_settings (key, value)
  values ('stock_transfer_counter', '1')
  on conflict (key) do update
    set value = (coalesce(gmt_settings.value::integer, 0) + 1)::text,
        updated_at = now()
  returning value::integer into v_num;
  return 'TRF-' || lpad(v_num::text, 5, '0');
end;
$gmt$;
