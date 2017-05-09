# -*- coding: utf-8 -*-
import sys
import re
import yaml
import json
import time
import common
import csv

CONFIG = yaml.load(open('../config.yaml', 'r'))
LOG_FILE = "measurement.csv"

def countdown():
    num = 3
    for i in range(0, num):
        time.sleep(1.0)
        print num - i
        

def main(src_mac_address, x, y, duration):
    print "Please turn on wifi and prepare"
    countdown()
    start_time = int(time.time())
    print "Waiting for for {0} secounds...".format(duration)
    time.sleep(duration)
    finish_time = int(time.time())
    print "{0} -> {1}".format(start_time, finish_time)

    ret = common.http_post(CONFIG['url'], CONFIG['api_token'], CONFIG['message_type_measure'], [{
        "start_time": start_time,
        "finish_time": finish_time,
        "src_mac": src_mac_address,
        "x": x,
        "y": y,
    }])
    # Output csv file
    f = open(LOG_FILE, "a")
    writer = csv.writer(f, lineterminator='\n')
    writer.writerow([start_time, finish_time, src_mac_address, x, y])
    f.close()

    if ret:
        print "[Success] Log posting is complete."
    else:
        print "[Warn] Did not posted the log yet. {0}".fotmat(LOG_FILE)

    print "Please turn off wifi."

# Usage: python measurement.py src_mac_address x y duration
if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3], long(sys.argv[4]))
