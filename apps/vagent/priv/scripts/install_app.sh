#!/usr/bin/env bash

# set -x
readonly SCRIPT_NAME=$(basename $0)

function help {
    echo "Usage: $0 <app_name> <app_version>"
    exit 1
}

if [ $# -ne 2 ]; then
    help
fi

APP_NAME=$1
APP_VERSION=$2

if [ "$APP_VERSION" == "latest" ]; then
    sudo apt install -y $APP_NAME
    e=$?
fi

if [ "$APP_VERSION" != "latest" ]; then
    sudo apt install -y $APP_NAME=$APP_VERSION
    e=$?
fi

if [ $e -ne 0 ]; then
    echo -ne "Failed_to_install"
    exit 1
fi

echo -ne "install_app_success"
exit 0
