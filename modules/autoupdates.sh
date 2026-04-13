#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

ensure_ui_environment
require_root
require_whiptail

main() {
    if ! yes_no_box "Automatic Security Updates" "Automatische Security Updates aktivieren?\n\nInstalliert 'unattended-upgrades' und aktiviert den Dienst."; then
        exit 0
    fi

    clear
    echo "Installiere unattended-upgrades..."
    echo

    DEBIAN_FRONTEND=noninteractive apt update
    DEBIAN_FRONTEND=noninteractive apt install -y unattended-upgrades apt-listchanges
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -plow unattended-upgrades

    systemctl enable unattended-upgrades
    systemctl restart unattended-upgrades

    sleep 1

    local tmp_file
    tmp_file="$(mktemp)"
    {
        echo "===== unattended-upgrades Status ====="
        systemctl status unattended-upgrades --no-pager || true
        echo
        echo "===== Aktive Timer ====="
        systemctl list-timers 'apt*' || true
    } > "$tmp_file" 2>&1

    textbox_file "Auto Updates Status" "$tmp_file"
    rm -f "$tmp_file"

    msg_box "Auto Updates" "Automatische Security Updates wurden aktiviert."
}

main "$@"
