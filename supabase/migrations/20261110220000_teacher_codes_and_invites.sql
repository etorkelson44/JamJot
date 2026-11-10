-- JJ-043-C step 3 (JJ-044-C: permanent teacher codes): connecting a teacher to a student's
-- instrument two ways.
--  1. connect_teacher_by_code: a primary caregiver enters the teacher's permanent code.
--     Wrong codes are counted; 10 wrong in an hour pauses guessing for that account.
--  2. Teacher invites for teachers not on JamJot yet: a caregiver creates an invite
--     (expires in 30 days; this length is still an open decision), the teacher sees the
--     student's first name + last initial + instrument before accepting, and accepting
--     connects them and fills in the instrument's teacher automatically.
-- Additive: one relaxed check constraint, one small table, five functions.

alter table public.invitations drop constraint if exists invitations_kind_check;
alter table public.invitations add constraint invitations_kind_check
  check (kind in ('caregiver','enrollment','studio_code','teacher_invite'));

create table if not exists public.teacher_code_attempts (
  id         bigint generated always as identity primary key,
  profile_id uuid not null,
  ok         boolean not null,
  at         timestamptz not null default now()
);
alter table public.teacher_code_attempts enable row level security; -- no policies: functions only

-- Make sure one active-or-pending enrollment exists for student x teacher x instrument.
create or replace function public.ensure_enrollment(p_student uuid, p_teacher uuid, p_instrument text)
returns uuid language plpgsql security definer set search_path='' as $$
declare eid uuid; studio uuid;
begin
  select id into eid from public.enrollments
    where student_id=p_student and teacher_id=p_teacher and lower(instrument)=lower(p_instrument)
      and status in ('pending','active') limit 1;
  if eid is not null then
    update public.enrollments set status='active' where id=eid and status='pending';
    return eid;
  end if;
  select studio_id into studio from public.teachers where id=p_teacher;
  insert into public.enrollments(student_id, teacher_id, studio_id, instrument, status, billing_owner)
    values(p_student, p_teacher, studio, p_instrument, 'active', case when studio is not null then 'studio' else 'teacher' end)
    returning id into eid;
  return eid;
end;
$$;
revoke all on function public.ensure_enrollment(uuid,uuid,text) from public, anon, authenticated;

create or replace function public.connect_teacher_by_code(p_code text, p_student_id uuid, p_instrument text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare t record; eid uuid; fails integer; n integer;
begin
  if auth.uid() is null then raise exception 'Sign in first' using errcode='42501'; end if;
  if not public.is_primary_guardian(p_student_id) then
    raise exception 'Only the primary caregiver can connect a teacher' using errcode='42501';
  end if;
  select count(*) into fails from public.teacher_code_attempts
    where profile_id=auth.uid() and not ok and at > now() - interval '1 hour';
  if fails >= 10 then
    return jsonb_build_object('ok',false,'error','Too many codes that did not match. Please try again in an hour.');
  end if;
  select tc.teacher_id, te.display_name, st.name as studio_name into t
    from public.teacher_codes tc join public.teachers te on te.id = tc.teacher_id
    left join public.studios st on st.id = te.studio_id
    where tc.code = upper(regexp_replace(coalesce(p_code,''), '[^A-Za-z0-9]', '', 'g'));
  if not found then
    insert into public.teacher_code_attempts(profile_id, ok) values (auth.uid(), false);
    return jsonb_build_object('ok',false,'error','That code was not found. Please check it with your teacher.');
  end if;
  if not exists (select 1 from public.student_instruments
                 where student_id=p_student_id and lower(instrument)=lower(p_instrument)) then
    return jsonb_build_object('ok',false,'error','Add that instrument to the student first.');
  end if;
  insert into public.teacher_code_attempts(profile_id, ok) values (auth.uid(), true);
  eid := public.ensure_enrollment(p_student_id, t.teacher_id, p_instrument);
  update public.student_instruments
     set instruction='teacher', enrollment_id=eid, teacher_name=null
   where student_id=p_student_id and lower(instrument)=lower(p_instrument);
  return jsonb_build_object('ok',true,'teacher_name',t.display_name,'studio_name',t.studio_name,'enrollment_id',eid);
end;
$$;

create or replace function public.create_teacher_invite(
    p_student_id uuid, p_instrument text, p_teacher_name text, p_known_as text, p_last_initial text)
returns text language plpgsql security definer set search_path='' as $$
declare inv record;
begin
  if auth.uid() is null then raise exception 'Sign in first' using errcode='42501'; end if;
  if not public.is_primary_guardian(p_student_id) then
    raise exception 'Only the primary caregiver can invite a teacher' using errcode='42501';
  end if;
  if not exists (select 1 from public.student_instruments
                 where student_id=p_student_id and lower(instrument)=lower(p_instrument)) then
    raise exception 'Add that instrument to the student first';
  end if;
  insert into public.invitations(kind, created_by, student_id, instrument, single_use, expires_at, preset_grants)
    values ('teacher_invite', auth.uid(), p_student_id, p_instrument, true, now() + interval '30 days',
            jsonb_build_object('teacher_name', nullif(trim(p_teacher_name),''),
                               'known_as', nullif(trim(p_known_as),''),
                               'last_initial', upper(left(nullif(trim(p_last_initial),''),1))))
    returning * into inv;
  update public.student_instruments
     set instruction='teacher', invitation_id=inv.id,
         teacher_name=coalesce(nullif(trim(p_teacher_name),''), teacher_name),
         teacher_known_as=coalesce(nullif(trim(p_known_as),''), teacher_known_as)
   where student_id=p_student_id and lower(instrument)=lower(p_instrument);
  return inv.token;
end;
$$;

-- What a teacher sees before accepting (callable signed out; the token is the secret).
create or replace function public.teacher_invite_preview(p_token text)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare inv record; stu record; g jsonb;
begin
  select * into inv from public.invitations where token=p_token and kind='teacher_invite';
  if not found then return null; end if;
  if inv.used_at is not null then return jsonb_build_object('status','used'); end if;
  if inv.expires_at is not null and inv.expires_at < now() then return jsonb_build_object('status','expired'); end if;
  select display_name into stu from public.students where id=inv.student_id;
  g := inv.preset_grants;
  return jsonb_build_object('status','ok','instrument',inv.instrument,
    'student', stu.display_name || case when coalesce(g->>'last_initial','')<>'' then ' '||(g->>'last_initial')||'.' else '' end);
end;
$$;

create or replace function public.accept_teacher_invite(p_token text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare inv record; tid uuid; eid uuid; stu record; g jsonb;
begin
  if auth.uid() is null then raise exception 'Sign in first' using errcode='42501'; end if;
  select * into inv from public.invitations where token=p_token and kind='teacher_invite' for update;
  if not found then return jsonb_build_object('ok',false,'error','Invite not found'); end if;
  if inv.used_at is not null then return jsonb_build_object('ok',false,'error','This invite was already used'); end if;
  if inv.expires_at is not null and inv.expires_at < now() then
    return jsonb_build_object('ok',false,'error','This invite has expired'); end if;
  select id into tid from public.teachers where profile_id=auth.uid() order by created_at limit 1;
  if tid is null then return jsonb_build_object('ok',false,'error','needs_teacher_profile'); end if;
  eid := public.ensure_enrollment(inv.student_id, tid, inv.instrument);
  update public.student_instruments
     set instruction='teacher', enrollment_id=eid, invitation_id=null, teacher_name=null
   where student_id=inv.student_id and lower(instrument)=lower(inv.instrument);
  update public.invitations set used_at=now(), used_by=auth.uid() where id=inv.id;
  select display_name into stu from public.students where id=inv.student_id;
  g := inv.preset_grants;
  return jsonb_build_object('ok',true,'instrument',inv.instrument,
    'student', stu.display_name || case when coalesce(g->>'last_initial','')<>'' then ' '||(g->>'last_initial')||'.' else '' end);
end;
$$;

revoke all on function public.connect_teacher_by_code(text,uuid,text) from public, anon;
revoke all on function public.create_teacher_invite(uuid,text,text,text,text) from public, anon;
revoke all on function public.accept_teacher_invite(text) from public, anon;
revoke all on function public.teacher_invite_preview(text) from public;
grant execute on function public.connect_teacher_by_code(text,uuid,text) to authenticated;
grant execute on function public.create_teacher_invite(uuid,text,text,text,text) to authenticated;
grant execute on function public.accept_teacher_invite(text) to authenticated;
grant execute on function public.teacher_invite_preview(text) to anon, authenticated;

-- ROLLBACK: drop the five functions and teacher_code_attempts; restore the original kind check
--           (caregiver, enrollment, studio_code) after deleting any teacher_invite rows.
