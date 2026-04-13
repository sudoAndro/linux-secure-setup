#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

ensure_ui_environment
require_root
require_whiptail

SYSCTL_FILE="/etc/sysctl.d/99-linux-secure-setup.conf"

write_sysctl_config() {
    cat > "$SYSCTL_FILE" <<'EOF'
# Managed by linux-secure-setup
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
EOF
}

main() {
    if ! yes_no_box "Kernel Hardening" "Kernel Security Parameter setzen?\n\nEs werden sichere sysctl-Werte fuer Netzwerk- und Redirect-Schutz gesetzt."; then
        exit 0
    fi

    clear
    echo "Wende Kernel-Hardening an..."
    echo

    write_sysctl_config
    sysctl --system >/dev/null

    local tmp_file
    tmp_file="$(mktemp)"
    {
        echo "===== Gespeicherte Konfiguration ====="
        cat "$SYSCTL_FILE"
        echo
        echo "===== Aktive Werte ====="
        sysctl \
            net.ipv4.icmp_echo_ignore_broadcasts \
            net.ipv4.conf.all.rp_filter \
            net.ipv4.conf.default.rp_filter \
            net.ipv4.tcp_syncookies \
            net.ipv4.conf.all.accept_redirects \
            net.ipv4.conf.default.accept_redirects \
            net.ipv4.conf.all.send_redirects \
            net.ipv4.conf.default.send_redirects \
            net.ipv4.conf.all.accept_source_route \
            net.ipv4.conf.default.accept_source_route \
            net.ipv6.conf.all.accept_redirects \
            net.ipv6.conf.default.accept_redirects
    } > "$tmp_file" 2>&1

    textbox_file "Kernel Hardening Status" "$tmp_file"
    rm -f "$tmp_file"

    msg_box "Kernel Hardening" "Kernel-Parameter wurden erfolgreich gesetzt."
}

main "$@"
