-- Founder-approved 2026-11-05 22:11 CT ("Yes do what you suggested"):
-- the Full Setlist bonus. When every assignment on a lesson has been
-- finished at least once during that lesson's week (completed playing
-- segment in-window; written-only = caregiver-confirmed), the student
-- earns +10 coins and +10 fans, exactly once per lesson, idempotently
-- reconciled (key setlist/<lesson id>). Appended to the settle function;
-- everything above the new block is unchanged from the current version.
create or replace function jamjot_private.settle_practice(sid uuid)
 returns void language plpgsql security definer set search_path to '' as $function$
declare
  s record; song record; day_key date; previous_day date; nth integer := 0;
  coins integer; fans integer; goal integer; mins integer; repeats integer;
  old_coins integer; old_fans integer; eligible boolean; day_minutes integer; daily_bonus_paid boolean := false;
begin
  perform pg_advisory_xact_lock(hashtextextended(sid::text, 0));
  update public.sessions set total_seconds=least(greatest(total_seconds,0),
    greatest(0,extract(epoch from (coalesce(ended_at,now())-started_at))::integer+60))
    where student_id=sid and source='app' and manual_override_seconds is null;
  for s in select * from public.sessions where student_id=sid order by started_at,id loop
    day_key := (s.started_at at time zone 'UTC')::date;
    if previous_day is distinct from day_key then nth:=0; previous_day:=day_key; daily_bonus_paid:=false; end if;
    select coalesce(sum(coalesce(manual_override_seconds,total_seconds)),0)/60 into day_minutes
      from public.sessions where student_id=sid and (started_at at time zone 'UTC')::date=day_key;
    select coalesce(max(l.goal_minutes),15) into goal from (
      select distinct on (coalesce(enrollment_id::text,'family')) goal_minutes
      from public.lessons where student_id=sid and (week_start is null or week_start <= day_key)
      order by coalesce(enrollment_id::text,'family'), week_start desc nulls last, created_at desc
    ) l;
    goal := greatest(goal,1);
    mins := greatest(coalesce(s.manual_override_seconds,s.total_seconds),0)/60;
    coins:=0; fans:=0;
    if s.source='manual' or s.manual_override_seconds is not null then
      if mins>0 then coins:=greatest(1,round(mins/2.0)::integer); end if;
      if mins>=2 then fans:=least(15,5*greatest(1,mins/10)); end if;
    else
      for song in select assignment_id, sum(seconds) as seconds,
          bool_or(completed) as completed,
          count(*) filter (where completed and goal_results @> '{"extra_practice":true}' and seconds>=60) as repeats
        from public.session_segments where session_id=s.id and assignment_id is not null
        group by assignment_id order by assignment_id loop
        eligible:=song.completed and song.seconds>=60;
        if eligible then
          nth:=nth+1;
          coins:=coins+5;
          fans:=fans+least(nth*5,15)+least(song.repeats,greatest(0,(song.seconds-60)/60))*5;
        end if;
      end loop;
      if s.ended_at is not null and day_minutes>=goal and not daily_bonus_paid then
        coins:=coins+10+least(day_minutes-goal,10);
        daily_bonus_paid:=true;
      end if;
    end if;
    update public.sessions set goal_met=(day_minutes>=goal) where id=s.id;
    select coalesce(sum(amount),0) into old_coins from public.berry_ledger
      where session_id=s.id and reconciliation_key is null;
    select coalesce(sum(amount),0) into old_fans from public.fan_ledger
      where session_id=s.id and reconciliation_key is null;
    insert into public.berry_ledger(student_id,session_id,amount,reason,reconciliation_key)
      values(sid,s.id,coins-old_coins,'practice_reconciliation','session/'||s.id)
      on conflict(reconciliation_key) do update set amount=excluded.amount;
    insert into public.fan_ledger(student_id,session_id,amount,reason,reconciliation_key)
      values(sid,s.id,fans-old_fans,'practice_reconciliation','session/'||s.id)
      on conflict(reconciliation_key) do update set amount=excluded.amount;
  end loop;
  insert into public.berry_ledger(student_id,assignment_id,amount,reason,reconciliation_key)
    select l.student_id, a.id, 5, 'written_assignment', 'written/'||a.id
    from public.assignments a join public.lessons l on l.id=a.lesson_id
    where l.student_id=sid and a.kind='written' and a.written_verified_at is not null
  on conflict(reconciliation_key) do update set amount=excluded.amount;
  insert into public.fan_ledger(student_id,assignment_id,amount,reason,reconciliation_key)
    select l.student_id, a.id, 5, 'written_assignment', 'written/'||a.id
    from public.assignments a join public.lessons l on l.id=a.lesson_id
    where l.student_id=sid and a.kind='written' and a.written_verified_at is not null
  on conflict(reconciliation_key) do update set amount=excluded.amount;
  -- NEW (founder-approved 2026-11-05): Full Setlist weekly bonus.
  insert into public.berry_ledger(student_id,amount,reason,reconciliation_key)
    select l.student_id, 10, 'full_setlist', 'setlist/'||l.id
    from public.lessons l
    where l.student_id=sid
      and exists (select 1 from public.assignments a where a.lesson_id=l.id)
      and not exists (
        select 1 from public.assignments a
        where a.lesson_id=l.id
          and not (
            (a.kind='written' and a.written_verified_at is not null)
            or exists (
              select 1 from public.session_segments seg
              join public.sessions s2 on s2.id=seg.session_id
              where seg.assignment_id=a.id and seg.completed
                and s2.student_id=sid
                and (l.week_start is null or
                     ((s2.started_at at time zone 'UTC')::date
                        between l.week_start and l.week_start+6))
            )
          )
      )
  on conflict(reconciliation_key) do update set amount=excluded.amount;
  insert into public.fan_ledger(student_id,amount,reason,reconciliation_key)
    select l.student_id, 10, 'full_setlist', 'setlist/'||l.id
    from public.lessons l
    where l.student_id=sid
      and exists (select 1 from public.assignments a where a.lesson_id=l.id)
      and not exists (
        select 1 from public.assignments a
        where a.lesson_id=l.id
          and not (
            (a.kind='written' and a.written_verified_at is not null)
            or exists (
              select 1 from public.session_segments seg
              join public.sessions s2 on s2.id=seg.session_id
              where seg.assignment_id=a.id and seg.completed
                and s2.student_id=sid
                and (l.week_start is null or
                     ((s2.started_at at time zone 'UTC')::date
                        between l.week_start and l.week_start+6))
            )
          )
      )
  on conflict(reconciliation_key) do update set amount=excluded.amount;
end; $function$;
