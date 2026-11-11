import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const {PGlite}=await import(process.env.PGLITE_MODULE??'@electric-sql/pglite');
const db=new PGlite();
await db.exec(await readFile(new URL('backup-schema-fixture.sql',import.meta.url),'utf8'));
await db.exec(await readFile(new URL('../migrations/20261104172909_manual_data_backup.sql',import.meta.url),'utf8'));
await db.exec(await readFile(new URL('../migrations/20261111150000_manual_backup_instruments.sql',import.meta.url),'utf8'));
await db.exec(await readFile(new URL('../migrations/20261111152500_manual_backup_settings.sql',import.meta.url),'utf8'));
const id=n=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const parent=id(1),limited=id(2),teacher=id(3),studio=id(4),kid=id(5),stranger=id(6),familyB=id(7),teacherB=id(8),a=id(11),b=id(12);
await db.query("insert into profiles(id,full_name,app_pin_hash,phone) values($1,'Fictional Adult','never-export-pin','555-0100')",[parent]);
await db.query("insert into students(id,display_name,instruments,pin_hash,auth_user_id,created_by,offline_contact) values($1,'Melody',array['piano'],'never-export-child-pin',$2,$3,'{\"private\":\"never-export-contact\"}'),($4,'Other family',array['violin'],'private',null,$5,null)",[a,kid,parent,b,familyB]);
await db.query('insert into guardianships(id,student_id,profile_id,is_primary,can_message) values($1,$2,$3,true,true),($4,$2,$5,false,false),($6,$7,$8,true,true)',[id(20),a,parent,id(21),limited,id(22),b,familyB]);
await db.query("insert into studios(id,owner_id,name) values($1,$2,'Fictional Studio')",[id(30),studio]);
await db.query("insert into teachers(id,profile_id,studio_id,display_name) values($1,$2,$3,'Fictional Teacher'),($4,$5,null,'Other teacher')",[id(31),teacher,id(30),id(32),teacherB]);
await db.query("insert into enrollments(id,student_id,teacher_id,studio_id,status,instrument) values($1,$2,$3,$4,'active','piano'),($5,$6,$7,null,'active','violin'),($8,$2,$7,null,'active','violin')",[id(40),a,id(31),id(30),id(41),b,id(32),id(42)]);
await db.query("insert into lessons(id,student_id,title,goal_minutes) values($1,$2,'Scale lesson',15),($3,$4,'Other family lesson',15)",[id(50),a,id(51),b]);
await db.query("insert into assignments(id,lesson_id,title,score_id) values($1,$2,'Morning song',$3)",[id(60),id(50),id(61)]);
await db.query("insert into scores(id,owner_id,title,original_path,license_scope) values($1,$2,'Shared lesson document',$3,'owner')",[id(61),teacher,`${teacher}/score.pdf`]);
await db.query("insert into sessions(id,student_id,source,total_seconds,recorded_seconds,manual_override_seconds,audio_path) values($1,$2,'app',300,600,300,$3),($4,$2,'manual',900,null,null,null),($5,$6,'app',60,null,null,null)",[id(70),a,`${a}/${id(70)}/take.wav`,id(71),id(72),b]);
await db.query("insert into session_segments(id,session_id,assignment_id,seconds,audio_paths,audio_clips,goal_results) values($1,$2,$3,600,array[$4],'[]','{\"completed\":true}')",[id(80),id(70),id(60),`${a}/${id(70)}/take.wav`]);
await db.query("insert into berry_ledger(id,student_id,amount,session_id) values($1,$2,3,$3)",[id(90),a,id(70)]);
await db.query("insert into messages(id,enrollment_id,sender_id,body,deleted_at) values($1,$2,$3,'Piano feedback',null),($4,$5,$6,'Violin feedback',null),($7,$2,$3,'Deleted private content',now()),($8,$9,$6,'Other family message',null)",[id(100),id(40),teacher,id(101),id(42),teacherB,id(102),id(103),id(41)]);
await db.query("insert into private_notes(id,student_id,author_id,body) values($1,$2,$3,'My note'),($4,$2,$5,'Teacher private note')",[id(110),a,parent,id(111),teacher]);
async function snapshot(user){await db.exec('set role service_role');try{return (await db.query('select manual_backup_snapshot($1) as data',[user])).rows[0].data;}finally{await db.exec('reset role');}}
async function fingerprint(){const r=await db.query("select (select jsonb_agg(s) from sessions s) as practices,(select jsonb_agg(s) from session_segments s) as segments,(select jsonb_agg(b) from berry_ledger b) as rewards,(select jsonb_agg(s) from students s) as students");return createHash('sha256').update(JSON.stringify(r.rows)).digest('hex');}
const before=await fingerprint();
for(const role of ['anon','authenticated']){await db.exec('set role '+role);await assert.rejects(db.query('select manual_backup_snapshot($1)',[parent]),/permission denied/);await db.exec('reset role');}
for(const user of [kid,stranger,null])await assert.rejects(snapshot(user),/Adult export access required/);
for(const user of [parent,limited,teacher,studio]){
 const s=await snapshot(user);assert.deepEqual(s.student_ids,[a]);assert.equal(s.tables.students.length,1);assert.equal(s.tables.practices.length,2);assert.equal(s.tables.practices.find(r=>r.id===id(70)).manual_override_seconds,300);assert.equal(s.tables.practices.find(r=>r.id===id(70)).recorded_seconds,600);
 const serialized=JSON.stringify(s);for(const privateText of ['never-export','Other family','Deleted private content'])assert.equal(serialized.includes(privateText),false);
}
assert.equal((await snapshot(parent)).tables.scores[0].original_path,null);
assert.equal((await snapshot(parent)).tables.scores[0].file_export_status,'metadata_only_no_storage_permission');
assert.equal((await snapshot(teacher)).tables.scores[0].original_path,`${teacher}/score.pdf`);
assert.equal((await snapshot(parent)).tables.messages.length,2);
assert.equal((await snapshot(teacher)).tables.messages.length,1);
assert.equal((await snapshot(limited)).tables.messages,undefined);
assert.equal((await snapshot(studio)).tables.messages,undefined);
assert.equal((await snapshot(parent)).tables.private_notes[0].body,'My note');
assert.equal((await snapshot(teacher)).tables.private_notes[0].body,'Teacher private note');
assert.deepEqual((await snapshot(familyB)).student_ids,[b]);
assert.equal(await fingerprint(),before,'exports must not mutate practices, students or rewards');
// ---- multi-instrument data (second backup version) ----
await db.query("update students set hidden_instruments=array['violin'] where id=$1",[a]);
await db.query("update lessons set instrument='Piano' where id=$1",[id(50)]);
await db.query("update sessions set instrument='Piano' where id=$1",[id(70)]);
await db.query("insert into student_instruments(id,student_id,instrument,instruction,teacher_name,teacher_known_as) values($1,$2,'Piano','teacher','Fictional Teacher','Ms. F'),($3,$4,'Violin','caregiver',null,null)",[id(120),a,id(121),b]);
await db.query("insert into instrument_hidden_periods(id,student_id,instrument_key,hidden_from,hidden_until) values($1,$2,'violin','2026-10-01',null),($3,$4,'piano','2026-09-01','2026-09-15')",[id(130),a,id(131),b]);
await db.query("insert into teacher_codes(teacher_id,code) values($1,'FICT-CODE-1'),($2,'OTHER-CODE-2')",[id(31),id(32)]);
{
 const p=await snapshot(parent);
 assert.equal(p.tables.students[0].streak_rule,'any','caregiver backup includes the streak rule'); assert.ok('sound_prefs' in p.tables.students[0],'caregiver backup includes sound settings');
 assert.deepEqual(p.tables.students[0].hidden_instruments,['violin'],'caregiver backup includes the hidden instruments');
 assert.equal(p.tables.student_instruments.length,1);assert.equal(p.tables.student_instruments[0].instrument,'Piano');assert.equal(p.tables.student_instruments[0].teacher_known_as,'Ms. F');
 assert.equal(p.tables.instrument_hidden_periods.length,1);assert.equal(p.tables.instrument_hidden_periods[0].instrument_key,'violin');
 assert.equal(p.tables.lessons[0].instrument,'Piano');assert.equal(p.tables.practices.find(r=>r.id===id(70)).instrument,'Piano');
 assert.equal(p.tables.teacher_codes,undefined,'a caregiver backup never includes a teacher code');
 const limitedSnap=await snapshot(limited);assert.equal(limitedSnap.tables.student_instruments.length,1);
 const t=await snapshot(teacher);
 assert.equal(t.tables.students[0].hidden_instruments,null,'a teacher backup does not include the family hide setting');
 assert.equal(t.tables.instrument_hidden_periods,undefined,'a teacher backup does not include hide history');
 assert.equal(t.tables.student_instruments.length,1);
 assert.deepEqual(t.tables.teacher_codes.map(c=>c.code),['FICT-CODE-1'],'a teacher gets only their own code');
 const s=await snapshot(studio);assert.equal(s.tables.teacher_codes,undefined);assert.equal(s.tables.instrument_hidden_periods,undefined);
 const fb=await snapshot(familyB);assert.equal(fb.tables.student_instruments.length,1);assert.equal(fb.tables.student_instruments[0].instrument,'Violin');
 assert.equal(fb.tables.instrument_hidden_periods.length,1);assert.equal(fb.tables.instrument_hidden_periods[0].instrument_key,'piano');
 assert.equal(JSON.stringify(p).includes('OTHER-CODE'),false);assert.equal(JSON.stringify(p).includes('FICT-CODE'),false);
}
const first=await snapshot(parent);const again=await snapshot(parent);assert.deepEqual(first.tables,again.tables);
await db.query("update sessions set total_seconds=240,manual_override_seconds=240 where id=$1",[id(70)]);
const edited=await snapshot(parent);assert.equal(edited.tables.practices.find(r=>r.id===id(70)).total_seconds,240);assert.equal(first.tables.practices.find(r=>r.id===id(70)).total_seconds,300);
await db.query('delete from sessions where id=$1',[id(71)]);assert.equal((await snapshot(parent)).tables.practices.length,1);
await db.query("update enrollments set status='inactive' where id=$1",[id(40)]);assert.deepEqual((await snapshot(teacher)).student_ids,[]);assert.deepEqual((await snapshot(studio)).student_ids,[]);

console.log('PASS service-only RPC; child/unrelated denial; family isolation; caregiver, teacher and studio scope; messaging grants; private notes; no secrets; corrections/manual entries; repeated/edited/deleted snapshots; revoked enrollment; unchanged source records and rewards; instruments, hide history and teacher codes included only for the right people');
await db.close();
