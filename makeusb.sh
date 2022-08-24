#!/bin/bash

# Copyright (C) 2021 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

set -u

if [[ $(id -u) -ne 0 ]]; then
    echo -e "\e[1m\e[31;1m Please run this script as root \e[0m"
    exit 1
fi

# If running from within container change to builder directory
if [ "${BUILDER_PATH:=}" != "" ]; then
    cd ${BUILDER_PATH}
fi

source "scripts/textutils.sh"
source "scripts/fileutils.sh"
source "scripts/bulkfileutils.sh"
source "scripts/profileutils.sh"
source "scripts/pxemenuutils.sh"
source "scripts/templateutils.sh"

if [ -f ".env" ]; then
    source ".env"
fi

printHelp() {
    printMsg "\n Main ${T_BOLD}${C_BLUE}Make USB Script${T_RESET}"
    printMsg " You can specify one the following options:"
    printMsg "  ${T_BOLD}-p${T_RESET}, --profile              Build USB bootable image for the specified Profile. The image will be located in data/usr/share/nginx/html/usb/(Profile Name)/.  If omitted it will build menu system to select a profile from the USB stick."
    printMsg "  ${T_BOLD}-b${T_RESET}, --bios                 Set USB bootable stick to legacy BIOS or EFI, valid options [ efi | bios ].  Defaults to efi."
    printMsg "  ${T_BOLD}-l${T_RESET}, --bootloader           Set USB bootable stick bootloader to IPXE or SYSLINUX, valid options [ ipxe | syslinux ].  Defaults to syslinux."
    printMsg "  ${T_BOLD}-d${T_RESET}, --dev                  Path to usb devices, for example '/dev/sdc'. WARNING: this will wipe out the target device.  If omitted it will provide instructions how to flash a USB device."
    printMsg "  ${T_BOLD}-m${T_RESET}, --skip-memory          Skip system memory check."
    printMsg "  ${T_BOLD}-n${T_RESET}, --skip-net             Skips network autodetection and verification"
    printMsg "  ${T_BOLD}-g${T_RESET}, --random               Generate a random name for the image."
    printMsg "  ${T_BOLD}-h${T_RESET}, --help                 Show this help dialog"
    printMsg ""
    printMsg " Usage: $0 --profile Clear_Linux --bios efi"
    printMsg ""
    exit 0
}

export USB_PROFILE=""
export USB_BIOS="efi"
export USB_BOOTLOADER="syslinux"
export USB_DEV=""
export USB_RANDOM="false"
export SKIP_MEMORY="false"
export SKIP_NET="false"
export SINGLE_PROFILE=""
while (( "$#" )); do
    case "$1" in
        "-p" | "--profile"             )    export USB_PROFILE=$2
                                            shift 2;;
        "-b" | "--bios"                )    export USB_BIOS=$2
                                            shift 2;;
        "-l" | "--bootloader"          )    export USB_BOOTLOADER=$2
                                            shift 2;;
        "-d" | "--dev"                 )    export USB_DEV=$2
                                            shift 2;;
        "-m" | "--skip-memory"         )    export SKIP_MEMORY="true"
                                            shift 1;;
        "-n" | "--skip-net"            )    export SKIP_NET="true"
                                            shift 1;;
        "-g" | "--random"              )    export USB_RANDOM="true"
                                            shift 1;;
        "-v" | "--verbose"             )    export VERBOSE="true"
                                            shift 1;;
        "-h" | "--help"                )    printHelp;;
        "--"                           )    # end argument parsing
                                            shift
                                            break;;
        -* | --*=                      )    # unsupported flags
                                            echo "Error: Unsupported flag $1" >&2
                                            exit 1;;
        *                              )    # preserve positional arguments
                                            PARAMS="$PARAMS $1"
                                            shift;;
    esac
done

if [ -n "${USB_PROFILE}" ]; then
    validateInput filename "${USB_PROFILE}" "'--profile' value is not a valid profile name: ${USB_PROFILE}"
fi
validateInput custom "${USB_BIOS}" "'--bios' value is not a valid value [bios|efi]: ${USB_BIOS}" "^(bios|efi)$"
if [ -n "${USB_DEV}" ]; then
    validateInput dirname "${USB_DEV}" "'--dev' value is not a valid directory name value: ${USB_DEV}"
fi

if [[ "${SKIP_MEMORY}" == "false" ]]; then
    if [ $(grep MemTotal /proc/meminfo | awk '{print $2}') -lt 3145728 ]; then
        printErrMsg "  There is not enough memory available for Makeusb.sh.  This system needs 3G or more of RAM."
        exit
    fi
fi

# Copy flashusb.sh so that is available from the web
cp ./flashusb.sh data/usr/share/nginx/html/

# Incorporate proxy preferences
if [ "${HTTP_PROXY+x}" != "" ]; then
    export DOCKER_BUILD_ARGS="--build-arg http_proxy='${http_proxy}' --build-arg https_proxy='${https_proxy}' --build-arg HTTP_PROXY='${HTTP_PROXY}' --build-arg HTTPS_PROXY='${HTTPS_PROXY}' --build-arg NO_PROXY='localhost,127.0.0.1'"
    export DOCKER_RUN_ARGS="--env http_proxy=${http_proxy} --env https_proxy=${https_proxy} --env HTTP_PROXY=${HTTP_PROXY} --env HTTPS_PROXY=${HTTPS_PROXY} --env NO_PROXY=localhost,127.0.0.1"
    export AWS_CLI_PROXY="export http_proxy='${http_proxy}'; export https_proxy='${https_proxy}'; export HTTP_PROXY='${HTTP_PROXY}'; export HTTPS_PROXY='${HTTPS_PROXY}'; export NO_PROXY='localhost,127.0.0.1';"
else
    export DOCKER_BUILD_ARGS=""
    export DOCKER_RUN_ARGS=""
    export AWS_CLI_PROXY=""
fi

printMsg "\n-------------------------"
printMsg " ${T_BOLD}${C_BLUE}Welcome to Make USB${T_RESET}"
printMsg "-------------------------"
logMsg "Welcome to Make USB"
parseConfig
if [[ "${SKIP_NET}" == "true" ]]; then
    printBanner "Skipping ${C_GREEN}Network Config Check..."
    logMsg "Skipping Network Config Check..."
else
    printBanner "Checking ${C_GREEN}Network Config..."
    logMsg "Checking Network Config..."
fi
verifyNetworkConfig
printMsg ""
printMsg ""

# Verifiy uOS Images are built, if not run build process
if (docker images | grep uos/kernel > /dev/null 2>&1); then
    logMsg "uos/kernel is in the local image database."
else
    printBanner "Building ${C_GREEN}Micro OS (uOS)..."
    logMsg "Building Micro OS (uOS)..."
    source "scripts/buildUOS.sh"
fi

if [[ "${builder_config_disable_uos_wifi-x}" == "true" ]]; then
    logMsg "Skipping building Micro OS (uOS)"
else
    # Verifiy uOS Images are built, if not run build process
    if (docker images | grep uos/wlan > /dev/null 2>&1); then
        logMsg "uos/wlan is in the local image database."
    else
        printBanner "Building ${C_GREEN}Micro OS (uOS)..."
        logMsg "Building Micro OS (uOS)..."
        source "scripts/buildUOS.sh"
    fi
fi

if [ -n "${USB_PROFILE}" ]; then
    makeUsbProfile genProfileUsbBoot ${USB_PROFILE}
else
    genAllProfileUsbBoot
fi
