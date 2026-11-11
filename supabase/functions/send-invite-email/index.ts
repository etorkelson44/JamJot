import { createClient } from 'npm:@supabase/supabase-js@2';

// Sends an invitation email from JamJot (through Resend) so the inviter does not need a mail program.
// The inviter can edit the wording; the message must still contain the invite's own link. We only ever
// email invitations the caller created, one recipient each, with daily limits, so this cannot be used as
// a general mail relay. Without RESEND_API_KEY it answers {sent:false, reason:'email_not_configured'} and
// the app falls back to Gmail / mail app / copy.
const CORS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey, x-client-info',
};
const json = (obj: unknown, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });
const esc = (t: string) => t.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const linkify = (t: string) => esc(t).replace(/(https:\/\/jamjot\.app\/[^\s<]+)/g, '<a href="$1">$1</a>').replace(/\n/g, '<br>');

async function resend(key: string, payload: Record<string, unknown>) {
  const r = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  if (!r.ok) throw new Error(`mail service said ${r.status}`);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  try {
    const { token, to_email, subject, body, copy_me } = await req.json();
    const url = Deno.env.get('SUPABASE_URL')!;
    const caller = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
    });
    const { data: u } = await caller.auth.getUser();
    const uid = u?.user?.id;
    if (!uid) return json({ error: 'Not signed in' }, 401);

    const email = String(to_email ?? '').trim();
    if (!/^[^\s@<>,;]+@[^\s@<>,;]+\.[^\s@<>,;]+$/.test(email) || email.length > 200) {
      return json({ error: 'That email address does not look right.' }, 400);
    }
    const subj = String(subject ?? '').replace(/[\r\n]+/g, ' ').trim().slice(0, 150);
    const text = String(body ?? '').trim();
    if (!subj || !text || text.length > 4000) return json({ error: 'Please check the message.' }, 400);
    if (typeof token !== 'string' || !token || !text.includes(`token=${token}`)) {
      return json({ error: 'Please keep the invite link in the message.' }, 400);
    }

    const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const { data: inv } = await admin.from('invitations').select('*').eq('token', token).maybeSingle();
    if (!inv || inv.created_by !== uid) return json({ error: 'Invite not found' }, 404);
    if (inv.used_at) return json({ error: 'This invite was already used' }, 410);
    if (inv.expires_at && new Date(inv.expires_at) < new Date()) return json({ error: 'This invite has expired' }, 410);

    const key = Deno.env.get('RESEND_API_KEY');
    if (!key) return json({ sent: false, reason: 'email_not_configured' });

    const since = new Date(Date.now() - 24 * 3600 * 1000).toISOString();
    const { count } = await admin.from('invitations').select('id', { count: 'exact', head: true })
      .eq('created_by', uid).gte('email_sent_at', since);
    if ((count ?? 0) >= 20) return json({ error: 'That is a lot of invites for one day. Please try again tomorrow.' }, 429);
    if (inv.email_sent_at && Date.now() - new Date(inv.email_sent_at).getTime() < 60_000) {
      return json({ error: 'That invite was just sent. Give it a minute before sending again.' }, 429);
    }

    const { data: au } = await admin.auth.admin.getUserById(uid);
    const inviterEmail = au?.user?.email ?? null;
    const { data: prof } = await admin.from('profiles').select('full_name').eq('id', uid).maybeSingle();
    const inviterName = (prof?.full_name ?? '').trim() || 'A JamJot family';
    const from = Deno.env.get('INVITE_FROM_ADDRESS') ?? 'JamJot <invites@jamjot.app>';
    const fromAddr = from.includes('<') ? from.replace(/^[^<]*/, `${inviterName.replace(/[<>"]/g, '')} via JamJot `) : from;

    await resend(key, {
      from: fromAddr, to: [email], subject: subj, text,
      html: `<div style="font-family:sans-serif;font-size:16px;line-height:1.5">${linkify(text)}</div>`,
      ...(inviterEmail ? { reply_to: inviterEmail } : {}),
    });
    if (copy_me === true && inviterEmail) {
      const note = `Your invitation was sent to ${email}. Here is a copy of what they received. ` +
        `We'll email you again when they accept.\n\n-----\n\n${text}`;
      try {
        await resend(key, { from, to: [inviterEmail], subject: `Sent: ${subj}`, text: note,
          html: `<div style="font-family:sans-serif;font-size:16px;line-height:1.5">${linkify(note)}</div>` });
      } catch (_) { /* the invite itself went out; the copy is a courtesy */ }
    }
    await admin.from('invitations').update({ invitee_email: email, email_sent_at: new Date().toISOString() }).eq('id', inv.id);
    return json({ sent: true, copy_sent: copy_me === true && !!inviterEmail });
  } catch (_) {
    return json({ error: 'Could not send the email just now.' }, 500);
  }
});
