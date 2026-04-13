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
            "update"       "1  System Update and Upgrade" \
            "packages"     "2  Install Required Packages" \
            "language"     "3  System Language" \
            "timezone"     "4  Timezone" \
            "ssh"          "5  SSH Configuration and Hardening" \
            "ufw"          "6  UFW Firewall" \
            "fail2ban"     "7  Fail2Ban" \
            "crowdsec"     "8  CrowdSec" \
            "autoupdates"  "9  Automatic Security Updates" \
            "kernel"       "10 Kernel Hardening" \
            "cleanup"      "11 Cleanup" \
            "integrity"    "12 Package Integrity Check" \
            3>&1 1>&2 2>&3
    ) || {
        clear
        exit 0
    }

    case "$CHOICE" in
        update) bash "$MODULE_DIR/update.sh" ;;
        packages) bash "$MODULE_DIR/packages.sh" ;;
        language) bash "$MODULE_DIR/language.sh" ;;
        timezone) bash "$MODULE_DIR/timezone.sh" ;;
        ssh) bash "$MODULE_DIR/ssh.sh" ;;
        ufw) bash "$MODULE_DIR/ufw.sh" ;;
        fail2ban) bash "$MODULE_DIR/fail2ban.sh" ;;
        crowdsec) bash "$MODULE_DIR/crowdsec.sh" ;;
        autoupdates) bash "$MODULE_DIR/autoupdates.sh" ;;
        kernel) bash "$MODULE_DIR/kernel.sh" ;;
        cleanup) bash "$MODULE_DIR/cleanup.sh" ;;
        integrity) bash "$MODULE_DIR/integrity.sh" ;;
    esac
done
