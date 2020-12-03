#!/bin/bash

# Copyright (C) 2020 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

set -u

if [[ $(id -u) -ne 0 ]]; then
    echo -e "\e[1m\e[31;1m Please run this script as root \e[0m"
    exit 1
fi

source "scripts/textutils.sh"
source "scripts/fileutils.sh"
source "scripts/bulkfileutils.sh"
source "scripts/profileutils.sh"
source "scripts/pxemenuutils.sh"
source "scripts/templateutils.sh"

printHelp() {
    printMsg "\n Main ${T_BOLD}${C_BLUE}Virtual PXE Script${T_RESET}"
    printMsg " You can specify one the following options:"
    printMsg "  ${T_BOLD}-d${T_RESET}, --disk-size       A numeric valude is valid measured in gigabytes.  Defaults to '10'."
    printMsg "  ${T_BOLD}-f${T_RESET}, --disk-format     Valid input value is [ qcow2 | vdi | vmdk | vpc | vhdx | parallels ].  Defaults to 'qcow2'."
    printMsg "  ${T_BOLD}-m${T_RESET}, --memory-size     A numeric valude is valid measured in megabytes.  Defaults to '2048'."
    printMsg "  ${T_BOLD}-o${T_RESET}, --output          Valid input value is [ file | container ].  Defaults to 'file'"
    printMsg "  ${T_BOLD}-h${T_RESET}, --help            Show this help dialog"
    printMsg ""
    printMsg " Usage: $0"
    printMsg ""
    exit 0
}

DISK_SIZE="10"
DISK_FORMAT="qcow2"
MEMORY="2048"
OUTPUT="file"
VERBOSE="false"
# The following var is not used in vpxe.sh but for build.sh.  It will be added for future use.
SINGLE_PROFILE=""
while (( "$#" )); do
    case "$1" in
        "-d" | "--disk-size"           )    DISK_SIZE=$2
                                            shift 2;;
        "-f" | "--disk-format"         )    DISK_FORMAT=$2
                                            shift 2;;
        "-m" | "--memory-size"         )    MEMORY=$2
                                            shift 2;;
        "-o" | "--output"              )    OUTPUT=$2
                                            shift 2;;
        "-v" | "--verbose"             )    VERBOSE="true"
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
    export DOCKER_BUILD_ARGS="--build-arg http_proxy='${http_proxy}' --build-arg https_proxy='${https_proxy}' --build-arg HTTP_PROXY='${HTTP_PROXY}' --build-arg HTTPS_PROXY='${HTTPS_PROXY}' --build-arg NO_PROXY='localhost,127.0.0.1'"
    export DOCKER_RUN_ARGS="--env http_proxy='${http_proxy}' --env https_proxy='${https_proxy}' --env HTTP_PROXY='${HTTP_PROXY}' --env HTTPS_PROXY='${HTTPS_PROXY}' --env NO_PROXY='localhost,127.0.0.1'"
    export AWS_CLI_PROXY="export http_proxy='${http_proxy}'; export https_proxy='${https_proxy}'; export HTTP_PROXY='${HTTP_PROXY}'; export HTTPS_PROXY='${HTTPS_PROXY}'; export NO_PROXY='localhost,127.0.0.1';"
else
    export DOCKER_BUILD_ARGS=""
    export DOCKER_RUN_ARGS=""
    export AWS_CLI_PROXY=""
fi

printMsg "\n-------------------------"
printMsg " ${T_BOLD}${C_BLUE}Welcome Virtual PXE${T_RESET}"
printMsg "-------------------------"
logMsg "Welcome to Virtual PXE"
parseConfig
verifyNetworkConfig
if [ "${OUTPUT}" = "container" ]; then
    run "Building builder-qemu" \
        "docker build -q --rm ${DOCKER_BUILD_ARGS} -t builder-qemu dockerfiles/qemu" \
        ${LOG_FILE}
fi
printMsg ""
printMsg ""

# Begin the process of generating a temporary
# pxelinux.cfg/default file
# printBanner "\nGenerating Virtual ${C_GREEN}PXE Menu..."
logMsg "Generating Virtual PXE Menu"
profilesActions genProfileVirtualPxeMenu
echo " q) Quit"
echo ""
read -p 'Select the Profile Number: ' selected_profile
if [ ${selected_profile} = "q" ]; then exit; fi
validateInput numeric "${selected_profile}" "Input value is not a valid numeric value: ${selected_profile}"

bootProfile genProfileVirtualPxeBoot ${selected_profile}
