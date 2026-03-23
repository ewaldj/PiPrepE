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

readonly VERSION="0.12"

readonly BOOTSTRAP_URL="https://raw.githubusercontent.com/ewaldj/PiPrepE/refs/heads/main/piprepe_bootstrap.sh"
readonly PIPREPE_URL="https://raw.githubusercontent.com/ewaldj/PiPrepE/refs/heads/main/piprepe.sh"
readonly BOOTSTRAP_TMPFILE="/tmp/piprepe_bootstrap_$$.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# If not root: download ourselves to a real temp file, then re-exec as root
# via sudo (Raspberry Pi) or su (Debian without sudo).
# This is necessary because bash <(wget ...) gives us no real path on disk,
# so sudo/su cannot re-execute $0 directly.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

if [[ "${EUID}" -ne 0 ]]; then

    printf '%s\n' "[bootstrap] Downloading bootstrap to temp file for privilege escalation..."
    wget --header="Cache-Control: no-cache" --no-check-certificate -qO "$BOOTSTRAP_TMPFILE" "$BOOTSTRAP_URL"
    chmod +x "$BOOTSTRAP_TMPFILE"

    if command -v sudo >/dev/null 2>&1; then
        printf '%s\n' "[bootstrap] Root privileges required. Please enter your sudo password."
        exec sudo --preserve-env=TERM bash "$BOOTSTRAP_TMPFILE" "$@"
    else
        printf '%s\n' "[bootstrap] sudo not found. Please enter the root password."
        exec su -c "bash '$BOOTSTRAP_TMPFILE'" root
    fi

fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# From here on we are root
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

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
