#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

ensure_ui_environment
require_root
require_whiptail


install_crowdsec_packages() {

    local bouncer_pkg=""

    msg_box "CrowdSec" "Installiere CrowdSec..."

    apt update

    if apt-cache show crowdsec-firewall-bouncer >/dev/null 2>&1; then
        bouncer_pkg="crowdsec-firewall-bouncer"

    elif apt-cache show crowdsec-firewall-bouncer-nftables >/dev/null 2>&1; then
        bouncer_pkg="crowdsec-firewall-bouncer-nftables"

    elif apt-cache show crowdsec-firewall-bouncer-iptables >/dev/null 2>&1; then
        bouncer_pkg="crowdsec-firewall-bouncer-iptables"

    else
        msg_box "Fehler" "Kein kompatibles CrowdSec Firewall-Bouncer Paket gefunden."
        exit 1
    fi

    apt install -y crowdsec "$bouncer_pkg"
}


start_services() {

    msg_box "CrowdSec" "Starte CrowdSec Dienste..."

    systemctl enable --now crowdsec
    systemctl enable --now crowdsec-firewall-bouncer
}


verify_installation() {

    if systemctl is-active --quiet crowdsec && systemctl is-active --quiet crowdsec-firewall-bouncer; then

        msg_box "CrowdSec installiert" \
        "CrowdSec wurde erfolgreich installiert.\n\n\
Service Status:\n\
crowdsec: aktiv\n\
firewall-bouncer: aktiv\n\n\
Logs anzeigen:\n\
journalctl -u crowdsec\n\
journalctl -u crowdsec-firewall-bouncer"

    else

        msg_box "Fehler" \
        "CrowdSec scheint nicht korrekt zu laufen.\n\n\
Bitte prüfen:\n\
systemctl status crowdsec\n\
systemctl status crowdsec-firewall-bouncer"

        exit 1
    fi
}


main() {

    if ! yes_no_box "CrowdSec Installation" \
    "CrowdSec installiert einen Intrusion Detection Dienst.\n\n\
Dieser erkennt Angriffe und blockiert IPs automatisch über die Firewall.\n\n\
Soll CrowdSec installiert werden?"; then
        return
    fi

    install_crowdsec_packages

    start_services

    verify_installation
}

main
