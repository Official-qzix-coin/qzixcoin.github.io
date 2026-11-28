create schema if not exists qzix_private;
revoke all on schema qzix_private from public, anon;
grant usage on schema qzix_private to authenticated;

create or replace function qzix_private.demo_priority_for_current_user()
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
revoke all on function qzix_private.demo_priority_for_current_user() from public, anon;
grant execute on function qzix_private.demo_priority_for_current_user() to authenticated;

create or replace function public.qzix_demo_my_priority()
returns table (
  record_id bigint, level_label text, share_percent numeric,
  illustrative_amount numeric, created_at timestamptz, demo_priority bigint
)
language sql stable security invoker
set search_path = pg_catalog, public, qzix_private
as $$
  select * from qzix_private.demo_priority_for_current_user();
$$;
revoke all on function public.qzix_demo_my_priority() from public, anon;
grant execute on function public.qzix_demo_my_priority() to authenticated;
