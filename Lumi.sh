#!/usr/bin/env sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if ! command -v node >/dev/null 2>&1; then
  echo "Lumi requires Node.js. Install Node.js 22 or newer, then run ./Lumi.sh again." >&2
  exit 1
fi

exec node "$PROJECT_ROOT/scripts/launch-lumi.mjs" "$@"
