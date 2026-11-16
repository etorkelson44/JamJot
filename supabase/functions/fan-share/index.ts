import { createClient } from 'npm:@supabase/supabase-js@2';

// NoteStar fans (2026-11-15): a kid (or their grown-up) sends a weekly album to fans the grown-ups listed.
// Creates one private share link per fan (RLS: only the kid's own account or a guardian), and emails it through
// Resend when RESEND_API_KEY is set. Without email it returns the links so the app can open Gmail / mail app.
// Only fans already saved for this student can receive mail, max 30 emails per student per day.
const CORS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey, x-client-info',
};
const json = (obj: unknown, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });
const esc = (t: string) => t.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  try {
    const { student_id, fan_ids, album_key, album_title, clips, origin } = await req.json();
    const url = Deno.env.get('SUPABASE_URL')!;
    const caller = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
    });
    const { data: u } = await caller.auth.getUser();
    if (!u?.user?.id) return json({ error: 'Not signed in' }, 401);
    if (typeof student_id !== 'string' || !Array.isArray(fan_ids) || fan_ids.length === 0 || fan_ids.length > 20) {
      return json({ error: 'Pick at least one fan.' }, 400);
    }
    if (typeof album_key !== 'string' || !Array.isArray(clips) || clips.length === 0 || clips.length > 30) {
      return json({ error: 'This album has nothing to send yet.' }, 400);
    }
    // Keep only the fields the fan page needs; paths must belong to this student.
    const cleanClips = clips.map((c: Record<string, unknown>) => ({
      title: String(c.title ?? 'Song').slice(0, 120),
      first_path: typeof c.first_path === 'string' && c.first_path.startsWith(`${student_id}/`) ? c.first_path : null,
      last_path: typeof c.last_path === 'string' && c.last_path.startsWith(`${student_id}/`) ? c.last_path : null,
    })).filter((c) => c.first_path || c.last_path);
    if (cleanClips.length === 0) return json({ error: 'This album has nothing to send yet.' }, 400);

    const { data: fans, error: fe } = await caller.from('fans').select('id,name,email').eq('student_id', student_id).in('id', fan_ids);
    if (fe || !fans || fans.length === 0) return json({ error: 'Those fans were not found.' }, 404);
    const { data: kid } = await caller.from('students').select('display_name').eq('id', student_id).maybeSingle();
    const kidName = (kid?.display_name ?? 'Your musician').trim();
    const title = String(album_title ?? `${kidName}'s Album`).slice(0, 120);

    const base = typeof origin === 'string' && /^https:\/\/([a-z0-9-]+\.)*(jamjot\.app|jamjot-gh\.pages\.dev)$/.test(origin)
      ? origin : 'https://jamjot.app';
    const rows = fans.map((f) => ({ student_id, fan_id: f.id, album_key, album_title: title, clips: cleanClips }));
    const { data: shares, error: se } = await caller.from('fan_shares').insert(rows).select('id,token,fan_id');
    if (se || !shares) return json({ error: 'Could not share right now.' }, 403);

    const links = shares.map((s) => {
      const f = fans.find((x) => x.id === s.fan_id)!;
      return { fan_id: f.id, name: f.name, email: f.email, link: `${base}/#/fan?t=${s.token}` };
    });

    const key = Deno.env.get('RESEND_API_KEY');
    if (!key) return json({ sent: false, reason: 'email_not_configured', links, kid_name: kidName, title });

    const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const since = new Date(Date.now() - 24 * 3600 * 1000).toISOString();
    const { count } = await admin.from('fan_shares').select('id', { count: 'exact', head: true })
      .eq('student_id', student_id).gte('emailed_at', since);
    if ((count ?? 0) + links.length > 30) return json({ sent: false, reason: 'daily_limit', links, kid_name: kidName, title });

    const from = (Deno.env.get('INVITE_FROM_ADDRESS') ?? 'NoteStar <invites@jamjot.app>')
      .replace(/^[^<]*/, `${kidName.replace(/[<>"]/g, '')} via NoteStar `);
    const sent: string[] = [];
    for (const l of links) {
      const text = `Hi ${l.name}!\n\n${kidName} practiced hard this week and made an album for you: "${title}".\n` +
        `Listen to how a song sounded at the start of the week and how it sounds now, then send ${kidName} some fan mail:\n\n${l.link}\n\n— NoteStar`;
      const html = `<div style="font-family:sans-serif;font-size:16px;line-height:1.5">` +
        `<p>Hi ${esc(l.name)}!</p><p>${esc(kidName)} practiced hard this week and made an album for you: <b>${esc(title)}</b>.</p>` +
        `<p>Listen to the first and last take of each song, then send ${esc(kidName)} some fan mail.</p>` +
        `<p><a href="${l.link}" style="background:#3B85F5;color:#111;padding:12px 20px;border-radius:999px;text-decoration:none;font-weight:bold">Listen to the album</a></p>` +
        `<p style="color:#4A4A4A;font-size:13px">NoteStar is a music practice app. You got this because ${esc(kidName)}'s family added you as a fan.</p></div>`;
      const r = await fetch('https://api.resend.com/emails', {
        method: 'POST', headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ from, to: [l.email], subject: `${kidName} sent you an album 🎵`, text, html }),
      });
      if (r.ok) sent.push(l.fan_id);
    }
    if (sent.length) {
      await admin.from('fan_shares').update({ emailed_at: new Date().toISOString() })
        .in('id', shares.filter((s) => sent.includes(s.fan_id)).map((s) => s.id));
    }
    return json({ sent: sent.length === links.length, sent_count: sent.length, links, kid_name: kidName, title });
  } catch (e) {
    return json({ error: String((e as Error)?.message ?? e) }, 500);
  }
});
