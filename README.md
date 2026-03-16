# PiPrepE  (Pi Preparation Easy)

Built and tested on Raspberry Pi OS (Trixie). It will probably run on Debian and similar systems too — just no guarantees.

## Copy this command into your Raspberry Pi shell to start the installation.
```
sudo /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/ewaldj/PiPrepE/refs/heads/main/piprepe.sh)"
```

## THIS IS A BETA VERSION! 


```
+----------------------------------------------------------------------------+
| Raspberry Pi Network Toolkit
| Prepared by Ewald Jeitler
| https://www.jeitler.guru
+----------------------------------------------------------------------------+
| Installed tools overview - partial list only
+----------------------------------------------------------------------------+
|
| Tools by Ewald Jeitler
|   eping       High-performance tool using fping and Python to test
|               thousands of hosts in parallel with integrated logging.
|   epinga      Tool for analyzing eping log files.
|   esplit      Tool for splitting large log files for epinga analysis.
|   muxpi       tmux-based Raspberry Pi helper for running iperf(3) and
|               other CLI tools in parallel test sessions with logging.
|   nm-e        A simplified interface for nmcli 
|
| Performance testing
|   iperf       Classic network throughput tester.
|   iperf3      Modern client/server bandwidth measurement tool.
|
| Monitoring and packet analysis
|   btop        Interactive monitor for CPU, memory, and network usage.
|   tcpdump     Command-line packet capture and inspection tool.
|   tcpreplay   Replay captured packets onto an interface.
|   netsniff-ng High-performance networking toolkit.
|   mausezahn   Packet generator included with netsniff-ng.
|
| Additional package source
|   GitHub .deb packages from PiPrepE/packages are installed automatically.
|   Current example: iperf3 3.20 arm64 packages from the repository folder.
|
| Useful notes
|   - Use 'll' for a colored long directory listing.
|   - All tools listed above can be run without file extensions.
+----------------------------------------------------------------------------+
| Enjoy the tools, have fun with network performance testing,
| and have a perfect day! - Ewald
+----------------------------------------------------------------------------+

  ```
