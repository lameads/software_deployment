#!/usr/bin/env python3
import requests
import json
import subprocess
import socket
import select
import time

# Suppress SSL warnings for self-signed certificates
requests.packages.urllib3.disable_warnings(
    requests.packages.urllib3.exceptions.InsecureRequestWarning
)

# Function to send data to the API endpoint
def send_to_api(box_id, latitude, longitude):
    # Check if any of the required variables are missing or empty
    if not box_id or not latitude or not longitude:
        print("Error: Missing required parameters (box_id, latitude, or longitude).")
        return

    api_key = 'dc01ff0ed25f21ba7cec825563071559'  # Static API key
    url = 'http://api.safeguardsolutions.org/box_locations'

    # Prepare parameters for the GET request
    params = {
        'api_key': api_key,
        'box_id': box_id,
        'latitude': latitude,
        'longitude': longitude
    }

    # Send the GET request to the API
    response = requests.get(url, params=params)

    # Check the response status
    if response.status_code != 200:
        print(f"Failed to send data to API. Status code: {response.status_code}")

# Function to read box ID from the file
def read_box_id():
    with open('/home/guard/box_id.txt', 'r') as f:
        return f.read().strip()

def peplink_router():
    """
    Logs in to the Peplink router and retrieves GPS info via the /api/info.location endpoint.
    Returns (latitude, longitude) if a valid GPS signal is present; otherwise, returns (None, None).
    """
    ROUTER_IP = "192.168.50.1"
    USERNAME = "admin"
    PASSWORD = "PepwaveAdmin123"

    session = requests.Session()

    # Step 1: Log in using admin credentials
    login_url = f"https://{ROUTER_IP}/api/login"
    login_payload = {"username": USERNAME, "password": PASSWORD}

    login_response = session.post(login_url, json=login_payload, verify=False)
    if login_response.status_code != 200:
        print(f"Error: Failed to log in. Status Code: {login_response.status_code}")
        return None, None

    # Verify that the required session cookie 'bauth' is present
    cookies = session.cookies.get_dict()
    if "bauth" not in cookies:
        print("Error: 'bauth' cookie not received. Login may not have been successful.")
        print("Cookies received:", cookies)
        return None, None

    # Step 2: Retrieve GPS information
    gps_url = f"https://{ROUTER_IP}/api/info.location"
    gps_response = session.get(gps_url, verify=False)
    if gps_response.status_code != 200:
        print(f"Error: Failed to retrieve GPS information. Status Code: {gps_response.status_code}")
        return None, None

    try:
        gps_data = gps_response.json()
    except json.JSONDecodeError:
        print("Error: Received non-JSON response from router when retrieving GPS info.")
        return None, None

    if gps_data.get("stat") != "ok":
        print("Error: Failed to retrieve GPS information.")
        print("Details:", json.dumps(gps_data, indent=2))
        return None, None

    # Extract GPS details from the response
    response = gps_data.get("response", {})
    gps_valid = response.get("gps", False)
    location = response.get("location", {})

    if gps_valid:
        latitude = location.get("latitude")
        longitude = location.get("longitude")
        return latitude, longitude
    else:
        print("No valid GPS signal detected.")
        return None, None
       
def parse_nmea_data(nmea_data):
    """
    Parse NMEA data and extract latitude and longitude.
    Prints the most accurate available data from GNGGA or GNRMC sentences.
    """
    if nmea_data.startswith('$GNGGA'):
        parts = nmea_data.split(',')
        if len(parts) >= 6:
            latitude = convert_to_decimal_degrees(parts[2], parts[3])  # Convert to decimal format
            longitude = convert_to_decimal_degrees(parts[4], parts[5])  # Convert to decimal format
            return latitude, longitude
    elif nmea_data.startswith('$GNRMC'):
        parts = nmea_data.split(',')
        if len(parts) >= 6:
            latitude = convert_to_decimal_degrees(parts[3], parts[4])  # Convert to decimal format
            longitude = convert_to_decimal_degrees(parts[5], parts[6])  # Convert to decimal format
            return latitude, longitude
    return None, None

def convert_to_decimal_degrees(degrees_minutes, direction):
    """Convert GPS coordinates from DMM to decimal degrees format."""
    if degrees_minutes == '' or direction == '':
        return None
    
    # Determine degrees length based on direction (latitude: 2, longitude: 3)
    degree_length = 2 if direction in ['N', 'S'] else 3
    
    degrees = float(degrees_minutes[:degree_length])  # Extract degrees
    minutes = float(degrees_minutes[degree_length:])  # Extract minutes
    decimal_degrees = degrees + (minutes / 60.0)

    if direction in ['S', 'W']:
        decimal_degrees = -decimal_degrees  # Negative for south or west
    return decimal_degrees

def sierra_wireless_listen_for_udp(timeout=120):
    """Listen for UDP broadcasts on port 65278 with a timeout and parse the NMEA data."""
    # Set up the UDP socket
    udp_ip = "0.0.0.0"  # Listen on all interfaces
    udp_port = 65278     # Port to listen to
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((udp_ip, udp_port))

    # Set the socket to non-blocking mode
    sock.setblocking(0)

    start_time = time.time()

    while True:
        # Check if the timeout has been reached
        if time.time() - start_time > timeout:
            print("Timeout reached, no data received.")
            return None, None

        # Use select to wait for the socket to be ready to receive data
        readable, _, _ = select.select([sock], [], [], 1)  # Timeout is set to 1 second

        if readable:
            data, addr = sock.recvfrom(1024)  # Buffer size of 1024 bytes
            nmea_data = data.decode('ascii').strip()  # Decode and strip any extra spaces

            latitude, longitude = parse_nmea_data(nmea_data)
            if latitude is not None and longitude is not None:
                # Once valid GPS coordinates are found, stop and print them
                return latitude, longitude

def main():
    # Step 1: Ping the router to update the ARP cache
    subprocess.run(["ping", "-c", "1", "192.168.50.1"], stdout=subprocess.PIPE, text=True)

    # Step 2: Retrieve the ARP table
    ip_neigh_output = subprocess.run(["ip", "neigh"], stdout=subprocess.PIPE, text=True).stdout

    # Step 3: Check for the MAC address fragment 'A8:C0:EA'
    if any(mac in ip_neigh_output.lower() for mac in ["a8:c0:ea", "10:56:ca"]):
        latitude, longitude = peplink_router()
        if latitude is not None and longitude is not None:
            #print("Latitude:", latitude)
            #print("Longitude:", longitude)

            # Read box ID from file
            box_id = read_box_id()

            # Send the data to the API
            send_to_api(box_id, latitude, longitude)
        else:
            print("Could not retrieve valid GPS information.")
    elif any(mac in ip_neigh_output.lower() for mac in ["28:a3:31", "00:14:3e"]):
        latitude, longitude = sierra_wireless_listen_for_udp()
        if latitude is not None and longitude is not None:
            #print("Latitude:", latitude)
            #print("Longitude:", longitude)

            # Read box ID from file
            box_id = read_box_id()

            # Send the data to the API
            send_to_api(box_id, latitude, longitude)
        else:
            print("Could not retrieve valid GPS information from Sierra router.")
    else:
        print("No Router Found")

if __name__ == "__main__":
    main()
