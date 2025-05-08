#!/usr/bin/sudo /bin/bash

project_dir=$(dirname "$(realpath "$0")")

# Read all directories containing "wlan" into the wlan_dirs array
readarray -d '' wlan_dirs < <(find "$project_dir" -type d -name "wlan*" -print0)

for dir in "${wlan_dirs[@]}"; do
    echo "Cleaning directory: $dir"
    cd "$dir"
    rm *.pcap
    rm *.zip
    cd "$project_dir"
done

exit 0