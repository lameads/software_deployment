import psutil
import sys

def main():
    filters = sys.argv[1:]
    
    # nics = [nic for nic in psutil.net_if_addrs().keys() if any(nic.startswith(filter) for filter in filters)]
    nics = [nic for nic in psutil.net_if_addrs().keys()]
    
    series_24_port = "enp1s0f0"
    series_23_port = "enp2s0"
    
    for nic in nics:
        if nic == series_24_port:
            print("24")     # 24 series port found
            return
        elif nic == series_23_port:
            print("23")     # 23 series port found
            return
        
    print("0")  # No NICs found
        
if __name__ == "__main__":
    main()
