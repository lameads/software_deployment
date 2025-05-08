from flask import Flask, request
import re
import os
from datetime import datetime
import uuid
from PIL import Image
import base64
import io
import json

app = Flask(__name__)

localhost_url = "127.0.0.1"
port = 7982

cap_dir = 'lpr_cap'
max_records_per_file = 100

json_data = None
b_capture_images = False

with open('server_capture_config.json', 'r') as file:
    json_data = json.load(file)

b_capture_images = json_data['log_images']

#with open('app_output.txt', 'a') as file:
#    file.write(str(b_capture_images))


# Compresses a base64 image string so we can save memory
def compress_base64_image(base64_string, output_format='JPEG', quality=75):
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


def write_header(filename:str):
    cap_file_path = os.path.join(cap_dir, filename)
    # TODO: Parse the json from the server_capture_config.json file
    header_list = json_data['header']
    header = ",".join(header_list)
    header += "\n"
    with open(cap_file_path, "a") as f:
        f.write(header)
        
# Function to generate filename with timestamp
def get_filename():
    now = datetime.now()
    timestamp = now.strftime("%Y%m%d_%H%M%S")
    filename = f'lpr_cap_{timestamp}_{uuid.uuid4()}.csv'
    write_header(filename=filename)
    return filename

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

    # capture_time = re.sub(time_pattern, '', body['time'])
    # plate_number = body['license_plate']
    # plate_state = body['country_region']
    # plate_color = body['plate_color']
    # vehicle_type = body['vehicle_type']
    # vehicle_color = body['vehicle_color']
    # vehicle_brand = body['vehicle_brand']
    # speed = body['speed']
    # lp_snapshot = body['license_plate_snapshot']
    # camera_id = body['camera_id']
    # camera_location = body['camera_location']
    
    #resolution_width = body['resolution_width']
    #resolution_height = body['resolution_height']
    #vehicle_tracking_box_x1 = body['vehicle_tracking_box_x1']
    #vehicle_tracking_box_y1 = body['vehicle_tracking_box_y1']
    #vehicle_tracking_box_x2 = body['vehicle_tracking_box_x2']
    #vehicle_tracking_box_y2 = body['vehicle_tracking_box_y2']
    #lpr_confidence = body['confidence']
    #plate_confidence = body['plate_confidence']
    
    # vehicle_snapshot = 'NULL'
    # if vehicle_count >= vehicle_snapshot_rate:
    #     vehicle_snapshot = body['snapshot']
    #     vehicle_count = 0
    # vehicle_snapshot = None
    # if "vehicle_snapshot" in body:
    #     vehicle_snapshot = body['vehicle_snapshot']
    
    # New version of the code where we parse the fields based on the json header key
    write_list = []
    keys = json_data.get('capture_fields')
    if keys is None:
        print("Error: Could not get header keys from json object")
        return ('', 500)
    
    for key in keys:
        val = body.get(key)
        if val is None:
            val = "-"
        write_list.append(str(val))
        
    write_str = ",".join(write_list)
    
            
        
    # cap_string = ""
    
    # if "vehicle_snapshot" in body and b_capture_images:
    #     vehicle_snapshot = body['vehicle_snapshot']
    #     compressed_vehicle_snapshot = compress_base64_image(vehicle_snapshot)
    #     #compressed_vehicle_snapshot = vehicle_snapshot
    #     cap_string = "{camera_id}, {capture_time}, {plate_number}, {plate_state}, {plate_color}, {vehicle_type}, {vehicle_color}, {vehicle_brand}, {speed}, {lp_snapshot}, {vehicle_snapshot}".format(camera_id=camera_id, capture_time=capture_time, plate_number=plate_number, plate_state=plate_state, plate_color=plate_color, vehicle_type=vehicle_type, vehicle_color=vehicle_color, vehicle_brand=vehicle_brand, speed=speed, lp_snapshot=lp_snapshot, vehicle_snapshot=compressed_vehicle_snapshot)
    #     #cap_string = f"{camera_id}, {capture_time}, {plate_number}, {plate_state}, {plate_color}, {vehicle_type}, {vehicle_color}, {vehicle_brand}, {speed}, {resolution_width}, {resolution_height}, {vehicle_tracking_box_x1}, {vehicle_tracking_box_y1}, {vehicle_tracking_box_x2}, {vehicle_tracking_box_y2}, {lpr_confidence}, {plate_confidence}, {lp_snapshot}, {vehicle_snapshot}"
    # else:
    #     # print("Else statement reached")
    #     cap_string = "{camera_id}, {capture_time}, {plate_number}, {plate_state}, {plate_color}, {vehicle_type}, {vehicle_color}, {vehicle_brand}, {speed}, {lp_snapshot}, -".format(camera_id=camera_id, capture_time=capture_time, plate_number=plate_number, plate_state=plate_state, plate_color=plate_color, vehicle_type=vehicle_type, vehicle_color=vehicle_color, vehicle_brand=vehicle_brand, speed=speed, lp_snapshot=lp_snapshot)
    #     #cap_string = f"{camera_id}, {capture_time}, {plate_number}, {plate_state}, {plate_color}, {vehicle_type}, {vehicle_color}, {vehicle_brand}, {speed}, {resolution_width}, {resolution_height}, {vehicle_tracking_box_x1}, {vehicle_tracking_box_y1}, {vehicle_tracking_box_x2}, {vehicle_tracking_box_y2}, {lpr_confidence}, {plate_confidence}, {lp_snapshot}"
    # File path with current filename
    cap_file_path = os.path.join(cap_dir, current_filename)
    
    if records_written >= max_records_per_file:
        current_filename = get_filename()
        records_written = 0

    with open(cap_file_path, "a") as f:
        f.write(write_str)
        f.write("\n")
    
    # Increment records written count
    records_written += 1
    
    # vehicle_count += 1

    return ('', 204)

if __name__ == '__main__':
    if not os.path.exists(cap_dir):
        os.makedirs(cap_dir)
    
    app.run(debug=False, host=localhost_url, port=port)

