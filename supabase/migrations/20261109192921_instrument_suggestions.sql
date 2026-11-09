-- Founder-approved 2026-11-09 (JJ-036-C); applied to the live project.
-- Private store of typed-in instruments for the team to review.
-- No student names or ids. Kids and families cannot read it.

create table public.instrument_suggestions (
  name          text primary key,            -- cleaned, lowercase ("kazoo")
  family_count  integer not null default 1,  -- distinct families who asked
  created_at    timestamptz not null default now(),
  last_seen_at  timestamptz not null default now()
);

-- Needed only to count each family once. Holds a one-way hash of the
-- signed-in account (not the id itself, and never the student).
create table public.instrument_suggestion_askers (
  name        text not null references public.instrument_suggestions(name) on delete cascade,
  asker_hash  text not null,
  primary key (name, asker_hash)
);

-- RLS on, with no policies: no one signed in can select, insert, update
-- or delete directly. The team reads the tables in the Supabase dashboard.
alter table public.instrument_suggestions enable row level security;
alter table public.instrument_suggestion_askers enable row level security;
revoke all on public.instrument_suggestions, public.instrument_suggestion_askers
  from anon, authenticated;

-- Add-only entry point. The app calls this only after "Yes, add it".
create or replace function public.suggest_instrument(p_name text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text := lower(btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g')));
  v_hash text;
begin
  if auth.uid() is null then return; end if;
  if v_name !~ '^[a-z][a-z '' -]{1,39}$' then return; end if;  -- letters only, 2-40 chars
  v_hash := encode(extensions.digest(auth.uid()::text || ':jamjot-instrument', 'sha256'), 'hex');

  insert into instrument_suggestions (name) values (v_name)
    on conflict (name) do update set last_seen_at = now();

  insert into instrument_suggestion_askers (name, asker_hash) values (v_name, v_hash)
    on conflict do nothing;
  if found then
    update instrument_suggestions
       set family_count = (select count(*) from instrument_suggestion_askers a where a.name = v_name)
     where name = v_name;
  end if;
end $$;

revoke execute on function public.suggest_instrument(text) from public, anon;
grant execute on function public.suggest_instrument(text) to authenticated;
