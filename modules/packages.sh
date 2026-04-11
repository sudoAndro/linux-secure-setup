#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_root
require_whiptail

PACKAGES=(
    curl wget ufw fail2ban debsums
    apt-transport-https ca-certificates gnupg lsb-release
)

main() {
    if ! yes_no_box "Install Packages" \
        "Folgende Pakete werden installiert:\n\ncurl, wget, ufw, fail2ban, debsums,\napt-transport-https, ca-certificates,\ngnupg, lsb-release\n\nFortfahren?"; then
        exit 0
    fi

    clear
    echo "Pakete werden installiert..."
    echo

    apt update
    apt install -y "${PACKAGES[@]}"

    echo
    echo "Pakete erfolgreich installiert."
    sleep 1

    msg_box "Install Packages" "Alle Pakete wurden erfolgreich installiert."
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

    msg_box "Install Packages" "Die benoetigten Pakete wurden erfolgreich installiert."
}

main "$@"#!/usr/bin/env bash
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

    info_box "Install Packages" "Die benötigten Pakete wurden erfolgreich installiert."
}

main "$@"
