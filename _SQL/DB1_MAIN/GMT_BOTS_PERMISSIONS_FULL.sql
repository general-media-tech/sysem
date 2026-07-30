-- ═══════════════════════════════════════════════════════════════════════════
-- GMT_BOTS_PERMISSIONS_FULL.sql — صلاحيات كاملة لكل البوتات · 2026-07-24
-- ═══════════════════════════════════════════════════════════════════════════
-- شغّل هذا الملف بعد GMT_00_BASE_TABLES و GMT_BOTS.
-- يعطي البوتات صلاحية كاملة للكتابة (تسجيل كل شيء) بكل الجداول.
-- الكتابة: مسموحة للجميع (anon + authenticated) — البوتات تسجّل من أي صفحة.
-- القراءة: للموظفين فقط (authenticated) — الأمان محفوظ.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1) جدول gmt_telemetry (تسجيل كل استعمال: نقرات، صفحات، أحداث) ──
create table if not exists gmt_telemetry (
  id bigint generated always as identity primary key,
  event_type text,
  page text,
  detail jsonb,
  session_id text,
  created_at timestamptz default now()
);

alter table gmt_telemetry enable row level security;

drop policy if exists telemetry_insert_all on gmt_telemetry;
create policy telemetry_insert_all on gmt_telemetry
  for insert to anon, authenticated with check (true);

drop policy if exists telemetry_select_auth on gmt_telemetry;
create policy telemetry_select_auth on gmt_telemetry
  for select to authenticated using (true);

-- تنظيف تلقائي: احذف السجلات الأقدم من 90 يوم (منع التضخّم)
drop policy if exists telemetry_delete_old on gmt_telemetry;
create policy telemetry_delete_old on gmt_telemetry
  for delete to authenticated using (created_at < now() - interval '90 days');

-- ── 2) تأكيد صلاحيات error_log ──
alter table if exists error_log enable row level security;
drop policy if exists errlog_insert_all on error_log;
create policy errlog_insert_all on error_log
  for insert to anon, authenticated with check (true);
drop policy if exists errlog_select_auth on error_log;
create policy errlog_select_auth on error_log
  for select to authenticated using (true);

-- ── 3) تأكيد صلاحيات inspector_sessions ──
alter table if exists inspector_sessions enable row level security;
drop policy if exists inspsess_insert_all on inspector_sessions;
create policy inspsess_insert_all on inspector_sessions
  for insert to anon, authenticated with check (true);
drop policy if exists inspsess_select_auth on inspector_sessions;
create policy inspsess_select_auth on inspector_sessions
  for select to authenticated using (true);

-- ── 4) تأكيد صلاحيات warden_incidents ──
alter table if exists warden_incidents enable row level security;
drop policy if exists warden_insert_all on warden_incidents;
create policy warden_insert_all on warden_incidents
  for insert to anon, authenticated with check (true);
drop policy if exists warden_select_auth on warden_incidents;
create policy warden_select_auth on warden_incidents
  for select to authenticated using (true);

-- ── 5) دالة عدّاد الإعدادات (يستعملها بعض البوتات) ──
create or replace function increment_settings_counter(counter_key text)
returns void language plpgsql security definer as $$
begin
  insert into gmt_settings (key, value)
  values (counter_key, '1')
  on conflict (key) do update
    set value = (coalesce(gmt_settings.value::int, 0) + 1)::text;
end;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- ✅ بعد تشغيل هذا الملف: كل البوتات تستطيع تسجيل كل شيء (نقرات، أخطاء،
--    جلسات، حوادث) من أي صفحة، والمالك/الموظف يقرأ التقارير.
-- ═══════════════════════════════════════════════════════════════════════════
