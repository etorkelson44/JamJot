import { caller, cors, json } from '../_shared/caller.ts';
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', {headers: cors});
  try {
    const body = await req.json();
    const client = caller(req);
    const {data,error} = body.action === 'wear'
      ? await client.rpc('wear_owned_avatar', {p_student_id:body.student_id,p_asset_key:body.asset_key})
      : await client.rpc('purchase_market_item', {p_student_id:body.student_id,p_item_id:body.item_id,p_request_id:body.request_id ?? crypto.randomUUID()});
    return error ? json({error:error.message},400) : json(data);
  } catch (_) { return json({error:'Could not complete this market request'},500); }
});
