# -*- coding: utf-8 -*-
import sys
sys.path.append('/srv')
import re
import yaml
import json
import time
import common
import csv

CONFIG = yaml.load(open('/srv/config.yaml', 'r'))
NUM_PER_REQUEST = 100

def main(csvfile, raspi_mac_addr):
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
                ret = common.http_post(CONFIG['url'], CONFIG['api_token'], CONFIG['message_type_sniffer'], data)
                if ret:
                    total += size
                del data[:]
        else:
            print "Skip invalid data."

    size = len(data)
    if size > 0:
        ret = common.http_post(CONFIG['url'], CONFIG['api_token'], CONFIG['message_type_sniffer'], data)
        if ret:
            total += size
    f.close()
    print "[INFO] Sent log record {0}".format(total)

# Usage sudo post_data.py csvfile raspi_mac_addr
if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])

