Launch this script, then the machine corresponding at the given MAC address will start if Wake On LAN has been configured in its BIOS.

This script will not stop until the remote machine has been detected as running (magic packets will be sent every 20 seconds until the machine is reachable).

Notes: Replace the default "00-00-00-00-00-00" MAC address directly by editing the script.


This script is based on https://gist.github.com/alimbada/4949168#file-wake-ps1
