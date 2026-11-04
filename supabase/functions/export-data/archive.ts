import { zipSync } from 'npm:fflate@0.8.2';

export type Row = Record<string, unknown>;
export type Snapshot = { schema_version: number; captured_at: string; account_id: string; student_ids: string[]; tables: Record<string, Row[]> };
export type Media = { bucket: 'recordings' | 'scores'; path: string; archive_path: string; record_ids: string[] };
export const tableNames = ['account','students','guardianships','enrollments','teachers','studios','lessons','assignments','goals','practices','song_practices','fan_ledger','berry_ledger','purchases','rewards','scores','saved_lessons','saved_assignments','messages','private_notes'];
const encoder = new TextEncoder();
export const MAX_BYTES = 64 * 1024 * 1024;
export function canonical(value: unknown): string {
  if (Array.isArray(value)) return '[' + value.map(canonical).join(',') + ']';
  if (value !== null && typeof value === 'object') return '{' + Object.keys(value).sort().map(k => JSON.stringify(k)+':'+canonical((value as Row)[k])).join(',') + '}';
  return JSON.stringify(value) ?? 'null';
}
export async function sha(bytes: Uint8Array): Promise<string> {
  return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', bytes as Uint8Array<ArrayBuffer>))).map(b=>b.toString(16).padStart(2,'0')).join('');
}
export async function snapshotVersion(s: Snapshot): Promise<string> {
  return await sha(encoder.encode(canonical({account_id:s.account_id,student_ids:s.student_ids,tables:s.tables})));
}
function safePath(path: string, prefix: string): boolean {
  return path.startsWith(prefix + '/') && path.length < 1024 && !/[\\\u0000-\u001f\u007f%?#:]/.test(path)
    && path.split('/').every(p=>p!=='' && p!=='.' && p!=='..');
}
export function mediaFor(s: Snapshot): Media[] {
  const files = new Map<string,Media>();
  const sessions = new Map((s.tables.practices ?? []).map(r=>[r.id,r]));
  function add(bucket: Media['bucket'], path: unknown, owner: unknown, record: unknown) {
    if (path == null || path === '') return;
    if (typeof path!=='string' || typeof owner!=='string' || !safePath(path,owner)) throw new Error('A file reference is invalid. No backup was created.');
    const key=bucket+'/'+path;
    const file=files.get(key) ?? {bucket,path,archive_path:'files/'+key,record_ids:[]};
    if (!file.record_ids.includes(String(record))) file.record_ids.push(String(record));
    files.set(key,file);
  }
  for (const r of s.tables.practices ?? []) {
    if (!s.student_ids.includes(String(r.student_id))) throw new Error('Invalid student scope.');
    add('recordings',r.audio_path,r.student_id,r.id);
  }
  for (const r of s.tables.song_practices ?? []) {
    const parent=sessions.get(r.session_id);
    if (!parent) throw new Error('A song practice has no authorized practice.');
    for (const path of (r.audio_paths ?? []) as unknown[]) add('recordings',path,parent.student_id,r.id);
    for (const clip of (r.audio_clips ?? []) as Row[]) add('recordings',clip.path,parent.student_id,r.id);
  }
  for (const r of s.tables.scores ?? []) {
    add('scores',r.original_path,r.owner_id,r.id);
    add('scores',r.musicxml_path,r.owner_id,r.id);
  }
  return [...files.values()].sort((a,b)=>a.archive_path.localeCompare(b.archive_path));
}
export function csv(rows: Row[]): string {
  const columns=[...new Set(rows.flatMap(r=>Object.keys(r)))].sort();
  const cell=(v:unknown)=>{
    let str=v==null?'':typeof v==='object'?canonical(v):String(v);
    // Spreadsheet formula protection. JSON always retains the original value.
    if (/^[\s]*[=+@-]/.test(str)) str="'"+str;
    return '"'+str.replaceAll('"','""')+'"';
  };
  return '\uFEFF'+[columns.map(cell).join(','),...rows.map(r=>columns.map(k=>cell(r[k])).join(','))].join('\r\n')+'\r\n';
}
export const readme = `JamJot — Your data backup

Unzip this folder. You do not need JamJot or an account to read it.
data/*.csv opens in a spreadsheet; data/*.json preserves exact types and text.
files/recordings contains the actual recordings. Open them in an audio player.
files/scores contains your own original documents and MusicXML scores. Shared
documents owned by someone else are metadata-only: the existing Storage policy
does not authorize you to download those files. See metadata_only_documents in
the manifest. Export does not widen those permissions, even for studio owners.
manifest.json maps files to stable record IDs, sizes and SHA-256 checksums.
Record IDs join students -> lessons -> assignments, and practices -> song_practices.
Goals, goal_results, completed flags and fan/berry ledgers represent progress and
achievements in this version. Purchases and rewards describe owned rewards.
Credited minutes are total_seconds / 60. Original recorded seconds and manual
overrides are preserved separately when available. Null means not recorded.

Every download is a complete independent snapshot of your authorized scope.
Downloading never inserts practices, changes balances, or awards rewards.
Keep the newest ZIP; optionally retain older ZIPs for history. Do not combine CSVs
by appending them: the same stable IDs occur in each snapshot. Edited records
retain IDs but receive a new content fingerprint. Missing records may have been
deleted OR may no longer be authorized; absence is not a deletion instruction.
Old ZIPs remain unchanged after later edits/deletions or permission changes.
There is no restore/import tool in this release. A future tool must validate
authorization, match stable IDs, resolve revisions and avoid replaying rewards.

Authorization is checked at download time. Only your own account details and
caregiver grants are included; other adults' private contact details, PIN/password
hashes, access tokens, invitations and calendar-feed tokens are excluded.
Messages require the existing messaging grant (studio ownership alone is not
a messaging grant); deleted messages are excluded. Private notes are author-only.
Calendars, billing and internal correction audit/security logs are outside v1.
Source timestamps are preserved; where the app has no updated_at, the manifest
uses a content fingerprint and export timestamp rather than inventing edit dates.
CSV formula-like text has a protective apostrophe; JSON retains exact content.
Some older audio may already be malformed; backup preserves original bytes and
cannot repair it. Missing files or export limits fail the entire download.
This first version supports up to 64 MiB uncompressed and 2,000 media files.
Database rows are captured together; they are checked again after file transfer.
Database changes during export require retry. Storage is not versioned: a file
replaced during download is the version actually downloaded, identified by hash.
Keep this ZIP private: it contains the personal data and recordings you selected.
`;
export async function buildArchive(s:Snapshot, load:(file:Media, remaining:number)=>Promise<Uint8Array>, verify:()=>Promise<Snapshot>):Promise<Uint8Array> {
  if(s.schema_version!==1) throw new Error('Unsupported backup format.');
  const files: Record<string,Uint8Array>={};
  let total=0;
  const add=(path:string,bytes:Uint8Array)=>{total+=bytes.length;if(total>MAX_BYTES)throw new Error('This backup is larger than the current 64 MiB limit. No partial backup was saved.');files[path]=bytes;};
  const tables: Record<string,unknown>={};
  for(const name of tableNames){
    const rows=s.tables[name]??[];
    add('data/'+name+'.json',encoder.encode(JSON.stringify(rows,null,2)+'\n'));
    add('data/'+name+'.csv',encoder.encode(csv(rows)));
    tables[name]={count:rows.length,records:await Promise.all(rows.map(async r=>({id:r.id,created_at:r.created_at??null,updated_at:r.updated_at??null,sha256:await sha(encoder.encode(canonical(r)))})))};
  }
  const media=mediaFor(s);
  if(media.length>2000)throw new Error('This backup exceeds the current file limit. No partial backup was saved.');
  const manifestFiles=[];
  for(const f of media){const bytes=await load(f,MAX_BYTES-total);if(bytes.length===0)throw new Error('A required file is empty. No backup was created.');add(f.archive_path,bytes);manifestFiles.push({...f,bytes:bytes.length,sha256:await sha(bytes)});}
  const version=await snapshotVersion(s);
  if(await snapshotVersion(await verify())!==version)throw new Error('Your data or permissions changed during the download. Please try again.');
  add('README.txt',encoder.encode(readme));
  add('manifest.json',encoder.encode(JSON.stringify({format:'jamjot-manual-backup',format_version:1,export_id:crypto.randomUUID(),account_id:s.account_id,captured_at:s.captured_at,completed_at:new Date().toISOString(),scope:{student_ids:s.student_ids},complete:true,snapshot_sha256:version,tables,files:manifestFiles,metadata_only_documents:(s.tables.scores??[]).filter(r=>r.file_export_status==='metadata_only_no_storage_permission').map(r=>({id:r.id,title:r.title,reason:'Existing Storage policy permits only the file owner to download.'})),restore_supported:false},null,2)+'\n'));
  return zipSync(files,{level:0});
}
