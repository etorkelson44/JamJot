// Retired diagnostic — does nothing.
Deno.serve(() => new Response(JSON.stringify({ ok: false, why: 'retired' }), { headers: { 'content-type': 'application/json' } }));
