#!/usr/bin/env bash

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
