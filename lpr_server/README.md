1. Install Debian 12 from bootable USB drive.
2. Set up root user account with password Emxhcrc0
3. Set up guard user account with password Emxhcrc0
4. Once installed, add guard to the sudoers file by switching to the root account:
    su
    cd /etc
    nano sudoers
    edit the sudoers file by adding guard ALL=(ALL:ALL) ALL below the line that specifies root ALL=(ALL:ALL) ALL
    write out and close the file. exit the terminal
    You should now be able to run sudo commands from the guard user
5. Enable the guard user to run sudo commands without entering the root password (needed for automation)
    Run sudo visudo as the guard user (or any user that has root permissions I believe)
    At the very bottom of the file, under the line that says "@includedir /etc/sudoers.d", append a new line that says "guard ALL=(ALL) NOPASSWD:ALL"
    Save and exit the file. Now we should be able to run shell scripts as root without using a password. This is necessary for running the scp up to the server from our automated lpr_send_stats.sh script.
6. Install git, as git is not installed by default on debian 12
    sudo apt install git
7. Clone the lpr_flask_server project from github with the following line:
    git clone https://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@github.com/jeisen-sportsmansdeals/lpr_flask_server.git
    Note that the random characters right after the https:// portion of the url specify the current personal access token, which is only available for 30 days starting at 7/30/2024. We will need to get a new access token when this one
    expires. However, my plan is to create a deploy key so we can utilize ssh to clone the repository. This will be a more secure way of doing things.
8. Rename the project directory from lpr_flask_server to lpr_server.
9. Create a virtual environment for the server to run:
    Run sudo apt update
    Be sure that venv (a subset of virtualenv) is installed on the machine. Try creating the virtual environment with "python3 -m venv venv" (uses venv to create a virtual environment in the current directory called "venv")
    If that fails, you should get a message stating that you must install venv using "sudo apt install python3.11-venv". Run this command to install and try creating the virtual environment again.
10. If the following aren't already installed, install the following with: sudo apt install python3-pip python3-dev build-essential libssl-dev libffi-dev python3-setuptools (shouldn't need to do this though). I believe these packages 
   should already be installed, but I included this step in case we get errors later on in the setup process for troubleshooting purposes.
11. Install modules from requirements.txt
    Navigate to the project folder and activate the virtual environment with source ./venv/bin/activate
    run pip3 install -r requirements.txt
    Start the server in development mode by running python3 app.py
12. Ensure that Gunicorn can run the application properly by manually running with Gunicorn: gunicorn --bind 0.0.0.0:5000 wsgi:app. You should be able to navigate to the url and see a method not permitted
    response from the server (the server is only configured to handle POST requests). You can also use postman to test it out as well but this probably isn't necessary.
13. Deactivate the virtual environment on the command line with deactivate
14. Install Nginx. Run sudo apt install nginx
15. Create a unit file for the flask app service called lpr_server.service sudo nano /etc/systemd/system/lpr_server.service In the file, add the following:
    ***********************************************************************************************
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
    ***********************************************************************************************
16. Start and enable the service with the following:
    sudo systemctl start lpr_server
    sudo systemctl enable lpr_server (running enable will make it so the lpr_server service starts up on boot automatically)
17. Check the status of the service with sudo systemctl status lpr_server
18. Configure Nginx to pass the requests to the flask server running on the specified port in the wsgi.py file entry point. To do this we need to create a new server block configuration file in the  
    sites-available directory with the following: sudo nano /etc/nginx/sites-available/lpr_server
    The file should look as follows:
    ***********************************************************************************************
    server {
        listen 7985;
        server_name localhost;

        location / {
            include proxy_params;
            proxy_pass http://127.0.0.1:7982;
            # proxy_pass http://unix:home/guard/lpr_server/lpr_server.sock;
        }
     }
    ***********************************************************************************************
19. Test this file for errors with: sudo nginx -t
20. Link the server block config file we just created to the sites-enabled folder with a simlink: sudo ln -s /etc/nginx/sites-available/lpr_server /etc/nginx/sites-enabled
21. Restart nginx: sudo systemctl restart nginx
22. Check the status of nginx by running sudo systemctl status nginx
23. Enable nginx so that it starts the enabled service(s) on boot: sudo systemctl enable nginx
24. Check nginx status and the lpr_server.service status again as well to be sure everything is running properly together.
25. Adjust the firewall if necessary (only do this if we need to at a later point I'd say, and only if we run into issues getting the server to work).
26. At this point, the server should be up and running. Be sure that we have called enable on both the wsgi service as well as nginx so that they both start on boot.
27. Make the lpr_send_stats.sh script executable by running chmod +x lpr_send_stats.sh
28. Be sure that zip is installed, as lpr_send_stats.sh requires zip to be installed. To install, run sudo apt install zip
29. Create a directory called "backups" for the lpr_send_stats.sh script to create and save backups to the capture files in.
30. Set up the local flask server to be able to SCP up to the remote server:
    Copy the .pem key for the remote server to the ~/.ssh/keys directory on the local machine.
    Create a file called "config" (no extension) directly in the .ssh folder. Path is sudo nano ~/.ssh/config
    To the config file, add the following:
    ***********************************************************************************************
    GSSAPIAuthentication no

    host sgs_api
            hostName api.safeguardsolutions.org
            user stats
            port 22
            IdentityFile ~/.ssh/keys/<pem_key_name_here>.pem
    ***********************************************************************************************
    Replace <pem_key_here> with whatever you have named your .pem key
    Once config is set, update permissions for the .pem key to work with the remote server securely by running: chmod 400 ~/.ssh/keys/<pem_key_name_here>.pem.
    Try to ssh into the server for initial setup by typing "ssh sgs_api". This will be necessary for scp to work properly.
32. Cron the file upload (send_lpr_stats.sh) script so that we can send stats up to the remote server. Type crontab -e and append the following line to the file: */15 * * * * /home/guard/lpr_server/lpr_send_stats.sh >> /var/log/lpr_bash.log 2>&1
33. Create the lpr_bash.log file in the /var/log directory. Give the file permission of 777:
    cd /var/log
    sudo touch lpr_bash.log
    sudo chmod 777 lpr_bash.log
35. Set up the machine to never sleep by going to settings -> power and setting auto suspend to off. Allow the screen to go blank after 5 minutes as well.
36. To be sure that autosuspend is turned off, open the gdm3 config file: sudo nano /etc/gdm3/greeter.dconf-defaults
37. Uncomment the line that says sleep-inactive-ac-timeout and change the value to 'blank'
38. Uncomment the line that says sleep-inactive-ac-type and change the value to 'blank'
39. Save and exit the file. Restart the gdm3 service with sudo systemctl restart gdm3 to make the changes take place on the system.
40. Next, go into the BIOS and ensure that the computer will boot on power, meaning that whenever it is plugged in it will automatically boot up. It will usually be under power boot settings or power management. It is different for every machine.
41. Install OpenSSH by running sudo apt-get update, followed by sudo apt-get install openssh-server
42. Install openvpn with sudo apt-get update, sudo apt-get install openvpn
43. Enable and start openvpn with sudo systemctl enable openvpn, systemctl start openvpn
44. Adjust the default openvpn config: sudo nano /etc/default/openvpn
    Uncomment the "AUTOSTART="all"" line
45. Create the conf file named after the physical location. Call it whatever the name of the location is. In this example the location will be called "office"
    sudo nano /etc/openvpn/office.conf and copy in the .conf file built for that device (NOTE: You cannot reuse .conf files from other machines that are up and         running. Be sure that there is no line sayig "data-ciphers-fallback BF-CBC", as that has caused issues starting and running the service in the past.
46. Navigate into the folder where office.conf is stored with cd /etc/openvpn.
47. From that folder, run sudo openvpn office.conf. This should start openvpn. If no errors occur, ctrl + c out of it to stop.
48. Run sudo systemctl restart openvpn, then check status with sudo systemctl status openvpn to ensure that the service is running and has not exited with an          error.
49. Install ip tables using sudo apt-get iptables so we can access the camera remotely via a masquerade. The masquerade lets the computer know that it needs to forward traffic on a specified port to a port on the local network. This allows us to connect via the vpn even though the LPR camera is not on the VPN.
50. Type the following on the command line to forward to the ip address of the camera on the network. Note that you must find the ip of the camera from the router to which it is conneted.
    iptables -t nat -A PREROUTING -d 10.8.0.8 -p tcp --dport 8080 -j DNAT --to-destination <camera_ip_address>:80
    iptables -t nat -A POSTROUTING -p tcp -d <camera_ip_address> --dport 80 -j MASQUERADE
51. Run sudo sysctl -w net.ipv4.ip_forward=1
52. Edit the sysctl.conf file using sudo nano /etc/sysctl.conf. Add the following at the bottom of the file: net.ipv4.ip_forward=1
53. Install net tools so we can do a network scan to find what IP address the connected LPR camera is. Run sudo apt-get install net-tools. Use arp -scan to scan (I believe).
54. NOTE: The following link can help if something isn't working in this guide: https://www.digitalocean.com/community/tutorials/how-to-serve-flask-applications-with-gunicorn-and-nginx-on-ubuntu-22-04
    Compared to the guide, I changed the ExecStart variable bind portion from unix:lpr_server.sock -m 007 wsgi:app to just use the localhost at port 7982 as the entry point for the app. Then I set the nginx config file to proxy 
    requests through port 7985 to the port specified in the lpr_server.service file (7982). I did this because the server is always going to run locally and should only be accessed locally. We may also be able to do it the other way, 
    with the named socket (lpr_server.sock), but I figured it was easier to do it this way. In newer versions we may want to experiment with doing it the other way with the named socket, but I had issues getting it to work this way in the
    past. I don't know if getting it to work with the named socket would increase speed or efficiency, but it may be worth looking into the difference between what I did versus using the socket in the lpr_server.service file.
55. For deploying using this repository, follow the guide on using deploy keys through github: https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys#deploy-keys
56. This link may also be useful in generating the ssh key necessary for allowing access: 
    https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent#generating-a-new-ssh-key
     


