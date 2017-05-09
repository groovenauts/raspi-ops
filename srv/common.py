# -*- coding: utf-8 -*-
import sys
import re
import yaml
import json
import requests
import time

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
