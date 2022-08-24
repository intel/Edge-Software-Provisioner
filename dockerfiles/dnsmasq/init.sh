#!/bin/sh

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

# copy files to web server directory to be serverd over http
rsync -rtc --exclude=images/ --exclude=pxelinux.cfg/ /srv/tftp/ /usr/share/nginx/html/tftp/

while (! ls /etc/dnsmasq/dnsmasq.conf > /dev/null 2>&1 ); do 
  echo \"Waiting for dnsmasq.conf file to be created\"; 
  sleep 5; 
done

exec dnsmasq --conf-file=/etc/dnsmasq/dnsmasq.conf -d --log-dhcp --log-queries=extra