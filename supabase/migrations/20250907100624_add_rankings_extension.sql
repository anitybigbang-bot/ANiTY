create or replace view public.user_watch_count as
select
  r.user_id,
  count(*)::int as watch_count
from public.ratings r
group by r.user_id;

grant select on public.user_watch_count to anon, authenticated;

create or replace view public.user_experience as
select
  uw.user_id,
  case
    when uw.watch_count >= 100 then 'pro'
    when uw.watch_count >= 50  then 'intermediate'
    else 'beginner'
  end as level,
  uw.watch_count
from public.user_watch_count uw;

grant select on public.user_experience to anon, authenticated;

create or replace view public.segment_rating_aggregates as
select
  r.anime_id,
  ue.level,
  avg(r.rating)::float as avg_rating,
  count(*)::int as rating_count
from public.ratings r
join public.user_experience ue on ue.user_id = r.user_id
group by r.anime_id, ue.level;

grant select on public.segment_rating_aggregates to anon, authenticated;

create or replace function public.get_rankings(
  p_segment text default 'all',    -- 'all' | 'beginner' | 'intermediate' | 'pro'
  p_limit int default 50,
  p_offset int default 0,
  p_min_votes int default 20
)
returns table (
  anime_id text,
  avg_rating float8,
  rating_count int,
  bayes_score float8
)
language sql stable set search_path = public as $$
  with base as (
    -- 全体（既存の rating_aggregates を利用）
    select a.anime_id, a.avg_rating, a.rating_count
      from public.rating_aggregates a
     where p_segment = 'all'
    union all
    -- セグメント別（本拡張）
    select s.anime_id, s.avg_rating, s.rating_count
      from public.segment_rating_aggregates s
     where s.level = p_segment and p_segment <> 'all'
  ),
  filtered as (
    select * from base where rating_count >= greatest(1, p_min_votes)
  ),
  global_stats as (
    select coalesce(avg(avg_rating), 0)::float8 as C, p_min_votes::float8 as m
      from filtered
  )
  select f.anime_id,
         f.avg_rating,
         f.rating_count,
         (f.rating_count/(f.rating_count + gs.m)) * f.avg_rating
       + (gs.m/(f.rating_count + gs.m)) * gs.C as bayes_score
    from filtered f cross join global_stats gs
   order by bayes_score desc, rating_count desc
   limit p_limit offset p_offset;
$$;

revoke all on function public.get_rankings(text, int, int, int) from public;
grant execute on function public.get_rankings(text, int, int, int) to anon, authenticated;
