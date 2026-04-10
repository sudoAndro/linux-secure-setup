#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

ensure_ui_environment
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
        "Folgende Pakete werden installiert:\n\ncurl\nwget\nufw\nfail2ban\ndebsums\napt-transport-https\nca-certificates\ngnupg\nlsb-release\n\nFortfahren?"; then
        exit 0
    fi

    clear
    echo "Updating package lists..."
    apt update

    echo
    echo "Installing required packages..."
    apt install -y "${PACKAGES[@]}"

    echo
    echo "Packages successfully installed."

    pause_enter
}

main "$@"#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
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

    if ! yes_no_box "Install Packages" "Folgende Pakete werden installiert:\n\ncurl\nwget\nufw\nfail2ban\ndebsums\napt-transport-https\nca-certificates\ngnupg\nlsb-release\n\nFortfahren?"; then
        exit 0
    fi

    clear
    echo "Updating package lists..."
    apt update

    echo
    echo "Installing required packages..."
    apt install -y "${PACKAGES[@]}"

    echo
    echo "Packages successfully installed."

    read -p "Press ENTER to return to menu..."
}

main "$@"
