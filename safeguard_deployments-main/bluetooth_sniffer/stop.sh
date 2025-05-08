#!/usr/bin/sudo /bin/bash

cd /home/guard/bluetooth_sniffer

# Kill the bluetooth process currently running
read -r CAP_PID < cap_pid.txt
echo $CAP_PID
kill -9 $CAP_PID

exit 0
