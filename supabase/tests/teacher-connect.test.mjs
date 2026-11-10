process.on('uncaughtException', e => { console.error('FAIL', e.message); process.exit(1); });
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const {PGlite} = await import(process.env.PGLITE_MODULE ?? '@electric-sql/pglite');
const db = new PGlite();
// Synthetic fixture (fictional data only).
await db.exec(`
create role authenticated; create role anon;
create schema auth;
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
create table profiles(id uuid primary key);
create table students(id uuid primary key, auth_user_id uuid, instruments text[] default '{}', display_name text);
create table guardianships(student_id uuid,profile_id uuid,is_primary boolean);
create table studios(id uuid primary key, name text);
create table teachers(id uuid primary key,profile_id uuid,studio_id uuid,display_name text,created_at timestamptz default now());
create table enrollments(id uuid primary key default gen_random_uuid(),student_id uuid,teacher_id uuid,studio_id uuid,instrument text,status text,billing_owner text);
create unique index uniq_active_enrollment on enrollments(student_id,teacher_id,instrument) where status in ('pending','active');
create table invitations(id uuid primary key default gen_random_uuid(), token text not null unique default md5(gen_random_uuid()::text), kind text not null check (kind in ('caregiver','enrollment','studio_code')), created_by uuid, student_id uuid, teacher_id uuid, studio_id uuid, instrument text, preset_grants jsonb not null default '{}', single_use boolean not null default true, expires_at timestamptz, used_at timestamptz, used_by uuid, created_at timestamptz default now());
create table lessons(id uuid primary key default gen_random_uuid(),student_id uuid,enrollment_id uuid,created_by uuid,title text,lesson_note text,goal_days int,goal_minutes int,week_start date,event_id uuid,assignment_request uuid);
create table assignments(id uuid primary key default gen_random_uuid(),lesson_id uuid,title text,song_note text,score_id uuid,order_idx int,suggested_minutes int);
create function is_self_student(sid uuid) returns boolean language sql stable security definer as $$select exists(select 1 from students where id=sid and auth_user_id=auth.uid())$$;
create function is_guardian(sid uuid) returns boolean language sql stable security definer as $$select exists(select 1 from guardianships where student_id=sid and profile_id=auth.uid())$$;
create function is_student_teacher(sid uuid) returns boolean language sql stable security definer as $$select exists(select 1 from enrollments e join teachers t on t.id=e.teacher_id where e.student_id=sid and e.status='active' and t.profile_id=auth.uid())$$;
create function can_see_student(sid uuid) returns boolean language sql stable security definer as $$select is_guardian(sid) or is_self_student(sid) or is_student_teacher(sid)$$;
create function is_primary_guardian(sid uuid) returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from guardianships where student_id=sid and profile_id=auth.uid() and is_primary)$$;
grant usage on schema public,auth to authenticated;
grant all on all tables in schema public to authenticated;
alter default privileges in schema public grant all on tables to authenticated;
`);
for (const m of ['20261110180000_multi_instrument_students','20261110190000_student_instruments_sync','20261110220000_teacher_codes_and_invites'])
  await db.exec(await readFile(new URL(`../migrations/${m}.sql`,import.meta.url),'utf8'));
const id = n => `00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const [kid,parent,otherParent,tprof,teacher,stranger] = [id(1),id(2),id(3),id(4),id(5),id(6)];
await db.query('insert into profiles values($1),($2),($3),($4)',[parent,otherParent,tprof,stranger]);
await db.query("insert into students values($1,null,'{Piano,Violin}','Zayne')",[kid]);
await db.query('insert into guardianships values($1,$2,true),($1,$3,false)',[kid,parent,otherParent]);
await db.query("insert into teachers(id,profile_id,display_name) values($1,$2,'Ada Fictional')",[teacher,tprof]);
async function asUser(u,sql,p=[]){ await db.query("select set_config('request.jwt.claim.sub',$1,false)",[u??'']); await db.exec('set role '+(u?'authenticated':'anon')); try{ return (await db.query(sql,p)).rows; } finally{ await db.exec('reset role'); } }
const code = (await db.query('select code from teacher_codes where teacher_id=$1',[teacher])).rows[0].code;

// --- connect by code -------------------------------------------------------------
await assert.rejects(asUser(otherParent,'select connect_teacher_by_code($1,$2,$3)',[code,kid,'Violin']));  // not primary
await assert.rejects(asUser(stranger,'select connect_teacher_by_code($1,$2,$3)',[code,kid,'Violin']));
let r = (await asUser(parent,'select connect_teacher_by_code($1,$2,$3) r',['nope',kid,'Violin']))[0].r;
assert.equal(r.ok,false);
r = (await asUser(parent,'select connect_teacher_by_code($1,$2,$3) r',[code,kid,'Cello']))[0].r;
assert.equal(r.ok,false);                                   // instrument not on the student
r = (await asUser(parent,'select connect_teacher_by_code($1,$2,$3) r',[` ${code.toLowerCase().slice(0,4)}-${code.slice(4).toLowerCase()} `,kid,'violin']))[0].r;
assert.equal(r.ok,true); assert.equal(r.teacher_name,'Ada Fictional');
let si = (await db.query("select instruction, enrollment_id from student_instruments where student_id=$1 and instrument='Violin'",[kid])).rows[0];
assert.equal(si.instruction,'teacher'); assert.ok(si.enrollment_id);
assert.equal((await db.query('select count(*)::int n from enrollments')).rows[0].n,1);
await asUser(parent,'select connect_teacher_by_code($1,$2,$3)',[code,kid,'Violin']);      // repeat-safe
assert.equal((await db.query('select count(*)::int n from enrollments')).rows[0].n,1);
// guessing is limited: 10 wrong codes pause the account
for (let i=0;i<10;i++) await asUser(otherParent,'select 1');   // (no-op, keeps style)
await db.query("update guardianships set is_primary=true where profile_id=$1",[otherParent]);
for (let i=0;i<10;i++) await asUser(otherParent,'select connect_teacher_by_code($1,$2,$3)',['WRONG'+i,kid,'Piano']);
r = (await asUser(otherParent,'select connect_teacher_by_code($1,$2,$3) r',[code,kid,'Piano']))[0].r;
assert.equal(r.ok,false); assert.match(r.error,/Too many/);
await db.query("update guardianships set is_primary=false where profile_id=$1",[otherParent]);

// --- invite a teacher not on JamJot ---------------------------------------------
await assert.rejects(asUser(otherParent,'select create_teacher_invite($1,$2,$3,$4,$5)',[kid,'Piano','Sam Example','Mr. Sam','k']));
const token = (await asUser(parent,'select create_teacher_invite($1,$2,$3,$4,$5) t',[kid,'Piano','Sam Example','Mr. Sam','k']))[0].t;
si = (await db.query("select instruction, teacher_name, teacher_known_as, invitation_id from student_instruments where student_id=$1 and instrument='Piano'",[kid])).rows[0];
assert.equal(si.instruction,'teacher'); assert.equal(si.teacher_name,'Sam Example'); assert.ok(si.invitation_id);
const preview = (await asUser(null,'select teacher_invite_preview($1) p',[token]))[0].p;   // signed out
assert.deepEqual(preview,{status:'ok',instrument:'Piano',student:'Zayne K.'});
assert.equal((await asUser(null,'select teacher_invite_preview($1) p',['bogus']))[0].p,null);
await assert.rejects(asUser(null,'select accept_teacher_invite($1)',[token]));              // must sign in
let a = (await asUser(stranger,'select accept_teacher_invite($1) r',[token]))[0].r;         // no teacher profile
assert.equal(a.ok,false); assert.equal(a.error,'needs_teacher_profile');
await db.query("insert into teachers(id,profile_id,display_name) values($1,$2,'Sam Example')",[id(7),stranger]);
a = (await asUser(stranger,'select accept_teacher_invite($1) r',[token]))[0].r;
assert.equal(a.ok,true); assert.equal(a.student,'Zayne K.');
si = (await db.query("select instruction, enrollment_id, teacher_name, invitation_id from student_instruments where student_id=$1 and instrument='Piano'",[kid])).rows[0];
assert.equal(si.instruction,'teacher'); assert.ok(si.enrollment_id); assert.equal(si.invitation_id,null);
a = (await asUser(stranger,'select accept_teacher_invite($1) r',[token]))[0].r;
assert.equal(a.ok,false);                                                                    // single use
assert.deepEqual((await asUser(null,'select teacher_invite_preview($1) p',[token]))[0].p,{status:'used'});
// expiry
const t2 = (await asUser(parent,'select create_teacher_invite($1,$2,$3,$4,$5) t',[kid,'Piano','','', ''] ))[0].t;
await db.query("update invitations set expires_at=now()-interval '1 day' where token=$1",[t2]);
assert.deepEqual((await asUser(null,'select teacher_invite_preview($1) p',[t2]))[0].p,{status:'expired'});
console.log('teacher codes and invites: all checks passed');
