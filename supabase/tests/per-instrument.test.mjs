process.on('uncaughtException', e => { console.error('FAIL', e.message); process.exit(1); });
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const {PGlite} = await import(process.env.PGLITE_MODULE ?? '@electric-sql/pglite');
const db = new PGlite();
// Synthetic fixture (fictional data only).
await db.exec(`
create role anon; create role authenticated; create role service_role bypassrls;
create schema auth;
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
create table students(id uuid primary key, auth_user_id uuid, avatar_key text, instruments text[] default '{}');
create table guardianships(student_id uuid,profile_id uuid,is_primary boolean,can_adjust_practice boolean);
create table studios(id uuid primary key,owner_id uuid);
create table teachers(id uuid primary key,profile_id uuid,studio_id uuid);
create table enrollments(id uuid primary key,student_id uuid,teacher_id uuid,studio_id uuid,status text);
create table lessons(instrument text, id uuid primary key default gen_random_uuid(),student_id uuid,enrollment_id uuid,goal_minutes integer,created_by uuid,title text,lesson_note text,goal_days integer,event_id uuid,week_start date,created_at timestamptz default now());
create table assignments(kind text, written_verified_at timestamptz, id uuid primary key default gen_random_uuid(),lesson_id uuid references lessons(id),title text,song_note text,score_id uuid,order_idx integer,suggested_minutes integer);
create table sessions(id uuid primary key default gen_random_uuid(),student_id uuid references students(id),started_at timestamptz default now(),ended_at timestamptz,total_seconds integer default 0,goal_met boolean default false,source text default 'app',entered_by uuid,entry_note text,audio_path text);
create table session_segments(id uuid primary key default gen_random_uuid(),session_id uuid references sessions(id) on delete cascade,assignment_id uuid references assignments(id),seconds integer default 0,wall_seconds integer default 0,completed boolean default false,goal_results jsonb default '{}',audio_paths text[] default '{}',audio_clips jsonb default '[]');
create table berry_ledger(assignment_id uuid, id uuid primary key default gen_random_uuid(),student_id uuid,session_id uuid references sessions(id) on delete set null,amount integer not null,reason text not null);
create table fan_ledger(like berry_ledger including all);
create table market_items(id uuid primary key,stand text,owner_id uuid,studio_id uuid,student_id uuid,title text,price integer check(price>0),kind text,asset_key text,active boolean default true);
create table purchases(id uuid primary key default gen_random_uuid(),student_id uuid,item_id uuid references market_items(id),price_paid integer,status text);
create function is_self_student(sid uuid) returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from students where id=sid and auth_user_id=auth.uid())$$;
create function is_guardian(sid uuid) returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from guardianships where student_id=sid and profile_id=auth.uid())$$;
grant usage on schema public,auth to authenticated;
grant select,insert,update,delete on all tables in schema public to authenticated;
`);
await db.exec(await readFile(new URL('../migrations/20261103200554_practice_integrity.sql',import.meta.url),'utf8'));
await db.exec(await readFile(new URL('../migrations/20261110200000_per_instrument_practice.sql',import.meta.url),'utf8'));
const id = n => `00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const one = id(1), two = id(2), parent = id(3), kidOne = id(4);
const scalar = async (sql,p=[]) => Object.values((await db.query(sql,p)).rows[0])[0];
await db.query("insert into students values($1,$2,null,'{Piano}'),($3,null,null,'{Piano,Violin}')",[one,kidOne,two]);
await db.query('insert into guardianships values($1,$2,true,true),($3,$2,true,true)',[one,parent,two]);
const session = (n, student, instrument, start, minutes) => db.query(
  "insert into sessions(id,student_id,started_at,ended_at,total_seconds,instrument) values($1,$2,$3,$4,$5,$6)",
  [id(n), student, start, new Date(new Date(start).getTime()+minutes*60000).toISOString(), minutes*60, instrument]);
const lesson = (n, student, instrument, goal) => db.query(
  "insert into lessons(id,student_id,created_by,goal_minutes,week_start,instrument) values($1,$2,$3,$4,'2026-10-26',$5)", [id(n), student, parent, goal, instrument]);
const coins = async sid => Number(await scalar('select coalesce(sum(amount),0) from berry_ledger where student_id=$1',[sid]));
const settle = async sid => { await db.query('select jamjot_private.settle_practice($1)',[sid]); };

// A. One instrument: the same single daily bonus as before (goal 15, did 15 => 10 coins).
await lesson(10, one, 'Piano', 15);
await session(11, one, null, '2026-10-28T12:00:00Z', 15);   // older app: no instrument
await settle(one);
assert.equal(await coins(one), 10);
await settle(one);
assert.equal(await coins(one), 10);   // repeat-safe

// B. Two instruments, only Piano meets its goal: Piano bonus only, no Full Band.
await lesson(20, two, 'Piano', 15); await lesson(21, two, 'Violin', 20);
await session(22, two, 'Piano', '2026-10-28T12:00:00Z', 15);
await session(23, two, 'Violin', '2026-10-28T13:00:00Z', 10);
await settle(two);
assert.equal(await coins(two), 10);
assert.equal(await scalar('select goal_met from sessions where id=$1',[id(22)]), true);
assert.equal(await scalar('select goal_met from sessions where id=$1',[id(23)]), false);

// C. Violin reaches its goal later that day: its own bonus (10) plus Full Band (10).
await db.query('update sessions set total_seconds=1200, ended_at=started_at + interval \'20 minutes\' where id=$1',[id(23)]);
await settle(two);
assert.equal(await coins(two), 30);
await settle(two);
assert.equal(await coins(two), 30);   // repeat-safe, Full Band paid once

// D. Minutes on one instrument do not count toward the other's goal.
await session(24, two, 'Piano', '2026-10-29T12:00:00Z', 60);
await settle(two);
assert.equal(await coins(two), 50);   // +20 (Piano 10 + 10 extra, capped); Violin missed, no Full Band

// E. An instrument with no lesson does not block Full Band; single-lesson day gives none.
await db.query("update students set instruments='{Piano,Violin,Flute}' where id=$1",[two]);
await settle(two);
assert.equal(await coins(two), 50);
console.log('per-instrument practice settlement: all checks passed');
