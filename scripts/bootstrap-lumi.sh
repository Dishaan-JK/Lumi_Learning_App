#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DATA_HOME=${XDG_DATA_HOME:-"$HOME/.local/share"}
RUNTIME_HOME="$DATA_HOME/lumi/runtime"
NODE_STATE="$RUNTIME_HOME/node-version"
DART_STATE="$RUNTIME_HOME/dart-version"
mkdir -p "$RUNTIME_HOME"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then printf '\033[92m'; fi
cat <<'BANNER'
  _     _   _ __  __ ___
 | |   | | | |  \/  |_ _|
 | |   | | | | |\/| || |
 | |___| |_| | |  | || |
 |_____|\___/|_|  |_|___|
BANNER
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then printf '\033[0m'; fi
printf '\n  Lumi setup  |  OS: Linux %s\n' "$(uname -m)"
printf '  Checking runtimes and packages, then starting Lumi.\n\n'

if [ "$(uname -s)" != Linux ]; then
  echo 'This source launcher currently supports Linux. Windows uses Lumi.bat.' >&2
  exit 1
fi

case "$(uname -m)" in
  x86_64|amd64) ASSET_ARCH=x64 ;;
  aarch64|arm64) ASSET_ARCH=arm64 ;;
  *) echo "Lumi does not have a bundled runtime for $(uname -m)." >&2; exit 1 ;;
esac

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Lumi needs '$1' to download and unpack its private runtimes." >&2
    exit 1
  fi
}

node_usable() {
  [ -x "$1" ] && "$1" -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 22 ? 0 : 1)' >/dev/null 2>&1
}
dart_usable() {
  [ -x "$1" ] || return 1
  local version major minor
  version=$("$1" --version 2>&1 | sed -n 's/.*version: \([0-9][0-9]*\)\.\([0-9][0-9]*\)\..*/\1 \2/p')
  read -r major minor <<< "$version"
  [ -n "$major" ] && { [ "$major" -gt 3 ] || { [ "$major" -eq 3 ] && [ "$minor" -ge 12 ]; }; }
}

NODE_BIN=$(command -v node || true)
if [ -n "$NODE_BIN" ] && node_usable "$NODE_BIN" && command -v npm >/dev/null 2>&1 && npm --version >/dev/null 2>&1; then
  echo "Using installed Node.js $("$NODE_BIN" --version) and npm."
else
  node_version=$(cat "$NODE_STATE" 2>/dev/null || true)
  NODE_BIN="$RUNTIME_HOME/node-v$node_version/bin/node"
  if [ -z "$node_version" ] || ! node_usable "$NODE_BIN" || [ ! -x "$(dirname "$NODE_BIN")/npm" ]; then
    for command_name in curl tar xz awk; do require_command "$command_name"; done
    node_version=$(curl -fsSL --max-time 15 https://nodejs.org/dist/index.tab | awk -F '\t' 'NR > 1 && $10 != "-" && !found { sub(/^v/, "", $1); print $1; found=1 }')
    if [ -z "$node_version" ] || [ "${node_version%%.*}" -lt 22 ]; then
      echo 'Could not find a Node.js 22 or newer runtime.' >&2; exit 1
    fi
    NODE_HOME="$RUNTIME_HOME/node-v$node_version"
    temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/lumi-runtime.XXXXXX")
    trap 'rm -rf "$temp_dir"' EXIT HUP INT TERM
    echo "Downloading Node.js $node_version for Linux $ASSET_ARCH..."
    curl -fL --retry 2 "https://nodejs.org/dist/v$node_version/node-v$node_version-linux-$ASSET_ARCH.tar.xz" -o "$temp_dir/node.tar.xz"
    mkdir "$temp_dir/node"
    tar -xJf "$temp_dir/node.tar.xz" --strip-components=1 -C "$temp_dir/node"
    node_usable "$temp_dir/node/bin/node" || { echo 'Downloaded Node.js is unusable.' >&2; exit 1; }
    rm -rf "$NODE_HOME"
    mv "$temp_dir/node" "$NODE_HOME"
    printf '%s\n' "$node_version" > "$NODE_STATE"
    trap - EXIT HUP INT TERM
    rm -rf "$temp_dir"
    NODE_BIN="$NODE_HOME/bin/node"
  fi
  export PATH="$(dirname "$NODE_BIN"):$PATH"
  echo "Using Lumi's private Node.js $("$NODE_BIN" --version)."
fi

system_dart=$(command -v dart || true)
# Flutter's wrapper may try to update its cache; use its SDK executable directly.
case "$system_dart" in
  */flutter/bin/dart) [ ! -x "${system_dart%/dart}/cache/dart-sdk/bin/dart" ] || system_dart="${system_dart%/dart}/cache/dart-sdk/bin/dart" ;;
esac
if [ -n "$system_dart" ] && dart_usable "$system_dart"; then
  LUMI_DART_EXECUTABLE="$system_dart"
  echo "Using installed Dart: $LUMI_DART_EXECUTABLE"
elif dart_usable "$RUNTIME_HOME/dart-sdk/bin/dart"; then
  LUMI_DART_EXECUTABLE="$RUNTIME_HOME/dart-sdk/bin/dart"
  echo "Using Lumi's private Dart SDK."
else
  for command_name in curl unzip sed; do require_command "$command_name"; done
  latest_dart=$(curl -fsSL --max-time 15 https://storage.googleapis.com/dart-archive/channels/stable/release/latest/VERSION | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([0-9][0-9.]*\)".*/\1/p')
  if [ -z "$latest_dart" ]; then echo 'Could not find a Dart runtime.' >&2; exit 1; fi
  temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/lumi-dart.XXXXXX")
  trap 'rm -rf "$temp_dir"' EXIT HUP INT TERM
  echo "Downloading Dart $latest_dart for Linux $ASSET_ARCH..."
  curl -fL --retry 2 "https://storage.googleapis.com/dart-archive/channels/stable/release/$latest_dart/sdk/dartsdk-linux-$ASSET_ARCH-release.zip" -o "$temp_dir/dart.zip"
  unzip -q "$temp_dir/dart.zip" -d "$temp_dir"
  dart_usable "$temp_dir/dart-sdk/bin/dart" || { echo 'Downloaded Dart SDK is unusable or older than 3.12.' >&2; exit 1; }
  rm -rf "$RUNTIME_HOME/dart-sdk"
  mv "$temp_dir/dart-sdk" "$RUNTIME_HOME/dart-sdk"
  printf '%s\n' "$latest_dart" > "$DART_STATE"
  trap - EXIT HUP INT TERM
  rm -rf "$temp_dir"
  LUMI_DART_EXECUTABLE="$RUNTIME_HOME/dart-sdk/bin/dart"
fi
export LUMI_DART_EXECUTABLE LUMI_RUNTIME_HOME="$RUNTIME_HOME"

# Keep the frontend and backend from the same downloaded project snapshot.
WEB_ROOT="$PROJECT_ROOT/dist"
if [ ! -f "$WEB_ROOT/index.html" ]; then
  echo 'The React bundle is missing. Download and extract the complete Lumi project again.' >&2
  exit 1
fi

CLI_DIR="$HOME/.local/bin"
CLI="$CLI_DIR/lumi"
mkdir -p "$CLI_DIR"
if [ ! -e "$CLI" ] || grep -q 'managed by Lumi' "$CLI" 2>/dev/null; then
  project_root_quoted=$(printf '%s' "$PROJECT_ROOT" | sed "s/'/'\\\\''/g")
  cat > "$CLI" <<EOF
#!/usr/bin/env sh
# managed by Lumi
exec '$project_root_quoted/Lumi.sh' "\$@"
EOF
  chmod 755 "$CLI"
else
  echo "A different '$CLI' already exists; leaving it unchanged." >&2
fi

if ! printf '%s' ":$PATH:" | grep -Fq ":$CLI_DIR:"; then
  profile="$HOME/.profile"
  if ! grep -Fq '# Lumi command path' "$profile" 2>/dev/null; then
    {
      printf '\n# Lumi command path\n'
      printf 'export PATH="$HOME/.local/bin:$PATH"\n'
    } >> "$profile"
  fi
  shell_name=${SHELL:-sh}
  case "${shell_name##*/}" in
    zsh) profile="$HOME/.zshrc" ;;
    bash) profile="$HOME/.bashrc" ;;
  esac
  if ! grep -Fq '# Lumi command path' "$profile" 2>/dev/null; then
    {
      printf '\n# Lumi command path\n'
      printf 'export PATH="$HOME/.local/bin:$PATH"\n'
    } >> "$profile"
  fi
fi

export LUMI_FRONTEND_PORT=${LUMI_FRONTEND_PORT:-5173}
export LUMI_WEB_DIR="$WEB_ROOT"
exec "$NODE_BIN" "$PROJECT_ROOT/scripts/launch-lumi.mjs" "$@"
