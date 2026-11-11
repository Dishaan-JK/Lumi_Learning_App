#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DATA_HOME=${XDG_DATA_HOME:-"$HOME/.local/share"}
RUNTIME_HOME="$DATA_HOME/lumi/runtime"
NODE_STATE="$RUNTIME_HOME/node-version"
DART_STATE="$RUNTIME_HOME/dart-version"
WEB_REVISION_FILE="$RUNTIME_HOME/web-revision"
MARKER="$RUNTIME_HOME/first-run-complete"
ARCHIVE_URL='https://github.com/Dishaan-JK/Lumi_Learning_App/archive/refs/heads/React_v.tar.gz'
mkdir -p "$RUNTIME_HOME"

if [ "$(uname -s)" != Linux ]; then
  echo 'This source launcher currently supports Linux. Windows uses Lumi.bat.' >&2
  exit 1
fi

case "$(uname -m)" in
  x86_64|amd64) ASSET_ARCH=x64 ;;
  aarch64|arm64) ASSET_ARCH=arm64 ;;
  *) echo "Lumi does not have a bundled runtime for $(uname -m)." >&2; exit 1 ;;
esac

for command_name in curl tar awk sed cut head; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Lumi needs the standard '$command_name' command to download and unpack its private runtimes." >&2
    exit 1
  fi
done

node_version=$(cat "$NODE_STATE" 2>/dev/null || true)
latest_node=$(curl -fsSL --max-time 15 https://nodejs.org/dist/index.tab 2>/dev/null \
  | awk -F '\t' 'NR > 1 && $10 != "-" { sub(/^v/, "", $1); print $1; exit }' || true)
if [ -n "$latest_node" ]; then node_version=$latest_node; fi
if [ -z "$node_version" ]; then
  echo 'Could not find a Node.js 22 or newer runtime and could not reach nodejs.org.' >&2
  exit 1
fi
node_major=${node_version%%.*}
if [ "$node_major" -lt 22 ]; then
  echo "Node.js 22 or newer is required; nodejs.org reported $node_version." >&2
  exit 1
fi

NODE_HOME="$RUNTIME_HOME/node-v$node_version"
NODE_BIN="$NODE_HOME/bin/node"
if [ ! -x "$NODE_BIN" ]; then
  temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/lumi-runtime.XXXXXX")
  trap 'rm -rf "$temp_dir"' EXIT HUP INT TERM
  node_archive="node-v$node_version-linux-$ASSET_ARCH.tar.xz"
  echo "Downloading Node.js $node_version for Linux $ASSET_ARCH..."
  curl -fL --retry 2 "https://nodejs.org/dist/v$node_version/$node_archive" -o "$temp_dir/node.tar.xz"
  mkdir "$temp_dir/node"
  tar -xJf "$temp_dir/node.tar.xz" --strip-components=1 -C "$temp_dir/node"
  rm -rf "$NODE_HOME"
  mv "$temp_dir/node" "$NODE_HOME"
  rm -f "$temp_dir/node.tar.xz"
  trap - EXIT HUP INT TERM
  rm -rf "$temp_dir"
fi
printf '%s\n' "$node_version" > "$NODE_STATE"

export PATH="$NODE_HOME/bin:$PATH"
export LUMI_DART_EXECUTABLE="$RUNTIME_HOME/dart-sdk/bin/dart"
export LUMI_RUNTIME_HOME="$RUNTIME_HOME"
current_dart=''
if [ -x "$LUMI_DART_EXECUTABLE" ]; then
  current_dart=$("$LUMI_DART_EXECUTABLE" --version 2>&1 | sed -n 's/.*version: \([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p')
fi
latest_dart=$(curl -fsSL --max-time 15 https://storage.googleapis.com/dart-archive/channels/stable/release/latest/VERSION 2>/dev/null \
  | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([0-9][0-9.]*\)".*/\1/p' || true)
if [ -z "$latest_dart" ]; then latest_dart=${current_dart:-$(cat "$DART_STATE" 2>/dev/null || true)}; fi
if [ -z "$latest_dart" ]; then
  echo 'Could not find a Dart 3.12 or newer runtime and could not reach dart.dev.' >&2
  exit 1
fi
dart_major=${latest_dart%%.*}
dart_minor=$(printf '%s\n' "$latest_dart" | cut -d. -f2)
if [ "$dart_major" -lt 3 ] || { [ "$dart_major" -eq 3 ] && [ "$dart_minor" -lt 12 ]; }; then
  echo "Dart 3.12 or newer is required; dart.dev reported $latest_dart." >&2
  exit 1
fi
if [ "$current_dart" != "$latest_dart" ]; then
  temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/lumi-dart.XXXXXX")
  trap 'rm -rf "$temp_dir"' EXIT HUP INT TERM
  dart_archive="dartsdk-linux-$ASSET_ARCH-release.zip"
  echo "Downloading Dart $latest_dart for Linux $ASSET_ARCH..."
  curl -fL --retry 2 "https://storage.googleapis.com/dart-archive/channels/stable/release/$latest_dart/sdk/$dart_archive" -o "$temp_dir/dart.zip"
  npm exec --yes --package=extract-zip -- extract-zip "$temp_dir/dart.zip" "$temp_dir"
  rm -rf "$RUNTIME_HOME/dart-sdk"
  mv "$temp_dir/dart-sdk" "$RUNTIME_HOME/dart-sdk"
  printf '%s\n' "$latest_dart" > "$DART_STATE"
  trap - EXIT HUP INT TERM
  rm -rf "$temp_dir"
fi
printf '%s\n' "$latest_dart" > "$DART_STATE"

WEB_ROOT="$PROJECT_ROOT/lumi-web/dist"
mkdir -p "$PROJECT_ROOT/lumi-web"
web_revision=$(curl -fsSL --max-time 15 https://api.github.com/repos/Dishaan-JK/Lumi_Learning_App/commits/React_v 2>/dev/null \
  | sed -n 's/.*"sha"[[:space:]]*:[[:space:]]*"\([a-f0-9][a-f0-9]*\)".*/\1/p' | head -n 1 || true)
installed_web_revision=$(cat "$WEB_REVISION_FILE" 2>/dev/null || true)
bundle_missing=0
if [ ! -f "$WEB_ROOT/index.html" ]; then bundle_missing=1; fi
if [ "$bundle_missing" -eq 1 ] || { [ -n "$web_revision" ] && [ -n "$installed_web_revision" ] && [ "$web_revision" != "$installed_web_revision" ]; }; then
  temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/lumi-web.XXXXXX")
  trap 'rm -rf "$temp_dir"' EXIT HUP INT TERM
  echo 'Downloading the React web app...'
  curl -fL --retry 2 "$ARCHIVE_URL" -o "$temp_dir/source.tar.gz"
  mkdir "$temp_dir/web"
  tar -xzf "$temp_dir/source.tar.gz" --strip-components=1 --wildcards -C "$temp_dir/web" '*/dist/*'
  test -f "$temp_dir/web/dist/index.html"
  rm -rf "$PROJECT_ROOT/lumi-web"
  mv "$temp_dir/web" "$PROJECT_ROOT/lumi-web"
  if [ -n "$web_revision" ]; then printf '%s\n' "$web_revision" > "$WEB_REVISION_FILE"; fi
  trap - EXIT HUP INT TERM
  rm -rf "$temp_dir"
elif [ -n "$web_revision" ] && [ -z "$installed_web_revision" ]; then
  # The first-run bundle came from the branch ZIP or the documented curl command.
  printf '%s\n' "$web_revision" > "$WEB_REVISION_FILE"
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

if [ ! -e "$MARKER" ]; then export LUMI_PROMPT_OPEN=1; fi
export LUMI_SETUP_MARKER="$MARKER"
export LUMI_FRONTEND_PORT=${LUMI_FRONTEND_PORT:-5173}
export LUMI_WEB_DIR="$WEB_ROOT"
exec "$NODE_BIN" "$PROJECT_ROOT/scripts/launch-lumi.mjs" "$@"
