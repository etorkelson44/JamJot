-- JJ-046-C: (1) hide / unhide an instrument, (2) teachers can rotate their code,
-- (3) every single-use invite expires after 30 days, plus the columns the invite emails need.
--
-- Hide is NOT delete. A hidden instrument keeps every lesson, assignment, goal and past session;
-- the app simply stops showing it, and it stops counting toward Full Band while hidden.
-- Unhide brings everything back. Additive: new columns/tables/functions, one replaced function
-- (settle_practice: only the Full Band instrument list changes).

alter table public.students add column if not exists hidden_instruments text[] not null default '{}';
-- (no column grant to `authenticated`: only hide_instrument / unhide_instrument change it)

create table if not exists public.instrument_hidden_periods (
  id             uuid primary key default gen_random_uuid(),
  student_id     uuid not null references public.students(id) on delete cascade,
  instrument_key text not null,
  hidden_from    date not null,
  hidden_until   date            -- null = still hidden
);
create index if not exists instrument_hidden_periods_student on public.instrument_hidden_periods(student_id);
alter table public.instrument_hidden_periods enable row level security;   -- internal; no client access

create or replace function public.hide_instrument(p_student_id uuid, p_instrument text)
returns void language plpgsql security definer set search_path='' as $$
declare k text := lower(trim(coalesce(p_instrument,''))); visible integer; hid text[]; today date := (now() at time zone 'UTC')::date;
begin
  if auth.uid() is null then raise exception 'Sign in first' using errcode='42501'; end if;
  if not public.is_guardian(p_student_id) then
    raise exception 'Only a caregiver can hide an instrument' using errcode='42501'; end if;
  if not exists (select 1 from public.student_instruments where student_id=p_student_id and lower(instrument)=k) then
    raise exception 'That instrument is not on this student'; end if;
  if exists (select 1 from public.students where id=p_student_id and k = any(hidden_instruments)) then return; end if;
  select hidden_instruments into hid from public.students where id=p_student_id;
  select count(*) into visible from public.student_instruments si
    where si.student_id=p_student_id and lower(si.instrument) <> k
      and not (lower(si.instrument) = any(coalesce(hid,'{}')));
  if visible < 1 then
    raise exception 'At least one instrument has to stay showing. Add another instrument first.'; end if;
  update public.students set hidden_instruments = array_append(hidden_instruments, k) where id=p_student_id;
  insert into public.instrument_hidden_periods(student_id, instrument_key, hidden_from) values (p_student_id, k, today);
end; $$;

create or replace function public.unhide_instrument(p_student_id uuid, p_instrument text)
returns void language plpgsql security definer set search_path='' as $$
declare k text := lower(trim(coalesce(p_instrument,''))); today date := (now() at time zone 'UTC')::date;
begin
  if auth.uid() is null then raise exception 'Sign in first' using errcode='42501'; end if;
  if not public.is_guardian(p_student_id) then
    raise exception 'Only a caregiver can show an instrument again' using errcode='42501'; end if;
  update public.students set hidden_instruments = array_remove(hidden_instruments, k) where id=p_student_id;
  update public.instrument_hidden_periods set hidden_until = today
    where student_id=p_student_id and instrument_key=k and hidden_until is null;
end; $$;

-- Deleting an instrument for good also ends any hidden state for it.
create or replace function public.clear_hidden_on_instrument_delete() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  update public.students set hidden_instruments = array_remove(hidden_instruments, lower(old.instrument)) where id=old.student_id;
  update public.instrument_hidden_periods set hidden_until=(now() at time zone 'UTC')::date
    where student_id=old.student_id and instrument_key=lower(old.instrument) and hidden_until is null;
  return null;
end; $$;
create trigger student_instruments_clear_hidden after delete on public.student_instruments
  for each row execute function public.clear_hidden_on_instrument_delete();

revoke all on function public.hide_instrument(uuid,text) from public, anon;
revoke all on function public.unhide_instrument(uuid,text) from public, anon;
revoke all on function public.clear_hidden_on_instrument_delete() from public, anon, authenticated;
grant execute on function public.hide_instrument(uuid,text) to authenticated;
grant execute on function public.unhide_instrument(uuid,text) to authenticated;

-- Teacher code rotation. Families are connected through the teacher link (enrollment),
-- never through the code text, so changing the code disconnects nobody.
alter table public.teacher_codes add column if not exists rotated_at timestamptz;
create or replace function public.rotate_teacher_code(p_teacher_id uuid) returns text
language plpgsql security definer set search_path='' as $$
declare c text;
begin
  if auth.uid() is null then raise exception 'Sign in first' using errcode='42501'; end if;
  if not exists (select 1 from public.teachers where id=p_teacher_id and profile_id=auth.uid()) then
    raise exception 'Only the teacher can change their code' using errcode='42501'; end if;
  update public.teacher_codes set code=public.new_teacher_code(), rotated_at=now()
    where teacher_id=p_teacher_id returning code into c;
  return c;
end; $$;
revoke all on function public.rotate_teacher_code(uuid) from public, anon;
grant execute on function public.rotate_teacher_code(uuid) to authenticated;

-- Invitations: 30-day expiry for every single-use invite (standing studio codes never expire),
-- plus bookkeeping for invite emails (written only by the edge functions).
alter table public.invitations add column if not exists invitee_email text;
alter table public.invitations add column if not exists email_sent_at timestamptz;
alter table public.invitations add column if not exists accepted_notice_at timestamptz;

create or replace function public.invitation_default_expiry() returns trigger
language plpgsql set search_path='' as $$
begin
  if new.expires_at is null and new.single_use then new.expires_at := now() + interval '30 days'; end if;
  return new;
end; $$;
create trigger invitations_default_expiry before insert on public.invitations
  for each row execute function public.invitation_default_expiry();
update public.invitations set expires_at = now() + interval '30 days'
  where expires_at is null and single_use and used_at is null;

create or replace function jamjot_private.settle_practice(sid uuid)
 returns void language plpgsql security definer set search_path to '' as $function$
declare
  s record; song record; day_key date; previous_day date; nth integer := 0;
  coins integer; fans integer; goal integer; mins integer; repeats integer;
  old_coins integer; old_fans integer; eligible boolean; day_minutes integer;
  first_instr text; inst text; paid_inst text[] := '{}'; fullband_paid boolean := false;
  fb_total integer; fb_met integer;
begin
  perform pg_advisory_xact_lock(hashtextextended(sid::text, 0));
  select lower(coalesce(st.instruments[1],'music')) into first_instr from public.students st where st.id=sid;
  first_instr := coalesce(first_instr,'music');
  update public.sessions set total_seconds=least(greatest(total_seconds,0),
    greatest(0,extract(epoch from (coalesce(ended_at,now())-started_at))::integer+60))
    where student_id=sid and source='app' and manual_override_seconds is null;
  for s in select * from public.sessions where student_id=sid order by started_at,id loop
    day_key := (s.started_at at time zone 'UTC')::date;
    inst := lower(coalesce(s.instrument, first_instr));
    if previous_day is distinct from day_key then
      nth:=0; previous_day:=day_key; paid_inst:='{}'; fullband_paid:=false;
    end if;
    select coalesce(sum(coalesce(x.manual_override_seconds,x.total_seconds)),0)/60 into day_minutes
      from public.sessions x
      where x.student_id=sid and (x.started_at at time zone 'UTC')::date=day_key
        and lower(coalesce(x.instrument, first_instr))=inst;
    select coalesce(max(l.goal_minutes),15) into goal from (
      select distinct on (coalesce(enrollment_id::text,'family')) goal_minutes
      from public.lessons
      where student_id=sid and (week_start is null or week_start <= day_key)
        and lower(coalesce(instrument, first_instr))=inst
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
      if s.ended_at is not null and day_minutes>=goal and not (inst = any(paid_inst)) then
        coins:=coins+10+least(day_minutes-goal,10);
        paid_inst:=array_append(paid_inst, inst);
      end if;
      -- Full Band: every instrument that has a lesson met its own daily goal today.
      if s.ended_at is not null and not fullband_paid then
        select count(*), count(*) filter (where t.dm >= t.goal) into fb_total, fb_met from (
          select g.ik, g.goal,
                 coalesce((select sum(coalesce(x.manual_override_seconds,x.total_seconds))
                           from public.sessions x
                           where x.student_id=sid and (x.started_at at time zone 'UTC')::date=day_key
                             and lower(coalesce(x.instrument, first_instr))=g.ik),0)/60 as dm
          from (
            select z.ik, greatest(max(z.goal_minutes),1) as goal from (
              select distinct on (lower(coalesce(lz.instrument, first_instr)), coalesce(lz.enrollment_id::text,'family'))
                     lower(coalesce(lz.instrument, first_instr)) as ik, lz.goal_minutes
              from public.lessons lz
              where lz.student_id=sid and (lz.week_start is null or lz.week_start <= day_key)
                and not (
                  exists (select 1 from public.instrument_hidden_periods hp
                          where hp.student_id=sid and hp.instrument_key=lower(coalesce(lz.instrument, first_instr))
                            and hp.hidden_from <= day_key and (hp.hidden_until is null or day_key < hp.hidden_until))
                  and not exists (select 1 from public.sessions hs
                          where hs.student_id=sid and (hs.started_at at time zone 'UTC')::date=day_key
                            and lower(coalesce(hs.instrument, first_instr))=lower(coalesce(lz.instrument, first_instr)))
                )
              order by lower(coalesce(lz.instrument, first_instr)), coalesce(lz.enrollment_id::text,'family'),
                       lz.week_start desc nulls last, lz.created_at desc
            ) z group by z.ik
          ) g
        ) t;
        if fb_total >= 2 and fb_met = fb_total then
          coins:=coins+10;
          fullband_paid:=true;
        end if;
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
  -- Full Setlist weekly bonus (unchanged from 20261106041327).
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


-- ROLLBACK: restore settle_practice from 20261110200000_per_instrument_practice.sql;
--   drop trigger student_instruments_clear_hidden on public.student_instruments; drop trigger invitations_default_expiry on public.invitations;
--   drop function public.hide_instrument(uuid,text), public.unhide_instrument(uuid,text), public.rotate_teacher_code(uuid),
--     public.clear_hidden_on_instrument_delete(), public.invitation_default_expiry();
--   drop table public.instrument_hidden_periods; alter table public.students drop column hidden_instruments;
--   alter table public.teacher_codes drop column rotated_at;
--   alter table public.invitations drop column invitee_email, drop column email_sent_at, drop column accepted_notice_at;
