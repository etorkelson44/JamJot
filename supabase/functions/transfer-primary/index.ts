import { createClient } from 'npm:@supabase/supabase-js@2';

const CORS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey, x-client-info',
};

function json(obj: unknown, status = 200): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

// Hands the primary-caregiver role for one kid to another EXISTING caregiver.
// Only the current primary can call this, and they must re-prove themselves
// with their account password. The old primary keeps full access.
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  try {
    const { student_id, to_guardianship_id, password } = await req.json();
    if (!student_id || !to_guardianship_id || !password) {
      return json({ error: 'student_id, to_guardianship_id and password required' }, 400);
    }

    const url = Deno.env.get('SUPABASE_URL')!;
    const authHeader = req.headers.get('Authorization') ?? '';
    const caller = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData } = await caller.auth.getUser();
    const uid = userData?.user?.id;
    const email = userData?.user?.email;
    if (!uid || !email) return json({ error: 'Not signed in' }, 401);

    // Re-prove identity with the password — a PIN is not enough for this.
    const verifier = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!);
    const { error: pwErr } = await verifier.auth.signInWithPassword({ email, password });
    if (pwErr) return json({ error: 'Wrong password' }, 403);

    const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

    const { data: me } = await admin
      .from('guardianships')
      .select('*')
      .eq('student_id', student_id)
      .eq('profile_id', uid)
      .eq('is_primary', true)
      .maybeSingle();
    if (!me) return json({ error: 'Only the current primary caregiver can transfer the role' }, 403);

    const { data: target } = await admin
      .from('guardianships')
      .select('*')
      .eq('id', to_guardianship_id)
      .eq('student_id', student_id)
      .maybeSingle();
    if (!target) return json({ error: 'That caregiver was not found for this kid' }, 404);
    if (target.profile_id === uid) return json({ error: 'That is already you' }, 400);

    // Demote, then promote (old primary keeps full access).
    const { error: e1 } = await admin.from('guardianships').update({
      is_primary: false,
      can_message: true,
      can_view_calendar: true,
      family_event_level: 'edit',
      can_stock_rewards: true,
      can_adjust_practice: true,
      can_pay: true,
    }).eq('id', me.id);
    if (e1) return json({ error: e1.message }, 500);
    const { error: e2 } = await admin
      .from('guardianships')
      .update({ is_primary: true })
      .eq('id', target.id);
    if (e2) {
      // Put things back rather than leave the kid primary-less.
      await admin.from('guardianships').update({ is_primary: true }).eq('id', me.id);
      return json({ error: e2.message }, 500);
    }
    return json({ transferred: true });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
