create table if not exists public.qzix_demo_share_records (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  level_label text not null check (char_length(level_label) between 1 and 60),
  share_percent numeric(7,4) not null check (share_percent > 0 and share_percent <= 100),
  illustrative_amount numeric(14,2) not null default 0 check (illustrative_amount >= 0),
  record_type text not null default 'DEMO' check (record_type = 'DEMO'),
  created_at timestamptz not null default clock_timestamp()
);
create index if not exists qzix_demo_share_records_priority_idx
  on public.qzix_demo_share_records (created_at, id);
create index if not exists qzix_demo_share_records_user_idx
  on public.qzix_demo_share_records (user_id, created_at, id);

create table if not exists public.qzix_demo_audit_log (
  audit_id bigint generated always as identity primary key,
  record_id bigint not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  action text not null check (action in ('DEMO_RECORD_CREATED')),
  detail text not null default 'TEST DATA ONLY — NOT A PURCHASE OR PAYMENT',
  occurred_at timestamptz not null default clock_timestamp()
);
create index if not exists qzix_demo_audit_log_user_idx
  on public.qzix_demo_audit_log (user_id, occurred_at desc);

alter table public.qzix_demo_share_records enable row level security;
alter table public.qzix_demo_audit_log enable row level security;

drop policy if exists qzix_demo_records_owner_read on public.qzix_demo_share_records;
create policy qzix_demo_records_owner_read on public.qzix_demo_share_records
  for select to authenticated
  using ((select auth.uid()) = user_id or exists (
    select 1 from public.qzix_v2_admins a where a.user_id = (select auth.uid())
  ));
drop policy if exists qzix_demo_records_owner_insert on public.qzix_demo_share_records;
create policy qzix_demo_records_owner_insert on public.qzix_demo_share_records
  for insert to authenticated
  with check ((select auth.uid()) = user_id and record_type = 'DEMO');
drop policy if exists qzix_demo_audit_owner_read on public.qzix_demo_audit_log;
create policy qzix_demo_audit_owner_read on public.qzix_demo_audit_log
  for select to authenticated
  using ((select auth.uid()) = user_id or exists (
    select 1 from public.qzix_v2_admins a where a.user_id = (select auth.uid())
  ));

create or replace function public.qzix_demo_log_record_created()
returns trigger language plpgsql security definer
set search_path = pg_catalog, public
as $$
begin
  insert into public.qzix_demo_audit_log(record_id, user_id, action, detail)
  values (new.id, new.user_id, 'DEMO_RECORD_CREATED',
          'TEST DATA ONLY — NOT A PURCHASE, PAYMENT, OWNERSHIP OR PAYOUT');
  return new;
end;
$$;
revoke all on function public.qzix_demo_log_record_created() from public, anon, authenticated;
drop trigger if exists qzix_demo_record_audit_insert on public.qzix_demo_share_records;
create trigger qzix_demo_record_audit_insert
after insert on public.qzix_demo_share_records
for each row execute function public.qzix_demo_log_record_created();

create or replace function public.qzix_demo_my_priority()
returns table (
  record_id bigint, level_label text, share_percent numeric,
  illustrative_amount numeric, created_at timestamptz, demo_priority bigint
)
language sql stable security definer
set search_path = pg_catalog, public
as $$
  select ranked.id, ranked.level_label, ranked.share_percent,
         ranked.illustrative_amount, ranked.created_at, ranked.demo_priority
  from (
    select r.id, r.user_id, r.level_label, r.share_percent,
           r.illustrative_amount, r.created_at,
           row_number() over (order by r.created_at, r.id) as demo_priority
    from public.qzix_demo_share_records r
  ) ranked
  where ranked.user_id = auth.uid()
  order by ranked.created_at, ranked.id;
$$;
revoke all on function public.qzix_demo_my_priority() from public, anon;
grant execute on function public.qzix_demo_my_priority() to authenticated;
grant select, insert on public.qzix_demo_share_records to authenticated;
grant usage, select on sequence public.qzix_demo_share_records_id_seq to authenticated;
grant select on public.qzix_demo_audit_log to authenticated;
