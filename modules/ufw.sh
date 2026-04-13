#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

ensure_ui_environment
require_root
require_whiptail

main() {
    if ! yes_no_box "UFW Firewall" "UFW mit sicheren Standardregeln konfigurieren?\n\n- deny incoming\n- allow outgoing\n- SSH-Port freigeben\n- Firewall aktivieren"; then
        exit 0
    fi

    local ssh_port
    ssh_port="$(prompt_port)" || exit 0

    clear
    echo "Konfiguriere UFW..."
    echo

    if ! command -v ufw >/dev/null 2>&1; then
        DEBIAN_FRONTEND=noninteractive apt update
        DEBIAN_FRONTEND=noninteractive apt install -y ufw
    fi

    ufw default deny incoming
    ufw default allow outgoing
    ufw allow "${ssh_port}/tcp"

    if [[ "$ssh_port" != "22" ]]; then
        if yes_no_box "Port 22" "Soll Port 22/tcp entfernt werden?"; then
            ufw delete allow 22/tcp >/dev/null 2>&1 || true
        fi
    fi

    ufw --force enable

    local tmp_file
    tmp_file="$(mktemp)"
    ufw status verbose > "$tmp_file" 2>&1 || true
    textbox_file "UFW Status" "$tmp_file"
    rm -f "$tmp_file"

    msg_box "UFW Firewall" "UFW wurde erfolgreich konfiguriert."
}

main "$@"
