import { caller, admin, cors, json } from '../_shared/caller.ts';
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', {headers: cors});
  if (req.method !== 'POST') return json({error: 'Use POST'}, 405);
  try {
    const input = await req.json();
    const client = caller(req);
    const {data: auth} = await client.auth.getUser();
    if (!auth.user) return json({error: 'Sign in again'}, 401);
    if (input.action === 'retry_cleanup') {
      const {data: allowed} = await client.rpc('can_correct_practice', {sid: input.student_id});
      if (!allowed) return json({error: 'Not authorized'},403);
      const server=admin();
      const {data: paths,error} = await server.rpc('recording_cleanup_paths',{p_student_id:input.student_id});
      if (error) return json({ok:true,cleanup_pending:true});
      if (paths?.length) {
        const {error: removeError}=await server.storage.from('recordings').remove(paths);
        if (removeError) return json({ok:true,cleanup_pending:true});
        const {error: ackError}=await server.rpc('ack_recording_cleanup',{p_paths:paths});
        if (ackError) return json({ok:true,cleanup_pending:true});
      }
      return json({ok:true,cleanup_pending:false});
    }
    const {data, error} = await client.rpc('correct_practice', {
      p_session_id: input.session_id, p_action: input.action,
      p_segment_id: input.segment_id ?? null, p_path: input.path ?? null,
      p_minutes: input.minutes ?? null,
    });
    if (error) return json({error: error.message}, 400);
    const server = admin();
    // Also retries previously queued private files for this authorized student.
    const {data: paths, error: queueError} = await server.rpc('recording_cleanup_paths', {p_student_id: data.student_id});
    let cleanupPending = Boolean(queueError);
    if (paths?.length) {
      const {error: removeError} = await server.storage.from('recordings').remove(paths);
      cleanupPending = Boolean(removeError);
      if (!removeError) {
        const {error: ackError} = await server.rpc('ack_recording_cleanup', {p_paths: paths});
        cleanupPending = Boolean(ackError);
      }
    }
    return json({...data, cleanup_pending: cleanupPending});
  } catch (_) {
    return json({error: 'Practice correction could not be completed'}, 500);
  }
});
