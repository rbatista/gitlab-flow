#!/usr/bin/env bash

resolve_origin_url() {
    REMOTE_URL=$(git config --get remote.origin.url)
    if [ $REMOTE_URL != "https://*" ]; then
#       # Remove user
       URL=$(echo $REMOTE_URL | grep "@" | sed -e "s/^.*@/https:\/\//g")
#       # replace : on path
       URL=$(echo $URL | grep "[:\/]" | sed -e "s/:\([^0-9\/]\)/\/\1/g")
    fi

    py_script="
import urlparse

uri = '$URL'
result = urlparse.urlsplit(uri)
print result.scheme + '://' + result.netloc
"

    URL=$(python -c "$py_script")
    echo $URL
}

get_private_token() {
    PRIVATE_TOKEN=$(git config --get gitlab.private-token)
    if [ "x$PRIVATE_TOKEN" != "x" ]; then
        echo $PRIVATE_TOKEN
        return
    fi

    USER=$(git config --get gitlab.user)
    USER_FOUND=1
    if [ "x$USER" = "x" ]; then
        USER_FOUND=0
        read -p "Enter your gitlab user: " USER
    fi
    read -s -p "Enter your gitlab password: " PASSWORD
    echo -e "\n"

    ORIGIN_URL=$(resolve_origin_url)
    echo "Getting private token for user $USER from $ORIGIN_URL"
    USER_DATA=`curl -skX POST "$ORIGIN_URL/api/v3/session?login=$USER&password=$PASSWORD"`

    py_script="
import sys,json

user_data = json.load(sys.stdin)
private_token = ''
if (user_data.has_key('private_token')):
    private_token = user_data['private_token']

print private_token
"
    PRIVATE_TOKEN=$(echo $USER_DATA | python -c "$py_script")

    if [ "x$PRIVATE_TOKEN" = "x" ]; then
        echo "Authentication error."
        exit 1
    elif [ $USER_FOUND -eq 0 ]; then
        git config --add --local gitlab.user "$USER"
        git config --add --local gitlab.private-token "$PRIVATE_TOKEN"
    fi

    echo $PRIVATE_TOKEN
}
