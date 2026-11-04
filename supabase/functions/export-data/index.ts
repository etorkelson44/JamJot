import { createClient } from 'npm:@supabase/supabase-js@2.57.4';
import { type Snapshot } from './archive.ts';
import { makeHandler, ExportError } from './handler.ts';
  const url=Deno.env.get('SUPABASE_URL')!;
  const anon=Deno.env.get('SUPABASE_ANON_KEY')!;
  const secret=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const admin=createClient(url,secret,{auth:{persistSession:false,autoRefreshToken:false}});
  Deno.serve(makeHandler({
    authenticate:async(token,password)=>{
      const client=createClient(url,anon,{auth:{persistSession:false,autoRefreshToken:false}});
      const {data:identity,error}=await client.auth.getUser(token.slice(7));
      if(error||!identity.user?.email)throw new ExportError('Please sign in again.',401);
      const {data:verified,error:badPassword}=await client.auth.signInWithPassword({email:identity.user.email,password});
      if(badPassword||verified.user?.id!==identity.user.id){
        if(verified.session)await client.auth.signOut({scope:'local'});
        throw new ExportError('Your account password could not be verified.',403);
      }
      return {id:identity.user.id,cleanup:async()=>{await client.auth.signOut({scope:'local'});}};
    },
    snapshot:async(id)=>{
      const {data,error}=await admin.rpc('manual_backup_snapshot',{p_user:id});
      if(error){if(error.code==='42501')throw new ExportError('Only authorized adult accounts can download data.',403);throw new ExportError('Backup is not available on this server yet.',503);}
      return data as Snapshot;
    },
    load:async(file,remaining)=>{
      // Only exact references from the authorized snapshot are fetched, never request URLs.
      const path=file.path.split('/').map(encodeURIComponent).join('/');
      const res=await fetch(`${url}/storage/v1/object/authenticated/${file.bucket}/${path}`,{headers:{Authorization:`Bearer ${secret}`,apikey:secret},signal:AbortSignal.timeout(45000)});
      if(!res.ok||!res.body)throw new ExportError('A required recording or document could not be downloaded. No partial backup was saved.',409);
      if(Number(res.headers.get('Content-Length'))>remaining){await res.body.cancel();throw new ExportError('This backup is larger than the current 64 MiB limit. No partial backup was saved.',413);}
      const reader=res.body.getReader();const chunks:Uint8Array[]=[];let size=0;
      try{while(true){const {value,done}=await reader.read();if(done)break;size+=value.length;if(size>remaining){await reader.cancel();throw new ExportError('This backup is larger than the current 64 MiB limit. No partial backup was saved.',413);}chunks.push(value);}}finally{reader.releaseLock();}
      const bytes=new Uint8Array(size);let offset=0;for(const c of chunks){bytes.set(c,offset);offset+=c.length;}return bytes;
    },
  }));
