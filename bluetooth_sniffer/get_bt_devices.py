import subprocess

# This script searches for all available bluetooth devices on the machine, prioritizin the use of the UD-100 device. We use up to 2 bluetooth devices but 
# allow for the use of 1 device if a device goes down. If both are down then we will exit with a response of "0", at which point the bluetooth stats 
# send script will error out.

device_macs = []

try:
    result = subprocess.run(["bluetoothctl", "list"], capture_output=True, text=True)
    if result.returncode == 0:
        devices = result.stdout.strip().split("\n")
        if devices:
            # devices.append("Controller 00:01:12:34:56:78")
            # devices.append("Controller 80:21:12:34:56:78")
            # devices.append("Controller 00:01:85:76:98:20")
            # print(devices)
            for device in devices:
                if device.startswith("Controller"):
                    str_arr = device.split(" ")
                    mac_addr = str_arr[1]
                    device_macs.append(mac_addr)
                    
            # Sort so that a device with MAC address 00:01 is the first device listed in the output string
            device_macs.sort(key=lambda mac: (not mac.startswith("00:01"), mac))
            if len(device_macs) < 2:
                print(f"{device_macs[0]}")
            else:
                out_list = []
                for i in range(2):
                    out_list.append(device_macs[i])
                    
                print(f"{out_list[0]} {out_list[1]}")
                
            
        else:
            print("0")
            # print("Error: No devices found")
    else:
        print("0")
        # print("Error: Failed to find bluetooth devices")
except:
    print("0")
    # print("bluetoothctl not found. Be sure that it is installed")
    
