#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_root
require_whiptail

main() {
    whiptail --title "Cleanup" \
        --yesno \
"Unnoetige Pakete entfernen?

Folgende Pakete werden entfernt:
  - telnet
  - ftp
  - rsh-client

Danach werden offene Ports angezeigt.

Fortfahren?" 16 55 || exit 0

    clear
    echo "Cleanup wird ausgefuehrt..."
    echo

    DEBIAN_FRONTEND=noninteractive apt purge -y telnet ftp rsh-client || true
    apt autoremove -y
    sleep 1

    local tmp_file
    tmp_file=$(mktemp)
    {
        echo "===== Offene Ports ====="
        echo
        ss -tulpn
    } > "$tmp_file" 2>&1
    textbox_file "Offene Ports" "$tmp_file"
    rm -f "$tmp_file"

    msg_box "Cleanup" "Cleanup wurde erfolgreich abgeschlossen."
    exit 0
}

main "$@"#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_root
require_whiptail

main() {
    if ! yes_no_box "Automatic Security Updates" "Automatische Security Updates aktivieren?\n\nInstalliert 'unattended-upgrades' und aktiviert den Dienst."; then
        exit 0
    fi

    clear
    echo "Installiere unattended-upgrades..."
    echo

    apt update
    apt install -y unattended-upgrades apt-listchanges

    dpkg-reconfigure -plow unattended-upgrades

    systemctl enable unattended-upgrades
    systemctl restart unattended-upgrades

    sleep 1

    local tmp_file
    tmp_file=$(mktemp)
    {
        echo "===== unattended-upgrades Status ====="
        systemctl status unattended-upgrades --no-pager || true
        echo
        echo "===== Aktive Timers ====="
        systemctl list-timers apt* || true
    } > "$tmp_file" 2>&1
    textbox_file "Auto Updates Status" "$tmp_file"
    rm -f "$tmp_file"

    msg_box "Auto Updates" "Automatische Security Updates wurden aktiviert."
}

main "$@"#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

require_root
require_whiptail

show_open_ports() {
    local tmp_file
    tmp_file=$(mktemp)

    {
        echo "===== Offene Ports ====="
        echo
        ss -tulpn
    } > "$tmp_file" 2>&1

    textbox_file "Open Ports" "$tmp_file"
    rm -f "$tmp_file"
}

main() {
    if ! yes_no_box "Cleanup" "Unnötige Pakete entfernen und offene Ports anzeigen?\n\nEs werden typische Altlasten entfernt:\n- telnet\n- ftp\n- rsh-client"; then
        exit 0
    fi

    clear
    echo "Cleanup gestartet..."
    echo

    echo "Entferne unnötige Pakete..."
    apt purge -y telnet ftp rsh-client || true

    echo
    echo "Führe autoremove aus..."
    apt autoremove -y

    echo
    echo "Cleanup abgeschlossen."
    echo

    show_open_ports

    read -r -p "Press ENTER to return to menu..."
}

main "$@"
