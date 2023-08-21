#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

renew_certs() {
  while :; do 
    sleep 6h; 
    docker exec $(docker ps | grep _certbot_1 | awk '{print $NF}' | head -n 1) certbot renew; 
  done
}

# If Lets Encrypt is enabled run job to check every 6 hours to renew certificate as recommend by Lets Encrypt Certbot
if ( cat ${BUILDER_PATH}/conf/config.yml | grep letsencrypt_enabled | grep true | grep -v \# > /dev/null ); then
  echo "Spinning up Certbot certificate renewal checking service."
  renew_certs &
fi

# Make sure ISO memdisk is in the correct location
if [ ! -f ${BUILDER_PATH}/data/srv/tftp/images/iso/memdisk ]; then
  mkdir -p ${BUILDER_PATH}/data/srv/tftp/images/iso/
  cp /usr/share/syslinux/memdisk ${BUILDER_PATH}/data/srv/tftp/images/iso/memdisk
fi

# Make sure iPXE is in the correct location
if [ ! -f ${BUILDER_PATH}/data/srv/tftp/images/ipxe/ipxe.lkrn ]; then
  mkdir -p ${BUILDER_PATH}/data/srv/tftp/images/ipxe/
  cp /usr/share/ipxe/ipxe.lkrn ${BUILDER_PATH}/data/srv/tftp/images/ipxe/ipxe.lkrn
fi

# Make sure iPXE is in the correct location
if [ ! -f ${BUILDER_PATH}/data/srv/tftp/images/ipxe/wimboot ]; then
  mkdir -p ${BUILDER_PATH}/data/srv/tftp/images/ipxe/
  cp /usr/share/ipxe/wimboot ${BUILDER_PATH}/data/srv/tftp/images/ipxe/wimboot
fi

if [ ! -f ${BUILDER_PATH}/data/usr/share/nginx/html/mbr.bin ]; then
  mkdir -p ${BUILDER_PATH}/data/usr/share/nginx/html/
  cp /usr/share/syslinux/mbr.bin ${BUILDER_PATH}/data/usr/share/nginx/html/mbr.bin
fi

# Old method of detecting if this running from a container
# if [ "${TAG_PREFIX}" != "esp-dnsmasq" ]; then

if [ ! -d ${BUILDER_PATH}/root/.git ] && [ ! -f ${BUILDER_PATH}/root/.git ]; then
  if [ ! -f ${BUILDER_PATH}/template/pxe_bg.png ]; then 
    echo "Copying templates..."
    cp -a /opt/core/template/* ${BUILDER_PATH}/template/
  fi

  if [ ! -f ${BUILDER_PATH}/conf/config.yml ]; then 
    echo "Copying configs..."
    cp -a /opt/core/conf/* ${BUILDER_PATH}/conf/
  fi

  rsync -rtc /opt/core/build.sh ${BUILDER_PATH}/
  rsync -rtc /opt/core/build.sh ${BUILDER_PATH}/root/
  rsync -rtc /opt/core/scripts ${BUILDER_PATH}/
  rsync -rtc /opt/core/scripts ${BUILDER_PATH}/root/
  rsync -rtc /opt/core/dockerfiles ${BUILDER_PATH}/
  rsync -rtc ${BUILDER_PATH}/root/docker-compose.yml ${BUILDER_PATH}/
  
  # Make sure UOS is in the correct location
  if [ ! -f ${BUILDER_PATH}/data/srv/tftp/images/uos/vmlinuz ]; then
    rsync -rtc /opt/core/data/ ${BUILDER_PATH}/data/
  fi
 
  TAG_PREFIX_TMP=$(docker ps | grep esp-core | awk '{print $2}' | head -n 1)
  TAG_POSTFIX=$(echo ${TAG_PREFIX_TMP} | awk -F ':' '{print $2}')
  TAG_PREFIX=${TAG_PREFIX_TMP/\/esp-core:${TAG_POSTFIX}/}

  IMAGES="${CONTAINER_IMAGES}"
  if [ "${TAG_PREFIX}" != "" ] && [ "${TAG_PREFIX}" != "${TAG_PREFIX_TMP}" ]; then
    for image in ${IMAGES}; do
      if ( docker images | grep "${image} " > /dev/null 2>&1 ); then
        echo "docker image ${image} exists."
      elif ( ! docker pull ${image} > /dev/null 2>&1 ); then
         echo "docker image ${image} is unavailable for pulling."
      fi
      echo "docker image ${image} downloaded."
      stip_postfix=${image/:${TAG_POSTFIX}/}
      orig_image=${stip_postfix/${TAG_PREFIX}\//intel\/}
      docker tag ${image} ${orig_image}
    done
  fi

  cd ${BUILDER_PATH} && ./build.sh -C -S -P -g
  rsync -rtc /opt/core/*.sh ${BUILDER_PATH}/
  rsync -rtc /opt/core/*.sh ${BUILDER_PATH}/root/

  # Wait for dnsmasq service to start
  while (! docker ps | grep esp-dnsmasq > /dev/null 2>&1 ); do 
    echo "Waiting for dnsmasq to start"; 
    sleep 1; 
  done

  ./build.sh -C -S -g -n && \
  echo "Watching for changes in ${BUILDER_PATH}/conf/config.yml" && \
  inotifywait -e modify -m ${BUILDER_PATH}/conf/ |
  while read -r directory events filename; do
    if [ "${filename}" == "config.yml" ]; then
      echo "${BUILDER_PATH}/conf/config.yml has changed. Restarting services"
      # Sleeping for user to run build manually
      sleep 15
      ./build.sh -C -S -g && \
      docker restart $(docker ps | grep esp-dnsmasq | awk '{print $1}')
    fi
  done
else
  # ESP was built and started from this system.  This container skips all above steps as the user will use ./build.sh manually.
  echo "Watching for changes in ${BUILDER_PATH}/conf/config.yml"
  inotifywait -e modify -m ${BUILDER_PATH}/conf/ |
  while read -r directory events filename; do
    if [ "${filename}" == "config.yml" ]; then
      echo "${BUILDER_PATH}/conf/config.yml has changed."
    fi
  done
fi
