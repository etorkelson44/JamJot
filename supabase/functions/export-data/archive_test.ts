import {unzipSync,strFromU8} from 'npm:fflate@0.8.2';
import {buildArchive,mediaFor,csv,sha,type Snapshot} from './archive.ts';
import {makeHandler,ExportError} from './handler.ts';
function assert(ok:unknown,message='Assertion failed'):void{if(!ok)throw new Error(message);}
async function rejects(fn:()=>Promise<unknown>){let failed=false;try{await fn();}catch{failed=true;}assert(failed,'Expected rejection');}
const sid='00000000-0000-4000-8000-000000000011';
const snapshot:Snapshot={schema_version:1,captured_at:'2026-11-04T17:00:00Z',account_id:'adult',student_ids:[sid],tables:{account:[{id:'adult',full_name:'Fictional Adult'}],students:[{id:sid,display_name:'Fictional Melody',instruments:['piano']}],lessons:[{id:'lesson',student_id:sid,title:'A week of music',goal_minutes:15,goal_days:4}],assignments:[{id:'assignment',lesson_id:'lesson',title:'Morning song',score_id:'score',suggested_minutes:3}],goals:[{id:'goal',assignment_id:'assignment',kind:'steady_tempo',params:{bpm:80}}],berry_ledger:[{id:'berries',student_id:sid,session_id:'practice',amount:5,reason:'song completion'}],fan_ledger:[{id:'fans',student_id:sid,session_id:'practice',amount:5}],rewards:[{id:'reward',title:'Choose our next song',price:5}],purchases:[{id:'purchase',student_id:sid,item_id:'reward',price_paid:5,status:'owned'}],scores:[{id:'score',owner_id:'adult',title:'Morning song',musicxml_path:'adult/morning.musicxml',file_export_status:'included_if_present'},{id:'shared-score',title:'Shared score metadata',file_export_status:'metadata_only_no_storage_permission'}],practices:[{id:'practice',student_id:sid,audio_path:`${sid}/practice/take.wav`,total_seconds:120,manual_override_seconds:120,recorded_seconds:180}],song_practices:[{id:'song',session_id:'practice',audio_paths:[`${sid}/practice/take.wav`],audio_clips:[]}],messages:[{id:'message',body:'=HYPERLINK("bad")'}]}};
// Real 16-bit PCM WAV: a half-second, 440 Hz fictional tone, no person recorded.
function wav(){const samples=11025,buffer=new ArrayBuffer(44+samples*2),view=new DataView(buffer),b=new Uint8Array(buffer);const put=(offset:number,s:string)=>{for(let i=0;i<s.length;i++)b[offset+i]=s.charCodeAt(i);};put(0,'RIFF');view.setUint32(4,36+samples*2,true);put(8,'WAVE');put(12,'fmt ');view.setUint32(16,16,true);view.setUint16(20,1,true);view.setUint16(22,1,true);view.setUint32(24,22050,true);view.setUint32(28,44100,true);view.setUint16(32,2,true);view.setUint16(34,16,true);put(36,'data');view.setUint32(40,samples*2,true);for(let i=0;i<samples;i++)view.setInt16(44+i*2,Math.round(3000*Math.sin(i*2*Math.PI*440/22050)),true);return b;}
const audio=wav();
const score=new TextEncoder().encode('<?xml version="1.0" encoding="utf-8"?><score-partwise version="4.0"><work><work-title>Fictional morning song</work-title></work><part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list><part id="P1"><measure number="1"><attributes><divisions>1</divisions></attributes><note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><type>whole</type></note></measure></part></score-partwise>');
const load=async(file:{bucket:string})=>file.bucket==='scores'?score:audio;
Deno.test('complete ZIP, exact playable WAV, stable IDs and fingerprints, independent repeats',async()=>{
 const before=JSON.stringify(snapshot);let loads=0;
 const bytes=await buildArchive(snapshot,async(file)=>{loads++;return load(file);},async()=>snapshot);
 const zip=unzipSync(bytes);const manifest=JSON.parse(strFromU8(zip['manifest.json']));assert(manifest.complete&&manifest.format_version===1);assert(loads===2,'deduplicate repeated audio references, include the authorized document');assert(manifest.metadata_only_documents.length===1);
 assert(await sha(zip[`files/recordings/${sid}/practice/take.wav`])===await sha(audio));assert(manifest.files[0].sha256===await sha(audio));assert(manifest.tables.practices.records[0].id==='practice');
 assert(zip['README.txt']&&zip['data/practices.csv']);assert(strFromU8(zip['data/messages.csv']).includes("'=HYPERLINK"));assert(JSON.parse(strFromU8(zip['data/messages.json']))[0].body.startsWith('='));
 const repeat=unzipSync(await buildArchive(snapshot,load,async()=>snapshot));const m2=JSON.parse(strFromU8(repeat['manifest.json']));assert(m2.snapshot_sha256===manifest.snapshot_sha256);assert(m2.export_id!==manifest.export_id);assert(JSON.stringify(snapshot)===before);
 if(Deno.env.get('JAMJOT_BACKUP_FIXTURE'))await Deno.writeFile(Deno.env.get('JAMJOT_BACKUP_FIXTURE')!,bytes);
});
Deno.test('missing files, changed authorization/data, unsafe and foreign paths fail closed',async()=>{
 await rejects(()=>buildArchive(snapshot,async()=>{throw new Error('missing');},async()=>snapshot));
 await rejects(()=>buildArchive(snapshot,async()=>audio,async()=>({...snapshot,student_ids:[]})));
 await rejects(()=>buildArchive(snapshot,async()=>new Uint8Array(),async()=>snapshot));
 for(const path of ['other-family/take.wav',`${sid}/../other/take.wav`,`${sid}/%2e%2e/take.wav`,'https://private.example/secret']){
  let denied=false;try{mediaFor({...snapshot,tables:{practices:[{id:'p',student_id:sid,audio_path:path}]}});}catch{denied=true;}assert(denied);
 }
 assert(csv([{body:' @SUM(1)',note:'a,"b"\nnew line'}]).includes("' @SUM"));
});
Deno.test('handler authentication, password, forged identity, errors and success',async()=>{
 let calls=0,cleanups=0;
 const handler=makeHandler({authenticate:async(_token,password)=>{if(password!=='fictional-password')throw new ExportError('Verification failed',403);return {id:'adult',cleanup:async()=>{cleanups++;}};},snapshot:async(id)=>{assert(id==='adult');calls++;return snapshot;},load});
 const request=(body:unknown,auth=true)=>new Request('http://localhost/export-data',{method:'POST',headers:{...(auth?{Authorization:'Bearer fictional'}:{}),'Content-Type':'application/json'},body:JSON.stringify(body)});
 assert((await handler(request({password:'fictional-password'},false))).status===401);
 assert((await handler(request({password:'wrong'}))).status===403);
 assert((await handler(request({password:'fictional-password',account_id:'other'}))).status===400);
 assert(calls===0);
 const result=await handler(request({password:'fictional-password'}));assert(result.status===200);assert(result.headers.get('Content-Type')==='application/zip');assert(cleanups===1);assert(calls===2);
 const denied=makeHandler({authenticate:async()=>({id:'kid',cleanup:async()=>{cleanups++;}}),snapshot:async()=>{throw new ExportError('Adult access required',403);},load:async()=>{throw new Error('Must not read storage');}});
 assert((await denied(request({password:'fictional'}))).status===403);assert(cleanups===2);
});
