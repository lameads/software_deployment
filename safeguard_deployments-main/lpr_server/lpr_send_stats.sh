#!/usr/bin/sudo /bin/bash

# This script is executed by crontab at set increments to send the locally accumulated lpr_cap.csv file up to the server for parsing and insertion into the database.

cd /home/guard/lpr_server

# Read the txt config file to get send location and file name for the deployment
# An array is used here only because we used to read multiple lines from the config.txt file. Now we only require the location name and have done away with location id, so we no longer need to 
# read in more than one line from the config.txt file.
location_config="/home/guard/location_config.txt"
ARR=("")
j=0
while IFS= read -r line; do
    ARR[$j]="$line"
    j=$((j+1))
    if [ "$j" -gt "0" ]; then
        break
    fi
done < "$location_config"  

for file in /home/guard/lpr_server/lpr_cap/*.csv; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        extension="${filename##*.}"
        filename="${filename%.*}"

        # Create backup file with timestamp
        year=$(date +%Y)
        month=$(date +%m)
        day=$(date +%d)
        hour=$(date +%H)
        minute=$(date +%M)
	    seconds=$(date +%S)
        # Check when the file has last been modified. If it has been modified more than 5 minutes ago, then copy it up to the server
        CURRENT_TIME=$(date +%s)
        FILE_MOD_TIME=$(stat -c %Y "$file")
        TIME_DIFF=$((CURRENT_TIME - FILE_MOD_TIME))
	
        # If the file line count is greater than or equal to 100 lines, copy it up as well
        line_count=$(wc -l < "$file")
	
        if [[ "$line_count" -ge 100 || "$TIME_DIFF" -ge 300 ]]; then
            # wc -l is used to check number of lines in a file. If the number of lines is less than 100, we don't copy or scp the file (skip)
            cp "$file" "/home/guard/lpr_server/backups/${filename}_${ARR[0]}_${year}:${month}:${day}:${hour}:${minute}:${seconds}.csv"

            # Zip the original file
            zip -j "/home/guard/lpr_server/lpr_cap/${filename}.zip" "$file"

            # Remove the original CSV file
            rm "$file"
        fi
    fi
done

sleep 5

SEND_SUCCESS=false
CUR_TIME=$(date '+%Y-%m-%d %H:%M:%S')
i=0
file_count=0
for zipfile in /home/guard/lpr_server/lpr_cap/*.zip; do
    file_count=$((file_count+1))
    if [ -f "$zipfile" ]; then
        filename=$(basename "$zipfile")
        # Retry sending up to 2 times
        while [ "$i" -le 2 ]; do
            sudo -u guard scp -i /home/guard/.ssh/keys/sgs_stats_api1.pem "$zipfile" "safeguard_stats@api.safeguardsolutions.org:~/unprocessed_lpr/${ARR[0]}_${year}:${month}:${day}:${hour}:${minute}:${file_count}.zip" 
            
            if [ $? -eq 0 ]; then
                SEND_SUCCESS=true
                break
            else
                echo $?
            fi
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

# # Check if all files were sent successfully
# if $SEND_SUCCESS; then
#     echo "Sent all LPR capture files $CUR_TIME" >> send.log
#     echo "Sent all LPR capture files"
    

#     # rm -f /home/guard/lpr_server/backups/*.csv
#     rm -f /home/guard/lpr_server/lpr_cap/*.zip
    
#     # Recreate lpr_cap directory if it's removed accidentally
#     mkdir -p /home/guard/lpr_server/lpr_cap

# else
#     echo "Error: Could not send all LPR capture files $CUR_TIME. Retrying next time." >> send.log
# fi

exit 0
