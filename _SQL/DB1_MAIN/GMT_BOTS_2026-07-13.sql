-- ═══════════════════════════════════════════════════════════════════════════
-- GMT — جداول البوتات (الحارس · المفتّش · لوحة صحة النظام)   ·   2026-07-13
-- يغلق: BOT-1 (لا ذاكرة) · BOT-2 (التسجيل الصامت + لوحة الأدمن) · BOT-3 (الأخطاء الصامتة)
-- آمن للتشغيل أكثر من مرة.
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- ① error_log — الحارس (BOT-2): كل خطأ عند أي كاشير يصل هنا فوراً
-- ─────────────────────────────────────────────────────────────
create table if not exists error_log (
  id          bigserial primary key,
  session_id  text,
  user_name   text,
  branch      text,
  role        text,
  page        text,
  severity    text default 'error',      -- error | warn | critical | silent
  err_type    text,                      -- js | http | silent | slow | dead_click | double_write
  message     text,
  detail      jsonb,
  url         text,
  device      text,
  training    boolean default false,     -- من الوضع التدريبي؟ (لا يُحتسب بالتقارير)
  hits        int default 1,             -- تجميع المتكرر حتى لا تُغرق القاعدة
  created_at  timestamptz default now()
);
create index if not exists ix_errlog_created  on error_log (created_at desc);
create index if not exists ix_errlog_severity on error_log (severity);
create index if not exists ix_errlog_branch   on error_log (branch);
create index if not exists ix_errlog_session  on error_log (session_id);

-- ─────────────────────────────────────────────────────────────
-- ② inspector_sessions — المفتّش v3 (BOT-3): رحلة كل جلسة + الأخطاء الصامتة
--    هذا ما يعطي الإدارة **دليلاً حقيقياً بدل التخمين**.
-- ─────────────────────────────────────────────────────────────
create table if not exists inspector_sessions (
  id             bigserial primary key,
  session_id     text,
  user_name      text,
  role           text,
  page           text,
  duration_min   int,
  steps          jsonb,      -- الرحلة: ماذا ضغط · بأي ترتيب
  silent_errors  jsonb,      -- 🔴 زر بلا أثر · كتابة لم تُطبَّق · كتابة مزدوجة
  slow_requests  jsonb,      -- 🐌 >4 ثوانٍ (سبب التجميد UX-2)
  writes_total   int,
  writes_failed  int,
  coverage       jsonb,      -- تغطية الميزات
  training       boolean default false,
  report         text,       -- التقرير النصّي الجاهز للإرسال
  created_at     timestamptz default now()
);
create index if not exists ix_insp_created on inspector_sessions (created_at desc);
create index if not exists ix_insp_user    on inspector_sessions (user_name);

-- ─────────────────────────────────────────────────────────────
-- ③ التقارير الدورية (BOT-2 بند 5): يومي · أسبوعي
--    تُقرأ من لوحة 🩺 صحة النظام وتُرسَل تيليغرام.
-- ─────────────────────────────────────────────────────────────
create or replace view v_errors_daily as
select
  date_trunc('day', created_at)      as day,
  branch,
  page,
  severity,
  count(*)                            as total,
  count(distinct session_id)          as sessions,
  count(distinct user_name)           as users
from error_log
where training is not true
group by 1, 2, 3, 4
order by 1 desc, 5 desc;

create or replace view v_errors_weekly as
select
  date_trunc('week', created_at)      as week,
  err_type,
  message,
  count(*)                            as hits,
  count(distinct user_name)           as users,
  max(created_at)                     as last_seen
from error_log
where training is not true
group by 1, 2, 3
order by 1 desc, 4 desc;

-- الأكثر تعثّراً (مستخدم/صفحة) — لتعرف أين تدرّب وأين تُصلح
create or replace view v_top_offenders as
select
  user_name,
  page,
  count(*)                                                as errors,
  count(*) filter (where severity = 'critical')           as critical,
  count(*) filter (where err_type in ('silent','dead_click','double_write')) as silent_errors,
  max(created_at)                                         as last_error
from error_log
where training is not true
  and created_at > now() - interval '30 days'
group by 1, 2
order by 3 desc
limit 50;

-- ─────────────────────────────────────────────────────────────
-- ④ SEC-1 — RLS على جداول البوتات
--    الكتابة مفتوحة (الكاشير يجب أن يُبلّغ عن خطئه)،
--    لكن **القراءة للأدمن فقط** — الكاشير لا يرى أخطاء غيره.
-- ─────────────────────────────────────────────────────────────
alter table error_log          enable row level security;
alter table inspector_sessions enable row level security;

drop policy if exists errlog_insert_any  on error_log;
create policy errlog_insert_any  on error_log          for insert to anon, authenticated with check (true);

drop policy if exists insp_insert_any    on inspector_sessions;
create policy insp_insert_any    on inspector_sessions for insert to anon, authenticated with check (true);

-- القراءة: authenticated فقط (اربطها بدور admin عند تفعيل الحسابات المسمّاة SEC-3)
drop policy if exists errlog_read_auth   on error_log;
create policy errlog_read_auth   on error_log          for select to authenticated using (true);

drop policy if exists insp_read_auth     on inspector_sessions;
create policy insp_read_auth     on inspector_sessions for select to authenticated using (true);

-- ─────────────────────────────────────────────────────────────
-- ⑤ تنظيف تلقائي — لا تُغرق القاعدة
-- ─────────────────────────────────────────────────────────────
create or replace function gmt_prune_bot_logs()
returns void language sql as $$
  delete from error_log          where created_at < now() - interval '90 days';
  delete from inspector_sessions where created_at < now() - interval '60 days';
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- انتهى. تحقّق:
--   select count(*) from error_log;
--   select * from v_top_offenders;
-- ═══════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════
-- ⑥ warden_incidents — المراقب السيادي (2026-07-17)
--    كل حادثة يكتشفها نظام الحماية: برمجية/تقنية/عملية/حسابية/مخالفة قاعدة
-- ═══════════════════════════════════════════════════════════════
create table if not exists warden_incidents (
  id           bigserial primary key,
  incident_id  text,
  kind         text,              -- programmatic|technical|operational|financial|rule_violation
  title        text,
  what         text,
  how          text,
  why          text,
  rule_id      text,
  feature_id   text,
  severity     text default 'medium',
  page         text,
  user_name    text,
  role         text,
  branch       text,
  money_delta  numeric,           -- القيمة المخصومة/المضافة (للأخطاء الحسابية)
  evidence     text,
  resolved     boolean default false,
  recovered    boolean default false,  -- للفروقات المالية: هل استُرجع المبلغ؟
  created_at   timestamptz default now()
);
create index if not exists ix_warden_created  on warden_incidents (created_at desc);
create index if not exists ix_warden_kind      on warden_incidents (kind);
create index if not exists ix_warden_severity  on warden_incidents (severity);
create index if not exists ix_warden_money     on warden_incidents (money_delta) where money_delta is not null;

alter table warden_incidents enable row level security;
drop policy if exists warden_insert_any on warden_incidents;
create policy warden_insert_any on warden_incidents for insert to anon, authenticated with check (true);
drop policy if exists warden_read_auth on warden_incidents;
create policy warden_read_auth on warden_incidents for select to authenticated using (true);

-- عرض: الفروقات المالية غير المسترجَعة (متابعة أسبوعية)
create or replace view v_warden_money_pending as
select created_at, title, money_delta, user_name, branch, why
from warden_incidents
where kind='financial' and money_delta is not null and recovered=false
order by created_at desc;
