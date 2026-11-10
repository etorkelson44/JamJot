-- Same change; the void version must be dropped before the jsonb one lands.
drop function if exists public.verify_written_assignment(uuid);
create function public.verify_written_assignment(p_assignment_id uuid)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare sid uuid; before_coins integer; after_coins integer; before_fans integer; after_fans integer;
begin
  select l.student_id into sid from public.assignments a join public.lessons l on l.id=a.lesson_id where a.id=p_assignment_id;
  if sid is null or auth.uid() is null or not public.is_guardian(sid) then
    raise exception 'Only a caregiver can confirm written work' using errcode='42501';
  end if;
  update public.assignments set written_verified_at=now(), written_verified_by=auth.uid()
    where id=p_assignment_id and kind in ('written','both')
      and written_done_at is not null and jsonb_array_length(written_uploads)>0;
  if not found then raise exception 'Mark the written work done (with pages uploaded) first'; end if;
  perform pg_advisory_xact_lock(hashtextextended(sid::text,0));
  select coalesce(sum(amount),0) into before_coins from public.berry_ledger where student_id=sid;
  select coalesce(sum(amount),0) into before_fans from public.fan_ledger where student_id=sid;
  perform jamjot_private.settle_practice(sid);
  select coalesce(sum(amount),0) into after_coins from public.berry_ledger where student_id=sid;
  select coalesce(sum(amount),0) into after_fans from public.fan_ledger where student_id=sid;
  return jsonb_build_object('ok',true,'berries',after_coins-before_coins,'fans',after_fans-before_fans);
end; $$;
