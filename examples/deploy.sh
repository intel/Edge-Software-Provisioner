#!/bin/bash

if [[ $(id -u) -ne 0 ]]; then
    echo -e "\e[1m\e[31;1m Please run this script as root \e[0m"
    exit 1
fi

mkdir -p /opt/esp && \
cd /opt/esp && \
wget -O /opt/esp/docker-compose.yml https://github.com/myuser/esp/raw/branch/master/docker-compose.yml && \
docker-compose up -d