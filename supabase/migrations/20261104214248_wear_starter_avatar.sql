-- The free starter (Sonatina Sprout) is wearable by every student without a
-- purchase; bought avatars still require ownership.
create or replace function public.wear_owned_avatar(p_student_id uuid,p_asset_key text) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or not (public.is_self_student(p_student_id) or public.is_guardian(p_student_id)) then
    raise exception 'This account cannot change this avatar' using errcode='42501'; end if;
  if p_asset_key <> 'sonatina' and not exists(
      select 1 from public.purchases p join public.market_items m on m.id=p.item_id
      where p.student_id=p_student_id and m.kind='avatar' and m.asset_key=p_asset_key) then
    raise exception 'Choose an avatar from this student''s shelf'; end if;
  update public.students set avatar_key=p_asset_key where id=p_student_id;
  return jsonb_build_object('ok',true);
end;
$$;
