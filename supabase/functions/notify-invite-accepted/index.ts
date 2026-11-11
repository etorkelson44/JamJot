import { createClient } from 'npm:@supabase/supabase-js@2';

// Called by the app right after someone accepts an invite. Tells the inviter by email that it was accepted.
// Only the person who actually accepted (used_by) can trigger it, and only once per invite.
const CORS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey, x-client-info',
};
const json = (obj: unknown, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  try {
    const { token } = await req.json();
    const url = Deno.env.get('SUPABASE_URL')!;
    const caller = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
    });
    const { data: u } = await caller.auth.getUser();
    const uid = u?.user?.id;
    if (!uid) return json({ error: 'Not signed in' }, 401);
    const key = Deno.env.get('RESEND_API_KEY');
    if (!key) return json({ sent: false, reason: 'email_not_configured' });

    const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const { data: inv } = await admin.from('invitations').select('*').eq('token', token ?? '').maybeSingle();
    if (!inv || inv.used_by !== uid || !inv.used_at) return json({ sent: false, reason: 'not_accepted_by_you' });
    if (inv.accepted_notice_at) return json({ sent: false, reason: 'already_sent' });
    if (!inv.email_sent_at) return json({ sent: false, reason: 'not_emailed' });   // only invites sent from JamJot

    const { data: au } = await admin.auth.admin.getUserById(inv.created_by);
    const to = au?.user?.email;
    if (!to) return json({ sent: false, reason: 'no_inviter_email' });
    const { data: stu } = inv.student_id
      ? await admin.from('students').select('display_name').eq('id', inv.student_id).maybeSingle()
      : { data: null };
    const kid = stu?.display_name ?? 'your student';
    const g = inv.preset_grants ?? {};
    let who = (g.caregiver_name as string | undefined) ?? '';
    let what: string;
    if (inv.kind === 'teacher_invite') {
      const { data: t } = await admin.from('teachers').select('display_name').eq('profile_id', uid).limit(1).maybeSingle();
      who = t?.display_name ?? (g.teacher_name as string | undefined) ?? 'Your teacher';
      what = `${who} accepted your invitation and is now ${kid}'s ${inv.instrument ?? ''} teacher on JamJot.`.replace('  ', ' ');
    } else if (inv.kind === 'caregiver') {
      who = who || 'The person you invited';
      what = `${who} accepted your invitation and is now one of ${kid}'s caregivers on JamJot.`;
    } else {
      who = who || 'The person you invited';
      what = `${who} accepted your invitation and joined JamJot.`;
    }
    const from = Deno.env.get('INVITE_FROM_ADDRESS') ?? 'JamJot <invites@jamjot.app>';
    const text = `Good news! ${what}\n\nThey have set up their JamJot account, so you're all connected.\n\n— JamJot`;
    const r = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ from, to: [to], subject: `${who} accepted your JamJot invitation`, text }),
    });
    if (!r.ok) return json({ sent: false, reason: 'mail_service_error' });
    await admin.from('invitations').update({ accepted_notice_at: new Date().toISOString() }).eq('id', inv.id);
    return json({ sent: true });
  } catch (_) {
    return json({ sent: false, reason: 'error' });
  }
});
