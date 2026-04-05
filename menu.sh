#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$SCRIPT_DIR/modules"

# shellcheck source=/dev/null
source "$MODULE_DIR/common.sh"

require_root
require_whiptail

while true; do
    CHOICE=$(whiptail --title "Linux Secure Setup" \
        --menu "Choose an option" 20 78 12 \
	"1"  "System Update and Upgrade" \
        "2"  "Install Required Packages" \  
        "3"  "System Language" \
        "4"  "Timezone" \
        "5"  "Hostname" \
        "6"  "SSH Configuration and Hardening" \
        "7"  "UFW Firewall" \
        "8"  "Fail2Ban" \
        "9"  "CrowdSec" \
        "10" "Automatic Security Updates" \
        "11" "Kernel Hardening" \
        "12" "Cleanup" \
        "13" "Package Integrity Check" \
        3>&1 1>&2 2>&3)

    EXIT_STATUS=$?

    if [[ $EXIT_STATUS -ne 0 ]]; then
        clear
        exit 0
    fi

    case "$CHOICE" in
        1) bash "$MODULE_DIR/update.sh" ;;
        2) bash "$MODULE_DIR/packages.sh" ;;
        3) bash "$MODULE_DIR/language.sh" ;;
        4) bash "$MODULE_DIR/timezone.sh" ;;
        5) bash "$MODULE_DIR/hostname.sh" ;;
	6) bash "$MODULE_DIR/ssh.sh" ;;
        7) bash "$MODULE_DIR/ufw.sh" ;;
        8) bash "$MODULE_DIR/fail2ban.sh" ;;
        9) bash "$MODULE_DIR/crowdsec.sh" ;;
        10) bash "$MODULE_DIR/autoupdates.sh" ;;
        11) bash "$MODULE_DIR/kernel.sh" ;;
        12) bash "$MODULE_DIR/cleanup.sh" ;;
        13) bash "$MODULE_DIR/integrity.sh" ;;
        0)
            clear
            exit 0
            ;;
    esac
done
