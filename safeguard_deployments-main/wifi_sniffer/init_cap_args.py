import psutil
import subprocess
import sys

def main():
    channel_allocations = ["1", "6", "11", "2,3,4,5", "10,9,8,7", "36,40,44,48", "149,153,157,161", "52,56,60,64,100,104,108,112,116,120,124,128,132,136,140,144"]
    filters = sys.argv[1:]
    
    nics = [nic for nic in psutil.net_if_addrs().keys() if any(nic.startswith(filter) for filter in filters)]

    if nics:
        cap_args_str = ""
    
        for nic, channels in zip(nics, channel_allocations):
            cap_args_str += f"--nic {nic} {channels} "
            
        print(f"{cap_args_str.strip()}")
    else:
        print("0")
        
if __name__ == "__main__":
    main()
    
