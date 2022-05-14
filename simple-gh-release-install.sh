#!/bin/bash
set -e -o pipefail

REPO=$1
ARCH="linux_amd64|linux64"
INSTALLED=$HOME/.simple-gh-release-install

latest_url="$(wget -qO - https://api.github.com/repos/$REPO/releases/latest | egrep "browser_download_url.*($ARCH)" | sed -n '1s/.*"\([^"]*\)"$/\1/p')"

xinstall() {
  case "$1" in
    *.tar.gz)
      tar xz --no-same-owner --strip-components 1 --wildcards \*$(basename $REPO)
      ;;
    *.bz2)
      bunzip2 > "$(basename $REPO)"
      chmod +x "$(basename $REPO)"
      ;;
  esac    
}

[ -z "$latest_url" ] && exit 1

if ! grep -q "$latest_url" "$INSTALLED"; then
  wget -qO - "$latest_url" | xinstall "$latest_url"
  echo "$latest_url" >> "$INSTALLED"
fi
