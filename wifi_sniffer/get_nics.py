import psutil
import subprocess
import sys

def main():
    filters = sys.argv[1:]
    
    nics = [nic for nic in psutil.net_if_addrs().keys() if any(nic.startswith(filter) for filter in filters)]
    
    # nics = [nic for nic in psutil.net_if_addrs().keys() if (nic.startswith("wlx") or nic.startswith("wlan"))]

    # Prepare arguments as a space-separated string
    nic_args = " ".join(nics)

    # Print the NICs that were found
    # print(f"Available NICs: {nic_args}")

    if nics:
        # TODO: call the C program from this script or return the string to the bash script so it can call the C program. I'm thinking it will be best to call from the 
        # bash script as that would require slightly less modification (I think).
        # subprocess.run(["./your_program"] + nics)
        print(f"{nic_args}")
    else:
        print("0")
        
if __name__ == "__main__":
    main()
    

