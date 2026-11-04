import { caller, admin, cors, json } from '../_shared/caller.ts';
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', {headers: cors});
  if (req.method !== 'POST') return json({error: 'Use POST'}, 405);
  try {
    const input = await req.json();
    const client = caller(req);
    const {data: auth} = await client.auth.getUser();
    if (!auth.user) return json({error: 'Sign in again'}, 401);
    const {data, error} = await client.rpc('discard_recording', {
      p_session_id: input.session_id, p_path: input.path,
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
