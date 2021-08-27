#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

# This file is intended to contain functions that assist with the management
# of the PXE boot menu.

# If running this file alone, uncomment these lines:
# source "fileutils.sh"
# source "textutils.sh"

genPxeMenuHead() {
    makeDirectory "${TFTP_ROOT}/pxelinux.cfg"
    cp "./template/pxelinux.cfg/default.head" "${TFTP_ROOT}/pxelinux.cfg/tmp_default"
}

genPxeMenuTail() {
    if [ -f "${TFTP_ROOT}/pxelinux.cfg/tmp_default" ]; then
        cat "./template/pxelinux.cfg/default.tail" >> "${TFTP_ROOT}/pxelinux.cfg/tmp_default"
    else
        cp "./template/pxelinux.cfg/default.head" "${TFTP_ROOT}/pxelinux.cfg/tmp_default"
        cat "./template/pxelinux.cfg/default.tail" >> "${TFTP_ROOT}/pxelinux.cfg/tmp_default"
    fi
}

cleanupTmpPxeMenu() {
    if [ -f "${TFTP_ROOT}/pxelinux.cfg/tmp_default" ]; then
        rm "${TFTP_ROOT}/pxelinux.cfg/tmp_default"
    fi
    if [ -f "${TFTP_ROOT}/pxelinux.cfg/tmp_default.modified" ]; then
        rm "${TFTP_ROOT}/pxelinux.cfg/tmp_default.modified"
    fi
}

updatePxeMenu() {
    if [ -f "${TFTP_ROOT}/pxelinux.cfg/tmp_default" ]; then
        cp "${TFTP_ROOT}/pxelinux.cfg/tmp_default" "${TFTP_ROOT}/pxelinux.cfg/default"
        # makeDirectory "${TFTP_ROOT}/efi64/pxelinux.cfg"
        # cp "${TFTP_ROOT}/pxelinux.cfg/tmp_default" "${TFTP_ROOT}/efi64/pxelinux.cfg/default"
    fi
    cleanupTmpPxeMenu
}

# The usage for this is a little strange.
# If you are using this with spaces,
# you need to make sure you wrap the input
# with escaped quotes:  \"  \"
#
# for example:
# addLineToPxeMenu "\"Do this thing\""
addLineToPxeMenu() {
    local line=$1

    # The input value of line will contain quotes, so trim them now
    # local trimmed_line=$(docker run --rm -t alpine:3.9 echo "${line}" | awk -F\" '{ print $2 }')
    local trimmed_line=$(echo "${line}" | awk -F\" '{ print $2 }')

    # Write to file
    echo "${trimmed_line}" >> "${TFTP_ROOT}/pxelinux.cfg/tmp_default"
}

addLineToVirtualPxeMenu() {
    local line=$1

    # The input value of line will contain quotes, so trim them now
    # local trimmed_line=$(docker run --rm -t alpine:3.9 echo "${line}" | awk -F\" '{ print $2 }')
    local trimmed_line=$(echo "${line}" | awk -F\" '{ print $2 }')

    # Write to file
    echo "${trimmed_line}"
}

# When --boot-profile set this will make the PXE menu boot a specific profile
replaceDefaultPXEboot() {
    local number=$1

    sed -i "s#ONTIMEOUT local#ONTIMEOUT ${number}#" ${TFTP_ROOT}/pxelinux.cfg/tmp_default
}

# Helper function to return the location of the staging file for the PXE menu
getTmpPxeMenuLocation() {
    echo "${TFTP_ROOT}/pxelinux.cfg/tmp_default"
}
