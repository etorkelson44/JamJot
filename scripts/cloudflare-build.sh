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
flutter build web --release --base-href /
