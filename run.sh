#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

set -u

if [[ $(id -u) -ne 0 ]]; then
    echo -e "\e[1m\e[31;1m Please run this script as root \e[0m"
    exit 1
fi

source "scripts/textutils.sh"
source "scripts/fileutils.sh"

printHelp() {
    printMsg "\n ${T_BOLD}${C_BLUE}Run Script${T_RESET}"
    printMsg " This script simply starts (or restarts) the containers in the docker-compose.yml file."
    printMsg " If this is your first time deploying, please use ${T_BOLD}${C_YELLOW}build.sh${T_RESET} first."
    printMsg " Running this script without any arguments will safely attempt "
    printMsg " to bring up all containers without any downtime."
    printMsg ""
    printMsg " You can specify one the following options:"
    printMsg "  ${T_BOLD}-m${T_RESET}, --no-dnsmasq    Dnsmasq service will not be started (no DHCP or PXE)"
    printMsg "  ${T_BOLD}-f${T_RESET}, --force         Will forceably stop & re-create the containers"
    printMsg "  ${T_BOLD}-r${T_RESET}, --restart       Will only restart the containers"
    printMsg "  ${T_BOLD}-d${T_RESET}, --down          Will stop all containers and cleanup excess mounts"
    printMsg "  ${T_BOLD}-n${T_RESET}, --no-tail-logs  Do not tail the containers' logs after completion (default is to tail)"
    printMsg "  ${T_BOLD}-D${T_RESET}, --dynamic       RUN ESP with dynamic profile support, if included in build"
    printMsg "  ${T_BOLD}-h${T_RESET}, --help          Show this help dialog"
    printMsg ""
    printMsg " Usage: ./run.sh"
    printMsg ""
    exit 0
}

NO_DNSMASQ="false"
FORCE_RECREATE="false"
FORCE_RESTART="false"
DOWN="false"
NO_TAIL_LOGS="false"

# export HOSTNAME to make docker-compose can read it
export HOSTNAME="$(hostname)"

for var in "$@"; do
    case "${var}" in
        "-m" | "--no-dnsmasq"   ) NO_DNSMASQ="true";;
        "-f" | "--force"        ) FORCE_RECREATE="true";;
        "-r" | "--restart"      ) FORCE_RESTART="true";;
        "-d" | "--down"         ) DOWN="true";;
        "-n" | "--no-tail-logs" ) NO_TAIL_LOGS="true";;
        "-h" | "--help"         ) printHelp;;
    esac
done

printMsg "\n-------------------------"
printMsg " ${T_BOLD}${C_BLUE}Welcome${T_RESET}"
printMsg "-------------------------"
logMsg "Welcome to the builder host run script"

parseConfig

if [[ "${DOWN}" == "true" ]]; then
    printDatedInfoMsg "Stopping containers..."
    logMsg "run.sh down containers"
    sleep 1
    if podman -v >/dev/null 2>&1; then
        scripts/espctl.sh down
    else
        docker-compose down
    fi
    PWD=$(pwd)
    umount template/pxe_bg.png -l >/dev/null 2>&1
    umount data/srv/tftp/images -l >/dev/null 2>&1
    umount data/srv/tftp/pxelinux.cfg -l >/dev/null 2>&1
    umount data/srv/tftp/pxelinux.cfg_legacy -l >/dev/null 2>&1
    umount data/usr/share/nginx/html/tftp -l >/dev/null 2>&1
    sync >/dev/null 2>&1
    exit
fi

if [[ "${FORCE_RESTART}" == "true" ]]; then
    printDatedInfoMsg "Restarting containers..."
    logMsg "run.sh restarting containers"
    if podman -v >/dev/null 2>&1; then
        scripts/espctl.sh restart
    else
        docker-compose restart
    fi
else
    if [[ "${FORCE_RECREATE}" == "true" ]]; then
        printDatedInfoMsg "Stopping containers..."
        logMsg "run.sh force-recreating containers"
        sleep 1
        if podman -v >/dev/null 2>&1; then
            scripts/espctl.sh down
        else
            docker-compose down
        fi
        PWD=$(pwd)
        umount template/pxe_bg.png -l >/dev/null 2>&1
        umount data/srv/tftp/images -l >/dev/null 2>&1
        umount data/srv/tftp/pxelinux.cfg -l >/dev/null 2>&1
        umount data/srv/tftp/pxelinux.cfg_legacy -l >/dev/null 2>&1
        umount data/usr/share/nginx/html/tftp -l >/dev/null 2>&1
        sync >/dev/null 2>&1
    fi

    if [[ "${builder_config_disable_dnsmasq-false}" == "false" ]]; then
        if [[ "${NO_DNSMASQ}" == "false" ]]; then
            printDatedInfoMsg "Starting dnsmasq container..."
            logMsg "run.sh bringing up containers"
            if podman -v >/dev/null 2>&1; then
                scripts/espctl.sh up dnsmasq
            else
                docker-compose up -d dnsmasq
            fi
            printDatedInfoMsg "Waiting a moment before starting the remaining containers..."
            sleep 3
        fi
    fi

    if podman -v >/dev/null 2>&1; then
        scripts/espctl.sh up --no-dnsmasq
    else
        DOCKER_COMPOSE_SERVICES="core web registry-mirror squid"
        if [[ "${builder_config_letsencrypt_enabled-false}" == "true" ]]; then
            DOCKER_COMPOSE_SERVICES="${DOCKER_COMPOSE_SERVICES} certbot"
        fi
        if [[ "${builder_config_disable_gitea-false}" == "false" ]]; then
            DOCKER_COMPOSE_SERVICES="${DOCKER_COMPOSE_SERVICES} mirror"
        fi
        if [[ "${builder_config_disable_smb-false}" == "false" ]]; then
            DOCKER_COMPOSE_SERVICES="${DOCKER_COMPOSE_SERVICES} smb"
        fi
        if [[ "${builder_config_dynamic_profile__enabled-x}" == "true" ]]; then
            DOCKER_COMPOSE_SERVICES="${DOCKER_COMPOSE_SERVICES} dyn-profile"
        fi
        if [[ "${builder_config_disable_fluent_logging-true}" == "false" ]]; then
            DOCKER_COMPOSE_SERVICES="${DOCKER_COMPOSE_SERVICES} logging-server"
        fi
        docker-compose up -d ${DOCKER_COMPOSE_SERVICES}
    fi
fi

if [[ "${NO_TAIL_LOGS}" == "true" ]]; then
    printBanner "${C_GREEN}Intel Edge Software Provisioner is up!"
else
    printBanner "${C_GREEN}Following Logs..."
    printMsg ""
    printMsg "${T_BOLD}It is safe to press CTRL+C at any time to stop following logs.${T_RESET}"
    printMsg ""

    # Give the user a moment to read the above message before tailing logs.
    printMsgNoNewline "."
    sleep 1
    printMsgNoNewline "."
    sleep 1
    printMsgNoNewline "."
    sleep 1
    printMsg ""

    if podman -v >/dev/null 2>&1; then
        ./scripts/espctl.sh logs -f
    else
        docker-compose logs -f
    fi
fi
