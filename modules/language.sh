#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

ensure_ui_environment
require_root
require_whiptail

main() {
    local choice

    choice=$(
        whiptail --title "System Language" \
            --menu "Systemsprache auswaehlen" 15 60 2 \
            "de" "Deutsch" \
            "en" "English" \
            3>&1 1>&2 2>&3
    ) || exit 0

    case "$choice" in
        de)
            apt update
            apt install -y locales
            sed -i 's/^# *de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen || true
            locale-gen
            update-locale LANG=de_DE.UTF-8
            msg_box "Sprache" "Deutsch wurde eingerichtet.\n\nNeustart oder neue Anmeldung empfohlen."
            ;;
        en)
            apt update
            apt install -y locales
            sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen || true
            locale-gen
            update-locale LANG=en_US.UTF-8
            msg_box "Language" "English has been configured.\n\nReboot or re-login recommended."
            ;;
    esac
}

main "$@"
