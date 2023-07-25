#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

# This file contains functions and global variables intended to make
# file management easier within this application's scripts.

# These are helper variables to quickly identify where things will be stored
# These variables are used globally throughout this application's scripts
export IMAGE_ROOT="$(pwd)/data/usr/share/nginx/html/containers"

saveDockerImage() {
    makeDirectory ${IMAGE_ROOT}

    # The image list, this is where you can add more images to save to webroot
    local imageList=("intel/esp-logging-agent")

    for image in ${imageList[@]}; do
        # Check if docker image exists
        if [[ "$(docker images -q ${image} 2> /dev/null)" == "" ]]; then
            logMsg "Image ${image} does not exist"
        else
            logInfoMsg "Saving image ${image}"
            docker save ${image} | gzip > "${IMAGE_ROOT}/${image/\//_}.tar.gz"
        fi
    done
}