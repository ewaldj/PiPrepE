# PiPrepE (Pi Preparation Easy)

Automated post-install setup for Raspberry Pi OS (Trixie, arm64). Installs base network tools, optional GUI tools, custom tools and custom `.deb` packages in one run.
Built and tested on Raspberry Pi OS (Trixie). Debian and derivatives are not guaranteed to work.

## Start

Run in the Raspberry Pi shell:

```
bash <(wget --header="Cache-Control: no-cache" --no-check-certificate -qO- https://raw.githubusercontent.com/ewaldj/PiPrepE/refs/heads/main/piprepe_bootstrap.sh)
```

`piprepe_bootstrap.sh`:
- Installs `curl` and `sudo` if missing.
- Re-executes itself as root (`sudo`, or `su` if `sudo` is unavailable).
- Downloads and starts `piprepe.sh` from the `main` branch.

## Run sequence

1. Overview screen and confirmation prompt `[y/N]`.
2. Optional: new admin username and password (empty username = skip).
3. Prompt: install GUI tools and desktop environment `[y/N]`.
4. Unattended installation. Output is mirrored to `/var/log/piprepe.log`.
5. Summary (user, GUI, timezone, log, sources, skipped items).
6. Reboot prompt.

Packages not available via apt are skipped and listed under "Skipped items" in the summary.

## System setup

| Area | Action |
|---|---|
| apt | `update` + `upgrade`, non-interactive, `needrestart` set to automatic restart |
| GRUB | `grub-pc` target disk pre-seeded before apt runs, repaired after apt runs if left half-configured |
| Time | Timezone `Europe/Vienna`, NTP enabled |
| Shell | System-wide alias `ll='ls -la --color=auto'` in `/etc/bash.bashrc`, `TERM=vt220` mapped to `xterm-256color` |
| MOTD | Static MOTD and dynamic network MOTD (`/etc/update-motd.d/10-piprepe-network`) |
| Auto updates | `unattended-upgrades` installed, see below |
| Raspberry Pi | If `raspi-config` exists: boot mode without autologin, root filesystem expansion (reboot required) |

### Automatic updates

`/etc/apt/apt.conf.d/20auto-upgrades`:
- `Update-Package-Lists "1"`
- `Download-Upgradeable-Packages "1"`
- `AutocleanInterval "7"`
- `Unattended-Upgrade "1"`

`/etc/apt/apt.conf.d/52unattended-upgrades-local`:
- `Origins-Pattern`: `origin=*`
- `MinimalSteps`, `Remove-Unused-Dependencies`, `Remove-New-Unused-Dependencies`: `true`
- `Automatic-Reboot`, `InstallOnShutdown`: `false`
- `Dpkg::Options`: `--force-confdef`, `--force-confold`

Timers `apt-daily.timer`, `apt-daily-upgrade.timer` and `unattended-upgrades.service` are enabled.

## User management

- Optional: new user in group `sudo`.
- Invoking user is added to `sudo` if not a member.
- `joe` config per user: `:include /etc/joe/joerc`, `-nobackups`, `--wordwrap`.
- `tmux` config per user: `history-limit 100000`, `mouse on`.

## Base tools (apt)

| Category | Packages |
|---|---|
| Editor / terminal | `joe`, `tmux`, `screen`, `dialog`, `btop`, `bc` |
| Connectivity | `iputils-ping`, `traceroute`, `telnet`, `inetutils-ftp`, `curl`, `net-tools`, `ethtool`, `snmp`, `lldpd` |
| Scanning / capture | `nmap`, `fping`, `tcpdump`, `tcpreplay`, `netsniff-ng` (incl. `mausezahn`) |
| Performance | `iperf`, `iperf3` |
| Network / firewall | `iptables`, `ufw`, `network-manager` |
| Layer 2 testing | `yersinia` (`.deb` from `packages/`, requires `libnet9`) |
| Firmware | `firmware-iwlwifi`, `firmware-realtek`, `firmware-b43-installer`, `firmware-linux` |

## GUI tools (optional)

Installed only if GUI was selected at setup.

| Component | Detail |
|---|---|
| Desktop | `xfce4`, `xfce4-terminal`, `lightdm`, `lightdm-gtk-greeter` (only if `xfce4-session` is not installed) |
| Applications | `code` (Microsoft repository; fallback `code-oss`), `remmina`, `zenmap`, `firefox-esr`, `blueman`, `network-manager-gnome`, `qt6-wayland` |
| Remote access | `xrdp` |
| Wireshark | `wireshark-custom` 4.6.9 from `gui-packages/` (see below) |
| Default session | lightdm `user-session` set to `xfce` (X11) in `/etc/lightdm/lightdm.conf` (backup: `lightdm.conf.piprepe.bak`), `Session=` in `~/.dmrc` of invoking and new user; `autologin-session` is changed only if already set. Remote access: RDP (`xrdp`); VNC is not enabled. |
| xrdp keyboard | Per user `~/.xsessionrc` (`setxkbmap` values from `/etc/default/keyboard`) and `~/.xsession` (`startxfce4`) |

## Custom tools

Downloaded from GitHub to `/usr/local/bin` (mode 0755). A symlink without file extension is created for each tool (e.g. `eping` -> `eping.py`).

| Tool | Description | Source |
|---|---|---|
| `eping.py` | Parallel host reachability tester using fping + Python | [ewaldj/eping](https://github.com/ewaldj/eping) |
| `epinga.py` | Log analyzer for eping output | [ewaldj/eping](https://github.com/ewaldj/eping) |
| `esplit.py` | Log splitter for epinga analysis | [ewaldj/eping](https://github.com/ewaldj/eping) |
| `muxpi.sh` | tmux helper for iperf(3) parallel test sessions | [ewaldj/muxpi](https://github.com/ewaldj/muxpi) |
| `nm-e.sh` | Simplified nmcli interface | [ewaldj/nm-e](https://github.com/ewaldj/nm-e) |
| `mau-send.py`, `mau-recv.py` | Multicast and unicast traffic generator / receiver | [ewaldj/mau-tg](https://github.com/ewaldj/mau-tg) |
| `dscp-top.py` | Real-time DSCP traffic analyzer | [ewaldj/dscp-top](https://github.com/ewaldj/dscp-top) |
| `pmtu-diag.py` | Path MTU measurement in both directions, flags PMTUD black holes | [ewaldj/pmtu-diag](https://github.com/ewaldj/pmtu-diag) |
| `emtu-scan.py` | Host reachability and path-MTU (PMTUD) scanner for IP ranges | [ewaldj/emtu-scan](https://github.com/ewaldj/emtu-scan) |
| `usb-eth-notify` | Warning when USB Ethernet operates in USB 2.0 mode | [ewaldj/usb-eth-notify](https://github.com/ewaldj/usb-eth-notify) |

## Custom .deb packages

The script lists the folder content via the GitHub API (`main` branch) and downloads all `*.deb` files.

| Folder | Installed | Content |
|---|---|---|
| `packages/` | Always | `iperf3` 3.20, `libiperf0` 3.20, `yersinia` 0.8.2, `libnet9` 1.3 (all arm64) |
| `gui-packages/` | Only if GUI tools are selected | `wireshark-custom` 4.6.9 (arm64) |

Processing per folder:
1. Read package architecture with `dpkg-deb -f <file> Architecture`.
2. Keep packages with matching architecture or `all`; others are listed as skipped.
3. Install all kept files with one `apt install -y` call (dependencies resolved by apt).

### Package notes

- `iperf3` / `libiperf0`: Build 3.20-1 (arm64).
- `yersinia` 0.8.2-2.4 and `libnet9` 1.3+dfsg-3: Debian Forky (testing) arm64 builds. Package `yersinia` is not available in Debian 13 (Trixie). `libnet9` depends on `libc6 (>= 2.38)`.
- `wireshark-custom`: Installed to `/usr/local/bin`, `ldconfig` run in `postinst`. `dumpcap` gets `cap_net_raw,cap_net_admin+eip` via `setcap`. Package declares `Provides: wireshark, tshark` and `Conflicts: wireshark, wireshark-common, tshark`. Qt6 libraries are pulled in from apt.

### Add a package

1. Copy the `.deb` into `packages/` or `gui-packages/`.
2. Push to `main`.
3. No script change required.

Manual installation example:

```
sudo apt install ./libiperf0_3.20-1_arm64.deb ./iperf3_3.20-1_arm64.deb
```

## Repository layout

| Path | Content |
|---|---|
| `piprepe_bootstrap.sh` | Entry point: prerequisites, privilege escalation, starts `piprepe.sh` |
| `piprepe.sh` | Main setup script |
| `packages/` | `.deb` packages, always installed |
| `gui-packages/` | `.deb` packages, installed with GUI option |

## Notes

- Log: `/var/log/piprepe.log` (mode 600).
- Use `ll` for a colored long directory listing.
- Script version: variable `VERSION` in `piprepe.sh`.
