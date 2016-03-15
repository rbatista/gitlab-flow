#!/usr/bin/env python

import sys, json

def get_from(json_str, key):
    json_data = json.loads(json_str)
    value = ""
    if (json_data.has_key(key)):
        value = json_data[key]
    return value

def get_commands():
    switcher = {
        "get_from": get_from
    }
    return switcher

def resolve_command(command, args):
    commands = get_commands()
    command = commands.get(command, lambda args = "": "")
    return command(*args)

command = sys.argv[1]
args = sys.argv[2:]
print resolve_command(command, args)
