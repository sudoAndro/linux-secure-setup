#!/bin/bash

clear
echo "CrowdSec Modul kommt später."
echo
read -p "Enter drücken..."

#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

require_root
require_whiptail

show_crowdsec_status() {

    local tmp_file
    tmp_file=$(mktemp)

    {
        echo "===== CrowdSec Status ====="
        echo
        systemctl status crowdsec --no-pager
        echo
        echo "===== CrowdSec Metrics ====="
        cscli metrics || true
    } > "$tmp_file" 2>&1

    textbox_file "CrowdSec Status" "$tmp_file"
    rm -f "$tmp_file"
}

install_crowdsec() {

    echo "Installing CrowdSec..."

    curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.deb.sh | bash

    apt install -y crowdsec crowdsec-firewall-bouncer-iptables

    systemctl enable crowdsec
    systemctl restart crowdsec
}

main() {

    if ! yes_no_box "CrowdSec" "CrowdSec installieren?\n\nCrowdSec erkennt Angriffe und blockiert bekannte Angreifer."; then
        exit 0
    fi

    clear
    install_crowdsec

    echo
    echo "Installiere SSH Schutz..."

    cscli collections install crowdsecurity/sshd

    systemctl restart crowdsec

    echo
    echo "CrowdSec erfolgreich installiert."

    show_crowdsec_status

    read -r -p "Press ENTER to return to menu..."
}

main "$@"
