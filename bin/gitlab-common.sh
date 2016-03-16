#!/usr/bin/env bash

BASEDIR=$(dirname $0)

resolve_origin_url() {
    REMOTE_URL=$(git config --get remote.origin.url)
    URL=$($BASEDIR/gitlab-url.py "url_parse" "$REMOTE_URL")
    echo $URL
}

resolve_api_url() {
    echo $(resolve_origin_url)/api/v3/
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

    API_URL="$(resolve_api_url)session"
    echo "Getting private token for user $USER from $ORIGIN_URL"
    USER_DATA=`curl -skX POST "$API_URL?login=$USER&password=$PASSWORD"`

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

get_project_id() {
    PROJECT_ID=$(git config --get gitlab.project-id)
    if [ "x$PROJECT_ID" != "x" ]; then
        echo $PROJECT_ID
        return
    fi

    REMOTE_URL=$(git config --get remote.origin.url)
    if [ $REMOTE_URL = "https*" ]; then
        REMOTE_URL=$(echo $REMOTE_URL | grep "https" | sed -e "s/https\/\/://g")
    fi
    REMOTE_URL=$(echo $REMOTE_URL | grep ".git" | sed -e "s/\.git//g")
    REMOTE_URL=$(echo $REMOTE_URL | grep ":" | sed -e "s/:/\//g")
    NAMESPACE=$(echo $REMOTE_URL | grep "/" | cut -d/ -f2)
    PROJECT=$(echo $REMOTE_URL | grep "/" | cut -d/ -f3)
    ENCODED_SLASH="%2F"

    PRIVATE_TOKEN=$(get_private_token)
    API_URL="$(resolve_api_url)projects/${NAMESPACE}${ENCODED_SLASH}${PROJECT}"
    PROJECT_DATA=`curl --header "PRIVATE-TOKEN: $PRIVATE_TOKEN" -sk "$API_URL"`
#    echo $PROJECT_DATA

    MR_REGEX="\"merge_requests_enabled\":(true|false),"
    MR_ENABLE=$(echo $PROJECT_DATA | grep "\"merge_requests_enabled\"" | sed -e "s/^.*merge_requests_enabled\":\(true\|false\),.*/\1/g")
    MR_ENABLE=${MR_ENABLE:-'Undefined'}
    #echo -e "Merge Request: $MR_ENABLE\n"
    if [ $MR_ENABLE = "false" ]; then
        echo "Merge Request are disabled."
        exit 1
    fi

    PROJECT_ID=$(echo $PROJECT_DATA | grep "\"id\"" | sed -e "s/^.*\"id\":\([0-9]\+\),.*namespace.*/\1/g")
    PROJECT_ID=$(echo $PROJECT_ID | grep "^[0-9]\+$")
    if [ "x$PROJECT_ID" = "x" ]; then
        echo "The project was not found."
        exit 1;
    fi

    git config --add --local gitlab.project-id "$PROJECT_ID"

    echo $PROJECT_ID
}

get_current_branch() {
    CURRENT_BRANCH=$(git name-rev --name-only HEAD)
    echo $CURRENT_BRANCH
}
