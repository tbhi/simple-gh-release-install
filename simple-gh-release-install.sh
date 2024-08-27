#!/bin/bash
set -e -o pipefail

case "$(uname -m)" in
  x86_64)
    REGEX="linux.*amd64|linux64|linux_x86_64|ubuntu-latest-minimal|_x64_|centos-9-stream\.rpm"
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
  esac
}

ghinstall() {
  local repo=$1
  local latest_url="$(wget -qO - https://api.github.com/repos/$repo/releases/latest | grep -Ei "browser_download_url.*($REGEX)" | sed -n '1s/.*"\([^"]*\)"$/\1/p')"
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
    for repo in $(sed 's|.*github.com\/\([^/]*\/[^/]*\)\/.*|\1|' "$INSTALLED" | sort -u); do
      echo checking $repo
      ghinstall $repo
    done
    ;;
  "")
    die "Usage: $0 all|github_project/name"
    ;;
  *)
    ghinstall "$1"
    ;;
esac
