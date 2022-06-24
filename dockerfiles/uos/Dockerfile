# Copyright (C) 2020 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

FROM docker:19.03.12
LABEL maintainer "Bryan J Rodriguez <bryan.j.rodriguez@intel.com>"

RUN apk update && apk add --no-cache \
    bash \
    cpio \
    coreutils \
    curl \
    e2fsprogs \
    lsblk \
    findutils \
    gzip \
    dnsmasq \
    dumb-init \
    iptables \
    ovmf \
    parted \
    pv \
    qemu \
    qemu-img \
    qemu-system-x86_64 \
    rsync \
    syslinux \
    util-linux \
    xz

COPY /bin/linuxkit /usr/bin/linuxkit

ENTRYPOINT ["/bin/bash"]
CMD []
