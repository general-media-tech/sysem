-- ═══════════════════════════════════════════════════════════════
-- 🛒 GMT — البنية الأساسية لقاعدة DB2 المتجر الإلكتروني
-- جدولان: المنتجات (gmt_store) والتعليقات (gmt_comments)
-- ═══════════════════════════════════════════════════════════════

create table if not exists gmt_store (
  id          bigserial primary key,
  name        text,
  price       numeric default 0,
  category    text,
  description text,
  images      jsonb default '[]',
  options     jsonb default '[]',
  visible     boolean default true,
  sort_order  integer default 0,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

create table if not exists gmt_comments (
  id          bigserial primary key,
  product_id  bigint,
  name        text,
  comment     text,
  rating      integer,
  approved    boolean default false,
  created_at  timestamptz default now()
);

alter table gmt_store    enable row level security;
alter table gmt_comments enable row level security;

drop policy if exists store_read on gmt_store;
create policy store_read on gmt_store for select to anon, authenticated using (true);
drop policy if exists store_write on gmt_store;
create policy store_write on gmt_store for all to anon, authenticated using (true) with check (true);

drop policy if exists comm_read on gmt_comments;
create policy comm_read on gmt_comments for select to anon, authenticated using (true);
drop policy if exists comm_write on gmt_comments;
create policy comm_write on gmt_comments for insert to anon, authenticated with check (true);

-- ملاحظة: عدّل الأعمدة حسب متجرك الفعلي إن اختلفت. هذه البنية الأساسية.
