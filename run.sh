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
    printMsg "\n ${T_BOLD}${C_BLUE}Run Script${T_RESET}"
    printMsg " This script simply starts (or restarts) the containers in the docker-compose.yml file."
    printMsg " If this is your first time deploying, please use ${T_BOLD}${C_YELLOW}build.sh${T_RESET} first."
    printMsg " Running this script without any arguments will safely attempt "
    printMsg " to bring up all containers without any downtime."
    printMsg ""
    printMsg " You can specify one the following options:"
    printMsg "  ${T_BOLD}-f${T_RESET}, --force         Will forceably stop & re-create the containers"
    printMsg "  ${T_BOLD}-r${T_RESET}, --restart       Will only restart the containers"
    printMsg "  ${T_BOLD}-n${T_RESET}, --no-tail-logs  Do not tail the containers' logs after completion (default is to tail)"
    printMsg "  ${T_BOLD}-h${T_RESET}, --help          Show this help dialog"
    printMsg ""
    printMsg " Usage: ./run.sh"
    printMsg ""
    exit 0
}

FORCE_RECREATE="false"
FORCE_RESTART="false"
NO_TAIL_LOGS="false"
for var in "$@"; do
    case "${var}" in
        "-f" | "--force"        ) FORCE_RECREATE="true";;
        "-r" | "--restart"      ) FORCE_RESTART="true";;
        "-n" | "--no-tail-logs" ) NO_TAIL_LOGS="true";;
        "-h" | "--help"         ) printHelp;;
    esac
done

printMsg "\n-------------------------"
printMsg " ${T_BOLD}${C_BLUE}Welcome${T_RESET}"
printMsg "-------------------------"
logMsg "Welcome to the builder host run script"

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
        umount data/usr/share/nginx/html/tftp >/dev/null 2>&1
        umount data/usr/share/nginx/html/tftp >/dev/null 2>&1
        umount data/srv/tftp >/dev/null 2>&1
        umount data/srv/tftp >/dev/null 2>&1
        umount data/usr/share/nginx/html/index.html >/dev/null 2>&1
        umount data/usr/share/nginx/html/index.html >/dev/null 2>&1
        umount template/nginx/index.html >/dev/null 2>&1
        umount template/nginx/index.html >/dev/null 2>&1
    fi

    mkdir -p /var/cache/squid && chmod 777 /var/cache/squid
    printDatedInfoMsg "Starting dnsmasq container..."
    logMsg "run.sh bringing up containers"
    if podman -v >/dev/null 2>&1; then
        scripts/espctl.sh up dnsmasq
    else
        docker-compose up -d dnsmasq
    fi
    printDatedInfoMsg "Waiting a moment before starting the remaining containers..."
    sleep 3
    if podman -v >/dev/null 2>&1; then
        scripts/espctl.sh up
    else
        docker-compose up -d
    fi
fi

if podman -v >/dev/null 2>&1; then
    printMsg ""
    printMsg ""
    printBanner "${C_RED}This system is using Podman to run ESP. Please use 'scripts/espctl.sh down' to stop ESP!"
    printMsg ""
    printMsg ""
    sleep 3
fi

if [[ "${NO_TAIL_LOGS}" == "true" ]]; then
    printBanner "${C_GREEN}Run script completed!"
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
