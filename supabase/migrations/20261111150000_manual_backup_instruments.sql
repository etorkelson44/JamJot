-- Manual data backup, second version: adds the multi-instrument work (JJ-043-C and later).
-- New in the download: students.hidden_instruments and instrument_hidden_periods (caregivers only,
-- because they are a family setting), student_instruments (each instrument and who teaches it),
-- teacher_codes (a teacher's OWN code, in that teacher's download only), and the instrument on
-- each lesson and practice. Still read-only, service-only, and caller identity comes from Auth.
-- Rollback: re-run 20261104172909_manual_data_backup.sql.
create or replace function public.manual_backup_snapshot(p_user uuid)
returns jsonb language plpgsql stable security invoker
set search_path = public, pg_temp as $$
declare result jsonb;
begin
  if p_user is null or not (
    exists(select 1 from guardianships where profile_id=p_user)
    or exists(select 1 from teachers where profile_id=p_user)
    or exists(select 1 from studios where owner_id=p_user)
  ) then raise exception 'Adult export access required' using errcode='42501'; end if;

  with
  eligible as materialized (
    select s.id from students s where
      exists(select 1 from guardianships g where g.student_id=s.id and g.profile_id=p_user)
      or exists(select 1 from enrollments e left join teachers t on t.id=e.teacher_id
        left join studios st on st.id=e.studio_id where e.student_id=s.id
        and e.status='active' and (t.profile_id=p_user or st.owner_id=p_user))
  ),
  selected_lessons as materialized (select l.* from lessons l join eligible e on e.id=l.student_id),
  selected_assignments as materialized (select a.* from assignments a join selected_lessons l on l.id=a.lesson_id),
  selected_sessions as materialized (select s.* from sessions s join eligible e on e.id=s.student_id),
  selected_enrollments as materialized (select e.* from enrollments e join eligible s on s.id=e.student_id),
  selected_purchases as materialized (select p.* from purchases p join eligible e on e.id=p.student_id),
  selected_scores as materialized (select s.* from scores s where s.owner_id=p_user
    or exists(select 1 from selected_assignments a where a.score_id=s.id)),
  records as (
    select 'account' as kind, jsonb_build_object('id',p.id,'full_name',p.full_name,'phone',p.phone,'avatar_key',p.avatar_key,'created_at',p.created_at) as row
      from profiles p where p.id=p_user
    union all select 'students', jsonb_build_object('id',s.id,'display_name',s.display_name,'instruments',s.instruments,'avatar_key',s.avatar_key,'created_at',s.created_at,
      'hidden_instruments',case when exists(select 1 from guardianships g where g.student_id=s.id and g.profile_id=p_user) then to_jsonb(s.hidden_instruments) end)
      from students s join eligible e on e.id=s.id
    union all select 'guardianships',jsonb_build_object('id',g.id,'student_id',g.student_id,'profile_id',g.profile_id,'is_primary',g.is_primary,'can_message',g.can_message,'can_adjust_practice',g.can_adjust_practice,'display_name',g.display_name,'relationship',g.relationship,'created_at',g.created_at,'grants_updated_at',g.grants_updated_at)
      from guardianships g where g.profile_id=p_user
    union all select 'enrollments',jsonb_build_object('id',e.id,'student_id',e.student_id,'teacher_id',e.teacher_id,'studio_id',e.studio_id,'instrument',e.instrument,'status',e.status,'created_at',e.created_at) from selected_enrollments e
    union all select 'teachers',jsonb_build_object('id',t.id,'profile_id',t.profile_id,'studio_id',t.studio_id,'display_name',t.display_name,'instruments',t.instruments,'created_at',t.created_at) from teachers t
      where t.profile_id=p_user or exists(select 1 from selected_enrollments e where e.teacher_id=t.id)
    union all select 'studios',jsonb_build_object('id',s.id,'name',s.name,'owner_id',s.owner_id,'created_at',s.created_at) from studios s
      where s.owner_id=p_user or exists(select 1 from selected_enrollments e where e.studio_id=s.id)
    union all select 'lessons',jsonb_build_object('id',l.id,'student_id',l.student_id,'enrollment_id',l.enrollment_id,'created_by',l.created_by,'title',l.title,'lesson_note',l.lesson_note,'goal_days',l.goal_days,'goal_minutes',l.goal_minutes,'week_start',l.week_start,'instrument',l.instrument,'created_at',l.created_at) from selected_lessons l
    union all select 'assignments',jsonb_build_object('id',a.id,'lesson_id',a.lesson_id,'title',a.title,'song_note',a.song_note,'suggested_minutes',a.suggested_minutes,'order_idx',a.order_idx,'score_id',a.score_id,'is_performance',a.is_performance,'created_at',a.created_at) from selected_assignments a
    union all select 'goals',jsonb_build_object('id',g.id,'assignment_id',g.assignment_id,'kind',g.kind,'params',g.params,'created_at',g.created_at) from verifiable_goals g join selected_assignments a on a.id=g.assignment_id
    union all select 'practices',jsonb_build_object('id',s.id,'student_id',s.student_id,'started_at',s.started_at,'ended_at',s.ended_at,'total_seconds',s.total_seconds,'goal_met',s.goal_met,'audio_path',s.audio_path,'created_at',s.created_at,'entered_by',s.entered_by,'entry_note',s.entry_note,'source',s.source,'instrument',s.instrument,'manual_override_seconds',to_jsonb(s)->'manual_override_seconds','recorded_seconds',to_jsonb(s)->'recorded_seconds') from selected_sessions s
    union all select 'song_practices',jsonb_build_object('id',x.id,'session_id',x.session_id,'assignment_id',x.assignment_id,'kind',x.kind,'seconds',x.seconds,'wall_seconds',x.wall_seconds,'goal_results',x.goal_results,'completed',x.completed,'flagged',x.flagged,'audio_paths',x.audio_paths,'audio_clips',x.audio_clips) from session_segments x join selected_sessions s on s.id=x.session_id
    union all select 'fan_ledger',jsonb_build_object('id',x.id,'student_id',x.student_id,'amount',x.amount,'reason',x.reason,'session_id',x.session_id,'assignment_id',x.assignment_id,'segment_id',x.segment_id,'created_at',x.created_at) from fan_ledger x join eligible e on e.id=x.student_id
    union all select 'berry_ledger',jsonb_build_object('id',x.id,'student_id',x.student_id,'amount',x.amount,'reason',x.reason,'session_id',x.session_id,'assignment_id',x.assignment_id,'segment_id',x.segment_id,'created_at',x.created_at) from berry_ledger x join eligible e on e.id=x.student_id
    union all select 'purchases',jsonb_build_object('id',p.id,'item_id',p.item_id,'student_id',p.student_id,'price_paid',p.price_paid,'status',p.status,'created_at',p.created_at) from selected_purchases p
    union all select 'rewards',jsonb_build_object('id',m.id,'stand',m.stand,'owner_id',m.owner_id,'studio_id',m.studio_id,'student_id',m.student_id,'title',m.title,'description',m.description,'price',m.price,'asset_key',m.asset_key,'emoji',m.emoji,'kind',m.kind,'active',m.active,'created_at',m.created_at) from market_items m
      where m.owner_id=p_user or exists(select 1 from selected_purchases p where p.item_id=m.id)
    union all select 'scores',jsonb_build_object('id',s.id,'owner_id',s.owner_id,'title',s.title,'source',s.source,'license_scope',s.license_scope,'musicxml_path',case when s.owner_id=p_user then s.musicxml_path end,'original_path',case when s.owner_id=p_user then s.original_path end,'file_export_status',case when s.owner_id=p_user then 'included_if_present' else 'metadata_only_no_storage_permission' end,'created_at',s.created_at,'folder_path',s.folder_path,'folder',s.folder) from selected_scores s
    union all select 'saved_lessons',jsonb_build_object('id',s.id,'owner_id',s.owner_id,'payload',s.payload,'created_at',s.created_at) from saved_lessons s where s.owner_id=p_user
    union all select 'saved_assignments',jsonb_build_object('id',s.id,'owner_id',s.owner_id,'payload',s.payload,'created_at',s.created_at) from saved_assignments s where s.owner_id=p_user
    union all select 'messages',jsonb_build_object('id',m.id,'enrollment_id',m.enrollment_id,'sender_id',m.sender_id,'body',m.body,'created_at',m.created_at) from messages m join selected_enrollments e on e.id=m.enrollment_id
      where m.deleted_at is null and (exists(select 1 from teachers t where t.id=e.teacher_id and t.profile_id=p_user)
        or exists(select 1 from guardianships g where g.student_id=e.student_id and g.profile_id=p_user and (g.is_primary or g.can_message)))
    union all select 'student_instruments',jsonb_build_object('id',x.id,'student_id',x.student_id,'instrument',x.instrument,'instruction',x.instruction,'enrollment_id',x.enrollment_id,'teacher_name',x.teacher_name,'teacher_known_as',x.teacher_known_as,'created_at',x.created_at) from student_instruments x join eligible e on e.id=x.student_id
    union all select 'instrument_hidden_periods',jsonb_build_object('id',x.id,'student_id',x.student_id,'instrument_key',x.instrument_key,'hidden_from',x.hidden_from,'hidden_until',x.hidden_until) from instrument_hidden_periods x join eligible e on e.id=x.student_id
      where exists(select 1 from guardianships g where g.student_id=x.student_id and g.profile_id=p_user)
    union all select 'teacher_codes',jsonb_build_object('teacher_id',c.teacher_id,'code',c.code,'created_at',c.created_at,'rotated_at',c.rotated_at) from teacher_codes c join teachers t on t.id=c.teacher_id where t.profile_id=p_user
    union all select 'private_notes',jsonb_build_object('id',n.id,'student_id',n.student_id,'author_id',n.author_id,'body',n.body,'created_at',n.created_at) from private_notes n join eligible e on e.id=n.student_id where n.author_id=p_user
  ), grouped as (select kind,jsonb_agg(row order by row->>'id') as rows from records group by kind)
  select jsonb_build_object('schema_version',1,'captured_at',statement_timestamp(),'account_id',p_user,
    'student_ids',(select coalesce(jsonb_agg(id order by id),'[]'::jsonb) from eligible),
    'tables',coalesce(jsonb_object_agg(kind,rows),'{}'::jsonb)) into result from grouped;
  return result;
end $$;
revoke all on function public.manual_backup_snapshot(uuid) from public, anon, authenticated;
grant execute on function public.manual_backup_snapshot(uuid) to service_role;
