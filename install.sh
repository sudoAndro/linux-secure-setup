#!/usr/bin/env bash
set -euo pipefail

clear

echo -e "\033[1;32m"
cat << "EOF"
 _     _                    ____                             ____       _
| |   (_)_ __  _   ___  __ / ___|  ___  ___ _   _ _ __ ___  / ___|  ___| |_ _   _ _ __
| |   | | '_ \| | | \ \/ / \___ \ / _ \/ __| | | | '__/ _ \ \___ \ / _ \ __| | | | '_ \
| |___| | | | | |_| |>  <   ___) |  __/ (__| |_| | | |  __/  ___) |  __/ |_| |_| | |_) |
|_____|_|_| |_|\__,_/_/\_\ |____/ \___|\___|\__,_|_|  \___| |____/ \___|\__|\__,_| .__/
                                                                                 |_|
EOF
echo -e "\033[1;31m"
echo "                         Linux Secure Setup Toolkit - Created by sudoAndro"
echo -e "\033[0m"
echo

read -rp "Press ENTER to start setup..."


REPO_URL="https://github.com/sudoAndro/linux-secure-setup.git"
INSTALL_DIR="/opt/linux-secure-setup"

print_info() {
    echo -e "\e[1;34m[INFO]\e[0m $1"
}

print_ok() {
    echo -e "\e[1;32m[ OK ]\e[0m $1"
}

print_warn() {
    echo -e "\e[1;33m[WARN]\e[0m $1"
}

print_err() {
    echo -e "\e[1;31m[ERR ]\e[0m $1"
}

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        print_err "Bitte mit sudo oder als root ausfuehren."
        exit 1
    fi
}

check_dependencies() {
    local missing=()

    for cmd in git bash curl; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if ! command -v whiptail >/dev/null 2>&1; then
        missing+=(whiptail dialog ncurses-term)
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        print_info "Installiere fehlende Pakete: ${missing[*]}"
        apt update
        apt install -y "${missing[@]}"
    fi
}

install_or_update_repo() {
    if [[ -d "$INSTALL_DIR/.git" ]]; then
        print_info "Bestehende Installation gefunden. Aktualisiere Repository ..."
        git -C "$INSTALL_DIR" pull --ff-only
        print_ok "Repository wurde aktualisiert."
    else
        if [[ -d "$INSTALL_DIR" ]]; then
            print_warn "$INSTALL_DIR existiert bereits und wird ersetzt."
            rm -rf "$INSTALL_DIR"
        fi

        print_info "Klonen nach $INSTALL_DIR ..."
        git clone "$REPO_URL" "$INSTALL_DIR"
        print_ok "Repository wurde geklont."
    fi
}

fix_permissions() {
    print_info "Setze Berechtigungen ..."
    find "$INSTALL_DIR" -type f -name "*.sh" -exec chmod +x {} \;
    print_ok "Berechtigungen gesetzt."
}

create_launcher() {
    print_info "Erstelle Starter unter /usr/local/bin/linux-secure-setup ..."

    cat > /usr/local/bin/linux-secure-setup <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cd /opt/linux-secure-setup
exec sudo bash ./menu.sh
EOF

    chmod +x /usr/local/bin/linux-secure-setup
    print_ok "Starter wurde erstellt."
}

show_finish_message() {
    echo
    print_ok "Installation abgeschlossen."
    echo
    echo "Starten mit:"
    echo "  sudo bash /opt/linux-secure-setup/menu.sh"
    echo
    echo "Oder kuerzer:"
    echo "  linux-secure-setup"
    echo
}

main() {
    require_root
    check_dependencies
    install_or_update_repo
    fix_permissions
    create_launcher
    show_finish_message
    cd "$INSTALL_DIR"
    exec bash ./menu.sh
}

main "$@"
