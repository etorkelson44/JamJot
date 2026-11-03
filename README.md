# JamJot 🫐

Every minute of music goes in the jar.

A music-practice app for kids, families, teachers, and studios — with
verified practice minutes, a berry-powered reward market, lesson sheets
that round-trip between paper and app, and safety-first messaging.

- `app/` — the Flutter app (iOS, Android, web)
- `supabase/migrations/` — the database schema (already applied to prod)
- `app/ART_MANIFEST.md` — every art slot, ready for custom artwork

CI builds the web preview on every push to `main` (GitHub Pages).

## Practice reliability work

See `docs/PRACTICE_RELIABILITY_HANDOFF.md` for the implementation decisions,
validation results, and coordinated backend/app release requirements.

The app bundles Space Grotesk and commits `pubspec.lock` for repeatable builds.
After generating platform folders, run `python3 tool/configure_platform_permissions.py`
from `app/` to install the microphone permission descriptions before native builds.

Run Flutter checks from `app/`: `flutter analyze` and `flutter test`.
Run the isolated backend contract tests from `supabase/tests/` with
`pnpm install --frozen-lockfile` followed by `pnpm test` (Node 24).
These tests use synthetic data and never connect to the live backend.
