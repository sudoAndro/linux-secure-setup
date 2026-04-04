#!/bin/bash

clear
echo "Auto Updates Modul kommt als nächstes."
echo
read -p "Enter drücken..."

#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

require_root
require_whiptail

show_status() {
    local tmp_file
    tmp_file=$(mktemp)

    {
        echo "===== unattended-upgrades status ====="
        systemctl status unattended-upgrades --no-pager
        echo
        echo "===== enabled timers ====="
        systemctl list-timers apt*
    } > "$tmp_file" 2>&1

    textbox_file "Auto Updates Status" "$tmp_file"
    rm -f "$tmp_file"
}

main() {

    if ! yes_no_box "Automatic Security Updates" "Automatische Security Updates aktivieren?\n\nDies installiert 'unattended-upgrades'."; then
        exit 0
    fi

    clear
    echo "Installiere unattended-upgrades..."
    echo

    apt update
    apt install -y unattended-upgrades apt-listchanges

    echo
    echo "Aktiviere automatische Updates..."

    dpkg-reconfigure -plow unattended-upgrades

    systemctl enable unattended-upgrades
    systemctl restart unattended-upgrades

    echo
    echo "Automatische Updates aktiviert."
    echo

    show_status

    read -r -p "Press ENTER to return to menu..."
}

main "$@"
