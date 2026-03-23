#!/bin/bash

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# PiPrepE Bootstrap by ewald@jeitler.cc 2026 https://www.jeitler.guru
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Universal bootstrapper for PiPrepE.
# Works on Debian (as root) and Raspberry Pi OS (as sudo user).
# SSL check disabled to handle systems with wrong system time.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Usage (identical on both platforms):
#
#   bash <(wget --no-check-certificate -qO- https://raw.githubusercontent.com/ewaldj/PiPrepE/refs/heads/main/piprepe_bootstrap.sh)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

set -euo pipefail

readonly PIPREPE_URL="https://raw.githubusercontent.com/ewaldj/PiPrepE/refs/heads/main/piprepe.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Re-execute as root if needed
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

if [[ "${EUID}" -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
        printf '%s\n' "[bootstrap] ERROR: Not running as root and sudo is not installed." >&2
        printf '%s\n' "[bootstrap] Please run this script as root." >&2
        exit 1
    fi
    printf '%s\n' "[bootstrap] Root privileges required. Please enter your sudo password."
    exec sudo --preserve-env=TERM bash "$0" "$@"
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# From here on we are root
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

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
bash <(wget --header="Cache-Control: no-cache" --no-check-certificate -qO- "$PIPREPE_URL")