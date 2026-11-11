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
create table profiles(id uuid primary key);
create table students(id uuid primary key, auth_user_id uuid, avatar_key text, instruments text[] default '{}', display_name text);
create table guardianships(student_id uuid,profile_id uuid,is_primary boolean,can_adjust_practice boolean);
create table studios(id uuid primary key,owner_id uuid,name text);
create table teachers(id uuid primary key,profile_id uuid,studio_id uuid,display_name text,created_at timestamptz default now());
create table enrollments(id uuid primary key default gen_random_uuid(),student_id uuid,teacher_id uuid,studio_id uuid,instrument text,status text,billing_owner text);
create table invitations(id uuid primary key default gen_random_uuid(), token text not null unique default md5(gen_random_uuid()::text), kind text not null check (kind in ('caregiver','enrollment','studio_code')), created_by uuid, student_id uuid, teacher_id uuid, studio_id uuid, instrument text, preset_grants jsonb not null default '{}', single_use boolean not null default true, expires_at timestamptz, used_at timestamptz, used_by uuid, created_at timestamptz default now());
create table lessons(instrument text, id uuid primary key default gen_random_uuid(),student_id uuid,enrollment_id uuid,goal_minutes integer,created_by uuid,title text,lesson_note text,goal_days integer,event_id uuid,week_start date,created_at timestamptz default now(),assignment_request uuid);
create table assignments(kind text, written_verified_at timestamptz, id uuid primary key default gen_random_uuid(),lesson_id uuid references lessons(id),title text,song_note text,score_id uuid,order_idx integer,suggested_minutes integer);
create table sessions(id uuid primary key default gen_random_uuid(),student_id uuid references students(id),started_at timestamptz default now(),ended_at timestamptz,total_seconds integer default 0,goal_met boolean default false,source text default 'app',entered_by uuid,entry_note text,audio_path text);
create table session_segments(id uuid primary key default gen_random_uuid(),session_id uuid references sessions(id) on delete cascade,assignment_id uuid references assignments(id),seconds integer default 0,wall_seconds integer default 0,completed boolean default false,goal_results jsonb default '{}',audio_paths text[] default '{}',audio_clips jsonb default '[]');
create table berry_ledger(assignment_id uuid, id uuid primary key default gen_random_uuid(),student_id uuid,session_id uuid references sessions(id) on delete set null,amount integer not null,reason text not null);
create table fan_ledger(like berry_ledger including all);
create table market_items(id uuid primary key,stand text,owner_id uuid,studio_id uuid,student_id uuid,title text,price integer check(price>0),kind text,asset_key text,active boolean default true);
create table purchases(id uuid primary key default gen_random_uuid(),student_id uuid,item_id uuid references market_items(id),price_paid integer,status text);
create function is_self_student(sid uuid) returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from students where id=sid and auth_user_id=auth.uid())$$;
create function is_guardian(sid uuid) returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from guardianships where student_id=sid and profile_id=auth.uid())$$;
create function is_primary_guardian(sid uuid) returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from guardianships where student_id=sid and profile_id=auth.uid() and is_primary)$$;
create function is_student_teacher(sid uuid) returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from enrollments e join teachers t on t.id=e.teacher_id where e.student_id=sid and e.status='active' and t.profile_id=auth.uid())$$;
create function can_see_student(sid uuid) returns boolean language sql stable security definer set search_path=public as $$select is_guardian(sid) or is_self_student(sid) or is_student_teacher(sid)$$;
grant usage on schema public,auth to authenticated;
grant select,insert,update,delete on all tables in schema public to authenticated;
alter default privileges in schema public grant all on tables to authenticated;
`);
for (const m of ['20261103200554_practice_integrity','20261110180000_multi_instrument_students','20261110190000_student_instruments_sync','20261110200000_per_instrument_practice','20261110220000_teacher_codes_and_invites','20261110230000_hide_instruments_rotate_code_expiry','20261110231000_guard_hidden_instruments'])
  await db.exec(await readFile(new URL(`../migrations/${m}.sql`,import.meta.url),'utf8'));
const id = n => `00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const [kid,parent,other,tprof,teacher] = [id(1),id(2),id(3),id(4),id(5)];
const scalar = async (sql,p=[]) => Object.values((await db.query(sql,p)).rows[0])[0];
async function asUser(u,sql,p=[]){ await db.query("select set_config('request.jwt.claim.sub',$1,false)",[u??'']); await db.exec('set role '+(u?'authenticated':'anon')); try{ return (await db.query(sql,p)).rows; } finally{ await db.exec('reset role'); } }
await db.query('insert into profiles values($1),($2),($3)',[parent,other,tprof]);
await db.query("insert into students values($1,null,null,'{Piano,Violin}','Zayne')",[kid]);
await db.query('insert into guardianships values($1,$2,true,true)',[kid,parent]);
await db.query("insert into teachers(id,profile_id,display_name) values($1,$2,'Ada Fictional')",[teacher,tprof]);
const day = '2026-10-28';
const session = (n, instrument, hour, minutes, d=day) => db.query(
  "insert into sessions(id,student_id,started_at,ended_at,total_seconds,instrument) values($1,$2,$3,$4,$5,$6)",
  [id(n), kid, `${d}T${hour}:00:00Z`, new Date(new Date(`${d}T${hour}:00:00Z`).getTime()+minutes*60000).toISOString(), minutes*60, instrument]);
await db.query("insert into lessons(id,student_id,created_by,goal_minutes,week_start,instrument) values($1,$2,$3,15,'2026-10-26','Piano'),($4,$2,$3,15,'2026-10-26','Violin')",[id(10),kid,parent,id(11)]);
const coins = async () => Number(await scalar('select coalesce(sum(amount),0) from berry_ledger where student_id=$1',[kid]));
const settle = async () => { await db.query('select jamjot_private.settle_practice($1)',[kid]); };

// --- hide / unhide permissions and rules ----------------------------------------------
await assert.rejects(asUser(other,'select hide_instrument($1,$2)',[kid,'Violin']));         // not a caregiver
await assert.rejects(asUser(null,'select hide_instrument($1,$2)',[kid,'Violin']));
await assert.rejects(asUser(parent,'select hide_instrument($1,$2)',[kid,'Cello']));          // not on the student
await assert.rejects(asUser(parent,"update students set hidden_instruments='{piano}' where id=$1",[kid]));   // no direct writes
await asUser(parent,'select hide_instrument($1,$2)',[kid,'Violin']);
assert.deepEqual((await db.query('select hidden_instruments h from students where id=$1',[kid])).rows[0].h,['violin']);
await asUser(parent,'select hide_instrument($1,$2)',[kid,'VIOLIN']);                         // repeat-safe
assert.equal(await scalar('select count(*)::int from instrument_hidden_periods'),1);
await assert.rejects(asUser(parent,'select hide_instrument($1,$2)',[kid,'Piano']));         // last visible one stays
// all saved data is still there
assert.equal(await scalar("select count(*)::int from lessons where instrument='Violin'"),1);
assert.equal(await scalar("select count(*)::int from student_instruments where student_id=$1",[kid]),2);

// --- hidden instruments do not count toward Full Band or rewards -----------------------
await session(20,'Piano','12',15);
await settle();
assert.equal(await coins(),10);        // Piano's own bonus only; Violin is hidden so there is no "band" to complete
// the past is untouched: a day before hiding that paid Full Band keeps it when re-settled
await db.query("update instrument_hidden_periods set hidden_from='2026-10-29'");   // pretend it was hidden from the 29th
await db.query("update students set hidden_instruments='{}'");
await db.query("delete from instrument_hidden_periods");
await db.query("insert into instrument_hidden_periods(student_id,instrument_key,hidden_from,hidden_until) values($1,'violin','2026-10-29',null)",[kid]);
await session(21,'Violin','13',15);   // 28th: Violin practised too (before it was hidden)
await settle();
assert.equal(await coins(),30);        // 10 + 10 + Full Band 10 on the 28th, because Violin was showing then
await settle();
assert.equal(await coins(),30);        // repeat-safe
// a day inside the hidden period: Violin ignored, no Full Band
await session(22,'Piano','12',15,'2026-10-30');
await settle();
assert.equal(await coins(),40);        // Piano bonus only
// unhide: everything is back, and later days count Violin again
await db.query("update students set hidden_instruments='{violin}' where id=$1",[kid]);
await asUser(parent,'select unhide_instrument($1,$2)',[kid,'Violin']);
assert.deepEqual((await db.query('select hidden_instruments h from students where id=$1',[kid])).rows[0].h,[]);
assert.notEqual(await scalar("select hidden_until from instrument_hidden_periods where instrument_key='violin'"),null);
await assert.rejects(asUser(other,'select unhide_instrument($1,$2)',[kid,'Violin']));
assert.equal(await scalar("select count(*)::int from lessons where student_id=$1",[kid]),2);
await settle();
assert.equal(await coins(),40);        // re-settling after unhide leaves earlier payouts alone
// deleting a hidden instrument clears the hidden state
await asUser(parent,'select hide_instrument($1,$2)',[kid,'Violin']);
await db.query("delete from student_instruments where student_id=$1 and lower(instrument)='violin'",[kid]);
assert.deepEqual((await db.query('select hidden_instruments h from students where id=$1',[kid])).rows[0].h,[]);

// --- teacher code rotation -------------------------------------------------------------
const oldCode = await scalar('select code from teacher_codes where teacher_id=$1',[teacher]);
await asUser(parent,'select connect_teacher_by_code($1,$2,$3)',[oldCode,kid,'Piano']);
const enrollBefore = await scalar('select id from enrollments where student_id=$1',[kid]);
await assert.rejects(asUser(parent,'select rotate_teacher_code($1)',[teacher]));            // not the teacher
const newCode = (await asUser(tprof,'select rotate_teacher_code($1) c',[teacher]))[0].c;
assert.notEqual(newCode,oldCode);
assert.equal(await scalar('select enrollment_id from student_instruments where student_id=$1 and instrument=$2',[kid,'Piano']),enrollBefore);
assert.equal(await scalar("select status from enrollments where id=$1",[enrollBefore]),'active');   // still connected
let r = (await asUser(parent,'select connect_teacher_by_code($1,$2,$3) r',[oldCode,kid,'Piano']))[0].r;
assert.equal(r.ok,false);                                                                     // old code is dead
r = (await asUser(parent,'select connect_teacher_by_code($1,$2,$3) r',[newCode,kid,'Piano']))[0].r;
assert.equal(r.ok,true);

// --- every single-use invite now expires in 30 days -----------------------------------
await db.query("insert into invitations(kind,created_by,student_id) values('caregiver',$1,$2)",[parent,kid]);
assert.equal(await scalar("select (expires_at - created_at) = interval '30 days' from invitations where kind='caregiver'"),true);
await db.query("insert into invitations(kind,created_by,teacher_id,single_use) values('studio_code',$1,$2,false)",[tprof,teacher]);
assert.equal(await scalar("select expires_at from invitations where kind='studio_code'"),null);
console.log('hide instruments, code rotation, invite expiry: all checks passed');
