import { createClient } from 'npm:@supabase/supabase-js@2';

const CORS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey, x-client-info',
};

// Always HTTP 200: the app reads {error} or {draft, lessons} from the body.
// (A non-200 makes the client throw a generic error and hide the message.)
function json(obj: unknown): Response {
  return new Response(JSON.stringify(obj), {
    status: 200,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

// Reads a photo/scan of a handwritten or printed lesson sheet and turns it
// into one or more draft lessons: assignments (title, book, pages, notes)
// matched against the caller's own library (fuzzy, abbreviations welcome).
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  try {
    const { image_base64, media_type } = await req.json();
    if (!image_base64 || !media_type) {
      return json({ error: 'image_base64 and media_type required' });
    }

    const url = Deno.env.get('SUPABASE_URL')!;
    const authHeader = req.headers.get('Authorization') ?? '';
    const caller = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData } = await caller.auth.getUser();
    const uid = userData?.user?.id;
    if (!uid) return json({ error: 'Not signed in' });

    const apiKey = Deno.env.get('ANTHROPIC_API_KEY');
    if (!apiKey) return json({ error: 'scan_not_configured' });

    // The caller's library, for matching titles/books/pages to real files.
    const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const { data: scores } = await admin
      .from('scores')
      .select('id, title, folder')
      .eq('owner_id', uid)
      .limit(300);
    const catalog = (scores ?? [])
      .map((s) => `- id:${s.id} | ${s.folder ? s.folder + '/' : ''}${s.title}`)
      .join('\n');

    const today = new Date().toISOString().slice(0, 10);
    const prompt = `You are reading a music teacher's written lesson/assignment sheet (photo or scan). It is often MESSY HANDWRITING on a form, whiteboard, notebook page or sticky note. Read it slowly and carefully, line by line, before extracting anything. Transcribe what is actually written — do not invent songs or notes that are not on the sheet. Today's date is ${today}.\n\nThe family's sheet-music library (one file per line):\n${catalog || '(library is empty)'}\n\nRules:\n- Usually a sheet is ONE lesson. But if it clearly contains SEPARATE lessons (e.g. sections for different students by name, different dates/weeks, or clearly divided halves each with its own heading), extract each as its own lesson, in the order they appear. Give each lesson a lesson_title that includes any student name or date heading you see (e.g. 'Ben — week of Oct 12').\n- lesson_date: if the sheet shows a date (written anywhere: a heading, corner, 'week of ...'), put it in lesson_date as YYYY-MM-DD; use today's year when none is written, picking the year that puts the date nearest to today. If no date is visible, null.\n- Each song/piece/exercise becomes one assignment within its lesson: title, book (if named or abbreviated, expand common method-book abbreviations like 'Suz 2' -> 'Suzuki Book 2', 'FJH', 'Faber', 'Alfred'), pages (as written), note (the teacher's instructions for that piece, verbatim-ish).\n- written: set "written": true on an assignment when the sheet asks for pencil-and-paper work — theory pages, worksheets, writing note names or letters, composing on staff paper, flashcards or workbook pages to fill in, 'complete p. 12', circling or labeling exercises. Assignments that are purely playing/practicing get "written": false. When an assignment clearly involves BOTH playing and written work, still set "written": true (the app asks the teacher to choose).\n- SORT THE NOTES CAREFULLY: an instruction that sits next to, under, after, or is connected by an arrow/bracket to ONE song belongs in THAT assignment's note (e.g. 'RH alone', 'slowly', 'x3', 'mm 1-8', 'w/ metronome'). Only instructions that clearly apply to the whole week or everything on the sheet (e.g. 'practice 20 min/day', 'recital Saturday', 'count out loud on everything') go in lesson_note. When in doubt about which song an instruction belongs to, attach it to the nearest song above it.\n- Handwriting help: titles are often underlined, numbered, bulleted or at the left margin; instructions are usually smaller words after or under the title. Checkboxes, circled page numbers and arrows are common. If a word is hard to read, give your best reading rather than skipping the line — the person can correct it.\n- If the sheet gives only a book + page numbers, and you know that method book well, name the piece(s) that appear on those pages in the title; otherwise title it '<Book> p. <pages>'.\n- For each assignment, if one of the library files above clearly matches (fuzzy: abbreviations, partial titles, folder names count), put its id in score_id, else null.\n- Days/minutes goals if written go in goal_days / goal_minutes, else null.\n\nReply with ONLY this JSON, nothing else:\n{"lessons": [{"lesson_title": string, "lesson_date": string|null, "lesson_note": string, "goal_days": number|null, "goal_minutes": number|null, "assignments": [{"title": string, "book": string, "pages": string, "note": string, "score_id": string|null, "written": boolean}]}]}`;

    const content: unknown[] = [
      media_type === 'application/pdf'
        ? {
            type: 'document',
            source: { type: 'base64', media_type, data: image_base64 },
          }
        : {
            type: 'image',
            source: { type: 'base64', media_type, data: image_base64 },
          },
      { type: 'text', text: prompt },
    ];

    const resp = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model: 'claude-sonnet-5-5',
        max_tokens: 8000,
        messages: [{ role: 'user', content }],
      }),
    });
    if (!resp.ok) {
      const t = await resp.text();
      return json({ error: `Scanner error ${resp.status}: ${t.slice(0, 300)}` });
    }
    const out = await resp.json();
    // The model may answer in several blocks (thinking + text): take all text.
    const text: string = ((out?.content ?? []) as Array<Record<string, unknown>>)
      .filter((c) => c.type === 'text')
      .map((c) => c.text as string)
      .join('\n');
    const start = text.indexOf('{');
    const end = text.lastIndexOf('}');
    if (start < 0 || end < 0) {
      return json({ error: `Could not read the sheet (stop: ${out?.stop_reason ?? '?'})` });
    }
    let parsed: Record<string, unknown>;
    try {
      parsed = JSON.parse(text.slice(start, end + 1));
    } catch (_) {
      return json({ error: 'Could not read the sheet — try a straighter, closer photo?' });
    }
    const lessons = Array.isArray(parsed.lessons)
      ? parsed.lessons
      : [parsed]; // older single-lesson shape, just in case
    if (lessons.length === 0) return json({ error: 'Could not read the sheet' });
    // Back-compat: 'draft' stays the first lesson.
    return json({ draft: lessons[0], lessons });
  } catch (e) {
    return json({ error: `Scanner crashed: ${String(e).slice(0, 300)}` });
  }
});
