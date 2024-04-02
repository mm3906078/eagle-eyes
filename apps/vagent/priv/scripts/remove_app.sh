#!/usr/bin/env bash

# set -x
readonly SCRIPT_NAME=$(basename $0)

function help {
    echo "Usage: $0 <app_name>"
    exit 1
}

if [ $# -ne 1 ]; then
    help
fi

APP_NAME=$1

sudo apt remove -y $APP_NAME
e=$?

if [ $e -ne 0 ]; then
    echo -ne "Failed_to_remove"
    exit 1
fi

echo -ne "remove_app_success"
exit 0
