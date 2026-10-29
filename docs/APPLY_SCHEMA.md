# How to apply the JamJot schema (5 minutes, no coding)

1. Go to **supabase.com** and open your **JamJot** project.
2. In the left sidebar, click **SQL Editor** (the `>_` icon).
3. Click **New query**.
4. Open the file `0001_init.sql` (attached in our chat), select ALL of it
   (Ctrl/Cmd+A), copy, and paste it into the big empty box.
5. Click **Run** (bottom right). It takes a few seconds.
6. You should see "Success. No rows returned." That's the good outcome.
7. Sanity check: click **Table Editor** in the sidebar — you should now see
   tables like `students`, `guardianships`, `lessons`, `berry_ledger`,
   `market_items`, and more (24 in total).

If anything shows a red error instead, screenshot it and paste it to Claude.

## Then send Claude two things (safe to share):
- **Project URL** — Settings → API → "Project URL" (looks like
  `https://abcdefgh.supabase.co`)
- **anon / publishable key** — Settings → API → "anon public" key

These let the app connect. Do NOT send the `service_role` key unless
Claude specifically asks for a one-time setup step.
