# -*- coding: utf-8 -*-
import sys
import re
import yaml
import json
import time
import csv
import requests
import glob
import subprocess

NUM_CONNECTION = 5
NUM_PER_REQUEST = 100

def http_post(url, api_token, message_type, params):
    try:
        reqs = []
        for params2 in params:
            for param in params2:
                data = {
                    "api_token": api_token,
                    "logs": []
                }
                data['logs'].append({
                    "type": message_type,
                    "attributes": param
                })
                r = requests.post(url, data=json.dumps(data))
                if r.status_code == requests.codes.ok:
                    print "[SUCCESS] Sent record {0}.".format(len(params))
                    return True
                else:
                    print "[ERROR] Status: {0}, {1}".format(r.status_code, r.text)
                    return False
        return True
    except Exception as ex:
        print str(ex)
        return False

def read_csvfile(csv_file, raspi_mac_addr, url, api_token, message_type):
    data_per_request = []
    data = []
    f = open(csvfile, 'r')
    reader = csv.reader(f)
    header = next(reader)
    row = [ v for v in reader]
    table = {}
    for o in row:
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
                data.append(data_per_request)
                if len(data) >= NUM_CONNECTION:
                    http_post(url, api_token, message_type, data)
                    del data_per_request[:]
                    del data[:]
        # else:
        #     print "Skip invalid data."

    size = len(data_per_request)
    if size > 0:
        data.append(data_per_request)
    if len(data) > 0:
        http_post(url, api_token, message_type, data)
    f.close()

def main(target_dir, raspi_mac_addr, config_path):
    config = yaml.load(open(config_path, 'r'))
    url = config['url']
    api_token = config['api_token']
    message_type = config['message_type']

    # process pcap files
    while True:
        files = glob.glob(target_dir + "/packet_*.pcap")
        if len(files) <= 1:
            time.sleep(1.0)
            continue
        files.sort()
        for f in files:
            csv_file = f + ".csv"
            subprocess.call("sudo tshark -r '{}' -T fields -E separator=',' -e frame.time_epoch -e wlan.sa -e radiotap.dbm_antsignal > '{}'".format(f, csv_file), shell=True)
            read_csvfile(csv_file, raspi_mac_addr, url, api_token, message_type)


# Usage sudo post_data.py target_dir raspi_mac_addr config_path
if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3])

