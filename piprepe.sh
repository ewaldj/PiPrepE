#!/bin/bash

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
# PiPrepE.sh by ewald@jeitler.cc 2026 https://www.jeitler.guru
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
# codename: PiPrepE (Pi Preparation Easy) 
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
# When I wrote this code, only God and I knew how it worked.
# Now only God and the AI know it.
# And since the AI helped write it… good luck to all of us.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

set -euo pipefail

# Ensure sbin directories are in PATH (may be missing when called via bash <(wget ...))
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH}"

readonly VERSION="0.35"

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE="a"
export APT_LISTCHANGES_FRONTEND=none
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_FILE="/var/log/${SCRIPT_NAME%.*}.log"
readonly APT_CONFIG_DIR="/etc/apt/apt.conf.d"
readonly NEEDRESTART_CONFIG_DIR="/etc/needrestart/conf.d"
readonly LOCAL_BIN_DIR="/usr/local/bin"
readonly DEFAULT_TIMEZONE="Europe/Vienna"
readonly AUTHOR_NAME="Ewald Jeitler"
readonly AUTHOR_WEBSITE="https://www.jeitler.guru"
readonly MOTD_FILE="/etc/motd"
readonly MOTD_NETWORK_SCRIPT="/etc/update-motd.d/10-piprepe-network"
readonly JOE_INCLUDE_PATH="/etc/joe/joerc"
readonly GITHUB_PACKAGES_API_URL="https://api.github.com/repos/ewaldj/PiPrepE/contents/packages?ref=main"
readonly GITHUB_PACKAGES_REPO_PAGE="https://github.com/ewaldj/PiPrepE/tree/main/packages"
readonly TMUX_CONFIG_CONTENT=$'set-option -g history-limit 100000\nset-option -g mouse on\n'
readonly JOE_CONFIG_CONTENT=$':include /etc/joe/joerc\n-nobackups\n--wordwrap\n'
readonly BASH_ALIAS_LINE="alias ll='ls -la --color=auto'"
readonly DESKTOP_KEYBOARD_LAYOUT="at"
readonly DESKTOP_KEYBOARD_MODEL="pc105"
readonly BASIC_PACKAGES=(
    "joe"
    "dialog"
    "inetutils-ping"
    "inetutils-traceroute"
    "inetutils-telnet"
    "inetutils-ftp"
    "iptables"
    "tcpdump"
    "btop"
    "net-tools"
    "fping"
    "nmap"
    "curl"
    "tmux"
    "screen"
    "iperf"
    "iperf3" 
    "netsniff-ng"
    "tcpreplay"
    "bc"
    "network-manager"
    "ufw"
    "firmware-iwlwifi" 
    "firmware-realtek" 
    "firmware-b43-installer"
    "firmware-linux"
)

readonly GUI_PACKAGES=(
    "code"
    "wireshark"
    "remmina"
    "zenmap"
    "xrdp"
    "blueman"
    "firefox-esr"
)
readonly CUSTOM_GITHUB_TOOLS=(
    "eping.py|https://raw.githubusercontent.com/ewaldj/eping/main/eping.py"
    "epinga.py|https://raw.githubusercontent.com/ewaldj/eping/main/epinga.py"
    "esplit.py|https://raw.githubusercontent.com/ewaldj/eping/main/esplit.py"
    "muxpi.sh|https://raw.githubusercontent.com/ewaldj/muxpi/main/muxpi.sh"
    "nm-e.sh|https://raw.githubusercontent.com/ewaldj/nm-e/main/nm-e.sh"
    "mau-recv.py|https://raw.githubusercontent.com/ewaldj/mau-tg/main/mau-send.py"
    "mau-send.py|https://raw.githubusercontent.com/ewaldj/mau-tg/main/mau-send.py"
    "mau-time.py|https://raw.githubusercontent.com/ewaldj/mau-tg/main/mau-time.py"
)
readonly SYSTEM_BASHRC="/etc/bash.bashrc"
readonly TERM_FIX_BLOCK='if [ "$TERM" = "vt220" ]; then
    export TERM=xterm-256color
fi'


declare -a SKIPPED_ITEMS=()
TARGET_USERNAME=""
TARGET_PASSWORD=""
INVOKING_USERNAME=""
WIRESHARK_TARGET_USERNAME=""
DOWNLOAD_WORKSPACE=""
ROOTFS_EXPANSION_REQUESTED="false"
LIVE_PROGRESS_MODE="false"
USER_CREATION_REQUESTED="false"
GUI_INSTALL_REQUESTED="false"

if [[ "${EUID}" -ne 0 ]]; then
    ensure_interactive_terminal() {
        if [[ ! -t 0 || ! -t 1 || ! -t 2 ]]; then
            printf '%s
' "This script requires an interactive terminal." >&2
            exit 1
        fi
    }

    ensure_interactive_terminal

    if ! command -v sudo >/dev/null 2>&1; then
        printf '%s
' "This script must be run as root or with sudo, but sudo is not installed." >&2
        exit 1
    fi

    printf '%s
' "Root privileges are required. Please enter your sudo password to continue."
    sudo -v
    exec sudo --preserve-env=TERM bash "$0" "$@"
fi

cleanup() {
    if [[ -n "$DOWNLOAD_WORKSPACE" && -d "$DOWNLOAD_WORKSPACE" ]]; then
        rm -rf "$DOWNLOAD_WORKSPACE"
    fi
}

handle_error() {
    local exit_code="$1"
    local line_number="$2"
    local message="An error occurred at line ${line_number}. Check the log file: ${LOG_FILE}"

    printf '\nERROR: %s\n' "$message" >&2
    exit "$exit_code"
}

trap 'handle_error $? $LINENO' ERR
trap cleanup EXIT

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

print_status() {
    local message="$1"
    printf '\n[%s] %s\n' "$(date '+%F %T')" "$message"
}

ensure_interactive_terminal() {
    if [[ ! -t 0 || ! -t 1 || ! -t 2 ]]; then
        printf '%s\n' "This script requires an interactive terminal." >&2
        exit 1
    fi
}

ensure_directory_exists() {
    local directory_path="$1"

    if [[ ! -d "$directory_path" ]]; then
        printf '%s\n' "Required directory does not exist: $directory_path" >>"$LOG_FILE"
        return 1
    fi
}

ensure_directory_writable() {
    local directory_path="$1"

    if [[ ! -w "$directory_path" ]]; then
        printf '%s\n' "Directory is not writable: $directory_path" >>"$LOG_FILE"
        return 1
    fi
}

ensure_directory_exists_or_create() {
    local directory_path="$1"
    local parent_directory=""

    if [[ -d "$directory_path" ]]; then
        ensure_directory_writable "$directory_path"
        return 0
    fi

    parent_directory="$(dirname "$directory_path")"
    ensure_directory_exists "$parent_directory"
    ensure_directory_writable "$parent_directory"

    mkdir -p "$directory_path"
}

initialize_logging() {
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"
}

enable_live_progress_view() {
    local account_display=""

    exec > >(tee -a "$LOG_FILE") 2>&1
    LIVE_PROGRESS_MODE="true"

    if [[ "$USER_CREATION_REQUESTED" == "true" ]]; then
        account_display="$TARGET_USERNAME"
    else
        account_display="No new user requested"
    fi

    printf '\n============================================================\n'
    printf ' Automated setup started\n'
    printf ' Invoking user: %s\n' "$INVOKING_USERNAME"
    printf ' New admin account: %s\n' "$account_display"
    printf ' Wireshark group target: %s\n' "${WIRESHARK_TARGET_USERNAME:-none}"
    printf ' Live log file: %s\n' "$LOG_FILE"
    printf '============================================================\n'
}

run_logged_command() {
    local description="$1"
    shift

    printf '\n[%s] START: %s\n' "$(date '+%F %T')" "$description"
    "$@"
    printf '[%s] DONE:  %s\n' "$(date '+%F %T')" "$description"
}

apt_noninteractive() {
    apt-get \
        -o Dpkg::Options::=--force-confdef \
        -o Dpkg::Options::=--force-confold \
        "$@"
}

validate_username() {
    local candidate_username="$1"
    [[ "$candidate_username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]
}

trim_whitespace() {
    local value="$1"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

determine_invoking_username() {
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        INVOKING_USERNAME="${SUDO_USER}"
        return 0
    fi

    if command_exists logname; then
        INVOKING_USERNAME="$(logname 2>/dev/null || true)"
        if [[ -n "$INVOKING_USERNAME" && "$INVOKING_USERNAME" != "root" ]]; then
            return 0
        fi
    fi

    if [[ -n "${USER:-}" && "${USER}" != "root" ]]; then
        INVOKING_USERNAME="${USER}"
        return 0
    fi

    INVOKING_USERNAME="root"
}

display_startup_overview() {
    cat <<EOF_OVERVIEW

+----------------------------------------------------------------------------+
| PiPrepE - Pi Preparation Easy - by Ewald Jeitler
| https://www.jeitler.guru
+----------------------------------------------------------------------------+
| What this script does
+----------------------------------------------------------------------------+
|
| System setup
|   - apt update + upgrade (non-interactive, no prompts)
|   - Timezone set to Europe/Vienna, NTP enabled
|   - System-wide shell alias: ll='ls -la --color=auto'
|   - unattended-upgrades configured for automatic security updates
|   - Raspberry Pi specific settings (if raspi-config present):
|     boot mode, VNC, filesystem expansion
|
| User management
|   - Optional: create a new admin user with password (sudo group)
|   - Invoking user added to sudo group if not already a member
|   - Wireshark group membership for the target user
|   - joe + tmux config applied per user
|
| Base tools installed
|   joe, tmux, screen, curl, net-tools, nmap, fping, iptables,
|   tcpdump, tcpreplay, netsniff-ng (incl. mausezahn), btop,
|   inetutils (ping, traceroute, telnet, ftp), iperf, iperf3 dialog, ufw
|
| GUI tools (optional, asked at setup)
|   xfce4 + lightdm, wireshark,vs code, remmina,zenmap,xrdp 
|
| Custom tools by Ewald Jeitler (installed to /usr/local/bin)
|   eping          Parallel host reachability tester using fping + Python
|   epinga         Log analyzer for eping output
|   esplit         Log splitter for epinga analysis
|   muxpi          tmux helper for iperf(3) parallel test sessions
|   mau-tools      Multicast And Unicast Traffic Generator 
|   nm-e           Simplified nmcli interface
|   usb-eth-notify Warning when USB‑Ethernet operates in USB 2.0 mode
|
| GitHub .deb packages
|   Packages in PiPrepE/packages are installed automatically
|   (architecture-matched, e.g. iperf3 3.20 arm64)
|
| Useful notes
|   - Use 'll' for a colored long directory listing
|   - Full log written to /var/log/piprepe.log
+----------------------------------------------------------------------------+
| Enjoy the tools, have fun with network performance testing,
| and have a perfect day! - Ewald
+----------------------------------------------------------------------------+
EOF_OVERVIEW
}

prompt_to_continue() {
    local response=""

    while true; do
        printf '\nContinue with this setup? [y/N]: '
        IFS= read -r response
        response="$(trim_whitespace "$response")"

        case "${response,,}" in
            y|yes|j|ja)
                return 0
                ;;
            ""|n|no|nein)
                printf '%s\n' 'Setup cancelled by user.'
                exit 0
                ;;
            *)
                printf '%s\n' 'Please answer with y/yes or n/no.' >&2
                ;;
        esac
    done
}

prompt_for_username() {
    local entered_username=""

    while true; do
        printf '\nEnter the username for the new administrative account\n'
        printf '%s\n' 'Leave it empty and press Enter to skip user creation and only use the current user for the Wireshark group.'
        printf 'Username: '
        IFS= read -r entered_username
        entered_username="$(trim_whitespace "$entered_username")"

        if [[ -z "$entered_username" ]]; then
            USER_CREATION_REQUESTED="false"
            TARGET_USERNAME=""
            WIRESHARK_TARGET_USERNAME="$INVOKING_USERNAME"
            return 0
        fi

        if ! validate_username "$entered_username"; then
            printf '%s\n' 'Invalid username. Use lowercase letters, digits, underscore, or hyphen. The username must start with a lowercase letter or underscore.' >&2
            continue
        fi

        USER_CREATION_REQUESTED="true"
        TARGET_USERNAME="$entered_username"
        WIRESHARK_TARGET_USERNAME="$entered_username"
        return 0
    done
}

prompt_for_password() {
    local password_confirmation=""

    while true; do
        printf 'Enter the password for %s: ' "$TARGET_USERNAME"
        IFS= read -r -s TARGET_PASSWORD
        printf '\n'

        printf 'Confirm the password for %s: ' "$TARGET_USERNAME"
        IFS= read -r -s password_confirmation
        printf '\n'

        if [[ ${#TARGET_PASSWORD} -lt 8 ]]; then
            printf '%s\n' 'The password must be at least 8 characters long.' >&2
            continue
        fi

        if [[ "$TARGET_PASSWORD" != "$password_confirmation" ]]; then
            printf '%s\n' 'The passwords do not match. Please try again.' >&2
            continue
        fi

        return 0
    done
}

prompt_for_gui_installation() {
    local response=""

    while true; do
        printf '\nInstall GUI tools and desktop environment (xfce4 + wireshark + VS Code + xrdp etc.)? [y/N]: '
        IFS= read -r response
        response="$(trim_whitespace "$response")"

        case "${response,,}" in
            y|yes|j|ja)
                GUI_INSTALL_REQUESTED="true"
                return 0
                ;;
            ""|n|no|nein)
                GUI_INSTALL_REQUESTED="false"
                return 0
                ;;
            *)
                printf '%s\n' 'Please answer with y/yes or n/no.' >&2
                ;;
        esac
    done
}


collect_user_credentials() {
    print_status "Collecting account information..."
    prompt_for_username

    if [[ "$USER_CREATION_REQUESTED" == "true" ]]; then
        prompt_for_password
    else
        print_status "No new administrative user requested. The current invoking user will be used for the Wireshark group if possible."
    fi

    prompt_for_gui_installation
}

configure_needrestart() {
    if [[ -d "$NEEDRESTART_CONFIG_DIR" && -w "$NEEDRESTART_CONFIG_DIR" ]]; then
        cat >"${NEEDRESTART_CONFIG_DIR}/99-auto-restart-services.conf" <<'EOF_NEEDRESTART'
# Automatically restart services after package upgrades to avoid interactive prompts.
$nrconf{restart} = 'a';
EOF_NEEDRESTART
    fi
}

configure_wireshark_debconf() {
    if command_exists debconf-set-selections; then
        printf '%s\n' 'wireshark-common wireshark-common/install-setuid boolean true' | debconf-set-selections
    fi
}

is_package_available() {
    local package_name="$1"
    local candidate_version=""

    candidate_version="$(apt-cache policy "$package_name" 2>/dev/null | awk '/Candidate:/ {print $2}')" || true

    if [[ -n "$candidate_version" && "$candidate_version" != "(none)" ]]; then
        return 0
    fi

    # Fallback: apt-get dry-run is more reliable when apt-cache policy returns stale data
    apt_noninteractive install --dry-run "$package_name" >/dev/null 2>&1
}

resolve_package_name() {
    local requested_package="$1"

    case "$requested_package" in
        code)
            if is_package_available "code"; then
                printf '%s\n' "code"
                return 0
            fi

            if is_package_available "code-oss"; then
                printf '%s\n' "code-oss"
                return 0
            fi

            return 1
            ;;
        remmina)
            if is_package_available "remmina"; then
                printf '%s\n' "remmina"
                return 0
            fi

            return 1
            ;;
        *)
            if is_package_available "$requested_package"; then
                printf '%s\n' "$requested_package"
                return 0
            fi

            return 1
            ;;
    esac
}

setup_vscode_repository() {
    local arch=""
    local keyring_path="/etc/apt/keyrings/microsoft.gpg"
    local legacy_keyring_path="/usr/share/keyrings/microsoft.gpg"
    local sources_path="/etc/apt/sources.list.d/vscode.list"

    # Only amd64 and arm64 are supported by Microsoft
    arch="$(dpkg --print-architecture 2>/dev/null || true)"
    if [[ "$arch" != "amd64" && "$arch" != "arm64" ]]; then
        SKIPPED_ITEMS+=("VS Code repository not added: unsupported architecture (${arch})")
        return 0
    fi

    # Remove GPG key from legacy location if present to avoid
    # "Conflicting values set for option Signed-By" errors on re-runs
    if [[ -f "$legacy_keyring_path" ]]; then
        print_status "Removing Microsoft GPG key from legacy location..."
        rm -f "$legacy_keyring_path"
    fi

    # Remove any VS Code repo entries referencing a different key path
    # to prevent apt from seeing two conflicting Signed-By values
    sed -i '/packages\.microsoft\.com\/repos\/code/d' /etc/apt/sources.list 2>/dev/null || true
    find /etc/apt/sources.list.d/ -name "*.list" ! -name "vscode.list" \
        -exec sed -i '/packages\.microsoft\.com\/repos\/code/d' {} \; 2>/dev/null || true

    # Also remove conflicting .sources files (DEB822 format) for VS Code
    find /etc/apt/sources.list.d/ -name "*.sources" \
        -exec grep -l "packages\.microsoft\.com\/repos\/code" {} \; \
        | xargs -r rm -f




    if [[ -f "$sources_path" ]]; then
        print_status "VS Code repository already configured, skipping."
        return 0
    fi

    print_status "Adding Microsoft VS Code repository for ${arch}..."

    mkdir -p /etc/apt/keyrings

    # Ensure gnupg is available (not installed by default on minimal Debian)
    if ! command_exists gpg; then
        run_logged_command "Installing gnupg..." apt_noninteractive install -y gnupg
    fi

    run_logged_command "Downloading Microsoft GPG key..." \
        bash -c 'curl -fsSL --proto "=https" --tlsv1.2 https://packages.microsoft.com/keys/microsoft.asc \
            | gpg --dearmor --yes -o "'"$keyring_path"'"'

    printf '%s\n' \
        "deb [arch=${arch} signed-by=${keyring_path}] https://packages.microsoft.com/repos/code stable main" \
        > "$sources_path"

    run_logged_command "Updating package lists after adding VS Code repo..." apt_noninteractive update
}

install_package_group() {
    local description="$1"
    shift

    local -a requested_packages=("$@")
    local -a installable_packages=()
    local requested_package=""
    local resolved_package=""

    for requested_package in "${requested_packages[@]}"; do
        if resolved_package="$(resolve_package_name "$requested_package")"; then
            installable_packages+=("$resolved_package")
        else
            SKIPPED_ITEMS+=("Package unavailable: ${requested_package}")
        fi
    done

    if ((${#installable_packages[@]} > 0)); then
        run_logged_command "$description" apt_noninteractive install -y "${installable_packages[@]}"
    fi
}

is_desktop_environment_installed() {
    # Check for a running or configured display manager as indicator for an existing desktop
    if command_exists dpkg && dpkg -l 'task-desktop' 'xfce4' 'gnome-shell' 'lxde' 'mate-desktop-environment' 'xfce4-session' 'lxde-core' 2>/dev/null \
        | grep -q '^ii'; then
        return 0
    fi

    if command_exists systemctl && systemctl list-unit-files 2>/dev/null \
        | grep -qE '^(lightdm|gdm|sddm|xdm|nodm)\.service'; then
        return 0
    fi

    return 1
}

install_desktop_if_missing() {
    if is_desktop_environment_installed; then
        print_status "Desktop environment detected, skipping xfce4 installation."
        return 0
    fi

    print_status "No desktop environment detected. Installing xfce4 + lightdm..."
    run_logged_command "Installing xfce4 desktop..." \
        apt_noninteractive install -y xfce4 xfce4-terminal lightdm lightdm-gtk-greeter
}


ensure_python3_available() {
    if ! command_exists python3; then
        run_logged_command "Installing Python 3 for GitHub-hosted content..." apt_noninteractive install -y python3
    fi
}

fetch_github_packages_metadata() {
    local metadata_file="$1"

    run_logged_command "Fetching GitHub package metadata from PiPrepE/packages..." \
        curl -fsSL --proto '=https' --tlsv1.2 \
        -H 'Accept: application/vnd.github+json' \
        -o "$metadata_file" \
        "$GITHUB_PACKAGES_API_URL"
}

list_github_deb_packages() {
    local metadata_file="$1"

    python3 - "$metadata_file" <<'PY'
import json
import sys
from pathlib import Path

metadata_path = Path(sys.argv[1])
items = json.loads(metadata_path.read_text(encoding="utf-8"))

for item in items:
    if item.get("type") != "file":
        continue
    name = item.get("name", "")
    download_url = item.get("download_url", "")
    if name.endswith(".deb") and download_url:
        print(f"{name}|{download_url}")
PY
}

install_github_directory_deb_packages() {
    local metadata_file=""
    local packages_directory=""
    local current_architecture=""
    local deb_name=""
    local deb_url=""
    local downloaded_file=""
    local package_architecture=""
    local -a installable_deb_files=()
    local found_any_deb="false"

    prepare_download_workspace
    ensure_python3_available

    metadata_file="${DOWNLOAD_WORKSPACE}/github-packages.json"
    packages_directory="${DOWNLOAD_WORKSPACE}/github-deb-packages"
    current_architecture="$(dpkg --print-architecture)"

    mkdir -p "$packages_directory"
    fetch_github_packages_metadata "$metadata_file"

    while IFS='|' read -r deb_name deb_url; do
        if [[ -z "$deb_name" || -z "$deb_url" ]]; then
            continue
        fi

        found_any_deb="true"
        downloaded_file="${packages_directory}/${deb_name}"

        run_logged_command "Downloading package ${deb_name} from GitHub..." \
            curl -fsSL --proto '=https' --tlsv1.2 -o "$downloaded_file" "$deb_url"

        if [[ ! -s "$downloaded_file" ]]; then
            SKIPPED_ITEMS+=("Empty GitHub .deb download: ${deb_name}")
            continue
        fi

        package_architecture="$(dpkg-deb -f "$downloaded_file" Architecture 2>/dev/null || true)"
        if [[ -z "$package_architecture" ]]; then
            SKIPPED_ITEMS+=("Could not read package architecture: ${deb_name}")
            continue
        fi

        if [[ "$package_architecture" == "$current_architecture" || "$package_architecture" == "all" ]]; then
            installable_deb_files+=("$downloaded_file")
        else
            SKIPPED_ITEMS+=("GitHub package skipped due to architecture mismatch: ${deb_name} (${package_architecture} != ${current_architecture})")
        fi
    done < <(list_github_deb_packages "$metadata_file")

    if [[ "$found_any_deb" != "true" ]]; then
        SKIPPED_ITEMS+=("No .deb packages found in GitHub folder: ${GITHUB_PACKAGES_REPO_PAGE}")
        return 0
    fi

    if ((${#installable_deb_files[@]} == 0)); then
        SKIPPED_ITEMS+=("No compatible GitHub .deb packages were found for architecture: ${current_architecture}")
        return 0
    fi

    run_logged_command "Installing GitHub .deb packages from PiPrepE/packages..." \
        apt_noninteractive install -y "${installable_deb_files[@]}"
}

set_user_password() {
    printf '%s:%s\n' "$TARGET_USERNAME" "$TARGET_PASSWORD" | chpasswd
}

add_user_to_wireshark_group() {
    local username="$1"

    if [[ -z "$username" ]]; then
        SKIPPED_ITEMS+=("No user available for Wireshark group membership")
        return 0
    fi

    if ! id "$username" >/dev/null 2>&1; then
        SKIPPED_ITEMS+=("User not found for Wireshark group membership: ${username}")
        return 0
    fi

    if getent group wireshark >/dev/null 2>&1; then
        run_logged_command "Adding ${username} to wireshark group..." /usr/sbin/usermod -aG wireshark "$username"
    else
        SKIPPED_ITEMS+=("Group missing: wireshark")
    fi
}

get_user_home_directory() {
    local username="$1"
    getent passwd "$username" | cut -d: -f6
}

write_file_as_user() {
    local username="$1"
    local destination_path="$2"
    local file_content="$3"
    local home_directory=""
    local parent_directory=""
    local config_directory=""

    home_directory="$(get_user_home_directory "$username")"
    if [[ -z "$home_directory" || ! -d "$home_directory" ]]; then
        SKIPPED_ITEMS+=("Home directory missing for user: ${username}")
        return 0
    fi

    parent_directory="$(dirname "$destination_path")"
    mkdir -p "$parent_directory"
    printf '%s' "$file_content" >"$destination_path"

    # Ensure that any created user configuration directories remain writable
    # by the target user. This avoids permission issues such as a root-owned
    # ~/.config directory that would block desktop applications from creating
    # their own subdirectories later.
    if [[ "$parent_directory" == "$home_directory/.config"* ]]; then
        config_directory="$home_directory/.config"
        if [[ -d "$config_directory" ]]; then
            chown -R "$username:$username" "$config_directory"
        fi
    fi

    if [[ -e "$destination_path" ]]; then
        chown "$username:$username" "$destination_path"
    fi

    if [[ -d "$parent_directory" ]]; then
        chown -R "$username:$username" "$parent_directory"
    fi
}

configure_joe_for_user() {
    local username="$1"
    local user_home=""

    user_home="$(get_user_home_directory "$username")"
    if [[ -z "$user_home" ]]; then
        SKIPPED_ITEMS+=("Could not determine home directory for joe configuration: ${username}")
        return 0
    fi

    write_file_as_user "$username" "${user_home}/.joerc" "$JOE_CONFIG_CONTENT"
}

configure_tmux_for_user() {
    local username="$1"
    local user_home=""

    user_home="$(get_user_home_directory "$username")"
    if [[ -z "$user_home" ]]; then
        SKIPPED_ITEMS+=("Could not determine home directory for tmux configuration: ${username}")
        return 0
    fi

    write_file_as_user "$username" "${user_home}/.tmux.conf" "$TMUX_CONFIG_CONTENT"
}

configure_desktop_keyboard_for_user() {
    local username="$1"
    local user_home=""
    local labwc_environment_path=""

    user_home="$(get_user_home_directory "$username")"
    if [[ -z "$user_home" ]]; then
        SKIPPED_ITEMS+=("Could not determine home directory for desktop keyboard configuration: ${username}")
        return 0
    fi

    labwc_environment_path="${user_home}/.config/labwc/environment"
    write_file_as_user "$username" "$labwc_environment_path" \
$'XKB_DEFAULT_MODEL='"${DESKTOP_KEYBOARD_MODEL}"$'\nXKB_DEFAULT_LAYOUT='"${DESKTOP_KEYBOARD_LAYOUT}"$'\nXKB_DEFAULT_VARIANT=\nXKB_DEFAULT_OPTIONS=\n'
}

configure_system_bash_aliases() {
    if [[ ! -f "$SYSTEM_BASHRC" ]]; then
        SKIPPED_ITEMS+=("System bashrc not found: ${SYSTEM_BASHRC}")
        return 0
    fi
    if grep -Fqx "$BASH_ALIAS_LINE" "$SYSTEM_BASHRC"; then
        return 0
    fi
    cat >>"$SYSTEM_BASHRC" <<EOF_ALIAS
# Added by ${SCRIPT_NAME}
${BASH_ALIAS_LINE}
EOF_ALIAS

    # Add TERM fix if not already present
    if ! grep -Fq 'export TERM=xterm-256color' "$SYSTEM_BASHRC"; then
        cat >>"$SYSTEM_BASHRC" <<EOF_TERM

# Terminal fix for serial console - added by ${SCRIPT_NAME}
${TERM_FIX_BLOCK}
EOF_TERM
    fi
}

create_dynamic_network_motd() {
    # Create /etc/update-motd.d/ if it does not exist
    mkdir -p /etc/update-motd.d

    cat >"$MOTD_NETWORK_SCRIPT" <<'EOF_NETWORK_MOTD'
#!/bin/bash
# Dynamic network interface display - generated by PiPrepE
# Runs at every login via /etc/update-motd.d/

interfaces=()
while IFS= read -r line; do
    iface="${line%%:*}"
    # Skip loopback
    [[ "$iface" == "lo" ]] && continue
    # Only show interfaces that are UP
    if ip link show "$iface" 2>/dev/null | grep -q "state UP"; then
        interfaces+=("$iface")
    fi
done < <(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | awk '{print $1}')

if ((${#interfaces[@]} > 0)); then
    printf '+----------------------------------------------------------------------------+
'
    printf '| Network Interfaces                                                         |
'
    printf '+----------------------------------------------------------------------------+
'
    for iface in "${interfaces[@]}"; do
        addrs=()
        while IFS= read -r addr; do
            [[ -n "$addr" ]] && addrs+=("$addr")
        done < <(ip -o -4 addr show "$iface" 2>/dev/null | awk '{print $4}')
        while IFS= read -r addr; do
            [[ -n "$addr" ]] && addrs+=("$addr")
        done < <(ip -o -6 addr show "$iface" 2>/dev/null | grep -v 'fe80' | awk '{print $4}')
        if ((${#addrs[@]} > 0)); then
            printf '  %-12s %s
' "$iface" "${addrs[0]}"
            for addr in "${addrs[@]:1}"; do
                printf '  %-12s %s
' "" "$addr"
            done
        else
            printf '  %-12s (no address)
' "$iface"
        fi
    done
    printf '+----------------------------------------------------------------------------+
'
fi
EOF_NETWORK_MOTD

    chmod +x "$MOTD_NETWORK_SCRIPT"

    # Ensure PAM runs update-motd.d scripts on Debian
    # (on some minimal installs this may be disabled)
    if [[ -f /etc/pam.d/sshd ]]; then
        if ! grep -q "pam_motd.so.*motd_dir" /etc/pam.d/sshd 2>/dev/null; then
            if ! grep -q "pam_motd" /etc/pam.d/sshd 2>/dev/null; then
                printf '%s
' "session optional pam_motd.so motd=/run/motd.dynamic" >> /etc/pam.d/sshd
            fi
        fi
    fi
}

create_custom_motd() {
    cat >"$MOTD_FILE" <<'EOF_MOTD'
+----------------------------------------------------------------------------+
| PiPrepE - Pi Preparation Easy by Ewald Jeitler
| https://www.jeitler.guru
+----------------------------------------------------------------------------+
| Base tools installed
|   joe, tmux, screen, curl, net-tools, nmap, fping, iptables,
|   tcpdump, tcpreplay, netsniff-ng (incl. mausezahn), btop,
|   inetutils (ping, traceroute, telnet, ftp), iperf, dialog, ufw,
|   iperf, iperf3
|
| GUI tools (optional, asked at setup)
|   xfce4 + lightdm, wireshark,vs code, remmina,zenmap,xrdp 
|
| Custom tools by Ewald Jeitler (installed to /usr/local/bin)
|   eping          Parallel host reachability tester using fping + Python
|   epinga         Log analyzer for eping output
|   esplit         Log splitter for epinga analysis
|   muxpi          tmux helper for iperf(3) parallel test sessions
|   mau-tools      Multicast And Unicast Traffic Generator 
|   nm-e           Simplified nmcli interface
|   usb-eth-notify Warning when USB‑Ethernet operates in USB 2.0 mode
|
| Useful notes
|   - Use 'll' for a colored long directory listing
+----------------------------------------------------------------------------+
| Enjoy the tools, have fun with network performance testing,
| and have a perfect day! - Ewald
+----------------------------------------------------------------------------+

EOF_MOTD
}

configure_xrdp_keyboard() {
    # xrdp ignores /etc/default/keyboard — ~/.xsessionrc + ~/.xsession are the only reliable fix.
    local keyboard_file="/etc/default/keyboard"
    local xkblayout="" xkbmodel="" xkbvariant=""

    if [[ ! -f "$keyboard_file" ]]; then
        SKIPPED_ITEMS+=("xrdp keyboard fix skipped: ${keyboard_file} not found")
        return 0
    fi

    xkblayout="$( grep -E '^XKBLAYOUT=' "$keyboard_file" | cut -d= -f2 | tr -d '"' )"
    xkbmodel="$(  grep -E '^XKBMODEL='   "$keyboard_file" | cut -d= -f2 | tr -d '"' )"
    xkbvariant="$(grep -E '^XKBVARIANT=' "$keyboard_file" | cut -d= -f2 | tr -d '"' )"

    if [[ -z "$xkblayout" ]]; then
        SKIPPED_ITEMS+=("xrdp keyboard fix skipped: XKBLAYOUT not set in ${keyboard_file}")
        return 0
    fi

    local setxkbmap_cmd="setxkbmap -model ${xkbmodel:-pc105} -layout ${xkblayout}"
    [[ -n "$xkbvariant" ]] && setxkbmap_cmd="${setxkbmap_cmd} -variant ${xkbvariant}"

    print_status "xrdp keyboard: ${setxkbmap_cmd}"

    local u="" user_home=""
    local users_to_configure=()
    [[ -n "$INVOKING_USERNAME" && "$INVOKING_USERNAME" != "root" ]] &&         users_to_configure+=("$INVOKING_USERNAME")
    [[ "$USER_CREATION_REQUESTED" == "true" && -n "$TARGET_USERNAME" ]] &&         users_to_configure+=("$TARGET_USERNAME")

    for u in "${users_to_configure[@]}"; do
        if id "$u" >/dev/null 2>&1; then
            user_home="$(get_user_home_directory "$u")"
            if [[ -n "$user_home" && -d "$user_home" ]]; then
                write_file_as_user "$u" "${user_home}/.xsessionrc" "$setxkbmap_cmd"
                write_file_as_user "$u" "${user_home}/.xsession"   "startxfce4"
                print_status "xrdp keyboard+session written for ${u}"
            fi
        fi
    done
}

configure_user_customizations() {
    local username=""

    for username in "$INVOKING_USERNAME"; do
        if id "$username" >/dev/null 2>&1; then
            run_logged_command "Configuring joe for ${username}..." configure_joe_for_user "$username"
            run_logged_command "Configuring tmux for ${username}..." configure_tmux_for_user "$username"
        fi
    done

    if [[ "$USER_CREATION_REQUESTED" == "true" && -n "$TARGET_USERNAME" ]]; then
        if id "$TARGET_USERNAME" >/dev/null 2>&1; then
            run_logged_command "Configuring joe for ${TARGET_USERNAME}..." configure_joe_for_user "$TARGET_USERNAME"
            run_logged_command "Configuring tmux for ${TARGET_USERNAME}..." configure_tmux_for_user "$TARGET_USERNAME"
        fi
    fi

    if [[ "$GUI_INSTALL_REQUESTED" == "true" ]]; then
        run_logged_command "Configuring xrdp keyboard and session..." configure_xrdp_keyboard
    fi

    run_logged_command "Configuring system-wide shell aliases..." configure_system_bash_aliases
    run_logged_command "Creating custom MOTD..." create_custom_motd
    run_logged_command "Creating dynamic network MOTD..." create_dynamic_network_motd
}

configure_user_accounts() {
    if [[ "$USER_CREATION_REQUESTED" == "true" ]]; then
        ensure_directory_exists "/home"
        ensure_directory_writable "/home"

        if id "$TARGET_USERNAME" >/dev/null 2>&1; then
            print_status "Updating existing user ${TARGET_USERNAME}..."
        else
            run_logged_command "Creating user ${TARGET_USERNAME}..." /usr/sbin/useradd -m -s /bin/bash "$TARGET_USERNAME"
        fi

        run_logged_command "Setting password for ${TARGET_USERNAME}..." set_user_password

        if getent group sudo >/dev/null 2>&1; then
            run_logged_command "Adding ${TARGET_USERNAME} to sudo group..." /usr/sbin/usermod -aG sudo "$TARGET_USERNAME"
        else
            SKIPPED_ITEMS+=("Group missing: sudo")
        fi
    else
        print_status "Skipping new user creation because no username was provided."
    fi

    # Add the invoking user to the sudo group if not already a member
    if [[ -n "$INVOKING_USERNAME" && "$INVOKING_USERNAME" != "root" ]]; then
        if id "$INVOKING_USERNAME" >/dev/null 2>&1; then
            if getent group sudo >/dev/null 2>&1; then
                if ! id -nG "$INVOKING_USERNAME" 2>/dev/null | grep -qw sudo; then
                    run_logged_command "Adding invoking user ${INVOKING_USERNAME} to sudo group..." /usr/sbin/usermod -aG sudo "$INVOKING_USERNAME"
                else
                    print_status "Invoking user ${INVOKING_USERNAME} is already in the sudo group."
                fi
            fi
        fi
    fi

    add_user_to_wireshark_group "$WIRESHARK_TARGET_USERNAME"

    # Always also add the invoking user if different from WIRESHARK_TARGET_USERNAME
    if [[ -n "$INVOKING_USERNAME" && "$INVOKING_USERNAME" != "root"        && "$INVOKING_USERNAME" != "$WIRESHARK_TARGET_USERNAME" ]]; then
        add_user_to_wireshark_group "$INVOKING_USERNAME"
    fi

    unset TARGET_PASSWORD
    TARGET_PASSWORD=""
}

configure_auto_updates() {
    ensure_directory_exists "$APT_CONFIG_DIR"
    ensure_directory_writable "$APT_CONFIG_DIR"

    run_logged_command "Installing unattended-upgrades..." apt_noninteractive install -y unattended-upgrades

    cat >"${APT_CONFIG_DIR}/20auto-upgrades" <<'EOF_AUTO_UPGRADES'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF_AUTO_UPGRADES

    cat >"${APT_CONFIG_DIR}/52unattended-upgrades-local" <<'EOF_UNATTENDED'
Unattended-Upgrade::Origins-Pattern {
        "origin=*";
};

Unattended-Upgrade::Package-Blacklist {
};

Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::InstallOnShutdown "false";
Unattended-Upgrade::Automatic-Reboot "false";

Dpkg::Options {
        "--force-confdef";
        "--force-confold";
};
EOF_UNATTENDED

    if command_exists systemctl; then
        if systemctl list-unit-files 2>/dev/null | grep -q '^apt-daily\.timer'; then
            run_logged_command "Enabling APT automatic update timers..." systemctl enable --now apt-daily.timer apt-daily-upgrade.timer
        fi

        if systemctl list-unit-files 2>/dev/null | grep -q '^unattended-upgrades\.service'; then
            run_logged_command "Enabling unattended-upgrades service..." systemctl enable --now unattended-upgrades.service
        fi
    fi
}

determine_boot_mode_without_autologin() {
    local current_default_target=""

    current_default_target="$(systemctl get-default 2>/dev/null || true)"

    if [[ "$current_default_target" == "graphical.target" ]]; then
        printf '%s\n' "B3"
    else
        printf '%s\n' "B1"
    fi
}

configure_timezone_fallback() {
    if command_exists timedatectl; then
        run_logged_command "Setting timezone to ${DEFAULT_TIMEZONE}..." timedatectl set-timezone "$DEFAULT_TIMEZONE"
    else
        ln -snf "/usr/share/zoneinfo/${DEFAULT_TIMEZONE}" /etc/localtime
        printf '%s\n' "$DEFAULT_TIMEZONE" >/etc/timezone
    fi
}

enable_ntp() {
    if command_exists timedatectl; then
        if timedatectl set-ntp true; then
            return 0
        fi
    fi

    if command_exists systemctl && systemctl list-unit-files 2>/dev/null | grep -q '^systemd-timesyncd\.service'; then
        systemctl enable --now systemd-timesyncd.service
        return 0
    fi

    SKIPPED_ITEMS+=("No supported NTP service was found")
}

configure_system_time() {
    if command_exists raspi-config; then
        run_logged_command "Setting timezone to ${DEFAULT_TIMEZONE}..." raspi-config nonint do_change_timezone "$DEFAULT_TIMEZONE"
    else
        configure_timezone_fallback
    fi

    run_logged_command "Enabling NTP time synchronization..." enable_ntp
}

configure_raspberry_pi_settings() {
    local boot_mode=""

    if ! command_exists raspi-config; then
        SKIPPED_ITEMS+=("raspi-config not found; Raspberry Pi specific settings were skipped")
        return 0
    fi

    boot_mode="$(determine_boot_mode_without_autologin)"

    run_logged_command "Configuring Raspberry Pi boot mode without autologin..." raspi-config nonint do_boot_behaviour "$boot_mode"
    run_logged_command "Enabling Raspberry Pi VNC..." raspi-config nonint do_vnc 0
    run_logged_command "Expanding the root filesystem to maximum size..." raspi-config nonint do_expand_rootfs
    ROOTFS_EXPANSION_REQUESTED="true"
}

prepare_download_workspace() {
    if [[ -z "$DOWNLOAD_WORKSPACE" ]]; then
        DOWNLOAD_WORKSPACE="$(mktemp -d)"
    fi
}

create_command_symlink() {
    local installed_filename="$1"
    local source_path="${LOCAL_BIN_DIR}/${installed_filename}"
    local command_name="${installed_filename%.*}"
    local symlink_path="${LOCAL_BIN_DIR}/${command_name}"

    if [[ "$command_name" == "$installed_filename" ]]; then
        return 0
    fi

    run_logged_command "Creating command alias ${command_name}..." ln -sfn "$source_path" "$symlink_path"
}

install_remote_executable() {
    local tool_name="$1"
    local source_url="$2"
    local destination_directory="$3"
    local temporary_file=""

    prepare_download_workspace
    temporary_file="${DOWNLOAD_WORKSPACE}/${tool_name}"

    run_logged_command "Downloading ${tool_name} from GitHub..." \
        curl -fsSL --proto '=https' --tlsv1.2 -o "$temporary_file" "$source_url"

    if [[ ! -s "$temporary_file" ]]; then
        printf '%s\n' "Downloaded file is empty: $tool_name from $source_url" >>"$LOG_FILE"
        return 1
    fi

    run_logged_command "Installing ${tool_name} to ${destination_directory}..." \
        install -m 0755 "$temporary_file" "${destination_directory}/${tool_name}"

    create_command_symlink "$tool_name"
}

install_custom_github_tools() {
    local tool_definition=""
    local tool_name=""
    local source_url=""

    ensure_directory_exists_or_create "$LOCAL_BIN_DIR"
    ensure_python3_available

    for tool_definition in "${CUSTOM_GITHUB_TOOLS[@]}"; do
        tool_name="${tool_definition%%|*}"
        source_url="${tool_definition#*|}"
        install_remote_executable "$tool_name" "$source_url" "$LOCAL_BIN_DIR"
    done
}


prompt_for_reboot() {
    local response=""

    while true; do
        printf '
Would you like to reboot the system now? [y/N]: '
        IFS= read -r response
        response="$(trim_whitespace "$response")"

        case "${response,,}" in
            y|yes|j|ja)
                printf '%s
' 'Rebooting system now...'
                reboot
                ;;
            ""|n|no|nein)
                printf '%s
' 'Reboot skipped. You can reboot later manually if needed.'
                return 0
                ;;
            *)
                printf '%s
' 'Please answer with y/yes or n/no.' >&2
                ;;
        esac
    done
}

build_summary_message() {
    local reboot_note="No reboot is required right now."
    local new_user_summary="Skipped"
    local gui_summary="No"

    if [[ "$USER_CREATION_REQUESTED" == "true" ]]; then
        new_user_summary="$TARGET_USERNAME"
    fi

    if [[ "$GUI_INSTALL_REQUESTED" == "true" ]]; then
        gui_summary="Yes"
    fi

    if [[ "$ROOTFS_EXPANSION_REQUESTED" == "true" ]]; then
        reboot_note="Reboot recommended - filesystem expansion pending."
    elif [[ -f "/var/run/reboot-required" ]]; then
        reboot_note="Reboot recommended - pending package updates require it."
    fi

    printf '+----------------------------------------------------------------------------+\n'
    printf ' Setup completed successfully\n'
    printf '+----------------------------------------------------------------------------+\n'
    printf ' Invoking user         : %s\n' "$INVOKING_USERNAME"
    printf ' New admin user        : %s\n' "$new_user_summary"
    printf ' GUI tools installed   : %s\n' "$gui_summary"
    if [[ -n "$INVOKING_USERNAME" && "$INVOKING_USERNAME" != "root"        && "$INVOKING_USERNAME" != "$WIRESHARK_TARGET_USERNAME" ]]; then
        printf ' Wireshark group users : %s, %s\n' "${WIRESHARK_TARGET_USERNAME:-none}" "$INVOKING_USERNAME"
    else
        printf ' Wireshark group user  : %s\n' "${WIRESHARK_TARGET_USERNAME:-none}"
    fi
    printf ' Timezone              : %s\n' "$DEFAULT_TIMEZONE"
    printf ' Live log file         : %s\n' "$LOG_FILE"
    printf ' GitHub tools          : %s\n' "$LOCAL_BIN_DIR"
    printf ' GitHub .deb source    : %s\n' "$GITHUB_PACKAGES_REPO_PAGE"
    printf ' System alias          : %s\n' "$BASH_ALIAS_LINE"
    printf ' Desktop keyboard      : %s\n' "German (Austria)"
    printf '+----------------------------------------------------------------------------+\n'

    if ((${#SKIPPED_ITEMS[@]} > 0)); then
        printf ' Skipped items:\n'
        while IFS= read -r item; do
            printf '   - %s\n' "$item"
        done < <(printf '%s\n' "${SKIPPED_ITEMS[@]}" | sort -u)
    else
        printf ' Skipped items         : None\n'
    fi

    printf '+----------------------------------------------------------------------------+\n'
    printf ' %s\n' "$reboot_note"
    printf '+----------------------------------------------------------------------------+\n'
}

main() {
    ensure_interactive_terminal
    initialize_logging

    ensure_directory_exists "/var/log"
    ensure_directory_writable "/var/log"
    ensure_directory_exists "$APT_CONFIG_DIR"
    ensure_directory_writable "$APT_CONFIG_DIR"

    determine_invoking_username
    display_startup_overview
    prompt_to_continue

    print_status "Preparing setup..."
    collect_user_credentials
    enable_live_progress_view

    configure_needrestart
    configure_wireshark_debconf

    run_logged_command "Updating package lists..." apt_noninteractive update
    run_logged_command "Upgrading installed packages..." apt_noninteractive upgrade -y
    run_logged_command "Refreshing package lists after upgrade..." apt_noninteractive update

    install_package_group "Installing base tools..." "${BASIC_PACKAGES[@]}"

    if [[ "$GUI_INSTALL_REQUESTED" == "true" ]]; then
        setup_vscode_repository
        install_desktop_if_missing
        install_package_group "Installing GUI tools..." "${GUI_PACKAGES[@]}"
    else
        print_status "Skipping GUI tools and desktop installation as requested."
    fi

    configure_user_accounts
    configure_auto_updates
    configure_system_time
    configure_raspberry_pi_settings
    install_github_directory_deb_packages
    install_custom_github_tools
    configure_user_customizations
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/ewaldj/usb-eth-notify/refs/heads/main/e-install.sh)"
    printf '\n'
    build_summary_message
    printf '\n'
    prompt_for_reboot
}

main "$@"
