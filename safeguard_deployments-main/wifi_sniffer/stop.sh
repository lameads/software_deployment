#!/usr/bin/sudo /bin/bash

cd /home/guard/wifi_sniffer

read -r CAP_PID < cap_pid.txt
echo $CAP_PID

kill -9 $CAP_PID

source "./nic_env/bin/activate"

interfaces=$(python3 get_nics.py wlx wlan)
if [ "$interfaces" = "0" ]; then
    echo "ERROR: No interfaces found after setting to monitor mode"
    exit 0
fi
for iface in $interfaces; do
    ifconfig "$iface" down
done

sudo systemctl start NetworkManager

# May want to activate the ethernet ports for communication with the LPR camera (not sure if we need to do this)
ethernet_interfaces=$(python3 get_nics.py en)
if [ "$ethernet_interfaces" = "0" ]; then
    echo "ERROR: No ethernet interfaces found"
fi
for iface in $ethernet_interfaces; do
    ifconfig "$iface" up
done

deactivate

exit 0
