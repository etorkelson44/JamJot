import { caller, cors, json } from '../_shared/caller.ts';
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', {headers: cors});
  try {
    const body=await req.json();
    const {data,error}=await caller(req).rpc('log_practice_entry',{
      p_student_id:body.student_id,p_date:body.date,p_minutes:body.minutes,
      p_note:body.note ?? '',p_request_id:body.request_id ?? crypto.randomUUID(),
    });
    return error ? json({error:error.message},400) : json(data);
  } catch (_) { return json({error:'Could not log this practice'},500); }
});
