#!/bin/bash

# Copyright (C) 2021 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

# This file contains functions that are intended to trigger the downloading
# or management of potentially large numbers of files. Functions in this file
# typically run functions from fileutils.sh in looped constructs.


##############################################################################
# This script is used to manage ESP with podman

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
    printMsg "\n Main ${T_BOLD}${C_BLUE}ESP Control Script${T_RESET}"
    printMsg " You can specify one the following options:"
    printMsg "  ${T_BOLD}up${T_RESET}                    This will start all ESP Services"
    printMsg "  ${T_BOLD}down${T_RESET}                  This will stop all ESP Services"
    printMsg "  ${T_BOLD}restart${T_RESET}               This will restart all ESP Services"
    printMsg "  ${T_BOLD}logs${T_RESET}                  This will display logs for all ESP Services"
    printMsg "  ${T_BOLD}-f${T_RESET}                    This will follow logs for all ESP Services"
    printMsg "  ${T_BOLD}-m${T_RESET}, --no-dnsmasq      Dnsmasq service will not be started (no DHCP or PXE)"
    printMsg "  ${T_BOLD}-h${T_RESET}, --help            Show this help dialog"
    printMsg ""
    printMsg " Usage: $0 up"
    printMsg ""
    exit 0
}

UP="false"
DOWN="false"
RESTART="false"
LOGS="false"
FOLLOW="false"
SERVICE=""
NO_DNSMASQ="false"
while (( "$#" )); do
    case "$1" in
        "up"                           )    UP="true"
                                            shift 1;;
        "down"                         )    DOWN="true"
                                            shift 1;;
        "restart"                      )    RESTART="true"
                                            shift 1;;
        "logs"                         )    LOGS="true"
                                            shift 1;;
        "-f"                           )    FOLLOW="true"
                                            shift 1;;
        "-m" | "--no-dnsmasq"          )    NO_DNSMASQ="true"
                                            shift 1;;
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
                                            SERVICE="$1"
                                            shift;;
    esac
done

PWD=$(pwd)
CURDIR=$(basename ${PWD})

if systemctl status firewalld | grep service > /dev/null 2>&1; then
  if ! systemctl status firewalld | grep inactive > /dev/null 2>&1; then
    systemctl stop firewalld
  fi
fi

if [[ "${UP}" == "true" ]] || [[ "${RESTART}" == "true" ]]; then
  touch /etc/timezone
  mkdir -p ./data/usr/share/nginx/html
  mkdir -p ./data/etc/ssl/private
  mkdir -p ./data/usr/share/nginx/html/web-cert
  mkdir -p ./data/srv/tftp/images
  mkdir -p ./data/srv/tftp/pxelinux.cfg
  mkdir -p ./data/etc/
  mkdir -p ./data/var/lib/registry
  mkdir -p ./data/var/log/squid
  mkdir -p ./data/var/cache/squid
  mkdir -p ./data/usr/share/nginx/html/squid-cert
  mkdir -p ./data/gitea
  mkdir -p ./data/certbot/www
  mkdir -p ./data/certbot/conf
  mkdir -p ./data/certbot/lib
  mkdir -p ./data/usr/share/nginx/html/smb
  mkdir -p ./output
fi

if [[ "${DOWN}" == "true" ]]; then
  if docker ps -a | grep ${CURDIR}_core_1 > /dev/null; then
    podman rm ${CURDIR}_core_1 -f
  fi
  if docker ps -a | grep ${CURDIR}_web_1 > /dev/null; then
    podman rm ${CURDIR}_web_1 -f
  fi
  if docker ps -a | grep ${CURDIR}_dnsmasq_1 > /dev/null; then
    podman rm ${CURDIR}_dnsmasq_1 -f
  fi
  if docker ps -a | grep ${CURDIR}_registry-mirror_1 > /dev/null; then
    podman rm ${CURDIR}_registry-mirror_1 -f
  fi
  if docker ps -a | grep ${CURDIR}_squid_1 > /dev/null; then
    podman rm ${CURDIR}_squid_1 -f
  fi
  if docker ps -a | grep ${CURDIR}_mirror_1 > /dev/null; then
    podman rm ${CURDIR}_mirror_1 -f
  fi
  if docker ps -a | grep ${CURDIR}_smb_1 > /dev/null; then
    podman rm ${CURDIR}_smb_1 -f
  fi
  if docker ps -a | grep ${CURDIR}_certbot_1 > /dev/null; then
    podman rm ${CURDIR}_certbot_1 -f
  fi
  umount template/pxe_bg.png >/dev/null 2>&1
  umount data/srv/tftp/images >/dev/null 2>&1
  umount data/srv/tftp/pxelinux.cfg >/dev/null 2>&1
  umount data/srv/tftp/pxelinux.cfg_legacy >/dev/null 2>&1
  umount data/usr/share/nginx/html/tftp >/dev/null 2>&1
fi

if [[ "${RESTART}" == "true" ]]; then
  podman restart ${CURDIR}_core_1 2> /dev/null
  podman restart ${CURDIR}_web_1 2> /dev/null
  if podman ps | grep ${CURDIR}_dnsmasq_1 > /dev/null; then
    # Restart only if was up
    podman restart ${CURDIR}_dnsmasq_1 2> /dev/null
  fi
  podman restart ${CURDIR}_registry-mirror_1 2> /dev/null
  podman restart ${CURDIR}_squid_1 2> /dev/null
  podman restart ${CURDIR}_mirror_1 2> /dev/null
  podman restart ${CURDIR}_smb_1 2> /dev/null
  podman restart ${CURDIR}_certbot_1 2> /dev/null
fi

if [[ "${UP}" == "true" ]]; then
  if ! docker ps -a | grep ${CURDIR}_core_1 > /dev/null; then
    if [ "${SERVICE}" == "" ] || [ "${SERVICE}" == "core" ]; then
      podman run -d --privileged --name=${CURDIR}_core_1 --restart=always --network host -e BUILDER_PATH=${PWD} -e PATH=${PWD}:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin -e http_proxy=${http_proxy:-} -e https_proxy=${https_proxy:-} -e ftp_proxy=${ftp_proxy:-} -e no_proxy=${no_proxy:-} -e HTTP_PROXY=${HTTP_PROXY:-} -e HTTPS_PROXY=${HTTPS_PROXY:-} -e FTP_PROXY=${FTP_PROXY:-} -e NO_PROXY=${NO_PROXY:-} --mount type=bind,source=/run,destination=/run --mount type=bind,source=${PWD}/./,destination=${PWD}/root --mount type=bind,source=${PWD}/./conf,destination=${PWD}/conf,bind-propagation=shared --mount type=bind,source=${PWD}/./data,destination=${PWD}/data,bind-propagation=shared --mount type=bind,source=${PWD}/./dockerfiles/uos,destination=${PWD}/dockerfiles/uos,bind-propagation=shared --mount type=bind,source=${PWD}/./output,destination=${PWD}/output,bind-propagation=shared --mount type=bind,source=${PWD}/./template,destination=${PWD}/template,bind-propagation=shared builder-core
    fi
  fi

  if ! docker ps -a | grep ${CURDIR}_web_1 > /dev/null; then
    if [ "${SERVICE}" == "" ] || [ "${SERVICE}" == "web" ]; then
      podman run -d --privileged --name=${CURDIR}_web_1 --restart=always -p 80:80 -p 443:443 -e CN=edgebuilder.local -e O=edgebuilder -e OU=edgebuilder -e C=US -e http_proxy=${http_proxy:-} -e https_proxy=${https_proxy:-} -e ftp_proxy=${ftp_proxy:-} -e no_proxy=${no_proxy:-} -e HTTP_PROXY=${HTTP_PROXY:-} -e HTTPS_PROXY=${HTTPS_PROXY:-} -e FTP_PROXY=${FTP_PROXY:-} -e NO_PROXY=${NO_PROXY:-} --mount type=bind,source=${PWD}/./data/certbot/conf,destination=/etc/letsencrypt --mount type=bind,source=${PWD}/./data/certbot/www,destination=/var/www/certbot --mount type=bind,source=${PWD}/./data/etc/ssl/private,destination=/etc/ssl/private --mount type=bind,source=${PWD}/./data/srv/tftp,destination=/usr/share/nginx/html/tftp,bind-propagation=shared --mount type=bind,source=${PWD}/./data/usr/share/nginx/html,destination=/usr/share/nginx/html,bind-propagation=shared --mount type=bind,source=${PWD}/./data/usr/share/nginx/html/web-cert,destination=/etc/ssl/cert --mount type=bind,source=${PWD}/./template/nginx,destination=/usr/share/nginx/template builder-web
    fi
  fi

  if ! docker ps -a | grep ${CURDIR}_dnsmasq_1 > /dev/null; then
    if { [ "${SERVICE}" == "" ] || [ "${SERVICE}" == "dnsmasq" ] ; } && [ "${NO_DNSMASQ}" = "false" ]; then
      podman run -d --privileged --name=${CURDIR}_dnsmasq_1 --restart=always --network=host -e http_proxy=${http_proxy:-} -e https_proxy=${https_proxy:-} -e ftp_proxy=${ftp_proxy:-} -e no_proxy=${no_proxy:-} -e HTTP_PROXY=${HTTP_PROXY:-} -e HTTPS_PROXY=${HTTPS_PROXY:-} -e FTP_PROXY=${FTP_PROXY:-} -e NO_PROXY=${NO_PROXY:-} --mount type=bind,source=${PWD}/./template/pxe_bg.png,destination=/srv/tftp/pxe_bg.png --mount type=bind,source=${PWD}/./template/pxe_bg.png,destination=/srv/tftp/legacy/pxe_bg.png --mount type=bind,source=${PWD}/./template/pxe_bg.png,destination=/srv/tftp/efi32/pxe_bg.png --mount type=bind,source=${PWD}/./template/pxe_bg.png,destination=/srv/tftp/efi64/pxe_bg.png --mount type=bind,source=${PWD}/./data/srv/tftp/images,destination=/srv/tftp/images --mount type=bind,source=${PWD}/./data/srv/tftp/images,destination=/srv/tftp/legacy/images --mount type=bind,source=${PWD}/./data/srv/tftp/images,destination=/srv/tftp/efi32/images --mount type=bind,source=${PWD}/./data/srv/tftp/images,destination=/srv/tftp/efi64/images --mount type=bind,source=${PWD}/./data/srv/tftp/pxelinux.cfg/,destination=/srv/tftp/pxelinux.cfg/ --mount type=bind,source=${PWD}/./data/srv/tftp/pxelinux.cfg_legacy/,destination=/srv/tftp/legacy/pxelinux.cfg/ --mount type=bind,source=${PWD}/./data/srv/tftp/pxelinux.cfg/,destination=/srv/tftp/efi32/pxelinux.cfg/ --mount type=bind,source=${PWD}/./data/srv/tftp/pxelinux.cfg/,destination=/srv/tftp/efi64/pxelinux.cfg/ --mount type=bind,source=${PWD}/./data/etc,destination=/etc/dnsmasq,bind-propagation=shared builder-dnsmasq
    fi
  fi

  if ! docker ps -a | grep ${CURDIR}_registry-mirror_1 > /dev/null; then
    if [ "${SERVICE}" == "" ] || [ "${SERVICE}" == "registry-mirror" ]; then
      podman run -d --privileged --name=${CURDIR}_registry-mirror_1 --restart=always -p 5557:5000 -e http_proxy=${http_proxy:-} -e https_proxy=${https_proxy:-} -e ftp_proxy=${ftp_proxy:-} -e no_proxy=${no_proxy:-} -e HTTP_PROXY=${HTTP_PROXY:-} -e HTTPS_PROXY=${HTTPS_PROXY:-} -e FTP_PROXY=${FTP_PROXY:-} -e NO_PROXY=${NO_PROXY:-} --mount type=bind,source=${PWD}/./template/registry/,destination=/etc/docker/registry/,bind-propagation=shared --mount type=bind,source=${PWD}/./data/var/lib/registry,destination=/var/lib/registry registry:2 
    fi
  fi

  if ! docker ps -a | grep ${CURDIR}_squid_1 > /dev/null; then
    if [ "${SERVICE}" == "" ] || [ "${SERVICE}" == "squid" ]; then
      podman run -d --privileged --name=${CURDIR}_squid_1 --restart=always -p 3128:3128 -p 4128:4128 -e CN=squid.local -e O=squid -e OU=squid -e C=US -e http_proxy=${http_proxy:-} -e https_proxy=${https_proxy:-} -e ftp_proxy=${ftp_proxy:-} -e no_proxy=${no_proxy:-} -e HTTP_PROXY=${HTTP_PROXY:-} -e HTTPS_PROXY=${HTTPS_PROXY:-} -e FTP_PROXY=${FTP_PROXY:-} -e NO_PROXY=${NO_PROXY:-} --mount type=bind,source=${PWD}/./template/squid,destination=/etc/squid/template --mount type=bind,source=${PWD}/./data/var/cache/squid,destination=/var/spool/squid --mount type=bind,source=${PWD}/./data/var/log/squid,destination=/var/log/squid --mount type=bind,source=${PWD}/./data/usr/share/nginx/html/squid-cert,destination=/etc/squid-cert builder-squid
    fi
  fi

  if ! docker ps -a | grep ${CURDIR}_mirror_1 > /dev/null; then
    if [ "${SERVICE}" == "" ] || [ "${SERVICE}" == "mirror" ]; then
      podman run -d --privileged --name=${CURDIR}_mirror_1 --restart=always -p 3003:3000 -p 222:22 -e USER_UID=1000 -e USER_GID=1000 -e DISABLE_REGISTRATION=true -e DEFAULT_PRIVATE=public -e ENABLE_PUSH_CREATE_USER=true -e ENABLE_PUSH_CREATE_ORG=true -e http_proxy=${http_proxy:-} -e https_proxy=${https_proxy:-} -e ftp_proxy=${ftp_proxy:-} -e no_proxy=${no_proxy:-} -e HTTP_PROXY=${HTTP_PROXY:-} -e HTTPS_PROXY=${HTTPS_PROXY:-} -e FTP_PROXY=${FTP_PROXY:-} -e NO_PROXY=${NO_PROXY:-} --mount type=bind,source=${PWD}/./data/gitea,destination=/data --mount type=bind,source=/etc/timezone,destination=/etc/timezone,ro --mount type=bind,source=/etc/localtime,destination=/etc/localtime,ro gitea/gitea:1.12.6 
    fi
  fi

  if ! docker ps -a | grep ${CURDIR}_smb_1 > /dev/null; then
    if [ "${SERVICE}" == "" ] || [ "${SERVICE}" == "smb" ]; then
      podman run -d --privileged --name=${CURDIR}_smb_1 --restart=always -e http_proxy=${http_proxy:-} -e https_proxy=${https_proxy:-} -e ftp_proxy=${ftp_proxy:-} -e no_proxy=${no_proxy:-} -e HTTP_PROXY=${HTTP_PROXY:-} -e HTTPS_PROXY=${HTTPS_PROXY:-} -e FTP_PROXY=${FTP_PROXY:-} -e NO_PROXY=${NO_PROXY:-} --mount type=bind,source=${PWD}/./data/usr/share/nginx/html/smb,destination=/smbshare builder-smb 
    fi
  fi

  if ! docker ps -a | grep ${CURDIR}_certbot_1 > /dev/null; then
    if [ "${SERVICE}" == "" ] || [ "${SERVICE}" == "certbot" ]; then
      podman run -d --privileged --name=${CURDIR}_certbot_1 --restart=always -e http_proxy=${http_proxy:-} -e https_proxy=${https_proxy:-} -e ftp_proxy=${ftp_proxy:-} -e no_proxy=${no_proxy:-} -e HTTP_PROXY=${HTTP_PROXY:-} -e HTTPS_PROXY=${HTTPS_PROXY:-} -e FTP_PROXY=${FTP_PROXY:-} -e NO_PROXY=${NO_PROXY:-} --mount type=bind,source=${PWD}/./conf,destination=${PWD}/conf --mount type=bind,source=${PWD}/./data/certbot/conf,destination=/etc/letsencrypt --mount type=bind,source=${PWD}/./data/certbot/www,destination=/var/www/certbot --mount type=bind,source=${PWD}/./data/certbot/lib,destination=/var/lib/letsencrypt --mount type=bind,source=${PWD}/./data/etc/ssl/private,destination=/etc/ssl/private --mount type=bind,source=${PWD}/./data/usr/share/nginx/html/web-cert,destination=/etc/ssl/cert builder-certbot 
    fi
  fi
fi

if [[ "${LOGS}" == "true" ]]; then
  SERVICES=""
  if docker ps -a | grep ${CURDIR}_core_1 > /dev/null; then
    SERVICES="${CURDIR}_core_1 $SERVICES"
  fi
  if docker ps -a | grep ${CURDIR}_web_1 > /dev/null; then
    SERVICES="${CURDIR}_web_1 $SERVICES"
  fi
  if docker ps -a | grep ${CURDIR}_dnsmasq_1 > /dev/null; then
    SERVICES="${CURDIR}_dnsmasq_1 $SERVICES"
  fi
  if docker ps -a | grep ${CURDIR}_registry-mirror_1 > /dev/null; then
    SERVICES="${CURDIR}_registry-mirror_1 $SERVICES"
  fi
  if docker ps -a | grep ${CURDIR}_squid_1 > /dev/null; then
    SERVICES="${CURDIR}_squid_1 $SERVICES"
  fi
  if docker ps -a | grep ${CURDIR}_mirror_1 > /dev/null; then
    SERVICES="${CURDIR}_mirror_1 $SERVICES"
  fi
  if docker ps -a | grep ${CURDIR}_smb_1 > /dev/null; then
    SERVICES="${CURDIR}_smb_1 $SERVICES"
  fi
  if docker ps -a | grep ${CURDIR}_certbot_1 > /dev/null; then
    SERVICES="${CURDIR}_certbot_1 $SERVICES"
  fi

  if [ "${SERVICES}" != "" ]; then
    if [[ "${FOLLOW}" == "true" ]]; then
      podman logs -f ${SERVICES}
    else
      podman logs ${SERVICES}
    fi
  fi
fi