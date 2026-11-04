import { caller, cors, json } from '../_shared/caller.ts';
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', {headers: cors});
  try {
    const body = await req.json();
    const {data, error} = await caller(req).rpc('settle_practice_session', {p_session_id: body.session_id});
    return error ? json({error: error.message}, 400) : json(data);
  } catch (_) { return json({error: 'Could not settle practice'}, 500); }
});
