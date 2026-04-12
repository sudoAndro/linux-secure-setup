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
RUN_AS_USER="${SUDO_USER:-root}"

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
    print_err "Dieses Script muss mit sudo oder als root ausgefuehrt werden."
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

  if [[ ${#missing[@]} -gt 0 ]]; then
    print_info "Fehlende Pakete werden installiert: ${missing[*]}"
    apt update
    apt install -y "${missing[@]}"
  fi

  if ! command -v whiptail >/dev/null 2>&1; then
    print_info "whiptail fehlt. Wird installiert..."
    apt update
    apt install -y whiptail dialog ncurses-term
  fi
}

install_or_update_repo() {
  if [[ -d "$INSTALL_DIR/.git" ]]; then
    print_info "Bestehende Installation gefunden. Aktualisiere Repository ..."
    git -C "$INSTALL_DIR" fetch --all --prune
    git -C "$INSTALL_DIR" reset --hard origin/main
    print_ok "Repository wurde aktualisiert."
  else
    if [[ -d "$INSTALL_DIR" ]]; then
      print_warn "$INSTALL_DIR existiert bereits, ist aber kein Git-Repository."
      print_warn "Ordner wird entfernt und sauber neu erstellt."
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

  if id "$RUN_AS_USER" >/dev/null 2>&1; then
    chown -R "$RUN_AS_USER":"$RUN_AS_USER" "$INSTALL_DIR" || true
  fi

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

run_menu() {
  if [[ ! -f "$INSTALL_DIR/menu.sh" ]]; then
    print_err "menu.sh wurde in $INSTALL_DIR nicht gefunden."
    exit 1
  fi

  print_ok "Installation abgeschlossen."
  print_info "Starte Linux Secure Setup ..."
  cd "$INSTALL_DIR"
  exec bash ./menu.sh
}

main() {
  require_root
  check_dependencies
  install_or_update_repo
  fix_permissions
  create_launcher
  run_menu
}

main "$@"
