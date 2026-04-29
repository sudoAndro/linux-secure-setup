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

    sed -i -E "s|^[#[:space:]]*${key}[[:space:]]+.*|#${key} replaced|g" "$SSHD_CONFIG"
    echo "${key} ${value}" >> "$SSHD_CONFIG"
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
    systemctl daemon-reload
    systemctl restart ssh.service
}

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
    local first_line

    msg_box "SSH Public Key" "Die Datei authorized_keys wird jetzt geoeffnet:\n\n$auth_keys\n\nFuege deinen Public Key aus Windows oder einem anderen System ein.\n\nSpeichern in nano:\nCTRL+O, Enter\nBeenden:\nCTRL+X"

    nano "$auth_keys" </dev/tty >/dev/tty 2>&1

    if [[ ! -s "$auth_keys" ]]; then
        msg_box "Fehler" "Die Datei authorized_keys ist leer.\n\nEs wurde kein Public Key gespeichert."
        return 1
    fi

    first_line="$(grep -m1 -E '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-|sk-ssh-ed25519@openssh.com|sk-ecdsa-sha2-)' "$auth_keys" || true)"

    if [[ -z "$first_line" ]]; then
        msg_box "Fehler" "Die Datei enthaelt keinen gueltigen OpenSSH Public Key.\n\nBitte oeffne das Modul erneut und fuege einen gueltigen Key ein."
        return 1
    fi

    chown "$username:$username" "$auth_keys"
    chmod 600 "$auth_keys"

    msg_box "SSH Key" "Public Key wurde gespeichert."
    return 0
}

step_harden_ssh() {
    local port="$1"
    local username="$2"

    cp "$SSHD_CONFIG" "$SSHD_BACKUP"

    # Drop-in Ordner prüfen und bereinigen
    if [ -d /etc/ssh/sshd_config.d ]; then
        for f in /etc/ssh/sshd_config.d/*.conf; do
            [ -f "$f" ] && sed -i -E "s|^[#[:space:]]*Port[[:space:]]+.*||g" "$f" || true
        done
    fi

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

    msg_box "Wichtig" "Teste JETZT in einem ZWEITEN Terminal den neuen Login.\n\nBeispiel:\nssh -p $port $username@SERVER-IP\n\nDie aktuelle Sitzung offen lassen.\n\nErst wenn das funktioniert, darf Root deaktiviert werden."

    if yes_no_box "SSH Test" "Hat der Login mit dem SSH-Key erfolgreich funktioniert?"; then
        msg_box "Erfolg" "SSH wurde erfolgreich konfiguriert.\n\nUser: $username\nPort: $port\n\nRoot-Login bleibt deaktiviert."
    else
        rollback_ssh_config
        msg_box "Rollback ausgefuehrt" "Die SSH-Konfiguration wurde wiederhergestellt.\n\nBitte pruefe den Public Key und versuche es erneut."
        exit 1
    fi
}

main "$@"
