#!/usr/bin/env bash
set -euo pipefail

# Prepare the host for a packaged Linux executable. This intentionally updates only
# the runtime libraries/tools the app needs (never the entire system, except
# Arch-family distros where partial upgrades are unsupported).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIN_GLIBC="2.35"

die() { printf 'Lumi setup: %s\n' "$*" >&2; exit 1; }
say() { printf 'Lumi setup: %s\n' "$*"; }

command -v getconf >/dev/null || die "getconf is required to inspect the system C library."
command -v ldd >/dev/null || die "ldd is required to inspect executable dependencies."

arch="$(uname -m)"
case "$arch" in
  x86_64|amd64) asset_arch=x64 ;;
  aarch64|arm64) asset_arch=arm64 ;;
  *) die "Lumi's Linux builds target x86_64 and arm64; this machine reports $arch." ;;
esac
APP="${LUMI_EXECUTABLE:-$ROOT/release/lumi-linux-$asset_arch}"
[[ -x "$APP" ]] || die "Executable not found: $APP (set LUMI_EXECUTABLE to its path)."

libc_line="$(getconf GNU_LIBC_VERSION 2>/dev/null || true)"
current_glibc="${libc_line#glibc }"
if [[ -z "$current_glibc" ]]; then
  die "This executable needs glibc $MIN_GLIBC or newer. Alpine/musl systems are not compatible with this build."
fi

version_ok() { [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" == "$2" ]]; }
as_root() {
  if [[ "$(id -u)" == 0 ]]; then "$@"
  elif command -v sudo >/dev/null; then sudo "$@"
  else die "Package updates require root or sudo."
  fi
}
family_of() {
  local distro="${ID:-unknown}" like="${ID_LIKE:-}"
  case "$distro" in
    alpine) printf alpine ;;
    ubuntu|linuxmint|pop|debian|elementary|zorin|kali) printf debian ;;
    fedora|rhel|centos|rocky|almalinux) printf fedora ;;
    arch|manjaro|endeavouros|omarchy) printf arch ;;
    opensuse*|suse) printf suse ;;
    void) printf void ;;
    gentoo) printf gentoo ;;
    *)
      case "$like" in
        *alpine*) printf alpine ;;
        *debian*|*ubuntu*) printf debian ;;
        *fedora*|*rhel*) printf fedora ;;
        *arch*) printf arch ;;
        *suse*) printf suse ;;
        *void*) printf void ;;
        *gentoo*) printf gentoo ;;
        *) printf unknown ;;
      esac
      ;;
  esac
}

if version_ok "$current_glibc" "$MIN_GLIBC"; then
  say "glibc $current_glibc satisfies the executable requirement ($MIN_GLIBC+)."
else
  say "glibc $current_glibc is older than the required $MIN_GLIBC; attempting a targeted distro update."
  [[ -r /etc/os-release ]] || die "Cannot identify this distribution (missing /etc/os-release)."
  # shellcheck disable=SC1091
  . /etc/os-release
  family="$(family_of)"
  case "$family" in
    alpine) die "Alpine uses musl; this glibc executable cannot run there. Use a musl build or a supported glibc distro." ;;
    debian)
      command -v apt-get >/dev/null || die "apt-get is required to update glibc on this distro."
      as_root apt-get update
      as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --only-upgrade libc6
      ;;
    fedora)
      if command -v dnf >/dev/null; then as_root dnf -y upgrade glibc
      elif command -v yum >/dev/null; then as_root yum -y update glibc
      else die "dnf or yum is required to update glibc on this distro."; fi
      ;;
    arch)
      command -v pacman >/dev/null || die "pacman is required to update glibc."
      say "Arch-family systems require a full synchronized upgrade; updating the system with pacman -Syu."
      as_root pacman -Syu --noconfirm
      ;;
    suse)
      command -v zypper >/dev/null || die "zypper is required to update glibc."
      as_root zypper --non-interactive update glibc
      ;;
    void)
      command -v xbps-install >/dev/null || die "xbps-install is required to update glibc."
      as_root xbps-install -Syu glibc
      ;;
    gentoo)
      command -v emerge >/dev/null || die "emerge is required to update glibc."
      as_root emerge --ask=n sys-libs/glibc
      ;;
    *) die "Automatic glibc updates are not configured for '${PRETTY_NAME:-${ID:-unknown}}'. Update glibc to $MIN_GLIBC+ using your distro's supported upgrade path." ;;
  esac

  current_glibc="$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{print $2}')"
  version_ok "$current_glibc" "$MIN_GLIBC" || die "The distro repositories still provide glibc $current_glibc; Lumi requires $MIN_GLIBC+. Upgrade to a newer distro release."
  say "glibc is now $current_glibc."
fi

if ! command -v xdg-open >/dev/null; then
  [[ -r /etc/os-release ]] || die "xdg-open is missing and the distro could not be identified."
  # shellcheck disable=SC1091
  . /etc/os-release
  family="$(family_of)"
  case "$family" in
    debian) as_root apt-get update; as_root apt-get install -y xdg-utils ;;
    fedora) if command -v dnf >/dev/null; then as_root dnf -y install xdg-utils; else as_root yum -y install xdg-utils; fi ;;
    arch) as_root pacman -Syu --noconfirm xdg-utils ;;
    suse) as_root zypper --non-interactive install xdg-utils ;;
    void) as_root xbps-install -S xdg-utils ;;
    gentoo) as_root emerge --ask=n x11-misc/xdg-utils ;;
    *) say "xdg-open is unavailable; Lumi will print its local URL for you to open manually." ;;
  esac
fi

missing="$(ldd "$APP" 2>&1 | grep 'not found' || true)"
[[ -z "$missing" ]] || die "The executable still has missing shared libraries:\n$missing"
say "Runtime check passed. Launch Lumi with: $APP"
