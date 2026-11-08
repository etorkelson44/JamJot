import { createClient } from 'npm:@supabase/supabase-js@2';

// A personal iCalendar (ICS) feed: everything this person's JamJot
// calendar shows — their own events plus their kids' — for subscribing
// from Google Calendar, Apple Calendar, Skylight, Cozi, etc.
// Auth: the secret token in the URL (these apps cannot send headers).

function esc(s: string): string {
  return s.replace(/\\/g, '\\\\').replace(/;/g, '\\;').replace(/,/g, '\\,').replace(/\n/g, '\\n');
}
function dt(iso: string): string {
  return new Date(iso).toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');
}

Deno.serve(async (req) => {
  try {
    const url = new URL(req.url);
    const token = url.searchParams.get('token');
    if (!token) return new Response('missing token', { status: 400 });
    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );
    const { data: feed } = await admin
      .from('calendar_feeds')
      .select('profile_id')
      .eq('token', token)
      .maybeSingle();
    if (!feed) return new Response('unknown token', { status: 404 });
    const pid = feed.profile_id;

    // Their own events + their kids' events.
    const ids = new Set<string>();
    const events: Record<string, unknown>[] = [];
    const { data: own } = await admin
      .from('calendar_events')
      .select('*')
      .eq('owner_id', pid)
      .gte('starts_at', new Date(Date.now() - 60 * 86400000).toISOString());
    for (const e of own ?? []) { if (!ids.has(e.id)) { ids.add(e.id); events.push(e); } }
    const { data: kids } = await admin
      .from('guardianships')
      .select('student_id')
      .eq('profile_id', pid);
    const kidIds = (kids ?? []).map((g) => g.student_id);
    if (kidIds.length > 0) {
      const { data: es } = await admin
        .from('event_students')
        .select('calendar_events(*), student_id, students(display_name)')
        .in('student_id', kidIds);
      for (const r of es ?? []) {
        const e = r.calendar_events as Record<string, unknown> | null;
        if (!e) continue;
        if (new Date(e.starts_at as string).getTime() < Date.now() - 60 * 86400000) continue;
        if (!ids.has(e.id as string)) { ids.add(e.id as string); events.push(e); }
      }
    }

    const lines = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//JamJot//Practice Calendar//EN',
      'X-WR-CALNAME:JamJot',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
    ];
    for (const e of events) {
      const cancelled = e.status === 'cancelled';
      const title = `${cancelled ? 'CANCELLED: ' : ''}${e.title ?? 'Event'}`;
      const notes = [e.notes, e.status_note].filter(Boolean).join(' — ');
      lines.push('BEGIN:VEVENT');
      lines.push(`UID:${e.id}@jamjot`);
      lines.push(`DTSTAMP:${dt(new Date().toISOString())}`);
      lines.push(`DTSTART:${dt(e.starts_at as string)}`);
      if (e.ends_at) lines.push(`DTEND:${dt(e.ends_at as string)}`);
      lines.push(`SUMMARY:${esc(title)}`);
      if (notes) lines.push(`DESCRIPTION:${esc(notes)}`);
      lines.push(`STATUS:${cancelled ? 'CANCELLED' : 'CONFIRMED'}`);
      lines.push('END:VEVENT');
    }
    lines.push('END:VCALENDAR');
    return new Response(lines.join('\r\n'), {
      headers: {
        'Content-Type': 'text/calendar; charset=utf-8',
        'Content-Disposition': 'inline; filename=jamjot.ics',
        'Cache-Control': 'max-age=300',
      },
    });
  } catch (e) {
    return new Response(`feed error: ${String(e).slice(0, 200)}`, { status: 500 });
  }
});
