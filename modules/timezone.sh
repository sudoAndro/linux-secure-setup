#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_root
require_whiptail

main() {
    local timezone
    timezone=$(
        whiptail --title "Timezone" \
            --menu "Zeitzone auswaehlen:" 18 50 7 \
            "Europe/Zurich"  "Schweiz" \
            "Europe/Berlin"  "Deutschland" \
            "Europe/Vienna"  "Oesterreich" \
            "Europe/Paris"   "Frankreich" \
            "Europe/Rome"    "Italien" \
            "UTC"            "Universal Time" \
            "Manual"         "Manuell eingeben" \
            3>&1 1>&2 2>&3
    ) || exit 0

    if [[ "$timezone" == "Manual" ]]; then
        timezone=$(input_box "Timezone" "Zeitzone eingeben (Beispiel: Europe/Zurich)" "Europe/Zurich") || exit 0
    fi

    if [[ -z "${timezone// }" ]]; then
        msg_box "Fehler" "Keine Zeitzone eingegeben."
        exit 0
    fi

    clear
    echo "Zeitzone wird gesetzt..."
    echo

    if command -v timedatectl >/dev/null 2>&1; then
        timedatectl set-timezone "$timezone"
    else
        ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime
        echo "$timezone" > /etc/timezone
    fi

    msg_box "Timezone" "Zeitzone wurde gesetzt auf:\n\n  $timezone"
    exit 0
}

main "$@"#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_root
require_whiptail

main() {
    local choice
    choice=$(
        whiptail --title "System Language" \
            --menu "Systemsprache auswaehlen" 15 60 5 \
            "de" "Deutsch" \
            "en" "English" \
            3>&1 1>&2 2>&3
    ) || exit 0

    clear
    echo "Sprache wird konfiguriert..."
    echo

    case "$choice" in
        de)
            apt update && apt install -y locales
            sed -i 's/^# *de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen || true
            locale-gen
            update-locale LANG=de_DE.UTF-8
            msg_box "Sprache" "Deutsch wurde eingerichtet.\n\nNeustart oder neue Anmeldung empfohlen."
            ;;
        en)
            apt update && apt install -y locales
            sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen || true
            locale-gen
            update-locale LANG=en_US.UTF-8
            msg_box "Language" "English has been configured.\n\nReboot or re-login recommended."
            ;;
    esac
}

main "$@"#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

require_root
require_whiptail

main() {
    local timezone

    timezone=$(whiptail --title "Timezone" \
        --menu "Select timezone" 18 70 8 \
        "Europe/Zurich" "Switzerland" \
        "Europe/Berlin" "Germany" \
        "Europe/Vienna" "Austria" \
        "Europe/Paris" "France" \
        "Europe/Rome" "Italy" \
        "UTC" "Universal Time" \
        "Manual" "Enter manually" \
        3>&1 1>&2 2>&3) || exit 0

    if [[ "$timezone" == "Manual" ]]; then
        timezone=$(input_box "Timezone" "Enter timezone manually (example: Europe/Zurich)" "Europe/Zurich") || exit 0
    fi

    if [[ -z "${timezone// }" ]]; then
        msg_box "Fehler" "Keine Zeitzone eingegeben."
        exit 1
    fi

    if command -v timedatectl >/dev/null 2>&1; then
        timedatectl set-timezone "$timezone"
    else
        ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime
        echo "$timezone" > /etc/timezone
    fi

    msg_box "Timezone" "Timezone set to:\n$timezone"
}

main "$@"#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

require_root
require_whiptail

timezone=$(whiptail --title "Timezone" \
    --menu "Select timezone" 18 70 8 \
    "Europe/Zurich" "Switzerland" \
    "Europe/Berlin" "Germany" \
    "Europe/Vienna" "Austria" \
    "Europe/Paris" "France" \
    "Europe/Rome" "Italy" \
    "UTC" "Universal Time" \
    "Manual" "Enter manually" \
    3>&1 1>&2 2>&3) || exit 0

if [[ "$timezone" == "Manual" ]]; then
    timezone=$(input_box "Timezone" "Enter timezone manually (example: Europe/Zurich)" "Europe/Zurich") || exit 0
fi

if [[ -z "${timezone// }" ]]; then
    msg_box "Fehler" "Keine Zeitzone eingegeben."
    exit 1
fi

if command -v timedatectl >/dev/null 2>&1; then
    timedatectl set-timezone "$timezone"
else
    ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime
    echo "$timezone" > /etc/timezone
fi

msg_box "Timezone" "Timezone set to:\n$timezone"
