#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

set -u

if [[ $(id -u) -ne 0 ]]; then
    echo -e "\e[1m\e[31;1m Please run this script as root \e[0m"
    exit 1
fi

source "scripts/textutils.sh"

printHelp() {
    printMsg "\n Main ${T_BOLD}${C_BLUE}Build Script${T_RESET}"
    printMsg " You can specify one the following options:"
    printMsg "  ${T_BOLD}-p${T_RESET}, --skip-profile-builds  Skips the execution of profile-specific build.sh scripts"
    printMsg "  ${T_BOLD}-P${T_RESET}, --skip-profiles        Skips syncronizing profiles"
    printMsg "  ${T_BOLD}-f${T_RESET}, --skip-files           Skips syncronizing the files for profiles"
    printMsg "  ${T_BOLD}-s${T_RESET}, --skip-build-uos       Skips building the Utility Operating System (UOS)"
    printMsg "  ${T_BOLD}-S${T_RESET}, --skip-image-builds    Skips building all images and UOS"
    printMsg "  ${T_BOLD}-c${T_RESET}, --clean-uos            will clean the intermediary docker images used during building of UOS"
    printMsg "  ${T_BOLD}-b${T_RESET}, --skip-backups         Skips the creation of backup files inside the data directory when re-running build.sh"
    printMsg "  ${T_BOLD}--profile${T_RESET}                  Synchronize a specific profile and skip all others"
    printMsg "  ${T_BOLD}-h${T_RESET}, --help                 Show this help dialog"
    printMsg ""
    printMsg " Usage: ./build.sh"
    printMsg ""
    exit 0
}

UOS_CLEAN="false"
BUILD_UOS="true"
BUILD_IMAGES="true"
SKIP_FILES="false"
SKIP_BACKUPS="false"
SKIP_PROFILES="false"
SKIP_PROFILE_BUILDS="false"
SINGLE_PROFILE=""
while (( "$#" )); do
    case "$1" in
        "-c" | "--clean-uos"           )    export UOS_CLEAN="true"
                                            shift 1;;
        "-s" | "--skip-build-uos"      )    export BUILD_UOS="false"
                                            shift 1;;
        "-S" | "--skip-image-builds"   )    export BUILD_IMAGES="false"
                                            shift 1;;
        "-f" | "--skip-files"          )    export SKIP_FILES="true"
                                            shift 1;;
        "-b" | "--skip-backups"        )    export SKIP_BACKUPS="true"
                                            shift 1;;
        "-p" | "--skip-profile-builds" )    export SKIP_PROFILE_BUILDS="true"
                                            shift 1;;
        "-P" | "--skip-profiles"       )    export SKIP_PROFILES="true"
                                            shift 1;;
        "-l" | "--profile"             )    export SINGLE_PROFILE=$2
                                            shift 2;;
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

source "scripts/fileutils.sh"
source "scripts/bulkfileutils.sh"

printMsg "\n----------------------------------"
printMsg " ${T_BOLD}${C_BLUE}Welcome to the host build script${T_RESET}"
printMsg "----------------------------------"
logMsg "----------------------------------"
logMsg " Welcome to the host build script"
logMsg "----------------------------------"

# Parse the config before doing anything else
printBanner "Checking ${C_GREEN} Config..."
logMsg "Checking Config..."
parseConfig

source "scripts/templateutils.sh"

# Incorporate proxy preferences
if [ "${HTTP_PROXY+x}" != "" ] && [ "${http_proxy+x}" = "" ]; then
    export http_proxy=${HTTP_PROXY}
    if [ "${HTTPS_PROXY+x}" != "" ]; then
        export https_proxy=${HTTPS_PROXY}
    else
        export https_proxy=${HTTP_PROXY}
    fi
elif [ "${HTTP_PROXY+x}" = "" ] && [ "${http_proxy+x}" != "" ]; then
    export HTTP_PROXY=${http_proxy}
    if [ "${https_proxy+x}" != "" ]; then
        export HTTPS_PROXY=${https_proxy}
    else
        export HTTPS_PROXY=${http_proxy}
    fi
fi
if [ "${HTTP_PROXY+x}" != "" ]; then
    export DOCKER_BUILD_ARGS="--build-arg http_proxy='${http_proxy}' --build-arg https_proxy='${https_proxy}' --build-arg HTTP_PROXY='${HTTP_PROXY}' --build-arg HTTPS_PROXY='${HTTPS_PROXY}' --build-arg NO_PROXY='localhost,127.0.0.1'"
    export DOCKER_RUN_ARGS="--env http_proxy='${http_proxy}' --env https_proxy='${https_proxy}' --env HTTP_PROXY='${HTTP_PROXY}' --env HTTPS_PROXY='${HTTPS_PROXY}' --env NO_PROXY='localhost,127.0.0.1'"
    export AWS_CLI_PROXY="export http_proxy='${http_proxy}'; export https_proxy='${https_proxy}'; export HTTP_PROXY='${HTTP_PROXY}'; export HTTPS_PROXY='${HTTPS_PROXY}'; export NO_PROXY='localhost,127.0.0.1';"
else
    export DOCKER_BUILD_ARGS=""
    export DOCKER_RUN_ARGS=""
    export AWS_CLI_PROXY=""
fi

# Build Utility OS, if desired
if [[ "${BUILD_UOS}" == "true" ]] && [[ "${BUILD_IMAGES}" == "true" ]]; then
    printBanner "Building ${C_GREEN}Utility OS (UOS)..."
    logMsg "Building Utility OS (UOS)..."
    source "scripts/buildUOS.sh"
else
    printDatedInfoMsg "Skipping Build of UOS..."
    logMsg "Skipping Build of UOS..."
fi

if [[ "${BUILD_IMAGES}" == "true" ]]; then
    printBanner "Building ${C_GREEN}Utility Images..."

    # Using Docker for these utilities
    # reduces the footprint of our application

    # Build the aws-cli image
    run "(1/5) Building builder-aws-cli" \
        "docker build --rm ${DOCKER_BUILD_ARGS} -t builder-aws-cli dockerfiles/aws-cli" \
        ${LOG_FILE}

    # Build the wget image
    run "(2/5) Building builder-wget" \
        "docker build --rm ${DOCKER_BUILD_ARGS} -t builder-wget dockerfiles/wget" \
        ${LOG_FILE}

    # Build the git image
    run "(3/5) Building builder-git" \
        "docker build --rm ${DOCKER_BUILD_ARGS} -t builder-git dockerfiles/git" \
        ${LOG_FILE}

    # Build the dnsmasq image
    run "(4/5) Building builder-dnsmasq" \
        "docker build --rm ${DOCKER_BUILD_ARGS} -t builder-dnsmasq dockerfiles/dnsmasq" \
        ${LOG_FILE}

    # Build the squid image
    run "(5/5) Building builder-squid" \
        "docker build --rm ${DOCKER_BUILD_ARGS} -t builder-squid dockerfiles/squid" \
        ${LOG_FILE}

else
    printDatedInfoMsg "Skipping Build of ${C_GREEN}Utility Images..."
    logMsg "Skipping Build of Utility Images..."
fi

printBanner "Checking ${C_GREEN}Network Config..."
logMsg "Checking Network Config..."
# This function will ensure that the config options for
# network options that users can specify in conf/config.yml
# are set to _something_ non-empty.
verifyNetworkConfig

# Synchronize profiles. This step encapsulates a lot of profile-specific
# actions, such as cloning a profile repository, downloading the
# files for a profile, rendering templates for a profile, etc.
source "scripts/profileutils.sh"
source "scripts/pxemenuutils.sh"
printBanner "Starting ${C_GREEN}Gitea..."
logMsg "Starting Gitea..."
startGitea

if [[ "${SKIP_PROFILES}" == "false" ]]; then
    printBanner "Synchronizing ${C_GREEN}Profiles..."
    logMsg "Synchronizing Profiles..."
    syncProfiles
else
    printDatedInfoMsg "Skipping ${C_GREEN}Profile Sync"
    logInfoMsg "Skipping Profile Sync"
fi

# This next step will propagate the network configuration that was determined
# at the beginning of this script to dnsmasq.conf and the PXE menu
printBanner "Rendering ${C_GREEN}System Templates..."
logMsg "Rendering System Templates..."

# Begin the process of generating a temporary
# pxelinux.cfg/default file
printBanner "Generating ${C_GREEN}PXE Menu..."
logMsg "Generating PXE Menu..."
genPxeMenuHead
profilesActions genProfilePxeMenu
genPxeMenuTail

renderSystemNetworkTemplates
updatePxeMenu

# Finishing message
printBanner "${C_GREEN}Build Complete!"
logOkMsg "Build Complete!"

printMsg "\n${T_BOLD}Next, please use this command as root to start the services:${T_RESET}"
printMsg "\n${T_BOLD}${C_GREEN}./run.sh${T_RESET}\n"
