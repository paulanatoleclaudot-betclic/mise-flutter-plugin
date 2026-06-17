#!/usr/bin/env bash
#
# Install an official stable release from its prebuilt archive.

set -euo pipefail
RELEASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/utils.bash
source "${RELEASE_DIR}/utils.bash"

# Extract a Flutter archive (top-level `flutter/` dir) directly into $dest.
extract_archive() {
  local file="$1" dest="$2"
  case "$file" in
  *.zip)
    local tmp
    tmp="$(mktemp -d)"
    unzip -q "$file" -d "$tmp"
    (shopt -s dotglob && mv "$tmp"/flutter/* "$dest"/)
    rm -rf "$tmp"
    ;;
  *.tar.xz | *.tar.gz | *.tgz)
    tar xf "$file" -C "$dest" --strip-components=1
    ;;
  *)
    die "unsupported Flutter archive format for '$(basename "$file")'; expected .zip or .tar.xz"
    ;;
  esac
}

install_release() {
  local version="$1" install_path="$2"
  ensure_jq

  local releases_json base_url arch query archive sha256
  releases_json="$(fetch_releases_json)"
  base_url="$(printf '%s' "$releases_json" | "$JQ" -r '.base_url')"
  arch="$(dart_sdk_arch)"

  # macOS publishes both x64 and arm64 archives (explicit dart_sdk_arch); Linux
  # omits the field on its x64-only archives, so a missing field means x64.
  # shellcheck disable=SC2016  # $v and $a are jq variables, not shell ones
  query='[ .releases[] | select(.version == $v) | select((.dart_sdk_arch // "x64") == $a) ][0]'
  archive="$(printf '%s' "$releases_json" | "$JQ" -r --arg v "$version" --arg a "$arch" "${query} | .archive // empty")"
  sha256="$(printf '%s' "$releases_json" | "$JQ" -r --arg v "$version" --arg a "$arch" "${query} | .sha256 // empty")"

  [ -n "$archive" ] ||
    die "no Flutter release '${version}' found for $(os_name)/${arch}; for a custom build use 'flutter@ref:<commit>' or set the 'remote' option"

  local url="${base_url}/${archive}"
  local filename="${archive##*/}"
  local download_dir="${ASDF_DOWNLOAD_PATH:-$install_path}"
  local tarball="${download_dir}/${filename}"
  mkdir -p "$download_dir"

  msg "downloading ${filename}"
  curl -fL --retry 3 -o "$tarball" "$url"

  # Every official stable archive ships a sha256; a missing one means something
  # is wrong upstream, so fail closed rather than install unverified bits.
  [ -n "$sha256" ] || die "missing sha256 for Flutter archive '${archive}'"
  verify_sha256 "$tarball" "$sha256"

  msg "extracting ${filename}"
  rm -rf "$install_path"
  mkdir -p "$install_path"
  extract_archive "$tarball" "$install_path"
  rm -f "$tarball"

  [ -x "${install_path}/bin/$(flutter_bin_name)" ] ||
    die "unexpected archive layout: no bin/$(flutter_bin_name) under ${install_path}"
}
