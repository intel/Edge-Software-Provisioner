# Copyright (C) 2020 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

FROM intel/esp-qemu
LABEL maintainer "Bryan J Rodriguez <bryan.j.rodriguez@intel.com>"

COPY ${VIRTUAL_DISK} /data/volumes/vm.img

ENV NAME=${NAME:-vm} \
    RAM=4096 \
    SMP="4,sockets=1,cores=4,threads=1" \
    CPU=max \
    MOUSE=none \
    DISK_DEVICE=virtio \
    IMAGE=/data/volumes/vm.img \
    IMAGE_FORMAT=${DISK_FORMAT:-qcow2} \
    IMAGE_CACHE=none \
    IMAGE_DISCARD=unmap \
    IMAGE_CREATE=0 \
    ISO_DOWNLOAD=0 \
    NETWORK=bridge \
    NETWORK_BRIDGE=br0 \
    NETWORK_DEVICE=e1000 \
    GTK="" \
    VIDEO=spice \
    VNC=tcp \
    VNC_IP="" \
    VNC_ID=0 \
    VNC_PORT="" \
    VNC_SOCK="" \
    SPICE=sock \
    SPICE_IP=0.0.0.0 \
    SPICE_PORT=5901 \
    SPICE_SOCK=/var/run/kvmvideo/spice.sock \
    SPICE_OPTIONS="" \
    CUSTOM_VIDEO="" \
    TCP_PORTS="" \
    UDP_PORTS="" \
    ADD_FLAGS="" \
    RESOLUTION=""
