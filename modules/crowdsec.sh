#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_root
require_whiptail

main() {
    whiptail --title "CrowdSec" \
        --yesno \
"CrowdSec installieren?

Erkennt Angriffe und blockiert bekannte
Angreifer automatisch.

Fortfahren?" 13 55 || exit 0

    clear
    echo "Installiere CrowdSec..."
    echo

    curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.deb.sh | bash
    DEBIAN_FRONTEND=noninteractive apt install -y crowdsec crowdsec-firewall-bouncer-iptables

    systemctl enable crowdsec
    systemctl restart crowdsec

    echo
    echo "Installiere SSH-Schutz..."
    cscli collections install crowdsecurity/sshd
    systemctl restart crowdsec
    sleep 1

    local tmp_file
    tmp_file=$(mktemp)
    {
        echo "===== CrowdSec Status ====="
        systemctl status crowdsec --no-pager || true
        echo
        echo "===== Metrics ====="
        cscli metrics || true
    } > "$tmp_file" 2>&1
    textbox_file "CrowdSec Status" "$tmp_file"
    rm -f "$tmp_file"

    msg_box "CrowdSec" "CrowdSec wurde erfolgreich installiert."
    exit 0
}

main "$@"#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_root
require_whiptail

main() {
    if ! yes_no_box "CrowdSec" "CrowdSec installieren?\n\nCrowdSec erkennt Angriffe und blockiert bekannte Angreifer automatisch."; then
        exit 0
    fi

    clear
    echo "Installiere CrowdSec..."
    echo

    curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.deb.sh | bash
    apt install -y crowdsec crowdsec-firewall-bouncer-iptables

    systemctl enable crowdsec
    systemctl restart crowdsec

    echo
    echo "Installiere SSH-Schutz..."
    cscli collections install crowdsecurity/sshd
    systemctl restart crowdsec

    sleep 1

    local tmp_file
    tmp_file=$(mktemp)
    {
        echo "===== CrowdSec Status ====="
        systemctl status crowdsec --no-pager || true
        echo
        echo "===== CrowdSec Metrics ====="
        cscli metrics || true
    } > "$tmp_file" 2>&1
    textbox_file "CrowdSec Status" "$tmp_file"
    rm -f "$tmp_file"

    msg_box "CrowdSec" "CrowdSec wurde erfolgreich installiert."
}

main "$@"#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

require_root
require_whiptail

JAIL_LOCAL="/etc/fail2ban/jail.local"

show_fail2ban_status() {
    local tmp_file
    tmp_file=$(mktemp)

    {
        echo "===== fail2ban-client status ====="
        fail2ban-client status || true
        echo
        echo "===== fail2ban-client status sshd ====="
        fail2ban-client status sshd || true
    } > "$tmp_file" 2>&1

    textbox_file "Fail2Ban Status" "$tmp_file"
    rm -f "$tmp_file"
}

main() {
    local ssh_port

    if ! yes_no_box "Fail2Ban" "Fail2Ban fuer SSH einrichten?\n\nSchuetzt gegen Brute-Force-Angriffe auf SSH."; then
        exit 0
    fi

    ssh_port=$(prompt_port) || exit 0

    clear
    echo "Konfiguriere Fail2Ban..."
    echo

    cat > "$JAIL_LOCAL" <<EOF
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
backend = systemd

[sshd]
enabled = true
port = ${ssh_port}
logpath = %(sshd_log)s
EOF

    echo "Konfiguration geschrieben nach: $JAIL_LOCAL"
    echo

    systemctl enable fail2ban
    systemctl restart fail2ban

    echo "Fail2Ban wurde gestartet."
    echo

    show_fail2ban_status

    read -r -p "Press ENTER to return to menu..."
}

main "$@"#!/bin/bash

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
