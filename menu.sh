#!/usr/bin/env bash
set -euo pipefail

export TERM="${TERM:-xterm-256color}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$SCRIPT_DIR/modules"

# shellcheck source=/dev/null
source "$MODULE_DIR/common.sh"

ensure_ui_environment
require_root
require_whiptail

while true; do
    CHOICE=$(
        whiptail --title "Linux Secure Setup" \
            --menu "Waehle ein Modul:" 20 78 12 \
            "1"  "System Update and Upgrade" \
            "2"  "Install Required Packages" \
            "3"  "System Language" \
            "4"  "Timezone" \
            "5"  "SSH Configuration and Hardening" \
            "6"  "UFW Firewall" \
            "7"  "Fail2Ban" \
            "8"  "CrowdSec" \
            "9"  "Automatic Security Updates" \
            "10" "Kernel Hardening" \
            "11" "Cleanup" \
            "12" "Package Integrity Check" \
            3>&1 1>&2 2>&3
    ) || {
        clear
        exit 0
    }

    case "$CHOICE" in
        1) bash "$MODULE_DIR/update.sh" ;;
        2) bash "$MODULE_DIR/packages.sh" ;;
        3) bash "$MODULE_DIR/language.sh" ;;
        4) bash "$MODULE_DIR/timezone.sh" ;;
        5) bash "$MODULE_DIR/ssh.sh" ;;
        6) bash "$MODULE_DIR/ufw.sh" ;;
        7) bash "$MODULE_DIR/fail2ban.sh" ;;
        8) bash "$MODULE_DIR/crowdsec.sh" ;;
        9) bash "$MODULE_DIR/autoupdates.sh" ;;
        10) bash "$MODULE_DIR/kernel.sh" ;;
        11) bash "$MODULE_DIR/cleanup.sh" ;;
        12) bash "$MODULE_DIR/integrity.sh" ;;
    esac
done
