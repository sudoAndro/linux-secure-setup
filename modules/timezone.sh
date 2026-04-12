#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

ensure_ui_environment
require_root
require_whiptail

main() {
    local timezone

    timezone=$(
        whiptail --title "Timezone" \
            --menu "Zeitzone auswaehlen:" 18 60 7 \
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
        timezone="$(input_box "Timezone" "Zeitzone eingeben (Beispiel: Europe/Zurich)" "Europe/Zurich")" || exit 0
    fi

    timezone="$(printf '%s' "$timezone" | tr -d '\r')"

    if [[ -z "${timezone// }" ]]; then
        msg_box "Fehler" "Keine Zeitzone eingegeben."
        exit 0
    fi

    if [[ ! -e "/usr/share/zoneinfo/$timezone" ]]; then
        msg_box "Fehler" "Ungueltige Zeitzone:\n\n$timezone"
        exit 1
    fi

    if command -v timedatectl >/dev/null 2>&1; then
        timedatectl set-timezone "$timezone"
    else
        ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime
        echo "$timezone" > /etc/timezone
    fi

    msg_box "Timezone" "Zeitzone wurde gesetzt auf:\n\n$timezone"
}

main "$@"
