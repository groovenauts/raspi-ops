# -*- coding: utf-8 -*-
import sys
import re
import yaml
import json
import time
import csv
import requests

NUM_PER_REQUEST = 100

def http_post(url, api_token, message_type, params):
    try:
        data = {
            "api_token": api_token,
            "logs": []
        }
        for param in params:
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
    except Exception as ex:
        print str(ex)
        return False

def main(csvfile, raspi_mac_addr, config_path):
    config = yaml.load(open(config_path, 'r'))
    url = config['url']
    api_token = config['api_token']
    message_type = config['message_type']
    data = []
    total = 0
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
                    print "Skip duplicate data. ts={0} mac={1}".format(ts, src_mac)
                    continue
                table[ts + "." + src_mac] = True
                data.append({
                    "timestamp": ts,
                    "src_mac": src_mac,
                    "rssi": rssi,
                    "raspi_mac": raspi_mac_addr,
                })

            size = len(data)
            if size >= NUM_PER_REQUEST:
                ret = http_post(url, api_token, message_type, data)
                if ret:
                    total += size
                del data[:]
        else:
            print "Skip invalid data."

    size = len(data)
    if size > 0:
        ret = http_post(url, api_token, message_type, data)
        if ret:
            total += size
    f.close()
    print "[INFO] Sent log record {0}".format(total)

# Usage sudo post_data.py csvfile raspi_mac_addr config_path
if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3])

