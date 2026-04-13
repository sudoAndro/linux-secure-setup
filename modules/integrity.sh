#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

ensure_ui_environment
require_root
require_whiptail

main() {
    if ! yes_no_box "Package Integrity Check" "Systempakete mit debsums pruefen?\n\nDies erkennt veraenderte Dateien."; then
        exit 0
    fi

    clear
    echo "Starte Integritaetspruefung..."
    echo

    if ! command -v debsums >/dev/null 2>&1; then
        echo "debsums nicht gefunden - installiere..."
        DEBIAN_FRONTEND=noninteractive apt update
        DEBIAN_FRONTEND=noninteractive apt install -y debsums
    fi

    local results
    results="$(debsums -s 2>/dev/null || true)"

    local tmp_file
    tmp_file="$(mktemp)"
    {
        echo "===== System Package Integrity Check ====="
        echo
        if [[ -z "$results" ]]; then
            echo "Alle Pakete sind unveraendert."
        else
            echo "Veraenderte Dateien gefunden:"
            echo
            echo "$results"
        fi
    } > "$tmp_file"

    textbox_file "Integritaetspruefung" "$tmp_file"
    rm -f "$tmp_file"

    msg_box "Integritaet" "Pruefung abgeschlossen."
}

main "$@"
