#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

ensure_ui_environment
require_root
require_whiptail

JAIL_LOCAL="/etc/fail2ban/jail.local"

main() {
    if ! yes_no_box "Fail2Ban" "Fail2Ban fuer SSH einrichten?\n\nSchuetzt gegen Brute-Force-Angriffe auf SSH."; then
        exit 0
    fi

    local ssh_port
    ssh_port="$(prompt_port)" || exit 0

    clear
    echo "Installiere und konfiguriere Fail2Ban..."
    echo

    DEBIAN_FRONTEND=noninteractive apt update
    DEBIAN_FRONTEND=noninteractive apt install -y fail2ban

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

    systemctl enable fail2ban
    systemctl restart fail2ban

    sleep 1

    local tmp_file
    tmp_file="$(mktemp)"
    {
        echo "===== fail2ban-client status ====="
        fail2ban-client status || true
        echo
        echo "===== sshd jail ====="
        fail2ban-client status sshd || true
    } > "$tmp_file" 2>&1

    textbox_file "Fail2Ban Status" "$tmp_file"
    rm -f "$tmp_file"

    msg_box "Fail2Ban" "Fail2Ban wurde erfolgreich eingerichtet."
}

main "$@"
