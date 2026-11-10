-- Tour 2.0 interim reset (founder-approved 2026-11-05, JJ-017-C prep).
-- Only the founder's own kids use the app; founder authorized zeroing
-- coins/rewards and replacing avatars.
-- NOTE (repo export): this migration DELETES data (purchases, berry_ledger,
-- JamJot-stand market items). It already ran on the live project. Do not
-- re-run it against a database that holds real data.

-- 1) Zero out coins and purchased rewards (balances are views over ledgers).
delete from public.purchases;
delete from public.berry_ledger;

-- 2) Remove all JamJot-stand digital items (avatars). Teacher/family
--    grown-up reward stands are untouched.
delete from public.market_items where stand = 'jamjot';

-- 3) Everyone performs as Jalapresto; Strawberry Staccato switchable.
update public.students set avatar_key = 'jalapeno';

-- 4) The two freebies are every kid's band members — wearable without a
--    purchase. Everything else needs a purchase row (none exist now).
create or replace function public.wear_owned_avatar(p_student_id uuid, p_asset_key text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to ''
as $function$
begin
  if auth.uid() is null or not (public.is_self_student(p_student_id) or public.is_guardian(p_student_id)) then
    raise exception 'This account cannot change this avatar' using errcode='42501'; end if;
  if p_asset_key not in ('jalapeno','strawberry') and not exists(
      select 1 from public.purchases p join public.market_items m on m.id=p.item_id
      where p.student_id=p_student_id and m.kind='avatar' and m.asset_key=p_asset_key) then
    raise exception 'Choose one of your band members'; end if;
  update public.students set avatar_key=p_asset_key where id=p_student_id;
  return jsonb_build_object('ok',true);
end;
$function$;
