# Copyright (C) 2020 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

FROM alpine:3.13
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
  qemu-ui-spice-app \
  qemu-audio-sdl \
  qemu-audio-alsa \
  qemu-audio-oss \
  qemu-block-curl \
  qemu-block-nfs \
  qemu-block-ssh \
  qemu-modules \
  ttf-dejavu \
  util-linux \
  xf86-video-intel \
  xf86-video-qxl \
  xhost

# The following are guest tools to improve performance of the VM
# RUN https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso
# https://downloadmirror.intel.com/30100/a08/igfx_win10_100.9126.exe
# https://downloadmirror.intel.com/30100/a08/igfx_win10_100.9126.zip
# https://www.spice-space.org/download/windows/spice-guest-tools/spice-guest-tools-latest.exe

COPY bootstrapVm.sh /bin/
COPY qemu-ifup /etc/
COPY qemu-ifdown /etc/
COPY bridge.conf /etc/qemu/

ENV NAME vm0
ENV RAM 1024
ENV SMP 1,sockets=1,cores=1,threads=1
ENV CPU host
ENV BIOS ""
ENV AUDIO ""
ENV KEYBOARD ""
ENV MOUSE ""
ENV DISK_DEVICE ide
ENV IMAGE /data/volumes/vm.img 
ENV IMAGE_FORMAT qcow2
ENV IMAGE_SIZE 10G
ENV IMAGE_CACHE none
ENV IMAGE_DISCARD unmap
ENV IMAGE_CREATE 0
ENV DISK_AHCI ""
ENV ISO_DOWNLOAD 0
ENV NETWORK user
ENV NETWORK_BRIDGE br0
ENV NETWORK_DEVICE e1000
ENV NETWORK_IF eth0
ENV GTK ""
ENV VIDEO none
ENV GPU none
ENV VNC tcp
ENV VNC_IP ""
ENV VNC_ID 0
ENV VNC_PORT 5900
ENV VNC_SOCK /var/run/kvmvideo/vnc.sock
ENV SPICE tcp
ENV SPICE_IP 127.0.0.1
ENV SPICE_PORT 5900
ENV SPICE_SOCK /var/run/kvmvideo/spice.sock
ENV SPICE_OPTIONS ""
ENV CUSTOM_VIDEO ""
ENV TCP_PORTS ""
ENV UDP_PORTS ""
ENV USB_HUB ""
ENV BALLOON ""
ENV MONITOR ""
ENV ADD_FLAGS ""

ENTRYPOINT ["dumb-init"]
CMD ["/bin/bootstrapVm.sh"]