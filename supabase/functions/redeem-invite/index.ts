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

// The universal invite redeemer.
// kind 'enrollment': connects a family to a teacher.
// kind 'caregiver': adds the caller as a caregiver with chosen grants
//   (full_access turns every grant on; primary is never transferable).
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  try {
    const { token, student_id, new_student, accept } = await req.json();
    if (!token) return json({ error: 'token required' }, 400);

    const url = Deno.env.get('SUPABASE_URL')!;
    const authHeader = req.headers.get('Authorization') ?? '';
    const caller = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData } = await caller.auth.getUser();
    const uid = userData?.user?.id;
    if (!uid) return json({ error: 'Not signed in' }, 401);

    const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const { data: invite } = await admin
      .from('invitations')
      .select('*, teachers(id, display_name, instruments, studio_id, studios(name))')
      .eq('token', token)
      .maybeSingle();
    if (!invite) return json({ error: 'Invite not found' }, 404);
    if (invite.single_use && invite.used_at) {
      return json({ error: 'This invite was already used' }, 410);
    }
    if (invite.expires_at && new Date(invite.expires_at) < new Date()) {
      return json({ error: 'This invite has expired' }, 410);
    }

    // ---------------------------------------------------------- caregiver
    if (invite.kind === 'caregiver') {
      if (!invite.student_id) return json({ error: 'Broken invite' }, 400);
      const { data: student } = await admin
        .from('students')
        .select('display_name')
        .eq('id', invite.student_id)
        .maybeSingle();
      const g = invite.preset_grants ?? {};
      const info = {
        kind: 'caregiver',
        student_name: student?.display_name ?? 'a young musician',
        caregiver_name: g.caregiver_name ?? null,
        relationship: g.relationship ?? null,
        full_access: g.full_access === true,
      };
      if (!accept) return json({ mode: 'info', ...info });

      const { data: existing } = await admin
        .from('guardianships')
        .select('id')
        .eq('student_id', invite.student_id)
        .eq('profile_id', uid)
        .limit(1);
      if (existing && existing.length > 0) {
        return json({ mode: 'redeemed', already: true, ...info });
      }
      const full = g.full_access === true;
      const { error: e } = await admin.from('guardianships').insert({
        student_id: invite.student_id,
        profile_id: uid,
        is_primary: false, // an invite can never hand out primary
        display_name: String(g.caregiver_name ?? '').slice(0, 60),
        relationship: String(g.relationship ?? '').slice(0, 40),
        can_message: full || g.can_message === true,
        can_view_calendar: full || g.can_view_calendar !== false,
        family_event_level: full
          ? 'edit'
          : ['view', 'add', 'edit'].includes(g.family_event_level)
              ? g.family_event_level
              : 'view',
        can_stock_rewards: full || g.can_stock_rewards === true,
        can_adjust_practice: full || g.can_adjust_practice === true,
        can_pay: full || g.can_pay === true,
      });
      if (e) return json({ error: e.message }, 500);
      if (invite.single_use) {
        await admin
          .from('invitations')
          .update({ used_at: new Date().toISOString(), used_by: uid })
          .eq('id', invite.id);
      }
      return json({ mode: 'redeemed', ...info });
    }

    // ---------------------------------------------------------- enrollment
    const teacher = invite.teachers;
    const info = {
      kind: 'enrollment',
      teacher_name: teacher?.display_name ?? 'Your teacher',
      studio_name: teacher?.studios?.name ?? null,
      instrument: invite.instrument,
      student_hint: (invite.preset_grants ?? {})['student_name'] ?? null,
    };

    if (!student_id && !new_student) return json({ mode: 'info', ...info });

    let sid = student_id as string | undefined;
    if (!sid && new_student?.name) {
      const { data: created, error: e1 } = await admin
        .from('students')
        .insert({
          display_name: String(new_student.name).slice(0, 60),
          instruments: Array.isArray(new_student.instruments)
            ? new_student.instruments
            : [invite.instrument ?? 'Music'],
          created_by: uid,
        })
        .select()
        .single();
      if (e1) return json({ error: e1.message }, 500);
      sid = created.id;
      const { error: e2 } = await admin.from('guardianships').insert({
        student_id: sid,
        profile_id: uid,
        is_primary: true,
        can_message: true,
        can_view_calendar: true,
        family_event_level: 'edit',
        can_stock_rewards: true,
        can_adjust_practice: true,
        can_pay: true,
      });
      if (e2) return json({ error: e2.message }, 500);
    }
    if (!sid) return json({ error: 'Pick a kid or add one' }, 400);

    const { data: guard } = await admin
      .from('guardianships')
      .select('id')
      .eq('student_id', sid)
      .eq('profile_id', uid)
      .limit(1);
    if (!guard || guard.length === 0) {
      return json({ error: 'Only this kid\'s caregiver can accept' }, 403);
    }

    const { data: existing } = await admin
      .from('enrollments')
      .select('id')
      .eq('student_id', sid)
      .eq('teacher_id', invite.teacher_id)
      .eq('status', 'active')
      .limit(1);
    if (existing && existing.length > 0) {
      return json({ mode: 'redeemed', already: true, ...info });
    }

    const { error: e3 } = await admin.from('enrollments').insert({
      student_id: sid,
      teacher_id: invite.teacher_id,
      studio_id: invite.studio_id ?? teacher?.studio_id,
      instrument: invite.instrument ?? 'Music',
      status: 'active',
      billing_owner: (invite.studio_id ?? teacher?.studio_id) ? 'studio' : 'teacher',
    });
    if (e3) return json({ error: e3.message }, 500);

    if (invite.single_use) {
      await admin
        .from('invitations')
        .update({ used_at: new Date().toISOString(), used_by: uid })
        .eq('id', invite.id);
    }
    return json({ mode: 'redeemed', ...info });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
