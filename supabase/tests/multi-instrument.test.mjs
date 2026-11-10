process.on('uncaughtException', e => { console.error('FAIL', e.message); process.exit(1); });
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const {PGlite} = await import(process.env.PGLITE_MODULE ?? '@electric-sql/pglite');
const db = new PGlite();
// Synthetic fixture (fictional data only), not a production copy.
await db.exec(`
create role authenticated; create role anon;
create schema auth;
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
create table profiles(id uuid primary key);
create table students(id uuid primary key, auth_user_id uuid, instruments text[] default '{}');
create table guardianships(student_id uuid,profile_id uuid,is_primary boolean);
create table teachers(id uuid primary key,profile_id uuid);
create table enrollments(id uuid primary key,student_id uuid,teacher_id uuid,instrument text,status text);
create table invitations(id uuid primary key);
create table lessons(id uuid primary key default gen_random_uuid(),student_id uuid,enrollment_id uuid,created_by uuid,title text,lesson_note text,goal_days int,goal_minutes int,week_start date,event_id uuid,assignment_request uuid);
create table assignments(id uuid primary key default gen_random_uuid(),lesson_id uuid,title text,song_note text,score_id uuid,order_idx int,suggested_minutes int);
create function is_self_student(sid uuid) returns boolean language sql stable security definer as $$select exists(select 1 from students where id=sid and auth_user_id=auth.uid())$$;
create function is_guardian(sid uuid) returns boolean language sql stable security definer as $$select exists(select 1 from guardianships where student_id=sid and profile_id=auth.uid())$$;
create function is_student_teacher(sid uuid) returns boolean language sql stable security definer as $$select exists(select 1 from enrollments e join teachers t on t.id=e.teacher_id where e.student_id=sid and e.status='active' and t.profile_id=auth.uid())$$;
create function can_see_student(sid uuid) returns boolean language sql stable security definer as $$select is_guardian(sid) or is_self_student(sid) or is_student_teacher(sid)$$;
grant usage on schema public,auth to authenticated;
grant all on all tables in schema public to authenticated;
alter default privileges in schema public grant all on tables to authenticated;
`);
const id = n => `00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const [kid,parent,teacher,stranger,tprof] = [id(1),id(2),id(3),id(4),id(5)];
await db.query('insert into profiles values($1),($2),($3)',[parent,stranger,tprof]);
await db.query("insert into students values($1,null,'{Violin,Piano}'),($2,null,'{}')",[kid,id(9)]);
await db.query('insert into guardianships values($1,$2,true)',[kid,parent]);
await db.query('insert into teachers values($1,$2)',[teacher,tprof]);
await db.query("insert into enrollments values($1,$2,$3,'Violin','active')",[id(10),kid,teacher]);
// three pre-existing lessons: with enrollment, without (student has instruments), without (student has none)
await db.query("insert into lessons(id,student_id,enrollment_id,created_by,title) values($1,$2,$3,$4,'a'),($5,$2,null,$4,'b'),($6,$7,null,$4,'c')",[id(20),kid,id(10),parent,id(21),id(22),id(9)]);
await db.exec(await readFile(new URL('../migrations/20261110180000_multi_instrument_students.sql',import.meta.url),'utf8'));
const inst = async l => (await db.query('select instrument from lessons where id=$1',[l])).rows[0].instrument;
assert.equal(await inst(id(20)),'Violin');   // from enrollment
assert.equal(await inst(id(21)),'Violin');   // student's first instrument
assert.equal(await inst(id(22)),'Music');    // default
assert.equal((await db.query('select count(*)::int n from lesson_instrument_backfill_log')).rows[0].n,3);
const si = (await db.query('select instrument,instruction from student_instruments order by instrument')).rows;
assert.deepEqual(si,[{instrument:'Piano',instruction:'caregiver'},{instrument:'Violin',instruction:'teacher'}]);
async function asUser(u,sql,p=[]){ await db.query("select set_config('request.jwt.claim.sub',$1,false)",[u]); await db.exec('set role authenticated'); try{ return await db.query(sql,p);} finally{ await db.exec('reset role'); } }
// RLS: caregiver sees + adds; stranger sees nothing and cannot add; teacher sees.
assert.equal((await asUser(parent,'select * from student_instruments where student_id=$1',[kid])).rows.length,2);
await asUser(parent,"insert into student_instruments(student_id,instrument,teacher_name,teacher_known_as) values($1,'Cello','Ms. Fictional','Ms. F')",[kid]);
assert.equal((await asUser(stranger,'select * from student_instruments')).rows.length,0);
await assert.rejects(asUser(stranger,"insert into student_instruments(student_id,instrument) values($1,'Flute')",[kid]));
assert.equal((await asUser(tprof,'select * from student_instruments where student_id=$1',[kid])).rows.length,3);
// duplicate instrument (case-insensitive) rejected
await assert.rejects(asUser(parent,"insert into student_instruments(student_id,instrument) values($1,'cello')",[kid]));
// RPC stores the instrument; works without it too
const lesson = (extra={}) => JSON.stringify({student_id:kid,title:'t',goal_days:4,goal_minutes:15,...extra});
const songs = JSON.stringify([{title:'Song'}]);
const r1 = await asUser(parent,'select assign_library_lesson($1::jsonb,$2::jsonb,$3) id',[lesson({instrument:'Cello'}),songs,id(30)]);
assert.equal(await inst(r1.rows[0].id),'Cello');
const r2 = await asUser(parent,'select assign_library_lesson($1::jsonb,$2::jsonb,$3) id',[lesson(),songs,id(31)]);
assert.equal(await inst(r2.rows[0].id),null);
// teacher codes: existing teacher got one; new teacher gets one; owner + assigned caregiver see it; stranger does not
assert.equal((await db.query('select count(*)::int n from teacher_codes')).rows[0].n,1);
await db.query('insert into teachers values($1,$2)',[id(40),id(41)]);
assert.equal((await db.query('select count(*)::int n from teacher_codes')).rows[0].n,2);
assert.match((await db.query('select code from teacher_codes limit 1')).rows[0].code,/^[A-HJKMNP-Z2-9]{8}$/);
assert.equal((await asUser(tprof,'select * from teacher_codes')).rows.length,1);
assert.equal((await asUser(parent,'select * from teacher_codes')).rows.length,1);
assert.equal((await asUser(stranger,'select * from teacher_codes')).rows.length,0);
assert.equal((await asUser(parent,"update teacher_codes set code='AAAAAAAA' returning 1")).rows.length,0);
// two-way sync (migration 1b)
await db.exec(await readFile(new URL('../migrations/20261110190000_student_instruments_sync.sql',import.meta.url),'utf8'));
const arr = async sid => (await db.query('select instruments from students where id=$1',[sid])).rows[0].instruments;
await db.query("update students set instruments='{Violin,Flute}' where id=$1",[kid]);
const names = async sid => (await db.query('select instrument from student_instruments where student_id=$1 order by 1',[sid])).rows.map(r=>r.instrument);
assert.deepEqual(await names(kid),['Cello','Flute','Violin'].filter(n=>n!=='Cello'));   // Piano and Cello dropped, Flute added
await db.query("insert into student_instruments(student_id,instrument) values($1,'Harp')",[kid]);
assert.deepEqual((await arr(kid)).sort(),['Flute','Harp','Violin']);
await db.query("delete from student_instruments where student_id=$1 and instrument='Harp'",[kid]);
assert.deepEqual((await arr(kid)).sort(),['Flute','Violin']);
await db.query("insert into students values($1,null,'{Drums}')",[id(50)]);
assert.deepEqual(await names(id(50)),['Drums']);
console.log('multi-instrument migration: all checks passed');
