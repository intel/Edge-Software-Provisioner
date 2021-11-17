#!/bin/bash

# Copyright (C) 2020 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

LOG_FILE="builder.log"

export C_RED='\e[31m'
export C_GREEN='\e[32m'
export C_YELLOW='\e[33m'
export C_BLUE='\e[34m'
export C_MAGENTA='\e[35m'
export C_CYAN='\e[36m'
export C_WHITE='\e[37m'

export C_GRAY='\e[30;1m'
export C_L_RED='\e[31;1m'
export C_L_GREEN='\e[32;1m'
export C_L_YELLOW='\e[33;1m'
export C_L_BLUE='\e[34;1m'
export C_L_MAGENTA='\e[35;1m'
export C_L_CYAN='\e[36;1m'
export C_L_WHITE='\e[37;1m'

export T_RESET='\e[0m'
export T_BOLD='\e[1m'
export T_ULINE='\e[4m'

export T_ERR="${T_BOLD}\e[31;1m"
export T_ERR_ICON="[${T_BOLD}${C_RED}✗${T_RESET}]"

export T_OK_ICON="[${T_BOLD}${C_GREEN}✓${T_RESET}]"
export T_INFO_ICON="[${T_BOLD}${C_YELLOW}i${T_RESET}]"
export T_QST_ICON="${T_BOLD}[?]${T_RESET}"

function printMsg() {
    echo -e "${T_RESET}${1}" 2>&1
}

function printMsgNoNewline() {
    echo -n -e "${1}" 2>&1
}

function getFormattedDate() {
    date +"%Y-%m-%d %I:%M:%S"
}

function getPrettyDate() {
    echo "${C_BLUE}$(getFormattedDate)${T_RESET}"
}

function printDatedMsg() {
    printMsg "$(getPrettyDate) ${1}${T_RESET}"
}

function printDatedInfoMsg() {
    printDatedMsg "${T_INFO_ICON} ${1}"
}

function printErrMsg() {
    printMsg "${T_ERR_ICON}${T_ERR} ${1} ${T_RESET}"
}

function printDatedErrMsg() {
    printDatedMsg "${T_ERR_ICON}${T_ERR} ${1}"
}

function printOkMsg() {
    printMsg "${T_OK_ICON} ${1}${T_RESET}"
}

function printDatedOkMsg() {
    printDatedMsg "${T_OK_ICON} ${1}${T_RESET}"
}

function printBanner() {
    printMsg "\n${T_BOLD}${C_BLUE}${1}${T_RESET}"
}

# logMsg will log the given message
# $1 is the message to log
# $2 is optional log location
function logMsg() {
    # if a path was passed in, use it
    # otherwise, default to base log file
    local logLocation=${2:-${LOG_FILE}}

    echo "$(getFormattedDate) ${1}" >> "${logLocation}"
}

function logInfoMsg() {
    # if a path was passed in, use it
    # otherwise, default to base log file
    local logLocation=${2:-${LOG_FILE}}

    logMsg "INFO ${1}" "${logLocation}"
}

function logErrMsg() {
    # if a path was passed in, use it
    # otherwise, default to base log file
    local logLocation=${2:-${LOG_FILE}}

    logMsg "ERROR ${1}" "${logLocation}"
}

function logFatalErrMsg() {
    # if a path was passed in, use it
    # otherwise, default to base log file
    local logLocation=${2:-${LOG_FILE}}
    
    logErrMsg "${1}" "${logLocation}"
    echo -e "${T_ERR}Preview:${T_RESET}" 2>&1
    tail -n 3 ${LOG_FILE} 2>&1
    echo -e "${T_ERR}Please check ${LOG_FILE} for more details.${T_RESET}\n\n" 2>&1
    exit 1
}

function logOkMsg() {
    # if a path was passed in, use it
    # otherwise, default to base log file
    local logLocation=${2:-${LOG_FILE}}

    logMsg "OK ${1}" "${logLocation}"
}

function printAndLogDatedInfoMsg() {
    # if a path was passed in, use it
    # otherwise, default to base log file
    local logLocation=${2:-${LOG_FILE}}

    printDatedInfoMsg "${1}"
    logMsg "${1}" "${logLocation}"
}

function printAndLogDatedErrMsg() {
    # if a path was passed in, use it
    # otherwise, default to base log file
    local logLocation=${2:-${LOG_FILE}}

    printDatedErrMsg "${1}"
    logErrMsg "${1}" "${logLocation}"
}

function printAndLogDatedOkMsg() {
    # if a path was passed in, use it
    # otherwise, default to base log file
    local logLocation=${2:-${LOG_FILE}}

    printDatedOkMsg "${1}"
    logOkMsg "${1}" "${logLocation}"
}

function spinner() {
    local pid="$!"
    local spinstr="-\|/*"
    #tput civis # cursor invisible
    #while [ "$(ps a -o pid | grep ${pid})" ]; do
    while kill -0 ${pid} 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "${spinstr}" 2>&1
        local spinstr=${temp}${spinstr%"$temp"}
        sleep 0.08
        printf "\b\b\b\b\b\b" 2>&1
    done
    #tput cnorm # cursor visible
    printf "    \b\b\b\b" 2>&1
}

# function to run a long running process and show a spinner
# sample: run "message to display" <command to run> <where to log>
function run() {
    local msg=$1
    local runThis=$2
    local log=$3
    echo -e -n "$(getPrettyDate) ${msg}...${T_RESET}" 2>&1
    {
        # this is grouped so that the log is only appended once
        echo "$(getFormattedDate) START ${msg}..." 
        echo -e "${runThis}"
    } >> "${log}"
    (eval "${runThis}" >> "${log}" 2>&1) &
    spinner
    wait %1
    exitcode=$?
    if [ ${exitcode} -ne 0 ]; then
        local success=false
    else
        local success=true
    fi

    if [ "${success}" = false ]; then
        echo "$(getFormattedDate) FAILED: Running ${runThis}..." >> "${log}"
        echo -e "\n$(getPrettyDate) ${T_ERR_ICON}${T_ERR} FAILED: Running ${runThis}${T_RESET}" 2>&1
        echo -e "\n${T_ERR}Log Preview:${T_RESET}" 2>&1
        tail -n 3 "${log}" 2>&1
        echo -e "${T_ERR}Please check ${log} for more details.${T_RESET}\n\n" 2>&1
        if [ -f conf/.build.lock ]; then
            rm conf/.build.lock > /dev/null 2>&1
        fi
        if [ -f ../../conf/.build.lock ]; then
            rm ../../conf/.build.lock > /dev/null 2>&1
        fi
        exit 1
    else
        echo "$(getFormattedDate) SUCCESS: ${msg}..." >> "${log}"
        echo -e " ${T_OK_ICON} ${C_GREEN}Success${T_RESET}" 2>&1
    fi
}

# Ensures that we can consistently handle blank inputs of the following forms:
# None
# ''
# ""
# Will return either the original value if it is not empty, or an empty value.
function validateEmptyInput() {
    local input=$1

    if [[ "${input}" == "None" || "${input}" == "\"\"" || "${input}" == "''" ]]; then
        echo ""
    else
        echo "${input}"
    fi
}

validateInput() {
    local type=$1
    local string=$2
    local msg=$3
    local regex=${4:-*}

    case ${type} in

        "url" )
            local regex='^(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]\.[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]$'
            if [[ ! ${string} =~ ${regex} ]]; then
                printErrMsg "  ${msg}"
                exit;
            fi
        ;;

        "fqdn" )
            local regex='^(?=^.{4,253}$)(^(?:[a-zA-Z](?:(?:[a-zA-Z0-9\-]){0,61}[a-zA-Z])?\.)+[a-zA-Z]{2,}$)$'
            if [[ ! ${string} =~ ${regex} ]]; then
                printErrMsg "  ${msg}"
                exit;
            fi
        ;;

        "email" )
            local regex='^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$'
            if [[ ! ${string} =~ ${regex} ]]; then
                printErrMsg "  ${msg}"
                exit;
            fi
        ;;

        "filename" )
            local regex='^[A-Za-z0-9_\-\.]+$'
            if [[ ! ${string} =~ ${regex} ]]; then
                printErrMsg "  ${msg}"
                exit;
            fi
        ;;

        "dirname" )
            local regex='^[A-Za-z0-9_\-\/\.]+$'
            if [[ ! ${string} =~ ${regex} ]]; then
                printErrMsg "  ${msg}"
                exit;
            fi
        ;;

        "numeric" )
            local regex='^[0-9]+$'
            if [[ ! ${string} =~ ${regex} ]]; then
                printErrMsg "  ${msg}"
                exit;
            fi
        ;;

        "container" )
            local regex='^[A-Za-z0-9_\-\/\.:]+$'
            if [[ ! ${string} =~ ${regex} ]]; then
                printErrMsg "  ${msg}"
                exit;
            fi
        ;;

        "custom" )
            if [[ ! ${string} =~ ${regex} ]]; then
                printErrMsg "  ${msg}"
                exit;
            fi
        ;;

    esac

}
