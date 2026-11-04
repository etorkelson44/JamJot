import { buildArchive, type Media, type Snapshot } from './archive.ts';

const headers={
  'Access-Control-Allow-Origin':'*',
  'Access-Control-Allow-Headers':'authorization, content-type, apikey, x-client-info',
  'Access-Control-Allow-Methods':'POST, OPTIONS',
  'Access-Control-Expose-Headers':'Content-Disposition',
  'Cache-Control':'no-store',
  'X-Content-Type-Options':'nosniff',
};
const fail=(message:string,status:number)=>new Response(JSON.stringify({error:message}),{status,headers:{...headers,'Content-Type':'application/json'}});

// Kept injectable so authentication and denied paths can be tested without live accounts.
export function makeHandler(deps: {
  authenticate:(token:string,password:string)=>Promise<{id:string;cleanup:()=>Promise<void>}>,
  snapshot:(id:string)=>Promise<Snapshot>,
  load:(file:Media,remaining:number)=>Promise<Uint8Array>,
}) {
  return async (req:Request)=>{
    if(req.method==='OPTIONS')return new Response(null,{headers});
    if(req.method!=='POST')return fail('Use Download my data from adult Settings.',405);
    let cleanup:(()=>Promise<void>)|undefined;
    try {
      const token=req.headers.get('Authorization')??'';
      if(!/^Bearer \S+$/.test(token))return fail('Please sign in again.',401);
      // Bound the request before parsing; never log passwords or request bodies.
      const reader=req.body?.getReader();if(!reader)return fail('Account verification is required.',400);
      let raw='';const decoder=new TextDecoder();
      try { while(true){const chunk=await reader.read();if(chunk.done)break;raw+=decoder.decode(chunk.value,{stream:true});if(raw.length>4096){await reader.cancel();return fail('Request too large.',413);}} } finally {reader.releaseLock();}
      const body=JSON.parse(raw);
      if(!body || typeof body!=='object' || Array.isArray(body) || typeof body.password!=='string'||body.password.length<1||body.password.length>1024||Object.keys(body).some(k=>k!=='password'))return fail('Account verification is required.',400);
      const user=await deps.authenticate(token,body.password);
      cleanup=user.cleanup;
      body.password='';raw='';
      const snapshot=await deps.snapshot(user.id);
      const zip=await buildArchive(snapshot,deps.load,()=>deps.snapshot(user.id));
      return new Response(zip as Uint8Array<ArrayBuffer>,{headers:{...headers,'Content-Type':'application/zip','Content-Disposition':`attachment; filename="JamJot-backup-${snapshot.captured_at.slice(0,10)}.zip"`}});
    } catch(e) {
      // Only purpose-written messages leave the server. Provider errors may contain private detail.
      if(e instanceof ExportError)return fail(e.message,e.status);
      if(e instanceof SyntaxError)return fail('Account verification is required.',400);
      const safe=['Your data or permissions changed','This backup is larger','This backup exceeds','A required file is empty','A file reference is invalid'];
      if(e instanceof Error&&safe.some(prefix=>e.message.startsWith(prefix)))return fail(e.message,409);
      return fail('The complete backup could not be prepared. No partial backup was saved. Please try again.',503);
    } finally { if(cleanup)await cleanup().catch(()=>{}); }
  };
}
export class ExportError extends Error {constructor(message:string,public status:number){super(message);}}

