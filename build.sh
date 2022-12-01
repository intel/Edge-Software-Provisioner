#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

set -u

if [[ $(id -u) -ne 0 ]]; then
    echo -e "\e[1m\e[31;1m Please run this script as root \e[0m"
    exit 1
fi

# /dev/null is sometimes being deleted by a bug in Docker
# Verify /dev/null exists and is a character device file. If not, (re-)create it
if [ ! -c /dev/null ]; then
    rm -f /dev/null
    mknod -m 666 /dev/null c 1 3
fi

# If running from within container change to builder directory
if [ "${BUILDER_PATH:=}" != "" ]; then
    cd ${BUILDER_PATH}
fi

source "scripts/textutils.sh"

printHelp() {
    printMsg "\n Main ${T_BOLD}${C_BLUE}Build Script${T_RESET}"
    printMsg " You can specify one the following options:"
    printMsg "  ${T_BOLD}-p${T_RESET}, --skip-profile-builds  Skips the execution of profile-specific build.sh scripts"
    printMsg "  ${T_BOLD}-P${T_RESET}, --skip-profiles        Skips syncronizing profiles"
    printMsg "  ${T_BOLD}-f${T_RESET}, --skip-files           Skips syncronizing the files for profiles"
    printMsg "  ${T_BOLD}-s${T_RESET}, --skip-build-uos       Skips building the Micro Operating System (uOS)"
    printMsg "  ${T_BOLD}-S${T_RESET}, --skip-image-builds    Skips building all images and uOS"
    printMsg "  ${T_BOLD}-e${T_RESET}, --skip-image-embedded  Skips embedding custom files into uOS"
    printMsg "  ${T_BOLD}-n${T_RESET}, --skip-net             Skips network autodetection and verification"
    printMsg "  ${T_BOLD}-g${T_RESET}, --skip-git             Skips starting Gitea service"
    printMsg "  ${T_BOLD}-k${T_RESET}, --uos-kernel           Valid input value is [ intel | intel.signed | clearlinux | ubuntu | ubuntu.signed | fedora | redhat | alpine ].  Defaults to 'intel'. 'redhat' requires a licensed rhel system."
    printMsg "  ${T_BOLD}-c${T_RESET}, --clean-uos            will clean the intermediary docker images used during building of uOS"
    printMsg "  ${T_BOLD}-b${T_RESET}, --skip-backups         Skips the creation of backup files inside the data directory when re-running build.sh"
    printMsg "  ${T_BOLD}-l${T_RESET}, --profile              Synchronize a specific profile and skip all others"
    printMsg "  ${T_BOLD}-i${T_RESET}, --boot-profile         Set Profile as the at default PXE boot.  By default, PXE Menu will boot to disk. WARNING: if the profile is set developer this will be in and endless loop of rebooting and installing."
    printMsg "  ${T_BOLD}-t${T_RESET}, --tag                  This tag all images with a prefix to prepare images to be pushed container registry"
    printMsg "  ${T_BOLD}-u${T_RESET}, --push                 Push tagged images with prefix"
    printMsg "  ${T_BOLD}-h${T_RESET}, --help                 Show this help dialog"
    printMsg ""
    printMsg " Usage: ./build.sh"
    printMsg ""
    exit 0
}

export UOS_CLEAN="false"
export BUILD_UOS="true"
export BUILD_IMAGES="true"
export UOS_KERNEL="intel"
export SKIP_FILES="false"
export SKIP_BACKUPS="false"
export SKIP_PROFILES="false"
export SKIP_PROFILE_BUILDS="false"
export SKIP_PROFILE_EMBEDDED="false"
export SKIP_NET="false"
export SKIP_GIT="false"
export SINGLE_PROFILE=""
export BOOT_PROFILE=""
export FROM_CONTAINER="false"
export TAG=""
export PUSH=""
export DYNAMIC_PROFILE="false"
export ENV_FILE=".env"
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
        "-e" | "--skip-profile-embedded" )  export SKIP_PROFILE_EMBEDDED="true"
                                            shift 1;;
        "-P" | "--skip-profiles"       )    export SKIP_PROFILES="true"
                                            shift 1;;
        "-n" | "--skip-net"            )    export SKIP_NET="true"
                                            shift 1;;
        "-g" | "--skip-git"            )    export SKIP_GIT="true"
                                            shift 1;;
        "-k" | "--uos-kernel"          )    export UOS_KERNEL=$2
                                            shift 2;;
        "-C" | "--from-container"      )    export FROM_CONTAINER="true"
                                            shift 1;;
        "-l" | "--profile"             )    export SINGLE_PROFILE=$2
                                            shift 2;;
        "-i" | "--boot-profile"        )    export BOOT_PROFILE=$2
                                            shift 2;;
        "-t" | "--tag"                 )    export TAG=$2
                                            shift 2;;
        "-u" | "--push"                )    export PUSH=$2
                                            shift 2;;
        "-h" | "--help"                )    printHelp;;
        "--"                           )    # end argument parsing
                                            shift
                                            break;;
        -*                             )    # unsupported flags
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

if [ -f /etc/redhat-release ]; then
    if ! (podman -v >/dev/null 2>&1); then
        printErrMsg "  'podman' command is missing. Please install podman - 'yum install podman'"
        exit
    fi
elif ! (docker -v >/dev/null 2>&1); then
    printErrMsg "  'docker' command is missing. Please install docker."
    exit
fi

if [ "${UOS_KERNEL}" == "redhat" ] && [ ! -f /etc/redhat-release ]; then
    printErrMsg "  Building a Red Hat Kernel for uOS requires to be executed from a licensed Red Hat system."
    exit
fi

if [[ "${TAG}" != "" ]]; then
    export BUILD_IMAGES="false"
    export SKIP_PROFILES="true"
    if (docker images | grep builder-core >/dev/null 2>&1); then
        printBanner "Retagging container images..."
        logMsg "Retagging container images..."
        mkdir -p output
        cp docker-compose.yml output/docker-compose.yml
        for image in $(docker images | grep builder- | grep -v /builder | grep -v ${TAG} | awk '{print $3}'); do 
            echo "."
            docker tag ${image} ${TAG}/$(docker images | grep ${image} | grep -v /builder | grep -v ${TAG} | awk '{print $1}' | head -n 1)
            cur_image=$(docker images | grep ${image} | grep -v /builder | grep -v ${TAG} | awk '{print $1}' | head -n 1)
            new_image=${TAG}/$(docker images | grep ${image} | grep -v /builder | grep -v ${TAG} | awk '{print $1}' | head -n 1)
            sed -i "s#image: ${cur_image}#image: ${new_image}#" output/docker-compose.yml
        done
        for image in $(docker images | grep "uos/" | grep -v ${TAG} | awk '{print $3}'); do 
            echo "."
            cur_image=$(docker images | grep ${image} | grep -v ${TAG} | awk '{print $1}' | head -n 1)
            ver_image=$(docker images | grep ${image} | grep -v ${TAG} | awk '{print $2}' | head -n 1)
            new_image=${TAG}/${cur_image/uos\//uos-}
            docker tag ${image} ${new_image}:${ver_image}
        done
        printBanner "Retagging container images completed.  You can find a new docker-compose.yml file at 'output/docker-compose.yml'"
        logMsg "Retagging container images completed."
    else
        printBanner "Missing container images.  Please run ./build.sh without any switches to build containers..."
        logMsg "Missing container images.  Please run ./build.sh without any switches to build containers..."
    fi
    exit
fi

if [[ "${PUSH}" != "" ]]; then
    export BUILD_IMAGES="false"
    export SKIP_PROFILES="true"
    if (docker images | grep ${PUSH}/builder-core > /dev/null 2>&1); then
        printBanner "Pushing container images. (NOTE: run 'docker login' first if login required otherwise this command will fail.)"
        logMsg "Pushing container images..."
        for image in $(docker images | grep ${PUSH}/builder- | grep -v none | awk '{print $1}'); do 
            docker push ${image}:$(docker images | grep "${image} " | grep -v none | awk '{print $2}')
        done
        for image in $(docker images | grep "${PUSH}/uos-" | grep -v none | awk '{print $1}'); do 
            docker push ${image}:$(docker images | grep "${image} " | grep -v none | awk '{print $2}')
        done
    else
        printBanner "Missing container images with prefix '${PUSH}'..."
        logMsg "Missing container images with prefix '${PUSH}'..."
    fi
    exit
fi

# Build lock file is to keep more than ./build.sh process from runnning
if [ -f conf/.build.lock ]; then
    if [[ "${FROM_CONTAINER}" == "true" ]]; then
        printBanner "Build in progress. If a build is not in progress, confirm first before removing 'conf/.build.lock'."
        exit 1
    fi
    logMsg "Build in progress. If this is incorrect, confirm first from the logs of '$(docker ps | grep builder-core | awk '{print $11}')' before removing 'conf/.build.lock'..."
    printBanner "Build in progress. If a build is not in progress, confirm first before removing 'conf/.build.lock'."
    printMsg "Showing last 10 lines of '$(docker ps | grep builder-core | awk '{print $11}')' to see if its running with this command: \"docker logs $(docker ps | grep builder-core | awk '{print $11}')\""
    printBanner "$(docker ps | grep builder-core | awk '{print $11}') logs:"
    docker logs $(docker ps | grep builder-core | awk '{print $1}') | tail -10
    printMsg ""

    read -r -p "  Would you like to remove the lock file 'conf/.build.lock'? [y/n]: " answer
    validateInput custom "${answer}" "Please enter 'y' or 'n': ${answer}" "^(y|n)$"

    if [ "${answer}" = "y" ]; then
        rm conf/.build.lock
    else
        exit
    fi   
fi
touch conf/.build.lock

# Always delete env file when building. It wil be re-created during build
if [ -f ${ENV_FILE} ]; then
    rm ${ENV_FILE}
fi

# Parse the config before doing anything else
printBanner "Checking ${C_GREEN} Config..."
logMsg "Checking Config..."
parseConfig
logMsg "Parsing Secrets..."
source "scripts/secretconfig.sh"
getSecretInfo

source "scripts/templateutils.sh"

if [[ ! -z "${builder_config_dynamic_profile_enabled+x}" ]]; then
    if [[ "${builder_config_disable_dyn_profile-x}" == "true" ]] && [[ "${builder_config_dynamic_profile_enabled}" == "true" ]]; then
        printErrMsg "Dynamic Profile is enabled in 'conf/config.yml' but 'disable_dyn_profile' container build is set to 'true'.  Please set 'disable_dyn_profile' to 'false' and run './build.sh -S' again."
        exit
    elif [[ "${builder_config_dynamic_profile_enabled}" == "true" ]]; then
        export DYNAMIC_PROFILE="true"
    fi
fi

if [[ ! -z "${builder_config_interface+x}" ]]; then
    ifaceConfig=$(ip a show dev ${builder_config_interface} 2>&1)
    if [[ ${ifaceConfig} == *"does not exist"* ]]; then
        printErrMsg "The config.yml 'interface' device '${builder_config_interface}' does not exist"
        # Remove build lock
        rm conf/.build.lock 2>/dev/null
        exit
    fi
fi

# Incorporate proxy preferences
if [ "${HTTP_PROXY+x}" != "" ] && [ "${http_proxy+x}" == "" ]; then
    export http_proxy=${HTTP_PROXY}
    if [ "${HTTPS_PROXY+x}" != "" ]; then
        export https_proxy=${HTTPS_PROXY}
    else
        export https_proxy=${HTTP_PROXY}
        export HTTPS_PROXY=${http_proxy}
    fi
elif [ "${HTTP_PROXY+x}" == "" ] && [ "${http_proxy+x}" != "" ]; then
    export HTTP_PROXY=${http_proxy}
    if [ "${https_proxy+x}" != "" ]; then
        export HTTPS_PROXY=${https_proxy}
    else
        export HTTPS_PROXY=${http_proxy}
        export https_proxy=${http_proxy}
    fi
fi

if [ "${NO_PROXY+x}" != "" ] && [ "${no_proxy+x}" == "" ]; then
    export no_proxy=${NO_PROXY}
elif [ "${NO_PROXY+x}" == "" ] && [ "${no_proxy+x}" != "" ]; then
    export NO_PROXY=${no_proxy}
#none of NO_PROXY or no_proxy is set, so set both to default values
elif [ "${NO_PROXY+x}" == "" ] && [ "${no_proxy+x}" == "" ] && [ "${HTTP_PROXY+x}" != "" ]; then
    printDatedMsg "${T_INFO_ICON} no_proxy not set, using default: localhost,127.0.0.1"
    logMsg "no_proxy not set, using default: localhost,127.0.0.1"
    export NO_PROXY='localhost,127.0.0.1'
    export no_proxy='localhost,127.0.0.1'
fi

# Creating the environment file for the docker-compose
if [ "${HTTP_PROXY+x}" != "" ]; then
    echo "HTTP_PROXY=${HTTP_PROXY}" >>${ENV_FILE}
fi
if [ "${HTTPS_PROXY+x}" != "" ]; then
    echo "HTTPS_PROXY=${HTTPS_PROXY}" >>${ENV_FILE}
fi
if [ "${http_proxy+x}" != "" ]; then
    echo "http_proxy=${http_proxy}" >>${ENV_FILE}
fi
if [ "${https_proxy+x}" != "" ]; then
    echo "https_proxy=${https_proxy}" >>${ENV_FILE}
fi
if [ "${NO_PROXY+x}" != "" ]; then
    echo "NO_PROXY=${NO_PROXY}" >>${ENV_FILE}
fi
if [ "${no_proxy+x}" != "" ]; then
    echo "no_proxy=${no_proxy}" >>${ENV_FILE}
fi

if [ "${HTTP_PROXY+x}" != "" ]; then
    export DOCKER_BUILD_ARGS="--build-arg http_proxy='${http_proxy}' --build-arg https_proxy='${https_proxy}' --build-arg HTTP_PROXY='${HTTP_PROXY}' --build-arg HTTPS_PROXY='${HTTPS_PROXY}' --build-arg NO_PROXY='${NO_PROXY}' --build-arg no_proxy='${no_proxy}'"
    export DOCKER_RUN_ARGS="--env http_proxy='${http_proxy}' --env https_proxy='${https_proxy}' --env HTTP_PROXY='${HTTP_PROXY}' --env HTTPS_PROXY='${HTTPS_PROXY}' --env NO_PROXY='${NO_PROXY}' --env no_proxy='${no_proxy}'"
    export AWS_CLI_PROXY="export http_proxy='${http_proxy}'; export https_proxy='${https_proxy}'; export HTTP_PROXY='${HTTP_PROXY}'; export HTTPS_PROXY='${HTTPS_PROXY}'; export NO_PROXY='${NO_PROXY}'; export no_proxy='${no_proxy}' "
else
    export DOCKER_BUILD_ARGS=""
    export DOCKER_RUN_ARGS=""
    export AWS_CLI_PROXY=""
fi

if [ -d "data/usr/share/nginx/html/" ]; then
# Ensure previously mounted ISO images are properly unmounted
# for being able to detach the used loop device.
iso_images=$(find data/usr/share/nginx/html/ -iname '*.iso')
for iso_image in ${iso_images[@]}; do
    if mount | grep ${iso_image} >/dev/null 2>&1; then
        logMsg "umount ${iso_image}"
        umount ${iso_image}
    fi
done
fi

# Build Micro OS, if desired
if [[ "${BUILD_UOS}" == "true" ]] && [[ "${BUILD_IMAGES}" == "true" ]]; then
    printBanner "Building ${C_GREEN}Micro OS (uOS)..."
    logMsg "Building Micro OS (uOS)..."
    source "scripts/buildUOS.sh"
else
    printDatedInfoMsg "Skipping Build of uOS..."
    logMsg "Skipping Build of uOS..."
fi

if [[ "${BUILD_IMAGES}" == "true" ]]; then
    printBanner "Building ${C_GREEN}Utility Images..."

    # Using Docker for these utilities
    # reduces the footprint of our application

    # Build the aws-cli image
    if [[ "${builder_config_disable_aws_cli-x}" == "true" ]]; then
        printMsg "(1/11) SKIPPING: Building builder-aws-cli"
        logMsg "(1/11) SKIPPING: Building builder-aws-cli"
    else
        run "(1/11) Building builder-aws-cli" \
            "docker build --rm ${DOCKER_BUILD_ARGS} -t builder-aws-cli dockerfiles/aws-cli" \
            ${LOG_FILE}
    fi

    # Build the git image
    run "(2/11) Building builder-git" \
        "docker build --rm ${DOCKER_BUILD_ARGS} -t builder-git dockerfiles/git" \
        ${LOG_FILE}

    # Build the dnsmasq image
    if [[ "${builder_config_disable_dnsmasq-x}" == "true" ]]; then
        printMsg "(3/11) SKIPPING: Building builder-dnsmasq"
        logMsg "(3/11) SKIPPING: Building builder-dnsmasq"
    else
        run "(3/11) Building builder-dnsmasq (~10 min)" \
            "docker build --rm ${DOCKER_BUILD_ARGS} -t builder-dnsmasq dockerfiles/dnsmasq" \
            ${LOG_FILE}
    fi

    # Build the squid image
    run "(4/11) Building builder-squid" \
        "docker build --rm ${DOCKER_BUILD_ARGS} -t builder-squid dockerfiles/squid" \
        ${LOG_FILE}

    # Build the web image
    run "(5/11) Building builder-web" \
        "docker build --rm ${DOCKER_BUILD_ARGS} -t builder-web dockerfiles/nginx" \
        ${LOG_FILE}

    # Build the gitea image
    if [[ "${builder_config_disable_gitea-x}" == "true" ]]; then
        printMsg "(6/11) SKIPPING: Building builder-gitea"
        logMsg "(6/11) SKIPPING: Building builder-gitea"
    else
        run "(6/11) Building builder-gitea" \
            "docker build --rm ${DOCKER_BUILD_ARGS} -t builder-gitea dockerfiles/gitea" \
            ${LOG_FILE}
    fi

    # Build the qemu image
    if [[ "${builder_config_disable_qemu-x}" == "true" ]]; then
        printMsg "(7/11) SKIPPING: Building builder-qemu"
        logMsg "(7/11) SKIPPING: Building builder-qemu"
    else
        run "(7/11) Building builder-qemu" \
            "docker build --rm ${DOCKER_BUILD_ARGS} -t builder-qemu dockerfiles/qemu" \
            ${LOG_FILE}
    fi

    # Build the smb image
    if [[ "${builder_config_disable_smb-x}" == "true" ]]; then
        printMsg "(8/11) SKIPPING: Building builder-smb"
        logMsg "(8/11) SKIPPING: Building builder-smb"
    else
        run "(8/11) Building builder-smb" \
            "docker build --rm ${DOCKER_BUILD_ARGS} -t builder-smb dockerfiles/smb" \
            ${LOG_FILE}
    fi

    # Build the core image
    run "(9/11) Building builder-core" \
        "docker run -t --rm ${DOCKER_RUN_ARGS} --privileged -v $(pwd):/work alpine sh -c 'apk update && apk add --no-cache rsync && \
        cd /work && \
        mkdir -p dockerfiles/core/files/conf/ && \
        if [ ! -f dockerfiles/core/files/conf/config.yml ]; then rsync -rtc --exclude=.build.lock ./conf ./dockerfiles/core/files/; fi && \
        rsync -rtc --exclude=uos/lib/ --exclude=uos/uos-* --exclude=core/files/ ./dockerfiles ./dockerfiles/core/files/ && \
        rsync -rtc ./dockerfiles/uos/uos-*.yml ./dockerfiles/core/files/dockerfiles/uos/ && \
        rsync -rtc ./scripts ./dockerfiles/core/files/ && \
        rsync -rtc ./template ./dockerfiles/core/files/ && \
        rsync -rtc ./*.sh ./dockerfiles/core/files/ && \
        mkdir -p ./dockerfiles/core/files/data/srv/tftp/images/uos/ && \
        rsync -rtc ./data/srv/tftp/images/uos/initrd ./dockerfiles/core/files/data/srv/tftp/images/uos/initrd && \
        rsync -rtc ./data/srv/tftp/images/uos/vmlinuz ./dockerfiles/core/files/data/srv/tftp/images/uos/vmlinuz'; \
        docker build --rm ${DOCKER_BUILD_ARGS} -t builder-core dockerfiles/core" \
        ${LOG_FILE}

    # Build the certbot image
    if [[ "${builder_config_disable_certbot-x}" == "true" ]]; then
        printMsg "(10/11) SKIPPING: Building builder-certbot"
        logMsg "(10/11) SKIPPING: Building builder-certbot"
    else
        run "(10/11) Building builder-certbot" \
            "docker run -t --rm ${DOCKER_RUN_ARGS} --privileged -v $(pwd):/work alpine sh -c 'apk update && apk add --no-cache rsync && \
            cd /work && \
            rsync -rtc ./scripts ./dockerfiles/certbot/'; \
            docker build --rm ${DOCKER_BUILD_ARGS} -t builder-certbot dockerfiles/certbot" \
            ${LOG_FILE}
    fi

    # Build the dynamic profile image
    if [[ "${builder_config_disable_dyn_profile-x}" == "true" ]]; then
        printMsg "(11/11) SKIPPING: Building builder-dyn-profile"
        logMsg "(11/11) SKIPPING: Building builder-dyn-profile"
    else
        run "(11/11) Building dynamic profile service" \
            "docker build --rm ${DOCKER_BUILD_ARGS} -t builder-dyn-profile dockerfiles/dyn-profile" \
            ${LOG_FILE}
    fi

else
    printDatedInfoMsg "Skipping Build of ${C_GREEN}Utility Images..."
    logMsg "Skipping Build of Utility Images..."
fi


if [[ "${SKIP_NET}" == "true" ]]; then
    printBanner "Skipping ${C_GREEN}Network Config Check..."
    logMsg "Skipping Network Config Check..."
else
    printBanner "Checking ${C_GREEN}Network Config..."
    logMsg "Checking Network Config..."
fi
# This function will ensure that the config options for
# network options that users can specify in conf/config.yml
# are set to _something_ non-empty.
verifyNetworkConfig

# Synchronize profiles. This step encapsulates a lot of profile-specific
# actions, such as cloning a profile repository, downloading the
# files for a profile, rendering templates for a profile, etc.
source "scripts/profileutils.sh"
source "scripts/pxemenuutils.sh"

if [[ "${SKIP_GIT}" == "true" ]] || [[ "${builder_config_disable_gitea-x}" == "true" ]]; then
    printBanner "Skipping ${C_GREEN}Starting Gitea..."
    logMsg "Skipping Starting Gitea..."
else
    printBanner "Starting ${C_GREEN}Gitea..."
    logMsg "Starting Gitea..."
    startGitea
fi

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

if [[ "${DYNAMIC_PROFILE}" == "false" ]]; then
    # Begin the process of generating a temporary
    # pxelinux.cfg/default file
    printBanner "Generating ${C_GREEN}PXE Menu..."
    logMsg "Generating PXE Menu..."
    genPxeMenuHead
    profilesActions genProfilePxeMenu
    genPxeMenuTail

    printBanner "Generating ${C_GREEN}IPXE Menu..."
    logMsg "Generating IPXE Menu..."
    genIpxeMenuHead
    profilesActions genProfileIpxeMenu
    genIpxeMenuMiddle
    profilesActions genProfileIpxeGoto

    renderSystemNetworkTemplates
    updatePxeMenu
    updateIpxeMenu
else
    source "scripts/dynamicprofile.sh"
    logMsg "Setting up DynamicProfile without PXE boot menu..."
    renderSystemNetworkTemplates
    setDynamicProfileArgs
    exportProfileInfo
fi
# Finishing message
printBanner "${C_GREEN}Build Complete!"
logOkMsg "Build Complete!"

if [[ "${FROM_CONTAINER}" == "false" ]]; then
    printMsg "\n${T_BOLD}Next, please use this command as root to start the services:${T_RESET}"
    printMsg "\n${T_BOLD}${C_GREEN}./run.sh${T_RESET}\n"
fi

# Remove build lock
rm conf/.build.lock 2>/dev/null
