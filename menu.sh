#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$SCRIPT_DIR/modules"

# shellcheck source=/dev/null
source "$MODULE_DIR/common.sh"

require_root
require_whiptail

while true; do
    CHOICE=$(whiptail --title "Raspi Secure Setup" \
        --menu "Choose an option" 20 78 12 \
        "1"  "System Update and Upgrade" \
        "2"  "Install Required Packages" \
        "3"  "Create Admin User" \
        "4"  "SSH Configuration and Hardening" \
        "5"  "UFW Firewall" \
        "6"  "Fail2ban" \
        "7"  "CrowdSec" \
        "8"  "Automatic Security Updates" \
        "9"  "Kernel Hardening" \
        "10" "Cleanup" \
        "11" "Package Integrity Check" \
        "0"  "Exit" \
        3>&1 1>&2 2>&3)

    EXIT_STATUS=$?

    if [[ $EXIT_STATUS -ne 0 ]]; then
        clear
        exit 0
    fi

    case "$CHOICE" in
        1) bash "$MODULE_DIR/update.sh" ;;
        2) bash "$MODULE_DIR/packages.sh" ;;
        3) bash "$MODULE_DIR/user.sh" ;;
        4) bash "$MODULE_DIR/ssh.sh" ;;
        5) bash "$MODULE_DIR/ufw.sh" ;;
        6) bash "$MODULE_DIR/fail2ban.sh" ;;
        7) bash "$MODULE_DIR/crowdsec.sh" ;;
        8) bash "$MODULE_DIR/autoupdates.sh" ;;
        9) bash "$MODULE_DIR/kernel.sh" ;;
        10) bash "$MODULE_DIR/cleanup.sh" ;;
        11) bash "$MODULE_DIR/integrity.sh" ;;
        0)
            clear
            exit 0
            ;;
    esac
done
