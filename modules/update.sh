#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

ensure_ui_environment
require_root
require_whiptail

main() {
    if ! yes_no_box "System Update" "System jetzt aktualisieren?\n\napt update && apt upgrade -y"; then
        exit 0
    fi

    clear
    echo "System wird aktualisiert..."
    echo

    apt update && apt upgrade -y

    echo
    echo "Update abgeschlossen."

    msg_box "System Update" "Update wurde erfolgreich abgeschlossen."
}

main "$@"#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

require_root
require_whiptail

JAIL_LOCAL="/etc/fail2ban/jail.local"

show_fail2ban_status() {
    local tmp_file
    tmp_file=$(mktemp)

    {
        echo "===== fail2ban-client status ====="
        fail2ban-client status || true
        echo
        echo "===== fail2ban-client status sshd ====="
        fail2ban-client status sshd || true
    } > "$tmp_file" 2>&1

    textbox_file "Fail2Ban Status" "$tmp_file"
    rm -f "$tmp_file"
}

main() {
    local ssh_port

    if ! yes_no_box "Fail2Ban" "Fail2Ban fuer SSH einrichten?\n\nSchuetzt gegen Brute-Force-Angriffe auf SSH."; then
        exit 0
    fi

    ssh_port=$(prompt_port) || exit 0

    clear
    echo "Konfiguriere Fail2Ban..."
    echo

    cat > "$JAIL_LOCAL" <<EOF
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
backend = systemd

[sshd]
enabled = true
port = ${ssh_port}
logpath = %(sshd_log)s
EOF

    echo "Konfiguration geschrieben nach: $JAIL_LOCAL"
    echo

    systemctl enable fail2ban
    systemctl restart fail2ban

    echo "Fail2Ban wurde gestartet."
    echo

    show_fail2ban_status

    read -r -p "Press ENTER to return to menu..."
}

main "$@"#!/bin/bash

clear
echo "System wird aktualisiert..."
echo

sudo apt update && sudo apt upgrade -y

echo
echo "Update abgeschlossen."
read -p "Enter drücken..."
