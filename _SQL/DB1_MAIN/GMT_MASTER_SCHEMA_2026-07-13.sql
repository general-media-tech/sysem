-- ═══════════════════════════════════════════════════════════════════════════
-- GMT — مخطّط القاعدة الرئيسي (DB1_MAIN)   ·   2026-07-13
-- يغلق: ORD-1 · ORD-2 · ORD-5 · ADM-4 · PUR-2 · PUR-7 · INV-5 · SEC-2 · SEC-3
-- آمن للتشغيل أكثر من مرة (كله IF NOT EXISTS / OR REPLACE).
-- شغّله كاملاً بمحرر SQL في Supabase ثم أعد تحميل الصفحات.
-- ═══════════════════════════════════════════════════════════════════════════

-- ────────────────────────────────────────────────────────────────
-- ① ORD-1 — عمود tg_msg_id مفقود ⇒ كل تعديل/حذف رسالة تيليغرام يعطي HTTP 400
-- ────────────────────────────────────────────────────────────────
alter table if exists gmt_orders add column if not exists tg_msg_id  text;
alter table if exists gmt_orders add column if not exists tg_chat_id text;

-- ────────────────────────────────────────────────────────────────
-- ② ORD-2 — RPC معرَّفة غلط ⇒ خطأ 42703 «column id does not exist» بكل فتح
--    تُستدعى من صفحة الأوردرات لزيادة عدّاد بجدول الإعدادات.
-- ────────────────────────────────────────────────────────────────
create table if not exists gmt_settings (
  key         text primary key,
  value       text,
  counter     bigint      not null default 0,
  updated_at  timestamptz not null default now()
);

-- ⚠️ دالة العدّاد نُقلت إلى GMT_ORDERS_FIXES (النسخة الصحيحة تكتب بعمود value + قفل ضد السباق).
-- كانت هنا نسخة تكتب بعمود counter — لكن الكود يقرأ من value، فأُزيلت لمنع تعارض SQL-1.
-- لا تُعرّف الدالة هنا. عرّفها مرة واحدة فقط من GMT_ORDERS_FIXES بعد تشغيل:
--   DROP FUNCTION IF EXISTS increment_settings_counter(text);

-- ────────────────────────────────────────────────────────────────
-- ③ ORD-5 — المساءلة: من أنشأ / عدّل / حذف + حذف ناعم
--    كان صفر تتبّع — الحقل الوحيد نصّ ثابت «نظام تحصيل الشحن (آلي)».
-- ────────────────────────────────────────────────────────────────
alter table if exists gmt_orders add column if not exists created_by  text;
alter table if exists gmt_orders add column if not exists updated_by  text;
alter table if exists gmt_orders add column if not exists deleted_by  text;
alter table if exists gmt_orders add column if not exists deleted_at  timestamptz;
alter table if exists gmt_orders add column if not exists is_deleted  boolean not null default false;
create index if not exists idx_orders_not_deleted on gmt_orders (is_deleted) where is_deleted = false;

-- ملاحto (2026-07-17): جدول audit_log يُنشأ حصراً من GMT_ACCOUNTING_GUARDS.txt
-- (الذي يُشغّل قبل هذا الملف) بأعمدة: entity/entity_id/before_val/after_val/note/source.
-- أُزيل تعريفه المكرّر من هنا (كان بأعمدة table_name/row_id مختلفة) لمنع تعارض
-- «column table_name does not exist». مصدر واحد للجدول = لا تعارض.

-- ────────────────────────────────────────────────────────────────
-- ④ ADM-4 — تصفير العمولة بدل حذفها (الأثر يبقى)
-- ────────────────────────────────────────────────────────────────
alter table if exists invoice_commissions add column if not exists zeroed        boolean not null default false;
alter table if exists invoice_commissions add column if not exists zeroed_by     text;
alter table if exists invoice_commissions add column if not exists zeroed_at     timestamptz;
alter table if exists invoice_commissions add column if not exists zeroed_reason text;
alter table if exists invoice_commissions add column if not exists status        text default 'pending';
  -- الحالات: pending | approved | rejected | zeroed  (POS-2 يعرضها للكاشير بأربع حالات)

-- ────────────────────────────────────────────────────────────────
-- ⑤ PUR-2 — الترحيل: لا ختم بلا وصول فعلي + إمكانية إكمال الباقي + فكّ الختم
-- ────────────────────────────────────────────────────────────────
alter table if exists import_log add column if not exists transferred    boolean not null default false;
alter table if exists import_log add column if not exists transferred_at timestamptz;
alter table if exists import_log add column if not exists transferred_by text;
alter table if exists import_log add column if not exists transfer_moved jsonb  not null default '{}'::jsonb;
  -- ↑ {product_id: qty_moved} — يمنع تكرار الترحيل ويسمح بإكمال النقص لاحقاً
alter table if exists import_log add column if not exists unseal_reason  text;
alter table if exists import_log add column if not exists unsealed_at    timestamptz;

-- دفتر الاستلام (كل قطعة دخلت المخزون مربوطة بفاتورتها)
create table if not exists stock_receipts (
  id          bigserial primary key,
  import_id   text,
  product_id  text        not null,
  branch_key  text        not null,
  qty         numeric     not null,
  kind        text        not null default 'transfer_arrive',
  note        text,
  created_by  text,
  created_at  timestamptz not null default now()
);
create index if not exists idx_receipts_import  on stock_receipts (import_id);
create index if not exists idx_receipts_product on stock_receipts (product_id);

-- ────────────────────────────────────────────────────────────────
-- ⑥ INV-5 — أثر أي تعديل يدوي على الكميات (الاستثناء السيادي)
-- ────────────────────────────────────────────────────────────────
alter table if exists products add column if not exists qty_manual_reason text;
alter table if exists products add column if not exists qty_manual_at     timestamptz;
alter table if exists products add column if not exists cost_price        numeric default 0;
  -- ↑ PUR-7 يكتب هنا «التكلفة الواصلة» = سعر الوحدة + حصتها من المصاريف

-- ────────────────────────────────────────────────────────────────
-- ⑦ POS-4 / SEC-3 — الأدوار: الاستثناء بالدور لا بالفرع
-- ────────────────────────────────────────────────────────────────
alter table if exists gmt_users add column if not exists role         text not null default 'cashier';
  -- القيم: cashier | admin | sovereign
alter table if exists gmt_users add column if not exists display_name text;
alter table if exists gmt_users add column if not exists is_active    boolean not null default true;

-- ⚠️ اجعل حسابك أدمن (بدونه POS-4 يمنع الجميع من البيع تحت التكلفة):
--    update gmt_users set role = 'admin' where username = 'اسم_حسابك';
--    update gmt_users set role = 'sovereign' where username = 'حسابك_السيادي';

-- ────────────────────────────────────────────────────────────────
-- ⑧ POS-1 — المرتجع (العمود الذي يعترف الكود بغيابه)
-- ────────────────────────────────────────────────────────────────
alter table if exists invoices add column if not exists original_invoice_id text;
alter table if exists invoices add column if not exists is_refund           boolean not null default false;
alter table if exists invoices add column if not exists refund_reason       text;

-- ────────────────────────────────────────────────────────────────
-- ⑨ SEC-1 — RLS  🔴 أخطر بند بالنظام
--    اليوم: مفتاح anon مكشوف بلا سياسات ⇒ **أي شخص عنده الرابط يقرأ ويكتب ويحذف كل شيء**.
--    كلمات السر بالواجهة حاجز بصري فقط ولا تحمي القاعدة إطلاقاً.
--
--    ⚠️ اقرأ هذا قبل التشغيل:
--    تفعيل RLS بلا سياسات = **تعطيل النظام فوراً**. لذلك السياسات أدناه مرحلية:
--    المرحلة (أ) — القراءة والكتابة مسموحتان، لكن **الحذف ممنوع** على الجداول الحساسة.
--                  هذا وحده يغلق أخطر سيناريو (مسح البيانات) بلا كسر أي صفحة.
--    المرحلة (ب) — بعد تفعيل حسابات Supabase Auth الحقيقية: احصر الكتابة بـ authenticated.
--                  لا تشغّلها قبل ربط تسجيل الدخول الفعلي بالقاعدة.
-- ────────────────────────────────────────────────────────────────

-- ── المرحلة (أ): امنع الحذف (شغّلها الآن) ──
do $$
declare t text;
begin
  foreach t in array array['products','import_log','invoices','gmt_orders',
                           'invoice_commissions','stock_receipts','audit_log','contracts']
  loop
    if exists (select 1 from information_schema.tables
               where table_schema='public' and table_name=t) then
      execute format('alter table public.%I enable row level security', t);

      execute format('drop policy if exists gmt_read  on public.%I', t);
      execute format('drop policy if exists gmt_write on public.%I', t);
      execute format('drop policy if exists gmt_edit  on public.%I', t);

      execute format('create policy gmt_read  on public.%I for select using (true)', t);
      execute format('create policy gmt_write on public.%I for insert with check (true)', t);
      execute format('create policy gmt_edit  on public.%I for update using (true) with check (true)', t);
      -- ⛔ لا سياسة DELETE ⇒ الحذف مرفوض تلقائياً لكل من يحمل مفتاح anon
    end if;
  end loop;
end $$;

-- ── المرحلة (ب): لا تشغّلها إلا بعد ربط Supabase Auth (تكسر الصفحات قبل ذلك) ──
-- do $$
-- declare t text;
-- begin
--   foreach t in array array['products','import_log','invoices','gmt_orders','invoice_commissions']
--   loop
--     execute format('drop policy if exists gmt_write on public.%I', t);
--     execute format('drop policy if exists gmt_edit  on public.%I', t);
--     execute format('create policy gmt_write on public.%I for insert to authenticated with check (true)', t);
--     execute format('create policy gmt_edit  on public.%I for update to authenticated using (true) with check (true)', t);
--   end loop;
-- end $$;

-- ────────────────────────────────────────────────────────────────
-- ⑩ SEC-2 — أقفال الفترات المحاسبية (الجدول كان موجوداً بصفر استدعاء)
-- ────────────────────────────────────────────────────────────────
-- ────────────────────────────────────────────────────────────────
-- ملاحظة (2026-07-17): جدول period_locks ودالة gmt_is_locked يُنشآن حصراً من
-- GMT_ACCOUNTING_GUARDS.txt (يُشغّل قبل هذا الملف) بالبنية الصحيحة:
--   period_locks: branch_key/locked_upto/locked_by/locked_at/note
--   gmt_is_locked(p_branch text, p_date date)
-- أُزيل التعريف المكرّر من هنا (كان بأعمدة locked_to/reason ودالة بوسيطة واحدة)
-- لمنع تعارض الأعمدة وتوقيع الدالة. مصدر واحد = لا تعارض.

-- ────────────────────────────────────────────────────────────────
-- ⑪ التحقق — شغّلها بعد كل ما سبق. المتوقع: كل الأسطر ✅
-- ────────────────────────────────────────────────────────────────
select 'ORD-1  tg_msg_id'        as بند,
       case when exists (select 1 from information_schema.columns
              where table_name='gmt_orders' and column_name='tg_msg_id')
            then '✅' else '❌' end as النتيجة
union all select 'ORD-2  RPC',
       case when exists (select 1 from pg_proc where proname='increment_settings_counter')
            then '✅' else '❌' end
union all select 'ORD-5  المساءلة',
       case when exists (select 1 from information_schema.columns
              where table_name='gmt_orders' and column_name='created_by')
            then '✅' else '❌' end
union all select 'ADM-4  التصفير',
       case when exists (select 1 from information_schema.columns
              where table_name='invoice_commissions' and column_name='zeroed')
            then '✅' else '❌' end
union all select 'PUR-2  transfer_moved',
       case when exists (select 1 from information_schema.columns
              where table_name='import_log' and column_name='transfer_moved')
            then '✅' else '❌' end
union all select 'POS-1  المرتجع',
       case when exists (select 1 from information_schema.columns
              where table_name='invoices' and column_name='original_invoice_id')
            then '✅' else '❌' end
union all select 'POS-4  عمود الدور',
       case when exists (select 1 from information_schema.columns
              where table_name='gmt_users' and column_name='role')
            then '✅' else '❌' end
union all select 'SEC-1  RLS مفعَّل',
       case when (select count(*) from pg_tables
                  where schemaname='public' and rowsecurity = true) >= 4
            then '✅' else '❌' end;
