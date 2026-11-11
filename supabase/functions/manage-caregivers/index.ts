import { createClient } from 'npm:@supabase/supabase-js@2';

// Two actions for the primary caregiver (JJ-056-C, JJ-057-C):
//   cancel_invite    { invite_id }        - cancels an unused caregiver invite, emails the invitee (if we have their address)
//   remove_caregiver { guardianship_id }  - removes another caregiver from a kid, emails them a notice
// Only the person who made the invite / the kid's primary caregiver may do either. The primary caregiver
// can never be removed here (handing over primary stays in transfer-primary). The email is a courtesy:
// if it cannot be sent the action still happens and we say so.
const CORS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey, x-client-info',
};
const json = (obj: unknown, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });
const esc = (t: string) => t.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

async function sendMail(to: string, subject: string, text: string, replyTo: string | null, inviterName: string) {
  const key = Deno.env.get('RESEND_API_KEY');
  if (!key) return false;
  const from = Deno.env.get('INVITE_FROM_ADDRESS') ?? 'JamJot <invites@jamjot.app>';
  const fromAddr = from.includes('<') ? from.replace(/^[^<]*/, `${inviterName.replace(/[<>"]/g, '')} via JamJot `) : from;
  const r = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      from: fromAddr, to: [to], subject, text,
      html: `<div style="font-family:sans-serif;font-size:16px;line-height:1.5">${esc(text).replace(/\n/g, '<br>')}</div>`,
      ...(replyTo ? { reply_to: replyTo } : {}),
    }),
  });
  return r.ok;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  try {
    const { action, invite_id, guardianship_id } = await req.json();
    const url = Deno.env.get('SUPABASE_URL')!;
    const caller = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
    });
    const { data: u } = await caller.auth.getUser();
    const uid = u?.user?.id;
    if (!uid) return json({ error: 'Not signed in' }, 401);
    const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

    const isPrimary = async (studentId: string) => {
      const { data } = await admin.from('guardianships').select('id')
        .eq('student_id', studentId).eq('profile_id', uid).eq('is_primary', true).limit(1);
      return !!data && data.length > 0;
    };
    const names = async (studentId: string) => {
      const { data: prof } = await admin.from('profiles').select('full_name').eq('id', uid).maybeSingle();
      const { data: st } = await admin.from('students').select('display_name').eq('id', studentId).maybeSingle();
      const { data: au } = await admin.auth.admin.getUserById(uid);
      return {
        inviter: (prof?.full_name ?? '').trim() || 'The family',
        kid: st?.display_name ?? 'the young musician',
        inviterEmail: au?.user?.email ?? null,
      };
    };

    if (action === 'cancel_invite') {
      const { data: inv } = await admin.from('invitations').select('*').eq('id', invite_id).maybeSingle();
      if (!inv || inv.kind !== 'caregiver' || !inv.student_id) return json({ error: 'Invite not found' }, 404);
      if (inv.created_by !== uid && !(await isPrimary(inv.student_id))) return json({ error: 'Not allowed' }, 403);
      if (inv.used_at) return json({ error: 'This invite was already accepted. Remove the caregiver instead.' }, 409);
      const { error } = await admin.from('invitations').delete().eq('id', inv.id);
      if (error) return json({ error: 'Could not cancel that invite just now.' }, 500);
      let notified = false;
      const to = String(inv.invitee_email ?? '').trim();
      if (to) {
        const n = await names(inv.student_id);
        const who = String(inv.preset_grants?.caregiver_name ?? '').trim();
        notified = await sendMail(
          to,
          `Your invitation to ${n.kid}'s JamJot was cancelled`,
          `Hi${who ? ' ' + who : ''},\n\n${n.inviter} cancelled the invitation to join ${n.kid}'s JamJot, so the link in the earlier email no longer works.\n\n` +
            `If this was unexpected, please ask ${n.inviter} to send you a new invitation${n.inviterEmail ? ` (you can reply to this email to reach them)` : ''}.`,
          n.inviterEmail, n.inviter,
        ).catch(() => false);
      }
      return json({ done: true, notified });
    }

    if (action === 'remove_caregiver') {
      const { data: g } = await admin.from('guardianships').select('*').eq('id', guardianship_id).maybeSingle();
      if (!g) return json({ error: 'Caregiver not found' }, 404);
      if (!(await isPrimary(g.student_id))) return json({ error: 'Only the primary caregiver can remove a caregiver.' }, 403);
      if (g.is_primary || g.profile_id === uid) return json({ error: 'The primary caregiver cannot be removed here.' }, 400);
      const { data: au } = await admin.auth.admin.getUserById(g.profile_id);
      const targetEmail = au?.user?.email ?? null;
      const { error } = await admin.from('guardianships').delete().eq('id', g.id);
      if (error) return json({ error: 'Could not remove that caregiver just now.' }, 500);
      let notified = false;
      if (targetEmail) {
        const n = await names(g.student_id);
        const who = String(g.display_name ?? '').trim();
        notified = await sendMail(
          targetEmail,
          `You were removed from ${n.kid}'s JamJot`,
          `Hi${who ? ' ' + who : ''},\n\n${n.inviter} removed you as a caregiver on ${n.kid}'s JamJot, so you no longer have access to ${n.kid}'s practice, calendar or chats.\n\n` +
            `If this was unexpected, please ask ${n.inviter} to add you again${n.inviterEmail ? ` (you can reply to this email to reach them)` : ''}.`,
          n.inviterEmail, n.inviter,
        ).catch(() => false);
      }
      return json({ done: true, notified });
    }

    return json({ error: 'Unknown action' }, 400);
  } catch (_) {
    return json({ error: 'Something went wrong. Please try again.' }, 500);
  }
});
