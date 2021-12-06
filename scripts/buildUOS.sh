#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

# This file contains the logic to build the Micro OS.

# If running this file alone, uncomment these lines
# source "textutils.sh"
# source "fleutils.sh"

set -u

# /dev/null is being deleted when using a proxy and compiling tools.
# The following fix is to verify /dev/null exists and if not create /dev/null
if [ ! -c /dev/null ]; then
    rm -f /dev/null
    mknod -m 666 /dev/null c 1 3
fi

export GIT_COMMIT=$(git log -1 --oneline 2> /dev/null | awk '{print $1}')
if [ -z ${GIT_COMMIT} ]; then
    # Not a git repo, no way determine latest usobuilder image.  Always remove before builing.
    GIT_COMMIT="latest"
    if docker images | grep builder-uos; then 
        docker rmi $(docker images | grep builder-uos | awk '{print $3}')
    fi
fi
cd dockerfiles/uos
printDatedMsg "This can take a few minutes..."
if podman -v >/dev/null 2>&1; then
    touch /etc/containers/nodocker
    run "(0/12) Preparing Host Docker" \
        "docker rm hostbuilder-docker -f >/dev/null 2>&1; \
        mkdir -p /tmp/host-builder && \
        mkdir -p $(pwd)/lib/docker-host && \
        docker run -d --privileged --name hostbuilder-docker ${DOCKER_RUN_ARGS} -v /tmp/host-builder:/var/run -v $(pwd)/lib/docker-host:/var/lib/docker -v /lib/modules:/lib/modules docker:19.03.12-dind && \
        sleep 10" \
        ../../${LOG_FILE}
    run "(1/12) Downloading and preparing the kernel" \
        "docker run -t --rm --privileged ${DOCKER_RUN_ARGS} -v $(pwd):/uos -v /tmp/host-builder:/var/run docker:19.03.12-dind sh -c '\
        cd /uos && \
        docker build --rm ${DOCKER_BUILD_ARGS} -t uos/kernel -f ./Dockerfile.${UOS_KERNEL} .'" \
        ../../${LOG_FILE}
    run "(2/12) Downloading and preparing the initrd" \
        "docker run -t --rm --privileged ${DOCKER_RUN_ARGS} -v $(pwd):/uos -v /tmp/host-builder:/var/run docker:19.03.12-dind sh -c '\
        cd /uos && \
        docker build --rm ${DOCKER_BUILD_ARGS} -t uos/dyninit:v1.0 -f ./Dockerfile.dyninit .'" \
        ../../${LOG_FILE}
    run "(3/12) Building WiFi Tools" \
        "docker run -t --rm --privileged ${DOCKER_RUN_ARGS} -v $(pwd):/uos -v /tmp/host-builder:/var/run docker:19.03.12-dind sh -c '\
        cd /uos && \
        docker build --rm ${DOCKER_BUILD_ARGS} -t uos/wlan:v1.0 dockerfiles/wlan'" \
        ../../${LOG_FILE}
    run "(4/12) Building WiFi Firmware" \
        "docker run -t --rm --privileged ${DOCKER_RUN_ARGS} -v $(pwd):/uos -v /tmp/host-builder:/var/run docker:19.03.12-dind sh -c '\
        cd /uos && \
        docker build --rm ${DOCKER_BUILD_ARGS} -t uos/firmware-wifi:v1.0 -f ./dockerfiles/firmware/Dockerfile.${UOS_KERNEL} dockerfiles/firmware'" \
        ../../${LOG_FILE}
    run "(5/12) Compiling tools" \
        "if docker images | grep uosbuilder:${GIT_COMMIT}; then \
            echo 'uosbuilder exists'; \
        else \
            if docker images | grep builder-uos; then \
                docker rmi -f $(docker images | grep uosbuilder | awk '{print $3}'); \
            fi; \
            docker rm -f builder-docker >/dev/null 2>&1; \
            rm -fr /tmp/builder && \
            mkdir -p /tmp/builder && \
            mkdir -p $(pwd)/lib/docker && \
            docker run -d --privileged --name builder-docker ${DOCKER_RUN_ARGS} -v /tmp/builder:/var/run -v $(pwd)/lib/docker:/var/lib/docker docker:19.03.12-dind && \
            sleep 10 && \
            docker run -t --rm --privileged ${DOCKER_RUN_ARGS} -v $(pwd):/uos -v /tmp/builder:/var/run -v /tmp/host-builder:/tmp/host-docker docker:19.03.12-dind sh -c '\
                apk update && apk add --no-cache \
                    alpine-sdk \
                    coreutils \
                    git \
                    rsync \
                    wget && \
                git clone https://github.com/linuxkit/linuxkit --branch v0.8 && cd linuxkit/ && git checkout ad809fa3b6d133a04bf4f49f2b1e3b5f77616f6a && cd - && \
                cd /linuxkit && make && \
                docker -H unix:///tmp/host-docker/docker.sock build ${DOCKER_BUILD_ARGS} -t uosbuilder:${GIT_COMMIT} -f /uos/Dockerfile . && \
                docker -H unix:///tmp/host-docker/docker.sock save uosbuilder:${GIT_COMMIT} > /tmp/host-docker/uosbuilder.tar' && \
            docker load < /tmp/host-builder/uosbuilder.tar
            docker rm -f builder-docker && \
            rm -fr /tmp/builder; \
        fi" \
        ../../${LOG_FILE}
    run "(6/12) Building UOS" \
        "docker run -t --rm --privileged ${DOCKER_RUN_ARGS} -v /tmp/host-builder:/var/run -v $(pwd):/uos uosbuilder:${GIT_COMMIT} -c 'cd /uos && /usr/bin/linuxkit build -format kernel+initrd /uos/uos.yml' && \
        docker rm -f hostbuilder-docker && \
        rm -fr /tmp/host-builder" \
        ../../${LOG_FILE}
else
    run "(1/12) Downloading and preparing the kernel" \
        "docker build --rm ${DOCKER_BUILD_ARGS} -t uos/kernel -f ./Dockerfile.${UOS_KERNEL} ." \
        ../../${LOG_FILE}
    run "(2/12) Downloading and preparing the initrd" \
        "docker build --rm ${DOCKER_BUILD_ARGS} -t uos/dyninit:v1.0 -f ./Dockerfile.dyninit ." \
        ../../${LOG_FILE}
    run "(3/12) Building WiFi Tools" \
        "docker build --rm ${DOCKER_BUILD_ARGS} -t uos/wlan:v1.0 dockerfiles/wlan" \
        ../../${LOG_FILE}
    run "(4/12) Building WiFi Firmware" \
        "docker build --rm ${DOCKER_BUILD_ARGS} -t uos/firmware-wifi:v1.0 -f ./dockerfiles/firmware/Dockerfile.${UOS_KERNEL} dockerfiles/firmware" \
        ../../${LOG_FILE}
    run "(5/12) Compiling tools" \
        "if docker images | grep builder-uos:${GIT_COMMIT}; then \
            echo 'builder-uos exists'; \
        else \
            if docker images | grep builder-uos; then \
                docker rmi -f \$(docker images | grep builder-uos | awk '{print \$3}'); \
            fi; \
            docker rm -f builder-docker >/dev/null 2>&1; \
            rm -fr /tmp/builder && \
            docker run -d --privileged --name builder-docker ${DOCKER_RUN_ARGS} -v /tmp/builder:/var/run -v $(pwd)/lib/docker:/var/lib/docker docker:19.03.12-dind && \
            echo 'Waiting for Docker'; \
            while (! docker -H unix:////tmp/builder/docker.sock ps > /dev/null 2>&1); do echo -n '.'; sleep 0.5; done; echo 'ready' && \
            docker run -t ${DOCKER_RUN_ARGS} --rm -v $(pwd):/uos -v /tmp/builder:/var/run -v /var/run:/tmp/host-docker docker:19.03.12-dind sh -c '\
                apk update && apk add --no-cache \
                    alpine-sdk \
                    coreutils \
                    git \
                    rsync \
                    wget && \
                git clone https://github.com/linuxkit/linuxkit --branch v0.8 && cd linuxkit/ && git checkout ad809fa3b6d133a04bf4f49f2b1e3b5f77616f6a && cd - && \
                cd /linuxkit && make && \
                docker -H unix:///tmp/host-docker/docker.sock build ${DOCKER_BUILD_ARGS} -t builder-uos:${GIT_COMMIT} -f /uos/Dockerfile .' && \
            docker rm -f builder-docker && \
            rm -fr /tmp/builder; \
        fi" \
        ../../${LOG_FILE}
    run "(6/12) Building UOS" \
        "docker run -t --rm ${DOCKER_RUN_ARGS} -v /var/run/docker.sock:/var/run/docker.sock -v $(pwd):/uos builder-uos:${GIT_COMMIT} -c 'cd /uos && /usr/bin/linuxkit build -format kernel+initrd /uos/uos.yml'" \
        ../../${LOG_FILE}
fi
run "(7/12) Prepping initrd" \
    "docker run -t --rm --privileged ${DOCKER_RUN_ARGS} -v $(pwd):/uos alpine:3.12 sh -c '\
        apk update && apk add --no-cache \
            bash \
            cpio \
            coreutils \
            gzip \
            rsync && \
        cd /uos && \
        ./prepInitrd.sh 2>&1'" \
    ../../${LOG_FILE}
run "(8/12) Creating public directory to serve UOS images" \
    "mkdir -p ${TFTP_IMAGES}/uos" \
    ../../${LOG_FILE}
run "(9/12) Copying UOS initrd to public UOS directory" \
    "cp uos-initrd.img ${TFTP_IMAGES}/uos/initrd" \
    ../../${LOG_FILE}
run "(10/12) Copying UOS kernel to public UOS directory" \
    "cp uos-kernel ${TFTP_IMAGES}/uos/vmlinuz" \
    ../../${LOG_FILE}

if [[ "${UOS_CLEAN}" == true ]]; then
    run "(11/12) Cleaning up linuxkit images" \
        "docker rmi $(docker images | grep linuxkit | awk '{ print $3 }') " \
        ../../${LOG_FILE}

    run "(12/12) Cleaning up builder image" \
        "docker rmi builder-uos:${GIT_COMMIT} uos/dyninit:v1.0" \
        ../../${LOG_FILE}
else
    printMsg "Skipping (12/12) Cleaning up linuxkit images"
    # logMsg "Skipping (10/12) Cleaning up linuxkit images"
    printMsg "Skipping (12/12) Cleaning up builder images"
    # logMsg "Skipping (11/12) Cleaning up builder images"
fi

cd - >/dev/null
