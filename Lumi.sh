#!/usr/bin/env sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

case "$(uname -s)" in
  Linux)
    if ! command -v bash >/dev/null 2>&1; then
      echo 'Lumi needs Bash to start on Linux.' >&2
      exit 1
    fi
    if [ ! -f "$PROJECT_ROOT/scripts/bootstrap-lumi.sh" ]; then
      echo 'Lumi launcher files are missing. Extract the complete project archive and try again.' >&2
      exit 1
    fi
    exec bash "$PROJECT_ROOT/scripts/bootstrap-lumi.sh" "$@"
    ;;
  MINGW*|MSYS*|CYGWIN*)
    if ! command -v powershell.exe >/dev/null 2>&1 || ! command -v cygpath >/dev/null 2>&1; then
      echo 'Lumi needs Windows PowerShell and cygpath in this shell. Alternatively, double-click Lumi.bat.' >&2
      exit 1
    fi
    if [ ! -f "$PROJECT_ROOT/scripts/bootstrap-lumi.ps1" ]; then
      echo 'Lumi launcher files are missing. Extract the complete project archive and try again.' >&2
      exit 1
    fi
    windows_script=$(cygpath -w "$PROJECT_ROOT/scripts/bootstrap-lumi.ps1")
    exec powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$windows_script" "$@"
    ;;
  Darwin)
    echo 'The source launcher does not support macOS yet. Use a macOS release build if available.' >&2
    exit 1
    ;;
  *)
    echo "The Lumi source launcher does not support $(uname -s)." >&2
    exit 1
    ;;
esac
