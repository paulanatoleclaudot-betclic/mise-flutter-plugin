#!/usr/bin/env bash
#
# Shared helpers for the mise-flutter-plugin scripts.
#
# This plugin extends the stock Flutter behaviour (install an official stable
# release from the prebuilt archive, verified against its published sha256)
# with custom builds installed straight from a git ref/commit, optionally from
# a fork or an internal mirror via the `remote` tool option.

set -euo pipefail

# Directory containing this file, used to cache a bundled jq if the host has none.
UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Override-able base URL for the Flutter release storage (e.g. an internal
# Google Storage mirror). Structure must match storage.googleapis.com.
: "${FLUTTER_STORAGE_BASE_URL:=https://storage.googleapis.com}"

# Default upstream repository. Point at a fork or internal mirror with the
# `remote` (or its alias `url`) tool option.
FLUTTER_DEFAULT_REMOTE="https://github.com/flutter/flutter.git"

msg() { printf 'mise-flutter: %s\n' "$*" >&2; }
die() {
  printf 'mise-flutter: error: %s\n' "$*" >&2
  exit 1
}

# ----------------------------------------------------------------------------
# Platform detection
# ----------------------------------------------------------------------------

os_name() {
  case "$(uname -s)" in
  Darwin) echo macos ;;
  Linux) echo linux ;;
  MINGW* | MSYS* | CYGWIN*) echo windows ;;
  *) echo linux ;;
  esac
}

# Flutter's `dart_sdk_arch` value for the current machine.
dart_sdk_arch() {
  case "$(uname -m)" in
  arm64 | aarch64) echo arm64 ;;
  *) echo x64 ;;
  esac
}

flutter_bin_name() {
  if [ "$(os_name)" == "windows" ]; then
    echo flutter.bat
  else
    echo flutter
  fi
}

# ----------------------------------------------------------------------------
# Tool options (passed by mise as MISE_TOOL_OPTS__<KEY>)
# ----------------------------------------------------------------------------

# The configured custom remote, or the official upstream when unset.
flutter_remote() {
  printf '%s' "${MISE_TOOL_OPTS__REMOTE:-${MISE_TOOL_OPTS__URL:-$FLUTTER_DEFAULT_REMOTE}}"
}

# True when a fork / internal mirror was requested. A custom remote forces the
# git install path even for a plain version request.
is_custom_remote() {
  [ -n "${MISE_TOOL_OPTS__REMOTE:-}" ] || [ -n "${MISE_TOOL_OPTS__URL:-}" ]
}

# ----------------------------------------------------------------------------
# jq bootstrap (prefer the system binary, otherwise cache one next to this file)
# ----------------------------------------------------------------------------

jq_asset() {
  case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) echo jq-linux-amd64 ;;
  Linux-aarch64 | Linux-arm64) echo jq-linux-arm64 ;;
  Darwin-x86_64) echo jq-macos-amd64 ;;
  Darwin-arm64) echo jq-macos-arm64 ;;
  *) echo "" ;;
  esac
}

ensure_jq() {
  if [ -n "${JQ:-}" ] && [ -x "${JQ:-}" ]; then return; fi
  if command -v jq >/dev/null 2>&1; then
    JQ="$(command -v jq)"
    export JQ
    return
  fi
  local cached="${UTILS_DIR}/.jq"
  if [ ! -x "$cached" ]; then
    local asset
    asset="$(jq_asset)"
    [ -n "$asset" ] || die "jq is required but not installed, and no prebuilt jq is available for $(uname -s)-$(uname -m); please install jq"
    msg "downloading jq ($asset)"
    curl -fsSL "https://github.com/jqlang/jq/releases/latest/download/${asset}" -o "$cached"
    chmod +x "$cached"
  fi
  JQ="$cached"
  export JQ
}

# ----------------------------------------------------------------------------
# Releases metadata
# ----------------------------------------------------------------------------

releases_url() {
  printf '%s/flutter_infra_release/releases/releases_%s.json' "$FLUTTER_STORAGE_BASE_URL" "$(os_name)"
}

fetch_releases_json() {
  curl -fsSL "$(releases_url)"
}

# Print every stable version, deduplicated, oldest-first (the JSON is
# newest-first and macOS lists each version once per arch).
print_stable_versions() {
  ensure_jq
  fetch_releases_json |
    "$JQ" -r '.releases[] | select(.channel == "stable") | .version' |
    awk '!seen[$0]++' |
    awk '{ a[NR] = $0 } END { for (i = NR; i >= 1; i--) printf "%s ", a[i] }'
}

latest_stable_version() {
  ensure_jq
  # shellcheck disable=SC2016  # $h is a jq variable, not a shell one
  fetch_releases_json |
    "$JQ" -r '.current_release.stable as $h | .releases[] | select(.hash == $h) | .version' |
    head -n 1
}

# ----------------------------------------------------------------------------
# Checksums
# ----------------------------------------------------------------------------

verify_sha256() {
  local file="$1" expected="$2" actual
  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$file" | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  else
    die "no sha256 tool found (need sha256sum or shasum)"
  fi
  [ "$actual" == "$expected" ] ||
    die "checksum mismatch for $(basename "$file"): expected ${expected}, got ${actual}"
  msg "sha256 verified"
}
