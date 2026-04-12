#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

ensure_ui_environment
require_root
require_whiptail

SSHD_CONFIG="/etc/ssh/sshd_config"
SSHD_BACKUP="/etc/ssh/sshd_config.bak.$(date +%Y%m%d-%H%M%S)"

STEP_USERNAME=""
STEP_AUTH_KEYS=""

set_sshd_option() {
    local key="$1"
    local value="$2"

    if grep -qE "^[#[:space:]]*${key}[[:space:]]+" "$SSHD_CONFIG"; then
        sed -i -E "s|^[#[:space:]]*${key}[[:space:]]+.*|${key} ${value}|g" "$SSHD_CONFIG"
    else
        printf '%s %s\n' "$key" "$value" >> "$SSHD_CONFIG"
    fi
}

ensure_ssh_server_installed() {
    if ! command -v sshd >/dev/null 2>&1; then
        if yes_no_box "OpenSSH fehlt" "openssh-server ist nicht installiert.\n\nSoll es jetzt installiert werden?"; then
            apt update
            apt install -y openssh-server
        else
            msg_box "Abgebrochen" "Ohne openssh-server kann dieses Modul nicht fortfahren."
            exit 0
        fi
    fi
}

restart_ssh_service() {
    if systemctl list-unit-files | grep -q '^ssh\.service'; then
        systemctl restart ssh
        return 0
    fi

    if systemctl list-unit-files | grep -q '^sshd\.service'; then
        systemctl restart sshd
        return 0
    fi

    msg_box "Warnung" "Kein Dienstname ssh oder sshd erkannt.\n\nBitte SSH-Dienst manuell neu starten."
    return 1
}

verify_ssh_port() {
    local expected_port="$1"
    local listening
    local tmp_file

    listening="$(ss -tulpn 2>/dev/null | grep ssh || true)"

    if echo "$listening" | grep -Eq "[:.]${expected_port}[[:space:]]"; then
        return 0
    fi

    tmp_file="$(mktemp)"
    {
        echo "SSH hoert NICHT auf dem erwarteten Port ${expected_port}."
        echo
        echo "Aktuelle SSH Listener:"
        echo
        echo "$listening"
    } > "$tmp_file"

    textbox_file "SSH Port Fehler" "$tmp_file"
    rm -f "$tmp_file"

    return 1
}

rollback_ssh_config() {
    if [[ -f "$SSHD_BACKUP" ]]; then
        cp "$SSHD_BACKUP" "$SSHD_CONFIG"
        restart_ssh_service || true
    fi
}

step_user() {
    local username password password2

    username="$(input_box "Admin User" "Benutzernamen eingeben:" "")" || return 1
    username="$(printf '%s' "$username" | tr -cd 'a-zA-Z0-9_-')"

    if [[ -z "$username" ]]; then
        msg_box "Fehler" "Benutzername ist leer oder ungueltig."
        return 1
    fi

    if id "$username" >/dev/null 2>&1; then
        if ! id -nG "$username" | grep -qw sudo; then
            usermod -aG sudo "$username"
            msg_box "Admin User" "Benutzer '$username' existiert bereits\nund wurde zur sudo-Gruppe hinzugefuegt."
        else
            msg_box "Admin User" "Benutzer '$username' existiert bereits."
        fi
    else
        while true; do
            password="$(password_box "Passwort" "Passwort fuer '$username' eingeben:")" || return 1
            password2="$(password_box "Passwort bestaetigen" "Passwort erneut eingeben:")" || return 1

            if [[ -z "$password" ]]; then
                msg_box "Fehler" "Passwort darf nicht leer sein."
                continue
            fi

            if [[ "$password" != "$password2" ]]; then
                msg_box "Fehler" "Die Passwoerter stimmen nicht ueberein."
                continue
            fi

            break
        done

        useradd -m -s /bin/bash "$username"
        echo "${username}:${password}" | chpasswd
        usermod -aG sudo "$username"
        msg_box "Admin User" "Benutzer '$username' wurde erstellt\nund zur sudo-Gruppe hinzugefuegt."
    fi

    STEP_USERNAME="$username"
    return 0
}

step_prepare_ssh_dir() {
    local username="$1"
    local home_dir ssh_dir auth_keys

    home_dir="$(getent passwd "$username" | cut -d: -f6)"

    if [[ -z "$home_dir" ]]; then
        msg_box "Fehler" "Home-Verzeichnis fuer Benutzer '$username' konnte nicht ermittelt werden."
        return 1
    fi

    ssh_dir="$home_dir/.ssh"
    auth_keys="$ssh_dir/authorized_keys"

    mkdir -p "$ssh_dir"
    touch "$auth_keys"
    chown -R "$username:$username" "$ssh_dir"
    chmod 700 "$ssh_dir"
    chmod 600 "$auth_keys"

    msg_box "SSH Verzeichnis" "SSH-Verzeichnis vorbereitet:\n\n$auth_keys"
    STEP_AUTH_KEYS="$auth_keys"
    return 0
}

step_insert_key() {
    local username="$1"
    local auth_keys="$2"
    local default_key_path
    local pubkey_path
    local pubkey_content

    default_key_path="/home/${SUDO_USER:-$USER}/.ssh/id_ed25519.pub"

    clear >/dev/tty 2>/dev/null || true
    echo >/dev/tty
    echo "============================================================" >/dev/tty
    echo " SSH Public Key" >/dev/tty
    echo "============================================================" >/dev/tty
    echo >/dev/tty
    echo "Gib den PFAD zu deinem Public Key ein." >/dev/tty
    echo "Beispiel:" >/dev/tty
    echo "  $default_key_path" >/dev/tty
    echo >/dev/tty
    echo "Druecke einfach ENTER, um den Standardpfad zu verwenden." >/dev/tty
    echo >/dev/tty

    read -r -p "Public-Key-Pfad [$default_key_path]: " pubkey_path < /dev/tty

    if [[ -z "$pubkey_path" ]]; then
        pubkey_path="$default_key_path"
    fi

    pubkey_path="$(printf '%s' "$pubkey_path" | tr -d '\r')"

    if [[ ! -f "$pubkey_path" ]]; then
        msg_box "Fehler" "Datei nicht gefunden:\n\n$pubkey_path"
        return 1
    fi

    pubkey_content="$(head -n 1 "$pubkey_path" | tr -d '\r')"

    if [[ -z "$pubkey_content" ]]; then
        msg_box "Fehler" "Die Public-Key-Datei ist leer."
        return 1
    fi

    case "$pubkey_content" in
        ssh-ed25519\ *|ssh-rsa\ *|ecdsa-sha2-*\ *|sk-ssh-ed25519@openssh.com\ *|sk-ecdsa-sha2-*\ *)
            ;;
        *)
            msg_box "Fehler" "Die Datei sieht nicht wie ein gueltiger OpenSSH Public Key aus."
            return 1
            ;;
    esac

    mkdir -p "$(dirname "$auth_keys")"
    printf '%s\n' "$pubkey_content" > "$auth_keys"
    chown "$username:$username" "$auth_keys"
    chmod 600 "$auth_keys"

    msg_box "SSH Key" "Public Key wurde erfolgreich uebernommen:\n\n$pubkey_path"
}

step_harden_ssh() {
    local port="$1"
    local username="$2"

    cp "$SSHD_CONFIG" "$SSHD_BACKUP"

    set_sshd_option "Port" "$port"
    set_sshd_option "PermitRootLogin" "no"
    set_sshd_option "PasswordAuthentication" "no"
    set_sshd_option "PubkeyAuthentication" "yes"
    set_sshd_option "ChallengeResponseAuthentication" "no"
    set_sshd_option "KbdInteractiveAuthentication" "no"
    set_sshd_option "UsePAM" "yes"
    set_sshd_option "MaxAuthTries" "3"
    set_sshd_option "LoginGraceTime" "30"
    set_sshd_option "AllowUsers" "$username"
}

main() {
    ensure_ssh_server_installed

    msg_box "SSH Setup" "Dieses Modul richtet folgendes ein:\n\n1. Admin-User anlegen oder nutzen\n2. SSH-Verzeichnis vorbereiten\n3. Public Key eintragen\n4. SSH haerten\n\nRoot wird erst ganz am Schluss gesperrt."

    step_user || exit 0
    local username="$STEP_USERNAME"

    if [[ -z "$username" ]]; then
        msg_box "Fehler" "Kein gueltiger Benutzername."
        exit 1
    fi

    step_prepare_ssh_dir "$username" || exit 0
    local auth_keys="$STEP_AUTH_KEYS"

    if [[ -z "$auth_keys" ]]; then
        msg_box "Fehler" "authorized_keys Pfad konnte nicht ermittelt werden."
        exit 1
    fi

    step_insert_key "$username" "$auth_keys" || exit 0

    local port
    port="$(prompt_port)" || exit 0

    if ! yes_no_box "Bestaetigung" \
"SSH-Konfiguration die gesetzt wird:

User:                   $username
Port:                   $port
PermitRootLogin:        no
PasswordAuthentication: no
PubkeyAuthentication:   yes
MaxAuthTries:           3
LoginGraceTime:         30

Fortfahren?"; then
        msg_box "Abgebrochen" "Keine Aenderungen vorgenommen."
        exit 0
    fi

    step_harden_ssh "$port" "$username"

    if ! sshd -t; then
        rollback_ssh_config
        msg_box "Fehler" "sshd -t fehlgeschlagen.\n\nAlte Konfiguration wurde wiederhergestellt."
        exit 1
    fi

    if systemctl is-enabled ssh.socket >/dev/null 2>&1 || systemctl is-active --quiet ssh.socket 2>/dev/null; then
        systemctl disable --now ssh.socket || true
        systemctl mask ssh.socket || true
    fi

    restart_ssh_service || true
    sleep 1

    if ! verify_ssh_port "$port"; then
        rollback_ssh_config
        msg_box "Rollback" "Alte SSH-Konfiguration wurde wiederhergestellt.\n\nRoot wird NICHT gesperrt."
        exit 1
    fi

    if ! yes_no_box "Root Login deaktivieren" \
"SSH lauscht erfolgreich auf Port $port.\n\nSoll PermitRootLogin no gesetzt bleiben und root per SSH gesperrt bleiben?"; then
        set_sshd_option "PermitRootLogin" "yes"
        if sshd -t; then
            restart_ssh_service || true
            msg_box "Hinweis" "Root-Login wurde wieder erlaubt."
        else
            rollback_ssh_config
            msg_box "Fehler" "Konfiguration ungueltig. Backup wurde wiederhergestellt."
            exit 1
        fi
    fi

    msg_box "Erfolg" "SSH wurde erfolgreich konfiguriert.\n\nUser: $username\nPort: $port\n\nTeste jetzt in einem ZWEITEN Terminal zuerst den Login, bevor du die aktuelle Sitzung schliesst."
}

main "$@"
