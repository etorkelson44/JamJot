#!/bin/bash
# Build command for Cloudflare Pages (runs on Cloudflare's build machine).
# Flutter is not preinstalled there, so fetch the stable SDK first.
set -euo pipefail
ROOT="$(pwd)"
git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
export PATH="$HOME/flutter/bin:$PATH"
flutter --version
cd "$ROOT/app"
# Platform folders are not kept in the repo; regenerate the web one.
flutter create . --project-name jamjot --org app.jamjot --platforms web
flutter pub get
# BUILD_ID = this commit. The app compares it with build-id.txt on the site to
# notice when a newer version has been published (JJ-058-C).
BUILD_ID="${CF_PAGES_COMMIT_SHA:-$(git rev-parse HEAD 2>/dev/null || echo local)}"
flutter build web --release --base-href / --dart-define=BUILD_ID="$BUILD_ID"
printf '%s' "$BUILD_ID" > build/web/build-id.txt
