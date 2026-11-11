#!/usr/bin/env sh
set -eu

REPOSITORY="${LUMI_RELEASE_REPOSITORY:-Dishaan-JK/Lumi_Learning_App}"
INSTALL_DIR="${LUMI_INSTALL_DIR:-$HOME/.local/bin}"
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
  Linux) PLATFORM=linux ;;
  Darwin) PLATFORM=macos ;;
  *) echo "Lumi installer: unsupported operating system: $OS" >&2; exit 1 ;;
esac
case "$ARCH" in
  x86_64|amd64) ARCH=x64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) echo "Lumi installer: unsupported CPU architecture: $ARCH" >&2; exit 1 ;;
esac
if [ "$PLATFORM" = linux ] && [ -f /etc/alpine-release ]; then
  echo "Lumi installer: Alpine/musl Linux is not supported by the current release." >&2
  exit 1
fi

ASSET="lumi-$PLATFORM-$ARCH"
DEST="$INSTALL_DIR/lumi"
mkdir -p "$INSTALL_DIR"
printf 'Downloading Lumi for %s %s from %s...\n' "$PLATFORM" "$ARCH" "$REPOSITORY"
curl --fail --location --silent --show-error \
  "https://github.com/$REPOSITORY/releases/latest/download/$ASSET" \
  --output "$DEST"
chmod 700 "$DEST"
printf 'Installed at %s\nLaunching Lumi...\n' "$DEST"
exec "$DEST"
