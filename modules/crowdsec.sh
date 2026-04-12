#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

ensure_ui_environment
require_root
require_whiptail

install_crowdsec_packages() {
    msg_box "CrowdSec" "Installiere CrowdSec und Firewall-Bouncer..."

    apt update

    if ! apt-cache show crowdsec >/dev/null 2>&1; then
        msg_box "Fehler" "Das Paket 'crowdsec' wurde in den konfigurierten Paketquellen nicht gefunden."
        exit 1
    fi

    if ! apt-cache show crowdsec-firewall-bouncer >/dev/null 2>&1; then
        msg_box "Fehler" "Das Paket 'crowdsec-firewall-bouncer' wurde in den konfigurierten Paketquellen nicht gefunden."
        exit 1
    fi

    apt install -y crowdsec crowdsec-firewall-bouncer
}

enable_collections() {
    msg_box "CrowdSec" "Aktiviere empfohlene Collections fuer Linux und SSH..."

    cscli collections install crowdsecurity/linux >/dev/null 2>&1 || true
    cscli collections install crowdsecurity/sshd >/dev/null 2>&1 || true
}

start_services() {
    msg_box "CrowdSec" "Starte CrowdSec Dienste..."

    systemctl enable --now crowdsec
    systemctl enable --now crowdsec-firewall-bouncer
}

verify_installation() {
    local crowdsec_status="inaktiv"
    local bouncer_status="inaktiv"

    if systemctl is-active --quiet crowdsec; then
        crowdsec_status="aktiv"
    fi

    if systemctl is-active --quiet crowdsec-firewall-bouncer; then
        bouncer_status="aktiv"
    fi

    if [[ "$crowdsec_status" == "aktiv" && "$bouncer_status" == "aktiv" ]]; then
        msg_box "CrowdSec installiert" \
"CrowdSec wurde erfolgreich installiert.

Status:
- crowdsec: $crowdsec_status
- firewall-bouncer: $bouncer_status

Pruefen mit:
systemctl status crowdsec
systemctl status crowdsec-firewall-bouncer"
    else
        msg_box "Fehler" \
"CrowdSec scheint nicht korrekt zu laufen.

Status:
- crowdsec: $crowdsec_status
- firewall-bouncer: $bouncer_status

Bitte pruefen mit:
systemctl status crowdsec
systemctl status crowdsec-firewall-bouncer"
        exit 1
    fi
}

main() {
    if ! yes_no_box "CrowdSec Installation" \
"CrowdSec erkennt Angriffe und blockiert boesartige IP-Adressen automatisch ueber die Firewall.

Soll CrowdSec installiert werden?"; then
        exit 0
    fi

    install_crowdsec_packages
    enable_collections
    start_services
    verify_installation
}

main "$@"
