#!/usr/bin/env bash

# set -x

function help() {
    echo "Usage: $0 <app_name>"
    echo if no app_name is provided, all apps will be updated
    echo multiple app_names are allowed
    exit 1
}

if [ $# -eq 0 ]; then
    sudo apt update
    sudo apt upgrade -y
    e=$?
    if [ $e -ne 0 ]; then
        echo -ne "Failed_to_update"
        exit 1
    fi
    echo -ne "update_app_success"
    exit 0
fi

for APP_NAME in "$@"; do
    sudo apt update
    sudo apt install -y $APP_NAME
    e=$?
    if [ $e -ne 0 ]; then
        echo -ne "Failed_to_update"
        exit 1
    fi
done

echo -ne "update_app_success"
exit 0
