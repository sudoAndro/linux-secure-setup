#!/bin/bash

clear
echo "UFW Modul kommt als nächstes."
echo
read -p "Enter drücken..."

#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

require_root
require_whiptail

show_ufw_status() {
    local tmp_file
    tmp_file=$(mktemp)

    ufw status verbose > "$tmp_file" 2>&1 || true
    textbox_file "UFW Status" "$tmp_file"
    rm -f "$tmp_file"
}

main() {
    local ssh_port
    local old_port

    if ! yes_no_box "UFW Firewall" "UFW mit sicheren Standardregeln konfigurieren?\n\n- deny incoming\n- allow outgoing\n- SSH-Port freigeben\n- Firewall aktivieren"; then
        exit 0
    fi

    ssh_port=$(prompt_port) || exit 0

    clear
    echo "Konfiguriere UFW..."
    echo

    echo "Setze Standardregeln..."
    ufw default deny incoming
    ufw default allow outgoing

    echo
    echo "Erlaube SSH-Port ${ssh_port}/tcp ..."
    ufw allow "${ssh_port}/tcp"

    if [[ "$ssh_port" != "22" ]]; then
        if yes_no_box "Port 22 entfernen" "Der gewählte SSH-Port ist ${ssh_port}.\n\nSoll die Freigabe für 22/tcp entfernt werden, falls sie existiert?"; then
            ufw delete allow 22/tcp >/dev/null 2>&1 || true
        fi
    fi

    echo
    echo "Aktiviere UFW..."
    ufw --force enable

    echo
    echo "UFW wurde konfiguriert."
    echo

    show_ufw_status

    read -r -p "Press ENTER to return to menu..."
}

main "$@"
