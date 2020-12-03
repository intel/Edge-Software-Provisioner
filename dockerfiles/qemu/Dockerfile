# Copyright (C) 2020 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

FROM alpine:edge
LABEL maintainer="Bryan J Rodriguez <bryan.j.rodriguez@intel.com>"

RUN apk update && apk add --no-cache \
  bash \
  dnsmasq \
  dumb-init \
  iptables \
  mesa-egl \
  mesa-gl \
  mesa-dri-virtio \
  mesa-dri-intel \
  ovmf \
  qemu-img \
  qemu-system-arm \
  qemu-system-x86_64 \
  qemu-system-i386 \
  qemu-ui-gtk \
  qemu-ui-sdl \
  qemu-ui-curses \
  qemu-audio-sdl \
  qemu-audio-alsa \
  qemu-audio-oss \
  qemu-block-curl \
  qemu-block-nfs \
  qemu-block-ssh \
  qemu-modules \
  xf86-video-intel \
  xf86-video-qxl \
  xhost

COPY bootstrapVm.sh /bin/
COPY qemu-ifup /etc/
COPY qemu-ifdown /etc/
COPY bridge.conf /etc/qemu/

ENV NAME=vm0 \
    RAM=1024 \
    SMP="1,sockets=1,cores=1,threads=1" \
    CPU=qemu64 \
    KEYBOARD="" \
    MOUSE="" \
    DISK_DEVICE=virtio \
    IMAGE=/data/volumes/vm.img \
    IMAGE_FORMAT=qcow2 \
    IMAGE_SIZE=10G \
    IMAGE_CACHE=none \
    IMAGE_DISCARD=unmap \
    IMAGE_CREATE=0 \
    ISO_DOWNLOAD=0 \
    NETWORK=user \
    NETWORK_BRIDGE=br0 \
    NETWORK_DEVICE=e1000 \
    NETWORK_IF=eth0 \
    GTK="" \
    VIDEO=none \
    VNC=tcp \
    VNC_IP="" \
    VNC_ID=0 \
    VNC_PORT=5900 \
    VNC_SOCK=/var/run/kvmvideo/vnc.sock \
    SPICE=tcp \
    SPICE_IP=127.0.0.1 \
    SPICE_PORT=5900 \
    SPICE_SOCK=/var/run/kvmvideo/spice.sock \
    SPICE_OPTIONS="" \
    CUSTOM_VIDEO="" \
    TCP_PORTS="" \
    UDP_PORTS="" \
    ADD_FLAGS=""

ENTRYPOINT ["dumb-init"]
CMD ["/bin/bootstrapVm.sh"]