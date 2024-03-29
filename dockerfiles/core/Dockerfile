# Copyright (C) 2020 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

FROM docker:20.10.8
LABEL maintainer "Bryan J Rodriguez <bryan.j.rodriguez@intel.com>"

RUN apk --no-cache add  \
      bash \
      dumb-init \
      docker-compose \
      inotify-tools \
      git \
      net-tools \
      nmap \
      nmap-scripts \
      rsync \
      syslinux \
      wget && \
    apk --no-cache -U upgrade && \
    update-ca-certificates

RUN mkdir -p /opt/core/conf /opt/core/data/srv /opt/core/scripts /opt/core/dockerfiles && \
    mkdir -p /usr/local/bin && \
    mkdir -p /usr/share/ipxe && \
    wget -O /usr/share/ipxe/ipxe.lkrn https://boot.ipxe.org/ipxe.lkrn && \
    wget -O /usr/share/ipxe/wimboot https://github.com/ipxe/wimboot/releases/latest/download/wimboot

COPY files/conf/ /opt/core/conf/
COPY files/data/ /opt/core/data/
COPY files/dockerfiles/ /opt/core/dockerfiles/
COPY files/scripts/ /opt/core/scripts/
COPY files/template/ /opt/core/template/
COPY files/*.sh /opt/core/
COPY files/dockerfiles/core/init.sh /usr/local/bin/init.sh

ENTRYPOINT [ "dumb-init", "/usr/local/bin/init.sh" ]
