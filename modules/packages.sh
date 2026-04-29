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
    ssh
    fail2ban
    debsums
    apt-transport-https
    ca-certificates
    gnupg
    lsb-release
)

main() {
    whiptail --title "Install Packages" \
        --yesno \
"Folgende Pakete werden installiert:

  curl
  wget
  ufw
  ssh
  fail2ban
  debsums
  apt-transport-https
  ca-certificates
  gnupg
  lsb-release

Fortfahren?" 22 55 || exit 0

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
