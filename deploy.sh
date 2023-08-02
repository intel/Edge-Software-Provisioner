#!/bin/bash

# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

if [[ $(id -u) -ne 0 ]]; then
    echo -e "\e[1m\e[31;1m Please run this script as root \e[0m"
    exit 1
fi

if (! which docker > /dev/null 2>&1); then
    echo -e "\e[1m\e[31;1m Please install docker before running this program \e[0m"
    exit 1
fi

if (! which docker-compose > /dev/null 2>&1); then
    mkdir -p /usr/local/bin
    wget --no-check-certificate -qO /usr/local/bin/docker-compose "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)"
		chmod a+x /usr/local/bin/docker-compose
fi

mkdir -p /opt/esp && \
cd /opt/esp && \
wget --no-check-certificate -O /opt/esp/docker-compose.yml https://raw.githubusercontent.com/iroxintel/Edge-Software-Provisioner/v3.1.2/compose/docker-compose.yml && \
docker-compose up -d core mirror && \
while (! ls /opt/esp/run.sh > /dev/null 2>&1 ); do \
	echo "Waiting for run.sh file to be created"; \
	sleep 5; \
done && \
./run.sh -n
