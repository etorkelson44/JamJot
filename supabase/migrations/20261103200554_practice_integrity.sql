-- Additive release against the inspected live schema (27 migrations through
-- 20261102010521). Do not apply as a replacement for the missing live baseline.
create schema if not exists jamjot_private;
revoke all on schema jamjot_private from public, anon, authenticated;

alter table public.sessions add column if not exists manual_override_seconds integer
  check (manual_override_seconds between 0 and 14400);
alter table public.sessions add column if not exists recorded_seconds integer;
alter table public.berry_ledger add column if not exists reconciliation_key text;
alter table public.fan_ledger add column if not exists reconciliation_key text;
create unique index if not exists berry_reconciliation_key on public.berry_ledger(reconciliation_key);
create unique index if not exists fan_reconciliation_key on public.fan_ledger(reconciliation_key);
alter table public.purchases add column if not exists request_id uuid;
create unique index if not exists purchase_request on public.purchases(student_id, request_id);

create table jamjot_private.practice_corrections (
  id uuid primary key default gen_random_uuid(), student_id uuid not null,
  session_id uuid not null, actor_id uuid not null, action text not null,
  before_value jsonb not null, requested_value jsonb not null, created_at timestamptz not null default now()
);
create table jamjot_private.recording_cleanup (
  path text primary key, student_id uuid not null, created_at timestamptz not null default now()
);
alter table jamjot_private.practice_corrections enable row level security;
alter table jamjot_private.recording_cleanup enable row level security;
grant usage on schema jamjot_private to service_role;
grant select, delete on jamjot_private.recording_cleanup to service_role;

create function public.can_correct_practice(sid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and (
    exists (select 1 from public.guardianships g where g.student_id=sid
      and g.profile_id=auth.uid() and (g.is_primary or g.can_adjust_practice))
    or exists (select 1 from public.enrollments e join public.teachers t on t.id=e.teacher_id
      where e.student_id=sid and e.status='active' and t.profile_id=auth.uid())
    or exists (select 1 from public.enrollments e join public.studios s on s.id=e.studio_id
      where e.student_id=sid and e.status='active' and s.owner_id=auth.uid())
  );
$$;
revoke all on function public.can_correct_practice(uuid) from public, anon;
grant execute on function public.can_correct_practice(uuid) to authenticated;

-- One deterministic settlement shared by automatic awards and corrections.
-- Original ledger rows stay intact; a single balancing row records each session's
-- difference. Negative balances are allowed after corrections, preserving purchases.
create function jamjot_private.settle_practice(sid uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  s record; song record; day_key date; previous_day date; nth integer := 0;
  coins integer; fans integer; goal integer; mins integer; repeats integer;
  old_coins integer; old_fans integer; eligible boolean; day_minutes integer; daily_bonus_paid boolean := false;
begin
  perform pg_advisory_xact_lock(hashtextextended(sid::text, 0));
  -- Retain the prior server-clock cap for automatic minutes.
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
end;
$$;
revoke all on function jamjot_private.settle_practice(uuid) from public, anon, authenticated;

-- Public wrapper checks ownership, then settles inside a single locked transaction.
create function public.settle_practice_session(p_session_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare sid uuid; before_coins integer; before_fans integer; after_coins integer; after_fans integer; s record;
begin
  select student_id into sid from public.sessions where id=p_session_id;
  if sid is null or auth.uid() is null or not (
      public.is_self_student(sid) or public.is_guardian(sid) or public.can_correct_practice(sid)) then
    raise exception 'Practice is not available to this account' using errcode='42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(sid::text,0));
  select coalesce(sum(amount),0) into before_coins from public.berry_ledger where student_id=sid;
  select coalesce(sum(amount),0) into before_fans from public.fan_ledger where student_id=sid;
  perform jamjot_private.settle_practice(sid);
  select coalesce(sum(amount),0) into after_coins from public.berry_ledger where student_id=sid;
  select coalesce(sum(amount),0) into after_fans from public.fan_ledger where student_id=sid;
  select * into s from public.sessions where id=p_session_id;
  return jsonb_build_object('ok',true,'berries',after_coins-before_coins,'fans',after_fans-before_fans,
    'minutes',s.total_seconds/60,'goal_met',s.goal_met);
end;
$$;
revoke all on function public.settle_practice_session(uuid) from public, anon;
grant execute on function public.settle_practice_session(uuid) to authenticated;

create function public.correct_practice(p_session_id uuid, p_action text,
    p_segment_id uuid default null, p_path text default null, p_minutes integer default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare s record; seg record; paths text[] := '{}'; c jsonb; remaining jsonb; removed_seconds integer; new_seconds integer;
begin
  select * into s from public.sessions where id=p_session_id;
  if not found or not public.can_correct_practice(s.student_id) then
    raise exception 'Only an authorized grown-up can correct this practice' using errcode='42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(s.student_id::text,0));
  select * into s from public.sessions where id=p_session_id for update;
  if s.ended_at is null then raise exception 'Finish this practice before editing it'; end if;
  insert into jamjot_private.practice_corrections(student_id,session_id,actor_id,action,before_value,requested_value)
    values(s.student_id,s.id,auth.uid(),p_action,to_jsonb(s),jsonb_build_object('segment',p_segment_id,'path',p_path,'minutes',p_minutes));
  if p_action='minutes' then
    if p_minutes is null or p_minutes not between 0 and 240 then raise exception 'Enter 0 to 240 minutes'; end if;
    update public.sessions set recorded_seconds=case when manual_override_seconds is null then total_seconds else recorded_seconds end,
      manual_override_seconds=p_minutes*60,total_seconds=p_minutes*60 where id=s.id;
  elsif p_action='automatic_minutes' then
    update public.sessions set total_seconds=coalesce(recorded_seconds,total_seconds),
      manual_override_seconds=null, recorded_seconds=null where id=s.id;
  elsif p_action='delete_session' then
    select coalesce(array_agg(p),'{}') into paths from public.session_segments x
      cross join lateral unnest(x.audio_paths) p where x.session_id=s.id;
    if s.audio_path is not null then paths:=array_append(paths,s.audio_path); end if;
    delete from public.berry_ledger where session_id=s.id;
    delete from public.fan_ledger where session_id=s.id;
    delete from public.sessions where id=s.id;
  elsif p_action in ('delete_song','delete_recording') then
    select * into seg from public.session_segments where id=p_segment_id and session_id=s.id for update;
    if not found then raise exception 'Song practice not found'; end if;
    if p_action='delete_song' then
      paths:=seg.audio_paths;
      removed_seconds:=seg.seconds;
      delete from public.session_segments where id=seg.id;
    else
      select value into c from jsonb_array_elements(seg.audio_clips) where value->>'path'=p_path;
      if c is null then raise exception 'This older recording needs its song practice removed to adjust minutes safely'; end if;
      paths:=array[p_path];
      removed_seconds:=least(seg.seconds,greatest(0,coalesce((c->>'sound_seconds')::integer,0)));
      select coalesce(jsonb_agg(value),'[]') into remaining from jsonb_array_elements(seg.audio_clips) where value->>'path'<>p_path;
      update public.session_segments set audio_clips=remaining,audio_paths=array_remove(audio_paths,p_path),
        seconds=greatest(0,seconds-removed_seconds),
        wall_seconds=greatest(0,wall_seconds-coalesce((c->>'wall_seconds')::integer,0)) where id=seg.id;
    end if;
    new_seconds:=greatest(0,(case when s.manual_override_seconds is null then s.total_seconds else coalesce(s.recorded_seconds,0) end)-removed_seconds);
    update public.sessions set recorded_seconds=new_seconds,
      total_seconds=coalesce(manual_override_seconds,new_seconds) where id=s.id;
  else raise exception 'Unknown practice correction'; end if;
  insert into jamjot_private.recording_cleanup(path,student_id)
    select distinct p,s.student_id from unnest(paths) p where p like s.student_id::text||'/%'
    on conflict(path) do nothing;
  perform jamjot_private.settle_practice(s.student_id);
  return jsonb_build_object('ok',true,'student_id',s.student_id,'cleanup_paths',paths);
end;
$$;
revoke all on function public.correct_practice(uuid,text,uuid,text,integer) from public,anon;
grant execute on function public.correct_practice(uuid,text,uuid,text,integer) to authenticated;

create function public.purchase_market_item(p_student_id uuid,p_item_id uuid,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare item public.market_items; balance integer; purchase public.purchases;
begin
  if auth.uid() is null or not (public.is_self_student(p_student_id) or public.is_guardian(p_student_id)) then
    raise exception 'This account cannot spend these coins' using errcode='42501';
  end if;
  if p_request_id is null then raise exception 'Purchase request required'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_student_id::text,0));
  select * into purchase from public.purchases where student_id=p_student_id and request_id=p_request_id;
  if found then
    if purchase.item_id<>p_item_id then raise exception 'Purchase request already used'; end if;
    return jsonb_build_object('ok',true,'purchase_id',purchase.id,'already_purchased',true);
  end if;
  -- Check item visibility under the caller's policies before privileged writes.
  select * into item from public.market_items m where id=p_item_id and active and (
    stand='jamjot' or (stand='caregiver' and (student_id=p_student_id or
      (student_id is null and exists(select 1 from public.guardianships g where g.student_id=p_student_id and g.profile_id=m.owner_id))))
    or (stand='teacher' and exists(select 1 from public.enrollments e join public.teachers t on t.id=e.teacher_id
      where e.student_id=p_student_id and e.status='active' and (t.profile_id=m.owner_id or e.studio_id=m.studio_id)))
  );
  if not found then raise exception 'That item is not on this student''s stand'; end if;
  if item.kind='avatar' and exists(select 1 from public.purchases p join public.market_items m on m.id=p.item_id
      where p.student_id=p_student_id and m.asset_key=item.asset_key) then
    raise exception 'Already owned — choose it from My Shelf'; end if;
  select coalesce(sum(amount),0) into balance from public.berry_ledger where student_id=p_student_id;
  if balance<item.price then raise exception 'Not enough coins: this costs %, your pouch holds %',item.price,balance; end if;
  insert into public.purchases(student_id,item_id,price_paid,status,request_id)
    values(p_student_id,item.id,item.price,case when item.kind='avatar' then 'fulfilled' else 'pending' end,p_request_id)
    returning * into purchase;
  insert into public.berry_ledger(student_id,amount,reason) values(p_student_id,-item.price,'market: '||item.title);
  if item.kind='avatar' and item.asset_key is not null then
    update public.students set avatar_key=item.asset_key where id=p_student_id;
  end if;
  return jsonb_build_object('ok',true,'purchase_id',purchase.id,'new_balance',balance-item.price,'kind',item.kind);
end;
$$;
revoke all on function public.purchase_market_item(uuid,uuid,uuid) from public,anon;
grant execute on function public.purchase_market_item(uuid,uuid,uuid) to authenticated;
-- Purchase insertion is exclusively the atomic RPC. Fulfillment remains unchanged.
drop policy if exists purchases_insert on public.purchases;

alter table public.sessions add column if not exists request_id uuid;
create unique index if not exists session_request on public.sessions(student_id,request_id);
create function public.log_practice_entry(p_student_id uuid,p_date date,p_minutes integer,p_note text,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare entry public.sessions; coins integer; fans integer;
begin
  if not public.can_correct_practice(p_student_id) then raise exception 'Only an authorized grown-up can log practice' using errcode='42501'; end if;
  if p_minutes is null or p_minutes not between 1 and 240 then raise exception 'Enter 1 to 240 minutes'; end if;
  if p_date is null or p_date>current_date or p_request_id is null then raise exception 'Choose a valid practice date'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_student_id::text,0));
  insert into public.sessions(student_id,started_at,ended_at,total_seconds,source,entered_by,entry_note,request_id)
    values(p_student_id,p_date+time '12:00' at time zone 'UTC',
      (p_date+time '12:00' at time zone 'UTC')+make_interval(mins=>p_minutes),p_minutes*60,'manual',auth.uid(),nullif(trim(p_note),''),p_request_id)
    on conflict(student_id,request_id) do nothing;
  select * into entry from public.sessions where student_id=p_student_id and request_id=p_request_id;
  perform jamjot_private.settle_practice(p_student_id);
  select coalesce(sum(amount),0) into coins from public.berry_ledger where session_id=entry.id;
  select coalesce(sum(amount),0) into fans from public.fan_ledger where session_id=entry.id;
  return jsonb_build_object('ok',true,'session_id',entry.id,'coins',coins,'fans',fans);
end;
$$;
revoke all on function public.log_practice_entry(uuid,date,integer,text,uuid) from public,anon;
grant execute on function public.log_practice_entry(uuid,date,integer,text,uuid) to authenticated;

-- Server-only cleanup API; private schema stays outside the Data API.
create function public.recording_cleanup_paths(p_student_id uuid) returns setof text
language sql security definer set search_path='' as $$
  select path from jamjot_private.recording_cleanup where student_id=p_student_id;
$$;
create function public.ack_recording_cleanup(p_paths text[]) returns void
language sql security definer set search_path='' as $$
  delete from jamjot_private.recording_cleanup where path=any(p_paths);
$$;
revoke all on function public.recording_cleanup_paths(uuid) from public,anon,authenticated;
revoke all on function public.ack_recording_cleanup(text[]) from public,anon,authenticated;
grant execute on function public.recording_cleanup_paths(uuid) to service_role;
grant execute on function public.ack_recording_cleanup(text[]) to service_role;

-- Preserve recording progress writes; edits to authoritative override fields and
-- direct deletes are reserved for the audited correction transaction.
revoke delete on public.sessions,public.session_segments from authenticated;
revoke update on public.sessions from authenticated;
grant update(ended_at,total_seconds) on public.sessions to authenticated;

-- A child can discard only an unfiled take from their own current session.
create function public.discard_recording(p_session_id uuid,p_path text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare sid uuid;
begin
  select student_id into sid from public.sessions where id=p_session_id and ended_at is null;
  if sid is null or auth.uid() is null or not (public.is_self_student(sid) or public.is_guardian(sid)) then
    raise exception 'This recording cannot be discarded' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended(sid::text,0));
  if p_path not like sid::text||'/'||p_session_id::text||'/%' or
    exists(select 1 from public.session_segments where p_path=any(audio_paths)) then
    raise exception 'Saved recordings must be removed by a grown-up'; end if;
  insert into jamjot_private.recording_cleanup(path,student_id) values(p_path,sid) on conflict do nothing;
  return jsonb_build_object('ok',true,'student_id',sid);
end;
$$;
revoke all on function public.discard_recording(uuid,text) from public,anon;
grant execute on function public.discard_recording(uuid,text) to authenticated;

alter table public.lessons add column if not exists assignment_request uuid;
create unique index if not exists lesson_assignment_request on public.lessons(created_by,assignment_request);
create function public.assign_library_lesson(p_lesson jsonb,p_assignments jsonb,p_request_id uuid)
returns uuid language plpgsql security invoker set search_path='' as $$
declare lesson_id uuid; song jsonb; ordinal bigint;
begin
  if auth.uid() is null or p_request_id is null then raise exception 'Sign in before assigning a lesson'; end if;
  select id into lesson_id from public.lessons where created_by=auth.uid() and assignment_request=p_request_id;
  if found then return lesson_id; end if;
  if nullif(trim(p_lesson->>'title'),'') is null or jsonb_array_length(p_assignments)=0 then raise exception 'A title and at least one song are required'; end if;
  if (p_lesson->>'goal_days')::integer not between 1 and 7 or (p_lesson->>'goal_minutes')::integer not between 1 and 240 then raise exception 'Choose 1–7 days and 1–240 minutes'; end if;
  insert into public.lessons(student_id,enrollment_id,created_by,title,lesson_note,goal_days,goal_minutes,week_start,event_id,assignment_request)
    values((p_lesson->>'student_id')::uuid,(p_lesson->>'enrollment_id')::uuid,auth.uid(),p_lesson->>'title',coalesce(p_lesson->>'lesson_note',''),
      (p_lesson->>'goal_days')::integer,(p_lesson->>'goal_minutes')::integer,(p_lesson->>'week_start')::date,(p_lesson->>'event_id')::uuid,p_request_id)
    returning id into lesson_id;
  for song,ordinal in select value, ordinality from jsonb_array_elements(p_assignments) with ordinality loop
    if nullif(trim(song->>'title'),'') is null then raise exception 'Each song needs a title'; end if;
    insert into public.assignments(lesson_id,title,song_note,score_id,order_idx,suggested_minutes)
      values(lesson_id,song->>'title',coalesce(song->>'note',''),(song->>'score_id')::uuid,ordinal-1,(song->>'suggested_minutes')::integer);
  end loop;
  return lesson_id;
end;
$$;
revoke all on function public.assign_library_lesson(jsonb,jsonb,uuid) from public,anon;
grant execute on function public.assign_library_lesson(jsonb,jsonb,uuid) to authenticated;

revoke insert on public.sessions from authenticated;
grant insert(id,student_id) on public.sessions to authenticated;

-- Studio owners granted correction access must also be able to read the result.
create policy correction_sessions_read on public.sessions for select to authenticated using(public.can_correct_practice(student_id));
create policy correction_segments_read on public.session_segments for select to authenticated using(
  exists(select 1 from public.sessions s where s.id=session_id and public.can_correct_practice(s.student_id)));
create policy correction_coins_read on public.berry_ledger for select to authenticated using(public.can_correct_practice(student_id));
create policy correction_fans_read on public.fan_ledger for select to authenticated using(public.can_correct_practice(student_id));
create policy correction_lessons_read on public.lessons for select to authenticated using(public.can_correct_practice(student_id));
create policy correction_assignments_read on public.assignments for select to authenticated using(
  exists(select 1 from public.lessons l where l.id=lesson_id and public.can_correct_practice(l.student_id)));

create function public.wear_owned_avatar(p_student_id uuid,p_asset_key text) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or not (public.is_self_student(p_student_id) or public.is_guardian(p_student_id)) then
    raise exception 'This account cannot change this avatar' using errcode='42501'; end if;
  if not exists(select 1 from public.purchases p join public.market_items m on m.id=p.item_id
      where p.student_id=p_student_id and m.kind='avatar' and m.asset_key=p_asset_key) then
    raise exception 'Choose an avatar from this student''s shelf'; end if;
  update public.students set avatar_key=p_asset_key where id=p_student_id;
  return jsonb_build_object('ok',true);
end;
$$;
revoke all on function public.wear_owned_avatar(uuid,text) from public,anon;
grant execute on function public.wear_owned_avatar(uuid,text) to authenticated;

-- Older clients must not overwrite a grown-up's authoritative credited minutes.
create function jamjot_private.protect_credited_minutes() returns trigger
language plpgsql set search_path='' as $$
begin
  if current_user in ('authenticated','anon') and
      (old.source='manual' or old.manual_override_seconds is not null) then
    raise exception 'A grown-up has adjusted this practice. Refresh before recording again' using errcode='42501';
  end if;
  return new;
end;
$$;
revoke all on function jamjot_private.protect_credited_minutes() from public,anon,authenticated;
create trigger protect_credited_minutes before update on public.sessions
  for each row execute function jamjot_private.protect_credited_minutes();
