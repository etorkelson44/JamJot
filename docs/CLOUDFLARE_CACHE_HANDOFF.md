# Cloudflare cache still serves the retired Note — handoff, 2026-11-09

## The problem
The blue JamJot Note mascot was retired (JJ-035-C). Its file was deleted
from the repo and the deployed site, but one address still shows it:

    https://jamjot.app/assets/assets/mascot/note.png   → 200, the old Note image

Cloudflare's cache in front of jamjot.app is serving a saved copy. The site
itself no longer has the file:

| Address | Result |
| --- | --- |
| `https://jamjot.app/assets/assets/mascot/note.png` | **200 image/png**, `cf-cache-status: REVALIDATED`, `cache-control: public, max-age=14400, must-revalidate` |
| `https://jamjot.app/assets/assets/mascot/note.png?x=1` | 404 (Maestro "jammed up" page), `cf-cache-status: BYPASS` |
| `https://jamjot.pages.dev/assets/assets/mascot/note.png` | 404 |

"REVALIDATED" means Cloudflare checked back and kept its copy (the old ETag
`"5288b42c4f44378f475e79bb29ff5bf6"`), so it may never expire on its own.

## Goal
Plain `https://jamjot.app/assets/assets/mascot/note.png` returns 404 and shows
the Maestro "jammed up" page, like every other missing address.

## Still to do
1. **Purge that one URL.** Either:
   - Dashboard: jamjot.app zone → Caching → Configuration → Purge Cache →
     Custom Purge → URL → `https://jamjot.app/assets/assets/mascot/note.png`.
   - API: a Cloudflare API token limited to the jamjot.app zone with
     Zone → Cache Purge → Purge and Zone → Zone → Read, saved through the
     session's secure credential form for `api.cloudflare.com` (never pasted
     into chat). Then `GET /client/v4/zones?name=jamjot.app` for the zone id
     and `POST /client/v4/zones/<id>/purge_cache` with
     `{"files":["https://jamjot.app/assets/assets/mascot/note.png"]}`.
     (An attempt to open that form on 2026-11-09 was cancelled.)
2. **Check it worked** (no query string — the query string skips the cache):

       curl -sI https://jamjot.app/assets/assets/mascot/note.png | grep -iE '^HTTP|cf-cache-status'

   Expect `HTTP/2 404`. Then open the address in a private browser window.
3. **Find out why the cache revalidates a deleted file.** Look at the
   jamjot.app zone's Cache Rules / Page Rules (e.g. a "Cache Everything" or
   edge-TTL rule on `/assets/*`). If one exists, decide whether to keep it.
   Without a change, any file removed in future can stay visible the same
   way, so a purge may need to be part of every release that removes a file.
4. **Codeberg backup (JJ-034-C).** Not confirmed for today's commits
   (`dad872c` … `23c6599`). This cloud session cannot reach codeberg.org and
   the repo doesn't say how the Codeberg copy is made. Confirm Codeberg's
   `main` shows `23c6599` or later.

## Already done (no action needed)
- `app/web/404.html` makes missing files return a real 404 (before it,
  Cloudflare Pages answered every missing path with the app page and 200).
  App and invite links use `jamjot.app/#/…`, so they are unaffected.
- That page and the `index.html` "can't load" fallback show perplexed
  Maestro (`maestro_jammed.png`) embedded inside the page, with the same
  words as the in-app JammedUp screen. Both checked with no network.
- The app loads `maestro_jammed.png` at startup, so the in-app jammed-up
  screen has him ready even if the connection drops later.
- Browser-tab and home-screen icons now use the JJ logo (`app/web/icons/`,
  `app/web/favicon.png`). The same Cloudflare cache may keep old icons for a
  while; purging `/favicon.png` and `/icons/*` is optional.

## Rules for this work
- Changing Cloudflare settings (cache rules, tokens) needs Erika's explicit
  yes. A one-URL purge was requested by Erika on 2026-11-09.
- Do not touch the JJ logo, Maestro or the fan emblem art.
- A private claude.ai preview of the 404 page was created by mistake
  (https://claude.ai/artifact/2QZJzYqTnxecCcPVXn3Ev5); its image doesn't load
  there. Delete it if Erika wants.
