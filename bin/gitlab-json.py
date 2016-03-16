#!/usr/bin/env python

import sys, json

def get_from(json_str, key):
    json_data = json.loads(json_str)
    value = ""
    if (json_data.has_key(key)):
        value = json_data[key]
    return value

def __url_to_obj(data_str):
    pairs = data_str.split('\,')
    data = dict()
    for pair in pairs:
        splited_pair = pair.split('=')
        data[splited_pair[0]] = splited_pair[1]

    return data

def to_json(data_str):
    data_obj = __url_to_obj(data_str)
    json_data = json.dumps(data_obj)
    return json_data

def get_commands():
    switcher = {
        "get_from": get_from,
        "to_json": to_json
    }
    return switcher

def resolve_command(command, args):
    commands = get_commands()
    command = commands.get(command, lambda args = "": "")
    return command(*args)

command = sys.argv[1]
args = sys.argv[2:]
print resolve_command(command, args)
