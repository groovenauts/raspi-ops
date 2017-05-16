# -*- coding: utf-8 -*-
import sys
import os
import re
import yaml
import json
import time
import csv
import requests
import glob
import subprocess
import Queue
import threading

NUM_CONNECTION = 5
NUM_PER_REQUEST = 400

def http_post(queue, url, api_token, message_type):
    while True:
        try:
            params = queue.get()
            if params is None:
                break
            data = {
                "api_token": api_token,
                "logs": []
            }
            for param in params:
                data['logs'].append({
                    "type": message_type,
                    "attributes": param
                })
            start_time = time.time()
            r = requests.post(url, data=json.dumps(data))
            finish_time = time.time()
            if r.status_code == requests.codes.ok:
                print "[SUCCESS] Sent record {0} in {1} secs.".format(len(params), finish_time - start_time)
            else:
                print "[ERROR] Status: {0}, {1} in {2} secs".format(r.status_code, r.text, finish_time - start_time)
            queue.task_done()
        except Exception as ex:
            print str(ex)

def read_csvfile(queue, csv_file, raspi_mac_addr, url, api_token, message_type):
    data_per_request = []
    data = []
    f = open(csv_file, 'r')
    reader = csv.reader(f)
    header = next(reader)
    table = {}
    for o in reader:
        if len(o) == 3:
            ts = o[0]
            src_mac = o[1]
            rssi = o[2]
            if ts and src_mac and rssi and raspi_mac_addr:
                ts = ts.split(".")[0]
                if table.has_key(ts + "." + src_mac):
                    # print "Skip duplicate data. ts={0} mac={1}".format(ts, src_mac)
                    continue
                table[ts + "." + src_mac] = True
                data_per_request.append({
                    "timestamp": ts,
                    "src_mac": src_mac,
                    "rssi": rssi,
                    "raspi_mac": raspi_mac_addr,
                })

            size = len(data_per_request)
            if size >= NUM_PER_REQUEST:
                push_time = time.time()
                queue.put(data_per_request)
                data_per_request = []
                pushed_time = time.time()
                wait_duration = pushed_time - push_time
                if wait_duration > 10:
                    print("Request queue push wait {} secs.".format(wait_duration))
        # else:
        #     print "Skip invalid data."

    size = len(data_per_request)
    if size > 0:
        push_time = time.time()
        queue.put(data_per_request)
        wait_duration = pushed_time - push_time
        if wait_duration > 10:
            print("Request queue push wait {} secs.".format(wait_duration))
    f.close()

def main(target_dir, raspi_mac_addr, config_path):
    config = yaml.load(open(config_path, 'r'))
    url = config['url']
    api_token = config['api_token']
    message_type = config['message_type']

    request_queue = Queue.Queue(maxsize=1)

    for i in range(NUM_CONNECTION):
        threading.Thread(target=http_post, args=(request_queue, url, api_token, message_type)).start()

    # process pcap files
    while True:
        files = glob.glob(target_dir + "/packet_*.pcap")
        if len(files) <= 1:
            time.sleep(1.0)
            continue
        files.sort()
        files.pop()
        for f in files:
            csv_file = f + ".csv"
            print("Dumping {} -> {}".format(f, csv_file))
            subprocess.call("sudo tshark -r '{}' -T fields -E separator=',' -e frame.time_epoch -e wlan.sa -e radiotap.dbm_antsignal > '{}'".format(f, csv_file), shell=True)
            read_csvfile(request_queue, csv_file, raspi_mac_addr, url, api_token, message_type)
            os.remove(csv_file)
            os.remove(f)

    request_queue.join()


# Usage sudo post_data.py target_dir raspi_mac_addr config_path
if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3])

