#!/usr/bin/sudo /bin/bash

parent_dir="/home/guard/wifi_sniffer"
cd $parent_dir
location_config="/home/guard/location_config.txt"
backups_dir="/home/guard/wifi_sniffer/backups"
pem_key_dir="/home/guard/.ssh/keys/sgs_stats_api1.pem"

expected_nic_count=8

read -r CAP_PID < cap_pid.txt
echo $CAP_PID
kill -9 $CAP_PID

# Create the backups directory if it doesn't already exist
if [ ! -d "$backups_dir" ]; then
    mkdir -p "$backups_dir"
fi

source "./nic_env/bin/activate"
interfaces=$(python3 get_nics.py wlx wlan)

if [ "$interfaces" = "0" ]; then
    echo "ERROR: No interfaces found"
    exit 0
fi
for iface in $interfaces; do
    echo "ifconfig $iface down"
    ifconfig $iface down
done

systemctl start NetworkManager

# Start the ethernet interfaces
ethernet_interfaces=$(python3 get_nics.py en)
if [ "$ethernet_interfaces" = "0" ]; then
    echo "ERROR: No ethernet interfaces found"
    exit 0
fi
for iface in $ethernet_interfaces; do
    echo "ifconfig $iface up"
    ifconfig $iface up
done

# Send all files in the folders up to the api server
ARR=()
IFS= read -r line < "$location_config"
ARR[0]="$line"

echo "Location Config File Param: ${ARR[0]}"

year=$(date +%y)
month=$(date +%m)
day=$(date +%d)
hour=$(date +%H)
minute=$(date +%M)

# Iterate through all wlan cap directories
for dir in $(find "$parent_dir" -type d -name 'wlan*'); do
    # echo "$dir"
    # Zip all pcap files and copy to backups folder
    for file in "$dir"/*.pcap; do
        if [ -f "$file" ]; then
            echo "$file lskjlk"
            filename=$(basename "$file")
            extension="${filename##.}"
            echo "$extension"
            filename="${filename%.*}"

            cp "$file" "$backups_dir/${filename}.pcap"
            zip -j "$dir/${filename}.zip" "$file"
            rm "$file"
        fi
    done

    # Send all zip files in the directory up to the server
    file_count=0
    for zipfile in "$dir"/*.zip; do
        # CUR_TIME=$(date '+%Y-%m-%d %H:%M:%S')
        i=0
        SEND_SUCCESS=false
        file_count=$((file_count+1))
        echo "this is hitting"
        if [ -f "$zipfile" ]; then
            filename=$(basename "$zipfile")
            echo "hit3"
            # Retry sending up to 2 times
            while [ "$i" -le 2 ]; do
                echo "hit4"
                sudo -u guard scp -i "$pem_key_dir" "$zipfile" "safeguard_stats@api.safeguardsolutions.org:~/pcap_unprocessed_wifi/${ARR[0]}_${year}:${month}:${day}:${hour}:${minute}:${file_count}.zip"
                if [ $? -eq 0 ]; then
                    echo "success hit"
                    SEND_SUCCESS=true
                    break
                else
                    echo $?
                fi
                echo $i
                i=$((i+1))
                sleep 2
            done
            if [ "$SEND_SUCCESS" = "false" ]; then
                echo "ERROR: Could not send file $filename to server" >&2
            else
                rm "$zipfile"
            fi
        fi
    done
done


# Restart the capture
airmon-ng check kill

interfaces=$(python3 get_nics.py wlx wlan)
if [ "$interfaces" = "0" ]; then
    echo "ERROR: No NICs found"
    exit 1
fi

iface_count=$(echo "$interfaces" | wc -w)
if [ "$iface_count" -lt "$expected_nic_count" ]; then
    echo "Warning: Only $iface_count interfaces found. Expected $expected_nic_count."
fi

for iface in $interfaces; do
    ifconfig "$iface" up
    airmon-ng start "$iface"
done

airmon-ng check kill

interfaces=$(python3 get_nics.py wlx wlan)
if [ "$interfaces" = "0" ]; then
    echo "ERROR: No interfaces found after setting to monitor mode"
    exit 0
fi
for iface in $interfaces; do
    ifconfig "$iface" up
done

# May want to activate the ethernet ports for communication with the LPR camera (not sure if we need to do this)
ethernet_interfaces=$(python3 get_nics.py en)
if [ "$ethernet_interfaces" = "0" ]; then
    echo "ERROR: No ethernet interfaces found"
fi
for iface in $ethernet_interfaces; do
    ifconfig "$iface" up
done



echo "Setup Finished"

sniff_args=$(python3 init_cap_args.py wlx)
if [ "$sniff_args" = "0" ]; then
    echo "ERROR: Could not initialize capture arguments for wifi capture"
    exit 1
fi

deactivate

# ./sniff --nic wlx00c0cab58dd9 1 --nic wlx00c0cab58ddc 6 --nic wlx00c0cab58dde 11 --nic wlx00c0cab58e4f 2,3,4,5 --nic wlx00c0cab58f31 10,9,8,7 --nic wlx00c0cab58f41 36,40,44,48 --nic wlx00c0cab58f51 149,153,157,161 --nic wlx00c0cab58f52 52,56,60,64,100,104,108,112,116,120,124,128,132,136,140,144 &
./sniff $sniff_args &
CAP_PID=$!
echo "$CAP_PID" > cap_pid.txt

exit 0
