import { createClient } from 'npm:@supabase/supabase-js@2';
import postgres from 'npm:postgres@3.4.4';

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

function jwtClaims(authHeader: string): Record<string, unknown> | null {
  try {
    const token = authHeader.replace(/^Bearer\s+/i, '');
    const payload = token.split('.')[1];
    const pad = payload.length % 4 === 0 ? '' : '='.repeat(4 - (payload.length % 4));
    return JSON.parse(atob(payload.replace(/-/g, '+').replace(/_/g, '/') + pad));
  } catch (_) {
    return null;
  }
}

// Lists the account's sign-ins (device, browser, IP, last active) and can
// sign out any one of them. Only the signed-in owner sees their own.
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  const sql = postgres(Deno.env.get('SUPABASE_DB_URL')!, { prepare: false });
  try {
    const { action, session_id } = await req.json();
    const url = Deno.env.get('SUPABASE_URL')!;
    const authHeader = req.headers.get('Authorization') ?? '';
    const caller = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData } = await caller.auth.getUser();
    const uid = userData?.user?.id;
    if (!uid) return json({ error: 'Not signed in' }, 401);
    const claims = jwtClaims(authHeader);
    const currentSession = (claims?.['session_id'] as string) ?? null;

    if (action === 'revoke') {
      if (!session_id) return json({ error: 'session_id required' }, 400);
      if (session_id === currentSession) {
        return json({ error: 'Use Sign out for this device' }, 400);
      }
      await sql`delete from auth.sessions where id = ${session_id} and user_id = ${uid}`;
      return json({ revoked: true });
    }

    const rows = await sql`
      select id, created_at, coalesce(refreshed_at, updated_at, created_at) as last_active,
             user_agent, ip::text as ip
      from auth.sessions
      where user_id = ${uid}
      order by coalesce(refreshed_at, updated_at, created_at) desc
      limit 50`;
    return json({
      sessions: rows.map((r) => ({
        id: r.id,
        created_at: r.created_at,
        last_active: r.last_active,
        user_agent: r.user_agent,
        ip: r.ip,
        current: r.id === currentSession,
      })),
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  } finally {
    await sql.end();
  }
});
