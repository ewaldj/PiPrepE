# PiPrepE  (Pi Preparation Easy)

Built and tested on Raspberry Pi OS (Trixie). It will probably run on Debian and similar systems too — just no guarantees.

## Copy this command into your Raspberry Pi shell to start the installation.
```
bash <(wget --header="Cache-Control: no-cache" --no-check-certificate -qO- https://raw.githubusercontent.com/ewaldj/PiPrepE/refs/heads/main/piprepe_bootstrap.sh)
```

## THIS IS A BETA VERSION! 


```
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
|   nm-e           Simplified nmcli interface
|   mau-tools      Multicast And Unicast Traffic Generator 
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
  ```
