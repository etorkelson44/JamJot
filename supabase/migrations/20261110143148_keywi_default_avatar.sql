-- JJ-040-C (approved 2026-11-10): Keywi is every student's default avatar
-- and a student can never have no avatar. Keywi is a free band member,
-- wearable without a purchase, like Ms. Straw-ccato and Señor Jalapresto.
alter table public.students alter column avatar_key set default 'kiwi';
alter table public.students alter column avatar_key set not null;

create or replace function public.wear_owned_avatar(p_student_id uuid, p_asset_key text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to ''
as $function$
begin
  if auth.uid() is null or not (public.is_self_student(p_student_id) or public.is_guardian(p_student_id)) then
    raise exception 'This account cannot change this avatar' using errcode='42501'; end if;
  if p_asset_key not in ('kiwi','jalapeno','strawberry') and not exists(
      select 1 from public.purchases p join public.market_items m on m.id=p.item_id
      where p.student_id=p_student_id and m.kind='avatar' and m.asset_key=p_asset_key) then
    raise exception 'Choose one of your band members'; end if;
  update public.students set avatar_key=p_asset_key where id=p_student_id;
  return jsonb_build_object('ok',true);
end;
$function$;
