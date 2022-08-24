#!/bin/bash

# Copyright (C) 2020 Intel Corporation
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
    printMsg "\n Main ${T_BOLD}${C_BLUE}Virtual PXE Script${T_RESET}"
    printMsg " You can specify one the following options:"
    printMsg "  ${T_BOLD}-d${T_RESET}, --disk-size       A numeric valude is valid measured in gigabytes.  Defaults to '10'."
    printMsg "  ${T_BOLD}-f${T_RESET}, --disk-format     Valid input value is [ qcow2 | vdi | vmdk | vpc | vhdx | parallels ].  Defaults to 'qcow2'."
    printMsg "  ${T_BOLD}-m${T_RESET}, --memory-size     A numeric value is valid measured in megabytes.  Defaults to '2048'."
    printMsg "  ${T_BOLD}-b${T_RESET}, --bios            Valid input value is [ efi ] or leave empty.  Defaults to empty value."
    printMsg "  ${T_BOLD}-o${T_RESET}, --output          Valid input value is [ file | container ].  Defaults to 'file'."
    printMsg "  ${T_BOLD}-p${T_RESET}, --profile         Enter the profile name to build."
    printMsg "  ${T_BOLD}-n${T_RESET}, --skip-net        Skips network autodetection and verification"
    printMsg "  ${T_BOLD}-h${T_RESET}, --help            Show this help dialog"
    printMsg ""
    printMsg " Usage: $0"
    printMsg ""
    exit 0
}

export DISK_SIZE="10"
export DISK_FORMAT="qcow2"
export MEMORY="2048"
export OUTPUT="file"
export VERBOSE="false"
export BIOS=""
export SINGLE_PROFILE=""
export SKIP_NET="false"
while (( "$#" )); do
    case "$1" in
        "-d" | "--disk-size"           )    export DISK_SIZE=$2
                                            shift 2;;
        "-f" | "--disk-format"         )    export DISK_FORMAT=$2
                                            shift 2;;
        "-m" | "--memory-size"         )    export MEMORY=$2
                                            shift 2;;
        "-b" | "--bios"                )    export BIOS=$2
                                            shift 2;;
        "-o" | "--output"              )    export OUTPUT=$2
                                            shift 2;;
        "-p" | "--profile"             )    export SINGLE_PROFILE=$2
                                            shift 2;;
        "-v" | "--verbose"             )    export VERBOSE="true"
                                            shift 1;;
        "-n" | "--skip-net"            )    export SKIP_NET="true"
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

validateInput numeric "${DISK_SIZE}" "'--disk-size' value is not a valid numeric value: ${DISK_SIZE}"
validateInput custom "${DISK_FORMAT}" "'--disk-format' value is not a valid value [qcow2|vdi|vmdk|vpc|vhdx|parallels]: ${DISK_FORMAT}" "^(qcow2|vdi|vmdk|vpc|vhdx|parallels)$"
validateInput numeric "${MEMORY}" "'--memory-size' value is not a valid numeric value: ${MEMORY}"
validateInput custom "${OUTPUT}" "'--output' value is not a valid value [file|container]: ${OUTPUT}" "^(file|container)$"

if [ $(grep MemTotal /proc/meminfo | awk '{print $2}') -lt 3145728 ]; then
    printErrMsg "  There is not enough memory available for Virtual PXE.  This system needs 3G or more of RAM."
fi

# Incorporate proxy preferences
if [ "${HTTP_PROXY+x}" != "" ]; then
    export DOCKER_BUILD_ARGS="--build-arg http_proxy='${http_proxy}' --build-arg https_proxy='${https_proxy}' --build-arg HTTP_PROXY='${HTTP_PROXY}' --build-arg HTTPS_PROXY='${HTTPS_PROXY}' --build-arg NO_PROXY='${NO_PROXY}' --build-arg no_proxy='${no_proxy}'"
    export DOCKER_RUN_ARGS="--env http_proxy='${http_proxy}' --env https_proxy='${https_proxy}' --env HTTP_PROXY='${HTTP_PROXY}' --env HTTPS_PROXY='${HTTPS_PROXY}' --env NO_PROXY='${NO_PROXY}' --env no_proxy='${no_proxy}'"
    export AWS_CLI_PROXY="export http_proxy='${http_proxy}'; export https_proxy='${https_proxy}'; export HTTP_PROXY='${HTTP_PROXY}'; export HTTPS_PROXY='${HTTPS_PROXY}'; export NO_PROXY='${NO_PROXY}'; export no_proxy='${no_proxy}';"
else
    export DOCKER_BUILD_ARGS=""
    export DOCKER_RUN_ARGS=""
    export AWS_CLI_PROXY=""
fi

printMsg "\n-------------------------"
printMsg " ${T_BOLD}${C_BLUE}Welcome to Virtual PXE${T_RESET}"
printMsg "-------------------------"
logMsg "Welcome to Virtual PXE"
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

if [ -z "${SINGLE_PROFILE}" ]; then
    # Begin the process of generating Virtual PXE Menu
    logMsg "Generating Virtual PXE Menu"
    profilesActions genProfileVirtualPxeMenu
    echo " q) Quit"
    echo ""
    read -p 'Select the Profile Number: ' selected_profile
    if [ ${selected_profile} = "q" ]; then exit; fi
    validateInput numeric "${selected_profile}" "Input value is not a valid numeric value: ${selected_profile}"
else
    selected_profile=$(profilesActions getProfileNumber)
fi

bootProfile genProfileVirtualPxeBoot ${selected_profile}
