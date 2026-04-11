#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

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
        echo "debsums nicht gefunden — installiere..."
        apt update && apt install -y debsums
    fi

    local results
    results=$(debsums -s 2>/dev/null || true)

    local tmp_file
    tmp_file=$(mktemp)
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

main "$@"#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

require_root
require_whiptail

run_integrity_check() {

    local tmp_file
    tmp_file=$(mktemp)

    echo "Running debsums integrity check..."

    RESULTS=$(debsums -s 2>/dev/null || true)

    {
        echo "===== System Package Integrity Check ====="
        echo

        if [[ -z "$RESULTS" ]]; then
            echo "✓ System integrity OK"
            echo
            echo "No modified package files detected."
        else
            echo "⚠ Modified package files detected:"
            echo
            echo "$RESULTS"
        fi

    } > "$tmp_file"

    textbox_file "Debsums Integrity Check" "$tmp_file"
    rm -f "$tmp_file"
}

main() {

    if ! yes_no_box "Package Integrity Check" "Systempakete mit debsums überprüfen?\n\nDies erkennt veränderte Dateien."; then
        exit 0
    fi

    clear
    echo "Starte Paketintegritätsprüfung..."
    echo

    if ! command -v debsums >/dev/null 2>&1; then
        echo "debsums nicht gefunden — installiere..."
        apt update
        apt install -y debsums
    fi

    run_integrity_check

    read -r -p "Press ENTER to return to menu..."
}

main "$@"
