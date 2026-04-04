#!/usr/bin/env bash

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
