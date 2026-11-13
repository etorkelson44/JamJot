-- JJ-061-C follow-up (Erika, 2026-11-13 07:23 CT): what each avatar is wearing moves from the device to the
-- database, so an outfit shows on every device and to the student's teacher and grown-ups.
-- Additive only: one new column, one small lookup table, one function. No existing data is changed.

-- avatar key -> list of accessory ids worn on that avatar, e.g. {"kiwi": ["sugar_shrub_shako"]}
alter table public.students add column if not exists outfits jsonb not null default '{}'::jsonb;

-- Accessories every student owns without buying. Paid accessories are NOT here: wearing those will require a
-- purchase check when the Market starts selling them.
create table if not exists public.free_accessories (
  id         text primary key,
  created_at timestamptz not null default now()
);
alter table public.free_accessories enable row level security;
drop policy if exists free_accessories_select on public.free_accessories;
create policy free_accessories_select on public.free_accessories for select to authenticated using (true);
insert into public.free_accessories (id) values ('sugar_shrub_shako') on conflict do nothing;

-- Save one avatar's outfit. Only the student or one of their grown-ups may change it, and only free accessories
-- can be worn for now.
create or replace function public.set_student_outfit(p_student_id uuid, p_avatar_key text, p_item_ids text[])
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_ids text[];
begin
  if auth.uid() is null or not (public.is_self_student(p_student_id) or public.is_guardian(p_student_id)) then
    raise exception 'This account cannot change this outfit' using errcode = '42501';
  end if;
  if p_avatar_key is null or p_avatar_key !~ '^[a-z0-9_]{1,40}$' then
    raise exception 'Unknown avatar';
  end if;
  select coalesce(array_agg(distinct i), '{}') into v_ids from unnest(coalesce(p_item_ids, '{}')) as i;
  if coalesce(array_length(v_ids, 1), 0) > 12 then
    raise exception 'Too many pieces in one outfit';
  end if;
  if exists (select 1 from unnest(v_ids) as i where not exists (select 1 from public.free_accessories f where f.id = i)) then
    raise exception 'That piece is not in this student''s wardrobe';
  end if;
  update public.students
     set outfits = case when coalesce(array_length(v_ids, 1), 0) = 0
                        then outfits - p_avatar_key
                        else jsonb_set(outfits, array[p_avatar_key], to_jsonb(v_ids)) end
   where id = p_student_id;
  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.set_student_outfit(uuid, text, text[]) from public, anon;
grant execute on function public.set_student_outfit(uuid, text, text[]) to authenticated;

-- ROLLBACK: drop function public.set_student_outfit(uuid, text, text[]); drop table public.free_accessories;
--           alter table public.students drop column outfits;
