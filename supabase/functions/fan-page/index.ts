import { createClient } from 'npm:@supabase/supabase-js@2';

// NoteStar fan page (2026-11-15). Public (verify_jwt = false): the secret token in the link is the key.
// GET  ?t=TOKEN          -> kid's first name, album title, songs with short-lived signed audio links.
// POST {t, name, message} -> saves fan mail. Pending until a grown-up approves, unless the family turned
//                            review off (students.fan_mail_review = false). Max 10 notes per link.
const CORS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey, x-client-info',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};
const json = (obj: unknown, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  try {
    const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const body = req.method === 'POST' ? await req.json() : {};
    const token = String(new URL(req.url).searchParams.get('t') ?? body.t ?? '');
    if (!/^[a-f0-9]{40,80}$/.test(token)) return json({ error: 'This link does not look right.' }, 400);
    const { data: share } = await admin.from('fan_shares')
      .select('id, student_id, fan_id, album_title, clips, created_at, fans(name), students(display_name, fan_mail_review)')
      .eq('token', token).maybeSingle();
    if (!share) return json({ error: 'This album link was not found. It may have been removed.' }, 404);
    const kid = (share.students as { display_name?: string; fan_mail_review?: boolean } | null);
    const kidName = (kid?.display_name ?? 'Your musician').split(' ')[0];

    if (req.method === 'POST') {
      const name = String(body.name ?? (share.fans as { name?: string } | null)?.name ?? '').trim().slice(0, 80);
      const message = String(body.message ?? '').trim();
      if (!name || !message || message.length > 1000) return json({ error: 'Please write a short note (up to 1000 letters).' }, 400);
      const { count } = await admin.from('fan_mail').select('id', { count: 'exact', head: true }).eq('share_id', share.id);
      if ((count ?? 0) >= 10) return json({ error: 'Thanks! This link has reached its fan mail limit.' }, 429);
      const status = kid?.fan_mail_review === false ? 'approved' : 'pending';
      const { error } = await admin.from('fan_mail').insert({
        share_id: share.id, student_id: share.student_id, fan_id: share.fan_id, fan_name: name, message, status,
      });
      if (error) return json({ error: 'Could not send right now. Please try again.' }, 500);
      return json({ ok: true, needs_review: status === 'pending', kid_name: kidName });
    }

    const songs = [];
    for (const c of (share.clips as Array<{ title: string; first_path: string | null; last_path: string | null }>) ?? []) {
      const sign = async (p: string | null) => {
        if (!p) return null;
        const { data } = await admin.storage.from('recordings').createSignedUrl(p, 6 * 3600);
        return data?.signedUrl ?? null;
      };
      songs.push({ title: c.title, first_url: await sign(c.first_path), last_url: await sign(c.last_path) });
    }
    return json({
      kid_name: kidName,
      fan_name: (share.fans as { name?: string } | null)?.name ?? '',
      album_title: share.album_title ?? `${kidName}'s Album`,
      songs,
    });
  } catch (e) {
    return json({ error: String((e as Error)?.message ?? e) }, 500);
  }
});
