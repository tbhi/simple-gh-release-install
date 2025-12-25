#!/bin/bash
set -e -o pipefail

case "$(uname -m)" in
  x86_64)
    REGEX="linux.*amd64|linux64|linux_x86_64|ubuntu-latest-minimal|_x64_|amd64\.deb"
    ;;
  armv7l)
    REGEX="linux_arm|linux_armv7"
    ;;
esac
INSTALLED=$HOME/.simple-gh-release-install

die() {
  echo "$@" 1>&2
  exit 1
}

xinstall() {
  local latest_url="$1"
  local repo=$2
  case "$latest_url" in
    *.tar.gz | *.tgz)
      local tmp="$(mktemp -d)"
      tar xz --no-same-owner -C "$tmp"
      find "$tmp" -type f -perm /u+x -exec mv {} . \;
      rm -rf "$tmp"
      ;;
    *.bz2)
      bunzip2 > "$(basename $repo)"
      chmod +x "$(basename $repo)"
      ;;
    *.zip)
      local tmp="$(mktemp -d)"
      cat > "$tmp"/zip
      unzip "$tmp"/zip -d "$tmp/out"
      find "$tmp/out" -type f -perm /u+x -exec mv {} . \;
      rm -rf "$tmp"
      ;;
    *.deb)
      local tmp="$(mktemp -d)"
      cat > "$tmp/deb"
      ar -vx --output "$tmp" "$tmp/deb"
      tar xf "$tmp"/data.tar.xz -C "$tmp"
      find "$tmp" -type f -perm /u+x -exec mv {} . \;
      rm -rf "$tmp"
      ;;
    *.rpm)
      local tmp="$(mktemp -d)"
      rpm2archive -n | tar x --no-same-owner -C "$tmp"
      find "$tmp" -type f -perm /u+x -exec mv {} . \;
      rm -rf "$tmp"
      ;;
     *)
      local name="$(basename "$repo")"
      cat > "$name"
      chmod +x "$name"
      ;;
  esac
}

repo_install() {
  local repo=$1
  local api_url
  case "$repo" in
    codeberg/*)
      repo="${repo#*/}"
      api_url="https://codeberg.org/api/v1/repos/$repo/releases/latest"
      ;;
    *)
      [[ "$repo" ==https://github.com/tbhi/simple-gh-release-install/tree/master */*/* ]] && repo="${repo#*/}"
      api_url="https://api.github.com/repos/$repo/releases/latest"
      ;;
  esac
  local latest_url=$(wget -qO - "$api_url" | jq -r '.assets[].browser_download_url' | grep -Em1 "$REGEX")
  [ -z "$latest_url" ] && die "empty latest url - hit github quota?"
  if ! [ -f "$INSTALLED" ] || ! grep -q "$latest_url" "$INSTALLED"; then
    wget -qO - "$latest_url" | xinstall "$latest_url" "$repo"
    echo "installed $latest_url"
    echo "$latest_url" >> "$INSTALLED"
  fi
}

case "$1" in
  all)
    [ -f "$INSTALLED" ] || die "no previously installed"
    for repo in $(sed -E 's#^https?://([^.]+)\.[^/]+/([^/]+/[^/]+)/.*$#\1/\2#' "$INSTALLED" | sort -u); do
      echo checking $repo
      repo_install $repo
    done
    ;;
  "")
    die "Usage: $0 all|github_project/name"
    ;;
  *)
    repo_install "$1"
    ;;  
esac
