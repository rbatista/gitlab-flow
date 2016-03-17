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
    USER_DATA=$( curl -sSkX POST "$API_URL?login=$USER&password=$PASSWORD" 2>&1 )
    if [ $? -ne 0 ]; then
        echo "Error: $USER_DATA"
        exit 1
    fi

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
    PROJECT_ID=$(git config --get gitlab.project.id)
    if [ "x$PROJECT_ID" != "x" ]; then
        echo $PROJECT_ID
        return
    fi

    REMOTE_URL=$(git config --get remote.origin.url)
    REMOTE_URL=$(echo $REMOTE_URL | sed -e "s/^https:\/\///g")
    REMOTE_URL=$(echo $REMOTE_URL | sed -e "s/\.git$//g")
    REMOTE_URL=$(echo $REMOTE_URL | sed -e "s/:\([^0-9]\)/\/\1/g")
    NAMESPACE=$(echo $REMOTE_URL | grep "/" | cut -d/ -f2)
    PROJECT=$(echo $REMOTE_URL | grep "/" | cut -d/ -f3)
    ENCODED_SLASH="%2F"

    PRIVATE_TOKEN=$(get_private_token)
    API_URL="$(resolve_api_url)projects/${NAMESPACE}${ENCODED_SLASH}${PROJECT}"
    PROJECT_DATA=$(curl --header "PRIVATE-TOKEN: $PRIVATE_TOKEN" -sSk "$API_URL" 2>&1 )
    if [ $? -ne 0 ]; then
        echo "Error: $PROJECT_DATA"
        exit 1
    fi

    MR_REGEX="\"merge_requests_enabled\":(true|false),"
    MR_ENABLE=$(echo $PROJECT_DATA | grep "\"merge_requests_enabled\"" | sed -e "s/^.*merge_requests_enabled\":\(true\|false\),.*/\1/g")
    MR_ENABLE=${MR_ENABLE:-'false'}
    if [ $MR_ENABLE = "false" ]; then
        echo "Merge Request are disabled."
        exit 1
    fi

    PROJECT_ID=$($BASEDIR/gitlab-json.py "get_from" "$PROJECT_DATA" "id")
    PROJECT_ID=$(echo $PROJECT_ID | grep "^[0-9]\+$")
    if [ "x$PROJECT_ID" = "x" ]; then
        echo "The project was not found."
        exit 1;
    fi

    git config --add --local gitlab.project.id "$PROJECT_ID"
    git config --add --local gitlab.project.namespace "$NAMESPACE"
    git config --add --local gitlab.project.name "$PROJECT"

    echo $PROJECT_ID
}

get_current_branch() {
    CURRENT_BRANCH=$(git branch | grep "*" | sed -e "s/*\s//g")
    echo $CURRENT_BRANCH
}

get_parent_branch() {
    BRANCH=${1:-$(get_current_branch)}

    # ref: http://stackoverflow.com/a/17843908
    # 1. Display a textual history of all commits, including remote branches.
    PARENT_BRANCH=$(git show-branch -a)
    # 2. Ancestors of the current commit are indicated by a star. Filter out everything else.
    PARENT_BRANCH=$(echo $PARENT_BRANCH | grep "\*")
    # 3. Ignore all the commits in the current branch.
    PARENT_BRANCH=$(echo $PARENT_BRANCH | grep -v "$CURRENT_BRANCH")
    # 4. The first result will be the nearest ancestor branch. Ignore the other results.
    PARENT_BRANCH=$(echo $PARENT_BRANCH | head -n1)
    # 5. Branch names are displayed [in brackets]. Ignore everything outside the brackets, and the brackets.
    PARENT_BRANCH=$(echo $PARENT_BRANCH | sed 's/.*\[\(.*\)\].*/\1/')
    # 6. Sometimes the branch name will include a ~# or ^# to indicate how many commits are between the referenced commit and the branch tip. We don't care. Ignore them.
    PARENT_BRANCH=$(echo $PARENT_BRANCH | sed 's/[\^~].*//')

    echo $PARENT_BRANCH
}

get_commits_between_branchs() {
    FROM=${1:-$(get_current_branch)}
    TO=$(get_parent_branch $BRANCH)

    COMMITS_DIFF=$(git log ${FROM}..${TO} --oneline)
    echo $COMMITS_DIFF
}

get_first_commit_in_branch() {
    BRANCH=${1:-$(get_current_branch)}
    PARENT_BRANCH=$(get_parent_branch $BRANCH)

    COMMITS_DIFF=$(get_commit_diff_between_branchs ${PARENT_BRANCH} ${BRANCH})
    FIRST_COMMIT=$(echo $COMMITS_DIFF | tail -1)

    echo $FIRST_COMMIT
}
