#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_root
require_whiptail

main() {
    whiptail --title "Cleanup" \
        --yesno \
"Unnoetige Pakete entfernen?

Folgende Pakete werden entfernt:
  - telnet
  - ftp
  - rsh-client

Danach werden offene Ports angezeigt.

Fortfahren?" 16 55 || exit 0

    clear
    echo "Cleanup wird ausgefuehrt..."
    echo

    DEBIAN_FRONTEND=noninteractive apt purge -y telnet ftp rsh-client || true
    apt autoremove -y
    sleep 1

    local tmp_file
    tmp_file=$(mktemp)
    {
        echo "===== Offene Ports ====="
        echo
        ss -tulpn
    } > "$tmp_file" 2>&1
    textbox_file "Offene Ports" "$tmp_file"
    rm -f "$tmp_file"

    msg_box "Cleanup" "Cleanup wurde erfolgreich abgeschlossen."
    exit 0
}

main "$@"#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_root
require_whiptail

main() {
    whiptail --title "Automatic Security Updates" \
        --yesno \
"Automatische Security Updates aktivieren?

Installiert 'unattended-upgrades' und
aktiviert den Dienst.

Fortfahren?" 13 55 || exit 0

    clear
    echo "Installiere unattended-upgrades..."
    echo

    DEBIAN_FRONTEND=noninteractive apt update
    DEBIAN_FRONTEND=noninteractive apt install -y unattended-upgrades apt-listchanges

    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -plow unattended-upgrades

    systemctl enable unattended-upgrades
    systemctl restart unattended-upgrades
    sleep 1

    local tmp_file
    tmp_file=$(mktemp)
    {
        echo "===== unattended-upgrades Status ====="
        systemctl status unattended-upgrades --no-pager || true
        echo
        echo "===== Aktive Timers ====="
        systemctl list-timers apt* || true
    } > "$tmp_file" 2>&1
    textbox_file "Auto Updates Status" "$tmp_file"
    rm -f "$tmp_file"

    msg_box "Auto Updates" "Automatische Security Updates wurden aktiviert."
    exit 0
}

main "$@"#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_root
require_whiptail

main() {
    if ! yes_no_box "Automatic Security Updates" "Automatische Security Updates aktivieren?\n\nInstalliert 'unattended-upgrades' und aktiviert den Dienst."; then
        exit 0
    fi

    clear
    echo "Installiere unattended-upgrades..."
    echo

    apt update
    apt install -y unattended-upgrades apt-listchanges

    dpkg-reconfigure -plow unattended-upgrades

    systemctl enable unattended-upgrades
    systemctl restart unattended-upgrades

    sleep 1

    local tmp_file
    tmp_file=$(mktemp)
    {
        echo "===== unattended-upgrades Status ====="
        systemctl status unattended-upgrades --no-pager || true
        echo
        echo "===== Aktive Timers ====="
        systemctl list-timers apt* || true
    } > "$tmp_file" 2>&1
    textbox_file "Auto Updates Status" "$tmp_file"
    rm -f "$tmp_file"

    msg_box "Auto Updates" "Automatische Security Updates wurden aktiviert."
}

main "$@"#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

require_root
require_whiptail

SYSCTL_FILE="/etc/sysctl.conf"

apply_kernel_hardening() {

    echo
    echo "Applying kernel hardening..."

    grep -q "icmp_echo_ignore_broadcasts" "$SYSCTL_FILE" || echo "net.ipv4.icmp_echo_ignore_broadcasts = 1" >> "$SYSCTL_FILE"
    grep -q "rp_filter" "$SYSCTL_FILE" || echo "net.ipv4.conf.all.rp_filter = 1" >> "$SYSCTL_FILE"
    grep -q "tcp_syncookies" "$SYSCTL_FILE" || echo "net.ipv4.tcp_syncookies = 1" >> "$SYSCTL_FILE"

    sysctl -p

    echo
    echo "Kernel parameters applied."
}

show_sysctl() {

    local tmp_file
    tmp_file=$(mktemp)

    {
        echo "===== Current Kernel Security Parameters ====="
        echo
        sysctl net.ipv4.icmp_echo_ignore_broadcasts
        sysctl net.ipv4.conf.all.rp_filter
        sysctl net.ipv4.tcp_syncookies
    } > "$tmp_file"

    textbox_file "Kernel Hardening Status" "$tmp_file"
    rm -f "$tmp_file"
}

main() {

    if ! yes_no_box "Kernel Hardening" "Kernel Security Parameter setzen?\n\n- icmp_echo_ignore_broadcasts\n- rp_filter\n- tcp_syncookies"; then
        exit 0
    fi

    clear
    apply_kernel_hardening
    show_sysctl

    read -r -p "Press ENTER to return to menu..."
}

main "$@"
