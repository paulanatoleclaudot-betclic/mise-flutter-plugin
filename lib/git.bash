#!/usr/bin/env bash
#
# Install a custom Flutter build directly from a git ref (commit / branch /
# tag), optionally from a fork or an internal mirror.

set -euo pipefail
GIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/utils.bash
source "${GIT_DIR}/utils.bash"

# Clone $remote into $install_path and check out $ref. install_env variables
# (e.g. HTTPS_PROXY for an internal mirror) are exported by mise, so the git
# subprocess inherits them automatically.
clone_ref() {
  local ref="$1" install_path="$2" remote="$3"

  rm -rf "$install_path"
  mkdir -p "$install_path"
  msg "cloning ${remote} @ ${ref}"

  # Fast path: shallow-fetch the exact ref. Works for branches, tags, and
  # commit SHAs on servers that serve them (GitHub does).
  git -C "$install_path" init -q
  git -C "$install_path" remote add origin "$remote"
  if git -C "$install_path" fetch -q --depth 1 origin "$ref" 2>/dev/null; then
    git -C "$install_path" -c advice.detachedHead=false checkout -q FETCH_HEAD
  else
    # Fallback: a full clone can reach any ref the server won't serve directly.
    msg "shallow fetch of '${ref}' failed; falling back to a full clone"
    rm -rf "$install_path"
    git clone -q "$remote" "$install_path"
    git -C "$install_path" -c advice.detachedHead=false checkout -q "$ref" ||
      die "ref '${ref}' not found in ${remote}"
  fi
}

install_from_git() {
  local ref="$1" install_path="$2"
  clone_ref "$ref" "$install_path" "$(flutter_remote)"
}
