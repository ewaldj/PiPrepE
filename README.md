# piprepe.sh 


## Copy this command into your Raspberry Pi shell to start the installation
```
sudo /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/ewaldj/PiPrepE/refs/heads/main/piprepe.sh)"
```

## THIS IS A BETA VERSION! 


```
+----------------------------------------------------------------------------+
| PiPrepE Raspberry Pi / Debian bootstrap script
| Author  : Ewald Jeitler 
| Website : https://www.jeitler.guru
+----------------------------------------------------------------------------+

This script performs the following actions automatically:

  1. Updates the system package lists and upgrades installed packages
  2. Installs base tools:
     joe, dialog, ping/traceroute/telnet/ftp, iptables, tcpdump, btop,
     net-tools, fping, nmap, curl, tmux, screen, iperf, iperf3,
     netsniff-ng, tcpreplay
  3. Installs GUI tools:
     VS Code or code-oss, Wireshark, Remmina, Zenmap, XRDP
  4. Optionally creates or updates one administrative user and adds it to:
     sudo and Wireshark (if the Wireshark group exists)
  5. If no new username is entered, no new account is created and only the
     current invoking user is added to the Wireshark group when possible
  6. Enables unattended automatic updates without automatic reboot
  7. Configures Raspberry Pi / system settings:
     - disable autologin
     - enable VNC
     - set timezone to ${DEFAULT_TIMEZONE}
     - enable NTP time synchronization
     - expand the root filesystem to the maximum SD card size
  8. Downloads and installs custom tools to ${LOCAL_BIN_DIR}:
     eping.py, epinga.py, esplit.py, muxpi.sh
  9. Creates extensionless command aliases for downloaded scripts:
     eping, epinga, esplit, muxpi
 10. Configures editors and shells:
     - joe config for current user and optional new user
     - tmux config for current user and optional new user
     - system-wide alias in /etc/bash.bashrc: ${BASH_ALIAS_LINE}
 11. Creates a custom MOTD with a short overview of installed tools
 12. If a new user is created, configures the Raspberry Pi desktop keyboard
     for that user to German (Austria)

Notes:
  - Run this script with sudo or as root.
  - The script does not reboot automatically.
  - Some changes, especially filesystem expansion, are fully active after a
    later manual reboot.
  - A detailed log is written to ${LOG_FILE}
  ```
