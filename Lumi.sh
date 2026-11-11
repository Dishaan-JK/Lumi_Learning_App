#!/usr/bin/env sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if ! command -v bash >/dev/null 2>&1; then
  echo 'Lumi needs Bash to install its private runtimes.' >&2
  exit 1
fi

exec bash "$PROJECT_ROOT/scripts/bootstrap-lumi.sh" "$@"
