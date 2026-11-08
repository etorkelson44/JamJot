import { createClient } from 'npm:@supabase/supabase-js@2';

Deno.serve(async () => {
  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );
  const path = `diag/test-${Date.now()}.txt`;
  const up = await admin.storage
    .from('scores')
    .upload(path, new Blob(['jamjot storage diag']), {
      contentType: 'text/plain',
    });
  const list = await admin.storage.from('scores').list('diag');
  return new Response(
    JSON.stringify({ upload: up, list_count: list.data?.length, list_error: list.error }),
    { headers: { 'Content-Type': 'application/json' } },
  );
});
