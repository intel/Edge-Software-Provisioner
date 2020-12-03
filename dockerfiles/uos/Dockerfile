# Copyright (C) 2020 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

# FROM docker:19.03.7-dind
FROM alpine:3.11
LABEL maintainer "Bryan J Rodriguez <bryan.j.rodriguez@intel.com>"

RUN apk update && apk add --no-cache \
    bash \
    dnsmasq \
    dumb-init \
    iptables \
    # mesa-egl \
    # mesa-gl \
    # mesa-dri-virtio \
    # mesa-dri-intel \
    ovmf \
    qemu \
    qemu-img \
    # qemu-system-arm \
    qemu-system-x86_64 
    # qemu-system-i386 \
    # qemu-ui-gtk \
    # qemu-ui-sdl \
    # qemu-ui-curses \
    # qemu-audio-sdl \
    # qemu-audio-alsa \
    # qemu-audio-oss \

COPY /bin/linuxkit /usr/bin/linuxkit

ENTRYPOINT ["/bin/bash"]
CMD []
