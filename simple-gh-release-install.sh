#!/bin/bash
set -e -o pipefail

ARCH="linux_amd64|linux64"
INSTALLED=$HOME/.simple-gh-release-install

die() {
  echo "$@" 1>&2
  exit 1
}

xinstall() {
  local latest_url="$1"
  local repo=$2
  case "$latest_url" in
    *.tar.gz)
      tar xz --no-same-owner --strip-components 1 --wildcards \*$(basename $repo)
      ;;
    *.bz2)
      bunzip2 > "$(basename $repo)"
      chmod +x "$(basename $repo)"
      ;;
  esac    
}

ghinstall() {
  local repo=$1
  local latest_url="$(wget -qO - https://api.github.com/repos/$repo/releases/latest | egrep "browser_download_url.*($ARCH)" | sed -n '1s/.*"\([^"]*\)"$/\1/p')"
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
