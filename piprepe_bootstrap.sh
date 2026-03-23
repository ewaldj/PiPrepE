#!/bin/bash

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# PiPrepE Bootstrap by ewald@jeitler.cc 2026 https://www.jeitler.guru
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Universal bootstrapper for PiPrepE.
# Works on Debian (as root or normal user) and Raspberry Pi OS (sudo user).
# SSL check disabled to handle systems with wrong system time.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Usage (identical on both platforms):
#
#   bash <(wget --header="Cache-Control: no-cache" --no-check-certificate -qO- https://raw.githubusercontent.com/ewaldj/PiPrepE/refs/heads/main/piprepe_bootstrap.sh)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

set -euo pipefail

readonly PIPREPE_URL="https://raw.githubusercontent.com/ewaldj/PiPrepE/refs/heads/main/piprepe.sh"
readonly BOOTSTRAP_TMPFILE="/tmp/piprepe_bootstrap_$$.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# When called via bash <(wget ...) the script has no real path on disk.
# To allow re-execution as root (sudo / su), we write ourselves to a
# temp file first, then re-exec from there.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

if [[ "${EUID}" -ne 0 ]]; then

    # If $0 is not a real file (e.g. /dev/fd/62), save ourselves to disk first
    if [[ ! -f "$0" ]]; then
        # bash exposes the script source on fd 255 when using process substitution
        cp "/proc/$$/fd/255" "$BOOTSTRAP_TMPFILE" 2>/dev/null || {
            printf '%s\n' "[bootstrap] ERROR: Could not save bootstrap script to a temporary file." >&2
            printf '%s\n' "[bootstrap] Please run as root directly: su -c 'bash <(wget ...)' root" >&2
            exit 1
        }
        chmod +x "$BOOTSTRAP_TMPFILE"
        exec bash "$BOOTSTRAP_TMPFILE" "$@"
    fi

    # Re-execute as root via sudo or su
    if command -v sudo >/dev/null 2>&1; then
        printf '%s\n' "[bootstrap] Root privileges required. Please enter your sudo password."
        exec sudo --preserve-env=TERM bash "$0" "$@"
    else
        printf '%s\n' "[bootstrap] sudo not found. Please enter the root password (su)."
        exec su -c "bash '$0'" root
    fi

fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# From here on we are root
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Clean up temp file if we created one
[[ -f "$BOOTSTRAP_TMPFILE" ]] && rm -f "$BOOTSTRAP_TMPFILE"

install_prerequisites() {
    local missing_packages=()

    command -v curl >/dev/null 2>&1 || missing_packages+=("curl")
    command -v sudo >/dev/null 2>&1 || missing_packages+=("sudo")

    if [[ ${#missing_packages[@]} -eq 0 ]]; then
        return 0
    fi

    printf '[bootstrap] Installing missing packages: %s\n' "${missing_packages[*]}"
    apt-get update -qq
    apt-get install -y --no-install-recommends "${missing_packages[@]}"
}

printf '%s\n' "[bootstrap] Starting PiPrepE bootstrap..."
install_prerequisites
printf '%s\n' "[bootstrap] Launching piprepe.sh..."
bash <(wget --no-check-certificate -qO- "$PIPREPE_URL")