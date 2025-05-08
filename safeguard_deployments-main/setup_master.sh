#!/bin/bash

location="$1"
box_id="$2"

# Install dependencies for wifi capture
sudo apt install -y aircrack-ng git python3.12-venv
sudo apt-get install -y libpcap-dev libbluetooth-dev dkms

sudo apt-get update
# sudo apt-get install -y openssh-server openvpn
sudo apt-get install openssh-server openvpn iptables-persistent arp-scan -y
echo 'AUTOSTART="all"' | sudo tee -a /etc/default/openvpn > /dev/null
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf

# Use a python script to determine whether we are dealing with a 23 or 24 series box. Determine this based on the ethernet port names, as they are different between boxes. The
# enp1s0f0 corresponds to 24 series boxes while enp2s0 corresponds to 23 series boxes. Depending on which one we are dealing with we will install a specific netplan.

cd ~/safeguard_deployments

mv wifi_sniffer ~
mv lpr_server ~
mv bluetooth_sniffer ~
mv np_requirements.txt ~
mv get_box_series.py ~

sudo iptables -t nat -A POSTROUTING -o enp1s0f0 -j MASQUERADE

cd ~

python3 -m venv np_env

source "np_env/bin/activate"
if [[ "$VIRTUAL_ENV" != "" ]]; then
    echo "Virtual environment activated: $VIRTUAL_ENV"
    
    # Install np_requirements.txt
    if [ -f "np_requirements.txt" ]; then
        echo "Installing np_requirements..."
        pip3 install -r np_requirements.txt
    else
        echo "np_requirements.txt not found"
        exit 1
    fi

    # Get the box series
    box_series=$(python3 get_box_series.py)
    if [ "$box_series" = "0" ]; then
        echo "Return 0, could not determine box series. Exiting..."
        exit 1
    elif [ "$box_series" = "24" ]; then
        # Add netplan for 24 series box
        echo "Found 24 series box. Adding netplan for 24 series..."
        cat <<EOF | sudo tee /etc/netplan/50-cloud-init.yaml > /dev/null
network:
  version: 2
  ethernets:
    enp1s0f0:
      addresses: [192.168.50.199/24]  # Static IP for enp1s0f0
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]  # DNS servers
      routes:
        - to: 0.0.0.0/0  # Default route for internet access
          via: 192.168.50.1  # Gateway
    enp1s0f1:
      addresses: [192.168.2.1/24]  # Static IP for enp1s0f1
      dhcp4: false
      optional: true
    enp1s0f2:
      addresses: [192.168.3.1/24]  # Static IP for enp1s0f2
      dhcp4: false
      optional: true
    enp1s0f3:
      addresses: [192.168.4.1/24]  # Static IP for enp1s0f3
      dhcp4: false
      optional: true
EOF

        sudo apt install dnsmasq -y
        # We shouldn't need the two lines below because we use sudo tee. If we used sudo tee -a then we would need these two lines as that would append to the file instead of overwrite it.
        sudo systemctl stop dnsmasq
        sudo rm /etc/dnsmasq.conf
        sudo touch /etc/dnsmasq.conf
        cat <<EOF sudo tee /etc/dnsmasq.conf > /dev/null
#dnsmasq:

port=5353

# Listen on the specified interfaces
interface=enp1s0f1
interface=enp1s0f2
interface=enp1s0f3

# Specify the domain name
domain-needed
bogus-priv

# DNS settings (e.g., using Google DNS)
server=8.8.8.8
server=8.8.4.4

# DHCP settings for enp1s0f1
dhcp-range=enp1s0f1,192.168.2.10,192.168.2.50,12h  # IP range and lease time
dhcp-option=enp1s0f1,3,192.168.50.199  # Default gateway for enp1s0f1
dhcp-option=enp1s0f1,6,8.8.8.8,8.8.4.4  # DNS servers

# DHCP settings for enp1s0f2
dhcp-range=enp1s0f2,192.168.3.10,192.168.3.50,12h  # Different IP range
dhcp-option=enp1s0f2,3,192.168.50.199  # Default gateway for enp1s0f2
dhcp-option=enp1s0f2,6,8.8.8.8,8.8.4.4  # DNS servers

# DHCP settings for enp1s0f3
dhcp-range=enp1s0f3,192.168.4.10,192.168.4.50,12h  # Different IP range
dhcp-option=enp1s0f3,3,192.168.50.199  # Default gateway for enp1s0f3
dhcp-option=enp1s0f3,6,8.8.8.8,8.8.4.4  # DNS servers
EOF

        sudo systemctl enable dnsmasq
        sudo systemctl start dnsmasq
        
    elif [ "$box_series" = "23" ]; then
        # Add netplan for 23 series box
        echo "Found 23 series box. Adding netplan for 23 series..."
        cat <<EOF | sudo tee /etc/netplan/50-cloud-init.yaml > /dev/null
network:
  version: 2
  ethernets:
    enp2s0:
      addresses: [192.168.50.199/24]  # Static IP for enp1s0f0
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]  # DNS servers
      routes:
        - to: 0.0.0.0/0  # Default route for internet access
          via: 192.168.50.1  # Gateway
EOF
    else
        echo "Unknown error while getting box series. Exiting..."
        exit 1
    fi
else
    echo "Failed to activate wifi sniffer virtual environment"
    exit 1
fi
deactivate


sudo apt install -y net-tools nginx zip

sudo touch /var/log/lpr_bash.log
sudo chmod 777 /var/log/lpr_bash.log

sudo touch /var/log/wifi_bash.log
sudo chmod 777 /var/log/wifi_bash.log

sudo touch /var/log/bt_bash.log
sudo chmod 777 /var/log/bt_bash.log

cd ~

touch location_config.txt
echo "$location" > location_config.txt

touch box_id.txt
echo "$box_id" > box_id.txt

# Install driver for the NICs
git clone -b v5.6.4.2 https://github.com/aircrack-ng/rtl8812au.git
cd rtl8812au
git checkout 63cf0b4584aa8878b0fe8ab38017f31c319bde3d
sudo make dkms_install

echo "Finished dependency install"

############## Begin initial setup for the deployment ##############

if [ -d "~/.ssh" ]; then
  echo ".ssh directory exists"
  cd ~/.ssh
else
  echo ".ssh directory does not exist. Making one"
  mkdir ~/.ssh
  chmod 700 ~/.ssh
  cd ~/.ssh
fi

mkdir keys

mv ~/safeguard_deployments/sgs_stats_api1.pem ~/.ssh/keys
chmod 400 ~/.ssh/keys/sgs_stats_api1.pem

cd ~/wifi_sniffer
chmod +x stop.sh
chmod +x sniff
chmod +x send_wifi_stats.sh
chmod +x clean_cap.sh
python3 -m venv nic_env
source "nic_env/bin/activate"
if [[ "$VIRTUAL_ENV" != "" ]]; then
    echo "Virtual environment activated: $VIRTUAL_ENV"

    if [ -f "requirements.txt" ]; then
        echo "Installing requirements..."
        pip3 install -r requirements.txt
    else
        echo "requirements.txt not found"
        exit 1
    fi
else
    echo "Failed to activate wifi sniffer virtual environment"
    exit 1
fi
deactivate

cd ~/lpr_server
mkdir lpr_cap
mkdir backups
chmod +x lpr_send_stats.sh
python3 -m venv venv
source "venv/bin/activate"
if [[ "$VIRTUAL_ENV" != "" ]]; then
    echo "Virtual environment activated: $VIRTUAL_ENV"

    if [ -f "requirements.txt" ]; then
        echo "Installing requirements..."
        pip3 install -r requirements.txt
    else
        echo "requirements.txt not found"
        exit 1
    fi
else
    echo "Failed to activate lpr virtual environment"
    exit 1
fi
deactivate

# Write server configuration files for lpr_server from this script (so we don't have to manually set it)
cd /etc/systemd/system
sudo touch lpr_server.service
cat <<EOF | sudo tee lpr_server.service > /dev/null
[Unit]
Description=Gunicorn instance to serve lpr_server
After=network.target

[Service]
User=guard
Group=www-data
WorkingDirectory=/home/guard/lpr_server
Environment="PATH=/home/guard/lpr_server/venv/bin"
ExecStart=/home/guard/lpr_server/venv/bin/gunicorn --workers 3 --bind 127.0.0.1:7982 wsgi:app

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl start lpr_server
sudo systemctl enable lpr_server

cd /etc/nginx/sites-available
sudo touch lpr_server
cat <<EOF | sudo tee lpr_server > /dev/null
server {
    listen 7985;
    server_name localhost;

    location / {
        include proxy_params;
        proxy_pass http://127.0.0.1:7982;
        # proxy_pass http://unix:home/guard/lpr_server/lpr_server.sock;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/lpr_server /etc/nginx/sites-enabled
sudo systemctl restart nginx
sudo systemctl enable nginx

########### End section for lpr_server config and initialization ################

cd ~/bluetooth_sniffer
chmod +x bt_scanners
chmod +x stop.sh
chmod +x send_bt_stats.sh
python3 -m venv bt_env
source "bt_env/bin/activate"
if [[ "$VIRTUAL_ENV" != "" ]]; then
    echo "Virtual environment activated: $VIRTUAL_ENV. Deactivating and continuing setup..."
else
    echo "Failed to activate bluetooth sniffer virtual environment"
    exit 1
fi
deactivate

cd ~

echo "Finished deployment initial setup..."
echo "Be sure to reboot the machine for the wifi drivers to start up"
