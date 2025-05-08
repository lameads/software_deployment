from flask import Flask, request
import re
import os
from datetime import datetime
import uuid
from PIL import Image
import base64
import io

app = Flask(__name__)

localhost_url = "127.0.0.1"
port = 7982

cap_dir = 'lpr_cap'
max_records_per_file = 15

usb_path = "/media/guard/5EBC332E6A497DA6"


# Compresses a base64 image string so we can save memory
def compress_base64_image(base64_string, output_format='JPEG', quality=50):
    # Decode the base64 string to binary data
    image_data = base64.b64decode(base64_string)
    
    # Open the image using Pillow
    image = Image.open(io.BytesIO(image_data))
    
    # Create a BytesIO object to hold the compressed image data
    compressed_image_io = io.BytesIO()
    
    # Save the image with the desired compression
    # JPEG format is used here as an example; adjust as needed
    image.save(compressed_image_io, format=output_format, quality=quality, optimize=True)
    
    # Get the binary data of the compressed image
    compressed_image_data = compressed_image_io.getvalue()
    
    # Re-encode the compressed image to base64
    compressed_base64_string = base64.b64encode(compressed_image_data).decode('utf-8')
    
    return compressed_base64_string


# Function to generate filename with timestamp
def get_filename():
    now = datetime.now()
    timestamp = now.strftime("%Y%m%d_%H%M%S")
    return f'lpr_cap_{timestamp}_{uuid.uuid4()}.csv'

# Global variables to track current file and records written
current_filename = get_filename()

records_written = 0
# vehicle_snapshot_rate = 3   # Use this variable to adjust the rate at which we pull in vehicle snapshots (3 means that one in every 3 captured records will be saved)
# vehicle_count = 0    # Used to determine how many vehicles have passed for us to decide when to collect a vehicle snapshot

@app.route('/', methods=['POST'])
def parse_json():
    global current_filename, records_written

    body = request.json    
    time_pattern = r'\.\d+$'

    capture_time = re.sub(time_pattern, '', body['time'])
    plate_number = body['license_plate']
    plate_state = body['country_region']
    plate_color = body['plate_color']
    vehicle_type = body['vehicle_type']
    vehicle_color = body['vehicle_color']
    vehicle_brand = body['vehicle_brand']
    speed = body['speed']
    lp_snapshot = body['license_plate_snapshot']
    camera_id = body['camera_id']
    camera_location = body['camera_location']
    # vehicle_snapshot = 'NULL'
    # if vehicle_count >= vehicle_snapshot_rate:
    #     vehicle_snapshot = body['snapshot']
    #     vehicle_count = 0
    # vehicle_snapshot = None
    # if "vehicle_snapshot" in body:
    #     vehicle_snapshot = body['vehicle_snapshot']
        
    cap_string = ""
    cap_str_no_vehicle_snapshot = ""
    
    if "vehicle_snapshot" in body:
        vehicle_snapshot = body['vehicle_snapshot']
        compressed_vehicle_snapshot = compress_base64_image(vehicle_snapshot)
        #compressed_vehicle_snapshot = vehicle_snapshot
        cap_string = "{camera_id}, {capture_time}, {plate_number}, {plate_state}, {plate_color}, {vehicle_type}, {vehicle_color}, {vehicle_brand}, {speed}, {lp_snapshot}, {vehicle_snapshot}".format(camera_id=camera_id, capture_time=capture_time, plate_number=plate_number, plate_state=plate_state, plate_color=plate_color, vehicle_type=vehicle_type, vehicle_color=vehicle_color, vehicle_brand=vehicle_brand, speed=speed, lp_snapshot=lp_snapshot, vehicle_snapshot=compressed_vehicle_snapshot)
        cap_str_no_vehicle_snapshot = "{camera_id}, {capture_time}, {plate_number}, {plate_state}, {plate_color}, {vehicle_type}, {vehicle_color}, {vehicle_brand}, {speed}, {lp_snapshot}".format(camera_id=camera_id, capture_time=capture_time, plate_number=plate_number, plate_state=plate_state, plate_color=plate_color, vehicle_type=vehicle_type, vehicle_color=vehicle_color, vehicle_brand=vehicle_brand, speed=speed, lp_snapshot=lp_snapshot)
    else:
        # print("Else statement reached")
        cap_string = "{camera_id}, {capture_time}, {plate_number}, {plate_state}, {plate_color}, {vehicle_type}, {vehicle_color}, {vehicle_brand}, {speed}, {lp_snapshot}".format(camera_id=camera_id, capture_time=capture_time, plate_number=plate_number, plate_state=plate_state, plate_color=plate_color, vehicle_type=vehicle_type, vehicle_color=vehicle_color, vehicle_brand=vehicle_brand, speed=speed, lp_snapshot=lp_snapshot)
        cap_str_no_vehicle_snapshot = "{camera_id}, {capture_time}, {plate_number}, {plate_state}, {plate_color}, {vehicle_type}, {vehicle_color}, {vehicle_brand}, {speed}, {lp_snapshot}".format(camera_id=camera_id, capture_time=capture_time, plate_number=plate_number, plate_state=plate_state, plate_color=plate_color, vehicle_type=vehicle_type, vehicle_color=vehicle_color, vehicle_brand=vehicle_brand, speed=speed, lp_snapshot=lp_snapshot)
    
    # File path with current filename
    cap_file_path = os.path.join(cap_dir, current_filename)
    
    # File path to USB drive
    usb_file_path = os.path.join(usb_path, current_filename)
    
  
    if records_written >= max_records_per_file:
        current_filename = get_filename()
        records_written = 0

    # Write data minus vehicle snapshot to the capture folder to be sent to the server
    with open(cap_file_path, "a") as f:
        f.write(cap_str_no_vehicle_snapshot)
        f.write("\n")
        
    # Write all data to USB, including the vehicle snapshot
    with open(usb_file_path, "a") as f:
        f.write(cap_string)
        f.write("\n")
    
    # Increment records written count
    records_written += 1
    
    # vehicle_count += 1

    return ('', 204)

if __name__ == '__main__':
    if not os.path.exists(cap_dir):
        os.makedirs(cap_dir)
        
    if not os.path.exists(usb_path):
        print("Error: Could not find USB drive path")

    app.run(debug=True, host=localhost_url, port=port)

