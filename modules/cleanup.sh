#!/usr/bin/env bash

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
