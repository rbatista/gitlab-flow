#!/usr/bin/env python

import sys, urlparse, re

def __remove_user_from_uri(uri):
    return re.sub(r"^.*@", r"https://", uri)

def __replace_path_colon(uri):
    return re.sub(r":([^0-9/])", r"/\1", uri)

def __strip_ssh_uri(uri):
    if (not uri.startswith('https://')):
        uri = __remove_user_from_uri(uri)
        uri = __replace_path_colon(uri)

    return uri

def url_parse(uri):
    uri = __strip_ssh_uri(uri)
    result = urlparse.urlsplit(uri)
    print result.scheme + '://' + result.netloc

def get_commands():
    switcher = {
        "url_parse": url_parse
    }

    return switcher

def resolve_command(command, args):
    commands = get_commands()
    command = commands.get(command, lambda args = "": "")
    return command(*args)


command = sys.argv[1]
args = sys.argv[2:]
resolve_command(command, args)
