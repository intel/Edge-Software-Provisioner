#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

# This file contains the logic to build the Utility OS.

# If running this file alone, uncomment these lines
# source "textutils.sh"
# source "fleutils.sh"

set -u

export GIT_COMMIT=$(git log -1 --oneline 2> /dev/null | awk '{print $1}')
if [ -z ${GIT_COMMIT} ]; then
    # Not a git repo, no way determine latest usobuilder image.  Always remove before builing.
    GIT_COMMIT="latest"
    if docker images | grep uosbuilder; then 
        docker rmi $(docker images | grep uosbuilder | awk '{print $3}')
    fi
fi
cd dockerfiles/uos
printDatedMsg "This can take a few minutes..."
run "(1/10) Downloading and preparing the kernel" \
    "docker build --rm ${DOCKER_BUILD_ARGS} -t clearlinux/kernel:5.5.5-911 -f ./Dockerfile.clearlinux ." \
    ../../${LOG_FILE}
run "(2/10) Downloading and preparing the initrd" \
    "docker build --rm ${DOCKER_BUILD_ARGS} -t builder/dyninit:v1.0 -f ./Dockerfile.dyninit ." \
    ../../${LOG_FILE}
run "(3/10) Compiling tools" \
    "if docker images | grep uosbuilder:${GIT_COMMIT}; then \
        echo 'uosbuilder exists'; \
    else \
        docker rmi -f $(docker images | grep uosbuilder | awk '{print $3}'); \
        docker rm -f builder-docker >/dev/null 2>&1; \
        rm -fr /tmp/builder && \
        docker run -d --privileged --name builder-docker ${DOCKER_RUN_ARGS} -v /tmp/builder:/var/run -v $(pwd)/lib/docker:/var/lib/docker docker:19.03.8-dind && \
        sleep 30 && \
        docker run -t ${DOCKER_RUN_ARGS} --rm -v $(pwd):/uos -v /tmp/builder:/var/run -v /var/run:/tmp/host-docker docker:19.03.8-dind sh -c '\
            apk update && apk add --no-cache \
                alpine-sdk \
                coreutils \
                git \
                rsync \
                wget && \
            git clone https://github.com/linuxkit/linuxkit --depth 1 --branch v0.8 && \
            cd /linuxkit && make && \
            docker -H unix:///tmp/host-docker/docker.sock build ${DOCKER_BUILD_ARGS} -t uosbuilder:${GIT_COMMIT} -f /uos/Dockerfile .' && \
        docker rm -f builder-docker && \
        rm -fr /tmp/builder; \
    fi" \
    ../../${LOG_FILE}
run "(4/10) Building UOS" \
    "docker run -t --rm ${DOCKER_RUN_ARGS} -v /var/run/docker.sock:/var/run/docker.sock -v $(pwd):/uos uosbuilder:${GIT_COMMIT} -c 'cd /uos && /usr/bin/linuxkit build -format kernel+initrd /uos/uos.yml'" \
    ../../${LOG_FILE}
run "(5/10) Prepping initrd" \
    "docker run -t --rm ${DOCKER_RUN_ARGS} -v $(pwd):/uos alpine:3.11 sh -c '\
        apk update && apk add --no-cache \
            bash \
            cpio \
            coreutils \
            gzip \
            rsync && \
        cd /uos && \
        ./prepInitrd.sh 2>&1'" \
    ../../${LOG_FILE}
run "(6/10) Creating public directory to serve UOS images" \
    "mkdir -p ${TFTP_IMAGES}/uos" \
    ../../${LOG_FILE}
run "(7/10) Moving UOS initrd to public UOS directory" \
    "cp uos-initrd.img ${TFTP_IMAGES}/uos/initrd" \
    ../../${LOG_FILE}
run "(8/10) Moving UOS kernel to public UOS directory" \
    "cp uos-kernel ${TFTP_IMAGES}/uos/vmlinuz" \
    ../../${LOG_FILE}

if [[ "${UOS_CLEAN}" == true ]]; then
    run "(9/10) Cleaning up linuxkit images" \
        "docker rmi $(docker images | grep linuxkit | awk '{ print $3 }') " \
        ../../${LOG_FILE}

    run "(10/10) Cleaning up builder image" \
        "docker rmi uosbuilder:${GIT_COMMIT} builder/dyninit:v1.0" \
        ../../${LOG_FILE}
else
    printMsg "Skipping (9/10) Cleaning up linuxkit images"
    logMsg "Skipping (9/10) Cleaning up linuxkit images"
    printMsg "Skipping (10/10) Cleaning up builder images"
    logMsg "Skipping (10/10) Cleaning up builder images"
fi

cd - >/dev/null
