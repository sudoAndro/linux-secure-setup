#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

ensure_ui_environment
require_root
require_whiptail

main() {
    if ! yes_no_box "Cleanup" "Unnoetige Pakete entfernen und offene Ports anzeigen?\n\nEs werden typische Altlasten entfernt:\n- telnet\n- ftp\n- rsh-client"; then
        exit 0
    fi

    clear
    echo "Cleanup gestartet..."
    echo

    DEBIAN_FRONTEND=noninteractive apt purge -y telnet ftp rsh-client || true
    apt autoremove -y

    local tmp_file
    tmp_file="$(mktemp)"
    {
        echo "===== Offene Ports ====="
        echo
        ss -tulpn || true
    } > "$tmp_file" 2>&1

    textbox_file "Open Ports" "$tmp_file"
    rm -f "$tmp_file"

    msg_box "Cleanup" "Cleanup wurde erfolgreich abgeschlossen."
}

main "$@"
