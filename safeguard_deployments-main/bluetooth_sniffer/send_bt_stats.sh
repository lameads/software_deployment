#!/usr/bin/sudo /bin/bash

cd /home/guard/bluetooth_sniffer

backups_dir="/home/guard/bluetooth_sniffer/backups"
hci0_dir="/home/guard/bluetooth_sniffer/hci0_cap_le"
hci1_dir="/home/guard/bluetooth_sniffer/hci1_cap_classic"

# Kill the bluetooth process currently running
read -r CAP_PID < cap_pid.txt
echo $CAP_PID
kill -9 $CAP_PID

# Create the backups directory if it doesn't already exist
if [ ! -d "$backups_dir" ]; then
    mkdir -p "$backups_dir"
fi
# Create capture directories if needed
if [ ! -d "$hci0_dir" ]; then
    mkdir -p "$hci0_dir"
fi
if [ ! -d "$hci1_dir" ]; then
    mkdir -p "$hci1_dir"
fi

# Send all files in the folders up to the api server
location_config="/home/guard/location_config.txt"
ARR=()
IFS= read -r line < "$location_config"
ARR[0]="$line"

echo "Location Config File Param: ${ARR[0]}"

year=$(date +%y)
month=$(date +%m)
day=$(date +%d)
hour=$(date +%H)
minute=$(date +%M)

for file in /home/guard/bluetooth_sniffer/hci0_cap_le/*.csv; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        extension="${filename##*.}"
        filename="${filename%.*}"

        # Check when the file has last been modified. If it has been modified more than 5 minutes ago, then copy it up to the server
        CURRENT_TIME=$(date +%s)
        FILE_MOD_TIME=$(stat -c %Y "$file")
        TIME_DIFF=$((CURRENT_TIME - FILE_MOD_TIME))

        cp "$file" "/home/guard/bluetooth_sniffer/backups/${filename}.csv"

        # Zip the original file
        zip -j "/home/guard/bluetooth_sniffer/hci0_cap_le/${filename}.zip" "$file"

        # Remove the original CSV file
        rm "$file"  
    fi
done

for file in /home/guard/bluetooth_sniffer/hci1_cap_classic/*.csv; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        extension="${filename##*.}"
        filename="${filename%.*}"

        # Check when the file has last been modified. If it has been modified more than 5 minutes ago, then copy it up to the server
        CURRENT_TIME=$(date +%s)
        FILE_MOD_TIME=$(stat -c %Y "$file")
        TIME_DIFF=$((CURRENT_TIME - FILE_MOD_TIME))

        cp "$file" "/home/guard/bluetooth_sniffer/backups/${filename}.csv"

        # Zip the original file
        zip -j "/home/guard/bluetooth_sniffer/hci1_cap_classic/${filename}.zip" "$file"

        # Remove the original CSV file
        rm "$file" 
    fi
done

####### Send all zip files and delete them after sending #########

SEND_SUCCESS=false
CUR_TIME=$(date '+%Y-%m-%d %H:%M:%S')
i=0
file_count=0
for zipfile in /home/guard/bluetooth_sniffer/hci0_cap_le/*.zip; do
    file_count=$((file_count+1))
    echo "this is hitting"
    if [ -f "$zipfile" ]; then
        filename=$(basename "$zipfile")
        echo "hit3"
        # Retry sending up to 2 times
        while [ "$i" -le 2 ]; do
            echo "hit4"
            sudo -u guard scp -i /home/guard/.ssh/keys/sgs_stats_api1.pem "$zipfile" "safeguard_stats@api.safeguardsolutions.org:~/unprocessed_bluetooth/${ARR[0]}_le_${year}:${month}:${day}:${hour}:${minute}:${file_count}.zip"
             
            if [ $? -eq 0 ]; then
                echo "success hit"
                SEND_SUCCESS=true
                break
            else
                echo $?
            fi
            echo i
            i=$((i+1))
            sleep 2
        done

        if [ "$SEND_SUCCESS" = "false" ]; then
            echo "Error: Could not send file $filename to server." >&2
        else 
            rm "$zipfile"
        fi
    fi
    SEND_SUCCESS=false
done

SEND_SUCCESS=false
i=0
file_count=0
CUR_TIME=$(date '+%Y-%m-%d %H:%M:%S')
for zipfile in /home/guard/bluetooth_sniffer/hci1_cap_classic/*.zip; do
    file_count=$((file_count+1))
    echo "this is hitting"
    if [ -f "$zipfile" ]; then
        filename=$(basename "$zipfile")
        echo "hit3"
        # Retry sending up to 2 times
        while [ "$i" -le 2 ]; do
            echo "hit4"
            sudo -u guard scp -i /home/guard/.ssh/keys/sgs_stats_api1.pem "$zipfile" "safeguard_stats@api.safeguardsolutions.org:~/unprocessed_bluetooth/${ARR[0]}_classic_${year}:${month}:${day}:${hour}:${minute}:${file_count}.zip"
             
            if [ $? -eq 0 ]; then
                echo "success hit"
                SEND_SUCCESS=true
                break
            else
                echo $?
            fi
            echo i
            i=$((i+1))
            sleep 2
        done

        if [ "$SEND_SUCCESS" = "false" ]; then
            echo "Error: Could not send file $filename to server." >&2
        else 
            rm "$zipfile"
        fi
    fi
    SEND_SUCCESS=false
done

# Turn the bluetooth adapters on and off to be safe. Shouldn't need this but I'm adding it as an extra precaution to ensure that things work properly.
hciconfig hci0 down
hciconfig hci0 up
hciconfig hci1 down
hciconfig hci1 up

# Restart the capture (only need this if we stop the capture to send, which I don't think we need to)
source "bt_env/bin/activate"
interface_args=$(python3 get_bt_devices.py)
if [ "$interface_args" = "0" ]; then
    echo "ERROR: Could not get bluetooth devices"
    exit 1
fi
deactivate

./bt_scanners $interface_args &
CAP_PID=$!
echo "$CAP_PID" > cap_pid.txt

exit 0
