# Copyright (C) 2020 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

FROM alpine:3.12
LABEL maintainer "Bryan J Rodriguez <bryan.j.rodriguez@intel.com>"

RUN apk add --no-cache \
    bash \
    dhcpcd \
    inotify-tools \
    tini \
    wireless-tools \
    wpa_supplicant 

COPY init.sh /usr/local/bin/init.sh
COPY wpa_supplicant.conf.template /opt/wpa_supplicant.conf.template

WORKDIR /

ENV COUNTRY=us \
    SSID='' \
    PSK=''

ENTRYPOINT ["tini", "--"]
CMD ["/usr/local/bin/init.sh"]
