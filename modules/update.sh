#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_root
require_whiptail

main() {
    if ! yes_no_box "System Update" "System jetzt aktualisieren?\n\napt update && apt upgrade -y"; then
        exit 0
    fi

    clear
    echo "System wird aktualisiert..."
    echo

    DEBIAN_FRONTEND=noninteractive apt update
    DEBIAN_FRONTEND=noninteractive apt upgrade -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold"

    echo
    echo "Update abgeschlossen."
    sleep 1

    msg_box "System Update" "Update wurde erfolgreich abgeschlossen."
}

main "$@"
