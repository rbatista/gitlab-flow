#!/usr/bin/env bash

BASEDIR=$(dirname $0)
MR_FILE_NAME="MR_EDITMSG"
SEPARATOR='${|}'

source $BASEDIR/gitlab-common.sh

prepare_merge_request_title() {
    BRANCH_SOURCE=$1

    COMMITS_DIFF=$(get_commits_between_branchs $BRANCH_SOURCE)
    DIFF_SIZE=$(echo "$COMMITS_DIFF" | wc -l)

    TITLE=""
    if [ $DIFF_SIZE -lt 2 ]; then
        TITLE=$(git log --format=%s -1 | cat)
    else
        TITLE=$(get_current_branch)
    fi

    echo $TITLE
}

prepare_merge_request_file() {
    BRANCH_SOURCE=$1

    TITLE=$(prepare_merge_request_title $BRANCH_SOURCE)
    DESCRIPTION=""

    EXPLANATION="
 # First line is the Merge Request title.
 # Let the second line in blank.
 # The third line ahead is the description of the Merge Request.
 # lines starting with # will be ignored.
 # Leave the lines in blank to abort the Merge Request."

    GIT_DIR=$(git rev-parse --git-dir)
    FILE=$GIT_DIR/$MR_FILE_NAME

    # create or empty the MR data file
    [ -f "$FILE" ] || touch $FILE
    truncate -s 0 $FILE

    echo -e "$TITLE" >> $FILE
    echo -e "$DESCRIPTION" >> $FILE
    echo -e "$EXPLANATION" >> $FILE

    echo $FILE
}

get_merge_request_data() {
    BRANCH_SOURCE=$1
    BRANCH_TARGET=$2

    FILE_NAME=$(prepare_merge_request_file $BRANCH_SOURCE)
    vi $FILE_NAME < `tty` > `tty`


    echo $FILE_NAME
}

create_merge_request() {
    BRANCH_SOURCE=$1
    BRANCH_TARGET=$2

    PROJECT_ID=$(get_project_id)

    FILE_NAME=$(get_merge_request_data $BRANCH_SOURCE $BRANCH_TARGET)
    # TITLE is the first line
    TITLE=$(cat $FILE_NAME | head -1)
    # description after second line
    DESCRIPTION=$(cat $FILE_NAME | sed -e "/^\s*#/d" | tail --lines=+3)

    echo "Title: \"$TITLE\""
    echo "Description: \"$DESCRIPTION\""

    if [ "x$TITLE" = "x" ]; then
        echo "Merge request aborted."
        exit 1
    fi

    PRIVATE_TOKEN=$(get_private_token)
    API_URL="$(resolve_api_url)projects/$PROJECT_ID/merge_requests"

    DATA="target_branch=$BRANCH_TARGET\,source_branch=$BRANCH_SOURCE\,title=$TITLE\,description=$DESCRIPTION"
    DATA=$($BASEDIR/gitlab-json.py "to_json" "$DATA")
    echo $DATA

    RESPONSE=$( curl -sSk --header "PRIVATE-TOKEN: $PRIVATE_TOKEN" -H "Content-Type: application/json" -X POST -d "$DATA" "$API_URL" 2>&1 )
    if [ $? -ne 0 ]; then
        echo "Error: $RESPONSE"
        exit 1
    fi

    RESPONSE2=$( echo $RESPONSE | grep "iid")
    if [ "x$RESPONSE2" = "x" ]; then
        MSG=$($BASEDIR/gitlab-json.py "get_from" "$RESPONSE" "message")
        echo "Error: $MSG"
        exit 1
    fi

    MR_ID=$($BASEDIR/gitlab-json.py "get_from" "$RESPONSE" "iid")

    echo "Merge Request created with success."

    NAMESPACE=$(git config --local gitlab.project.namespace)
    PROJECT=$(git config --local gitlab.project.name)
    echo "$(resolve_origin_url)/$NAMESPACE/$PROJECT/merge_requests/$MR_ID"
}
