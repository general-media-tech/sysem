-- ═══════════════════════════════════════════════════════════════════════════
-- GMT — قاعدة الكفالة والتتبّع (DB3)   ·   2026-07-13
-- يغلق: WAR-2 · WAR-3 · TRK-1 · CON-3
-- آمن للتشغيل أكثر من مرة.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── WAR-2 — البحث بالرقم التسلسلي (كان بـ short_id و invoice_no فقط) ──
alter table if exists warranties add column if not exists serial_number text;
create index if not exists idx_warranty_serial on warranties (serial_number);

-- ── WAR-3 — التعبئة الكاملة من الفاتورة (كانت 3 حقول فقط) ──
alter table if exists warranties add column if not exists customer_phone text;
alter table if exists warranties add column if not exists products_json  jsonb;
alter table if exists warranties add column if not exists sale_price     numeric;
alter table if exists warranties add column if not exists branch         text;

-- ── TRK-1 — رقمنا الداخلي (تاريخ + 6 أرقام) مفتاح بحث أول ──
--    ❓ ما زال بانتظار مثالك: هل هو `id` أم رقم مستقل؟
--    حتى تجيب، أنشأنا عموداً صريحاً — إن تبيّن أنه نفس `id` نحذفه بسطر واحد.
alter table if exists shipments add column if not exists internal_no text;
-- (2026-07-17) الفهرس مشروط بوجود الجدول — يمنع خطأ «shipments does not exist» بالتشغيل النظيف.
do $gmt_ship$
begin
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='shipments') then
    create unique index if not exists idx_shipment_internal on shipments (internal_no) where internal_no is not null;
  end if;
end $gmt_ship$;

-- مولّد الرقم الداخلي: YYMMDD-XXXXXX
create or replace function gmt_internal_no()
returns text
language sql volatile
as $$
  select to_char(now(),'YYMMDD') || '-' || lpad((floor(random()*1000000))::int::text, 6, '0');
$$;

-- ── CON-3 — بيانات العقود الشخصية مكشوفة (يُعالَج مع SEC-1) ──
--    نفس المرحلة (أ): قراءة وكتابة وتعديل مسموح، **الحذف ممنوع**.
do $$
declare t text;
begin
  foreach t in array array['warranties','contracts','shipments'] loop
    if exists (select 1 from information_schema.tables
               where table_schema='public' and table_name=t) then
      execute format('alter table public.%I enable row level security', t);
      execute format('drop policy if exists gmt_read  on public.%I', t);
      execute format('drop policy if exists gmt_write on public.%I', t);
      execute format('drop policy if exists gmt_edit  on public.%I', t);
      execute format('create policy gmt_read  on public.%I for select using (true)', t);
      execute format('create policy gmt_write on public.%I for insert with check (true)', t);
      execute format('create policy gmt_edit  on public.%I for update using (true) with check (true)', t);
    end if;
  end loop;
end $$;

-- ── التحقق ──
select 'WAR-2 serial_number' as بند,
       case when exists (select 1 from information_schema.columns
              where table_name='warranties' and column_name='serial_number')
            then '✅' else '❌' end as النتيجة
union all select 'TRK-1 internal_no',
       case when exists (select 1 from information_schema.columns
              where table_name='shipments' and column_name='internal_no')
            then '✅' else '❌' end;
