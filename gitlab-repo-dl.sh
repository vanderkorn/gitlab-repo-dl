#!/usr/bin/env bash

if [ -z "$GITLAB_URL" ]; then
    echo "Missing environment variable: GITLAB_URL (e.g. https://gitlab.com)"
    exit 1
fi

if [ -z "$GITLAB_TOKEN" ]; then
    echo "Missing environment variable: GITLAB_TOKEN"
    echo "See ${GITLAB_URL}/profile/account."
    exit 1
fi

if [ -z "$GITLAB_PROTOCOL" ]; then
    echo "Missing environment variable: GITLAB_PROTOCOL"
    exit 1
fi

if [ -z "$1" ]; then
    echo "Action is required. Can be one of 'group', 'all-repo-list', 'from-list'"
    exit 1
fi

if [ "$1" == "group" ]; then
    if [ -z "$2" ]; then
        echo "Group name is required."
        exit 1
    fi

    GROUP_NAME="$2"

    echo "Cloning all git projects in group $GROUP_NAME"
    
    TOTAL_PAGES=`curl "$GITLAB_URL/api/v4/groups/$GROUP_NAME/projects?private_token=$GITLAB_TOKEN&per_page=100" -sI | grep -e x-total-pages -e X-Total-Pages | awk '{print $2}' | sed 's/\\r//g'`

    for ((PAGE_NUMBER = 1; PAGE_NUMBER <= TOTAL_PAGES; PAGE_NUMBER++)); do

		if [[ "$GITLAB_PROTOCOL" == "https" ]]; then
			echo "Switch to to https protocol"
			REPO_SSH_URLS=$(curl -s "$GITLAB_URL/api/v4/groups/$GROUP_NAME/projects?private_token=$GITLAB_TOKEN&per_page=100&page=$PAGE_NUMBER" | jq '.[] | .http_url_to_repo' | sed 's/"//g' | sed 's/http:/https:/')
		else
			echo "Switch to to ssh protocol"
		    REPO_SSH_URLS=$(curl -s "$GITLAB_URL/api/v4/groups/$GROUP_NAME/projects?private_token=$GITLAB_TOKEN&per_page=100&page=$PAGE_NUMBER" | jq '.[] | .ssh_url_to_repo' | sed 's/"//g')
		fi

		for REPO_SSH_URL in $REPO_SSH_URLS; do
            REPO_PATH="$GROUP_NAME/$(echo "$REPO_SSH_URL" | awk -F'/' '{print $NF}' | awk -F'.' '{print $1}')"

            if [ ! -d "$REPO_PATH" ]; then
                echo "git clone $REPO_PATH"
                git clone "$REPO_SSH_URL" "$REPO_PATH"
            else
                echo "git pull $REPO_PATH"
                (cd "$REPO_PATH" && git pull)
            fi
        done
    done
    
    
elif [ "$1" == "all-repo-list" ]; then
    # Get total number of pages (with 20 projects per page) from HTTP header
    TOTAL_PAGES=`curl "$GITLAB_URL/api/v4/projects?private_token=$GITLAB_TOKEN&membership=true" -sI | grep -e x-total-pages -e X-Total-Pages | awk '{print $2}' | sed 's/\\r//g'`
     
    for ((PAGE_NUMBER = 1; PAGE_NUMBER <= TOTAL_PAGES; PAGE_NUMBER++)); do
		if [[ "$GITLAB_PROTOCOL" == "https" ]]; then
			echo "Switch to to https protocol"
			curl "$GITLAB_URL/api/v4/projects?private_token=$GITLAB_TOKEN&per_page=20&page=$PAGE_NUMBER&membership=true" | jq '.[] | .http_url_to_repo' | sed 's/"//g' |  sed 's/http:/https:/'
		else
			echo "Switch to to ssh protocol"
			curl "$GITLAB_URL/api/v4/projects?private_token=$GITLAB_TOKEN&per_page=20&page=$PAGE_NUMBER&membership=true" | jq '.[] | .ssh_url_to_repo' | sed 's/"//g' |  sed 's/http:/https:/'
		fi
    done
elif [ "$1" == "from-list" ]; then
    if [ -z "$2" ]; then
        echo "List file name required"
        exit 1
    fi

    if [ -z "$3" ]; then
        echo "Target directory required"
        exit 1
    fi

    LIST_FILE="$2"
    TARGET_DIR="$3"

    if [ ! -d "$TARGET_DIR" ]; then
        mkdir -p "$TARGET_DIR"
    fi

    while read REPO_SSH_URL; do
        REPO_PATH="$(echo "$REPO_SSH_URL" | awk -F':' '{print $NF}' | awk -F'.' '{print $1}')"

        if [ ! -d "$TARGET_DIR/$REPO_PATH" ]; then
            echo "git clone $REPO_PATH"
            git clone "$REPO_SSH_URL" "$TARGET_DIR/$REPO_PATH"
        else
            echo "git pull $REPO_PATH"
            (cd "$TARGET_DIR/$REPO_PATH" && git pull)
        fi
    done <"$LIST_FILE"
fi
