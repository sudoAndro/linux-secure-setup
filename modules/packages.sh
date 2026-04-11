#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_root
require_whiptail

PACKAGES=(
    curl
    wget
    ufw
    fail2ban
    debsums
    apt-transport-https
    ca-certificates
    gnupg
    lsb-release
)

main() {
    if ! yes_no_box "Install Packages" \
"Folgende Pakete werden installiert:

  curl
  wget
  ufw
  fail2ban
  debsums
  apt-transport-https
  ca-certificates
  gnupg
  lsb-release

Fortfahren?"; then
        exit 0
    fi

    clear
    echo "Pakete werden installiert..."
    echo

    DEBIAN_FRONTEND=noninteractive apt update
    DEBIAN_FRONTEND=noninteractive apt install -y "${PACKAGES[@]}"

    echo
    echo "Pakete erfolgreich installiert."
    sleep 1

    msg_box "Install Packages" "Alle Pakete wurden erfolgreich installiert."
}

main "$@"
