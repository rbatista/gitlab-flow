#!/usr/bin/env bash

BASEDIR=$(dirname $0)

resolve_origin_url() {
    REMOTE_URL=$(git config --get remote.origin.url)
    URL=$($BASEDIR/gitlab-url.py "url_parse" "$REMOTE_URL")
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

    PRIVATE_TOKEN=$($BASEDIR/gitlab-json.py "get_from" "$USER_DATA" "private_token")

    if [ "x$PRIVATE_TOKEN" = "x" ]; then
        echo "Authentication error."
        exit 1
    elif [ $USER_FOUND -eq 0 ]; then
        git config --add --local gitlab.user "$USER"
        git config --add --local gitlab.private-token "$PRIVATE_TOKEN"
    fi

    echo $PRIVATE_TOKEN
}

