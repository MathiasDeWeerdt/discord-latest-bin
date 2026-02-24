#!/usr/bin/env bash
# discord-latest-bin — AUR package update helper
# Detects new Discord releases, updates the PKGBUILD and .SRCINFO,
# and pushes the change to AUR.

set -euo pipefail
IFS=$'\n\t'

SCRIPT_NAME="$(basename "$0")"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISCORD_CDN="https://discord.com/api/download?platform=linux"
PKGBUILD_FILE="${REPO_DIR}/PKGBUILD"
WORK_DIR=""

if [[ -t 1 ]]; then
  RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
  BLUE='\033[0;34m' BOLD='\033[1m' RESET='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' BOLD='' RESET=''
fi

info()    { printf "  ${BLUE}::${RESET} %s\n" "$*"; }
success() { printf "  ${GREEN}ok${RESET}  %s\n" "$*"; }
warn()    { printf "  ${YELLOW}!!${RESET}  %s\n" "$*"; }
error()   { printf "  ${RED}!!${RESET}  %s\n" "$*" >&2; }
die()     { error "$*"; exit 1; }

header() {
  local title="$*"
  printf "\n${BOLD}%s${RESET}\n" "${title}"
  printf '%*s\n' "${#title}" '' | tr ' ' '-'
}

usage() {
  printf "\n${BOLD}Usage:${RESET} %s [OPTIONS]\n\n" "${SCRIPT_NAME}"
  printf "  Checks for a new Discord release, updates the PKGBUILD and .SRCINFO,\n"
  printf "  and pushes the change to AUR.\n\n"
  printf "${BOLD}Options:${RESET}\n"
  printf "  -f, --force      Update even if already on the latest version\n"
  printf "  -d, --dry-run    Show what would change without writing anything\n"
  printf "  -h, --help       Show this help and exit\n\n"
}

OPT_FORCE=false
OPT_DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force)    OPT_FORCE=true   ;;
    -d|--dry-run)  OPT_DRY_RUN=true ;;
    -h|--help)     usage; exit 0    ;;
    *) die "Unknown option: '$1' — run '${SCRIPT_NAME} --help' for usage." ;;
  esac
  shift
done

cleanup() {
  [[ -n "${WORK_DIR}" && -d "${WORK_DIR}" ]] && rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

check_deps() {
  header "Dependencies"
  local -a missing=()

  for cmd in wget ar makepkg git sha256sum sed; do
    if command -v "${cmd}" &>/dev/null; then
      success "${cmd}"
    else
      error "${cmd} not found"
      missing+=("${cmd}")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    warn "Missing: ${missing[*]}"
    exit 1
  fi
}

resolve_remote_version() {
  header "Checking latest Discord version"

  # Spider the CDN redirect to read the version from the Location header
  # without downloading the full package.
  local redirect_url
  redirect_url=$(
    wget --quiet --server-response --spider "${DISCORD_CDN}" 2>&1 \
      | grep -i 'Location:' | tail -1 | awk '{print $2}' | tr -d '[:space:]'
  )

  REMOTE_VERSION=$(printf '%s' "${redirect_url}" | grep -oP '\d+\.\d+\.\d+' | head -1 || true)
  [[ -n "${REMOTE_VERSION}" ]] || die "Could not parse version from: '${redirect_url}'"

  success "latest: ${REMOTE_VERSION}"
}

check_version() {
  CURRENT_VERSION=$(grep '^pkgver=' "${PKGBUILD_FILE}" | cut -d= -f2)

  info "current: ${CURRENT_VERSION}"
  info "latest:  ${REMOTE_VERSION}"

  if [[ "${OPT_FORCE}" == false && "${CURRENT_VERSION}" == "${REMOTE_VERSION}" ]]; then
    success "already up-to-date"
    exit 0
  fi

  [[ "${OPT_FORCE}" == true && "${CURRENT_VERSION}" == "${REMOTE_VERSION}" ]] && \
    warn "--force set, updating anyway"
}

download_deb() {
  header "Downloading Discord ${REMOTE_VERSION}"

  WORK_DIR=$(mktemp -d /tmp/discord-latest-bin.XXXXXX)
  DEB_FILE="${WORK_DIR}/discord-${REMOTE_VERSION}.deb"

  local versioned_url="https://stable.dl2.discordapp.net/apps/linux/${REMOTE_VERSION}/discord-${REMOTE_VERSION}.deb"
  wget --show-progress --quiet "${versioned_url}" -O "${DEB_FILE}"
  success "download complete"
}

compute_checksum() {
  header "Computing checksum"
  SHA256=$(sha256sum "${DEB_FILE}" | awk '{print $1}')
  success "${SHA256}"
}

update_pkgbuild() {
  header "Updating PKGBUILD"
  sed -i "s/^pkgver=.*/pkgver=${REMOTE_VERSION}/" "${PKGBUILD_FILE}"
  sed -i "s/^pkgrel=.*/pkgrel=1/" "${PKGBUILD_FILE}"
  sed -i "s/^sha256sums=.*/sha256sums=('${SHA256}')/" "${PKGBUILD_FILE}"
  success "pkgver=${REMOTE_VERSION}, pkgrel=1"
  success "sha256 updated"
}

update_srcinfo() {
  header "Regenerating .SRCINFO"
  cd "${REPO_DIR}"
  makepkg --printsrcinfo > .SRCINFO
  success ".SRCINFO updated"
}

push_to_aur() {
  header "Pushing to AUR"
  cd "${REPO_DIR}"

  if ! git remote get-url aur &>/dev/null; then
    warn "No 'aur' remote configured. Add it with:"
    info "  git remote add aur ssh://aur@aur.archlinux.org/discord-latest-bin.git"
    return
  fi

  git add PKGBUILD .SRCINFO
  git commit -m "update to ${REMOTE_VERSION}"
  git push aur main:master
  success "pushed to AUR"
}

main() {
  check_deps
  resolve_remote_version
  check_version

  if [[ "${OPT_DRY_RUN}" == true ]]; then
    download_deb
    compute_checksum
    warn "dry run — no changes written"
    info "would update: ${CURRENT_VERSION} -> ${REMOTE_VERSION}"
    info "sha256: ${SHA256}"
    exit 0
  fi

  download_deb
  compute_checksum
  update_pkgbuild
  update_srcinfo
  push_to_aur
}

main "$@"
