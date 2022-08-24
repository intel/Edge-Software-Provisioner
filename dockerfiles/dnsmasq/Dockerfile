# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

FROM alpine:3.14 as pxeFileProvider64
RUN apk --no-cache add syslinux

FROM alpine:3.14 as pxeFileProvider32
RUN echo "x86" > /etc/apk/arch && apk --no-cache add syslinux

FROM alpine:3.12 as iPXEcompile

RUN apk --no-cache add \
    git \
    bash \
    gcc \
    binutils \
    make \
    perl \
    xz-dev \
    mtools \
    cdrkit \
    syslinux \
    musl-dev \
    coreutils \
    openssl

# Define build argument for iPXE branch to clone/checkout
ARG IPXE_BRANCH="v1.21.1"

# Clone the iPXE repo
RUN git clone --branch "${IPXE_BRANCH}" --single-branch "https://github.com/ipxe/ipxe.git" /build/

# Enable Console Frambuffer
# Enable Download via HTTPS, FTP, SLAM, NFS
# Enable SANBoot via iSCSI, AoE, Infiniband SCSI RDMA, Fibre Channel, HTTP SAN
# Enable additional iPXE commands: nslookup, time, digest, lotest, vlan, reboot, poweroff, image_trust, pci, param, neighbour, ping, console, ipstat, profstat, ntp, cert
# Note that the "digest" command is not yet documented and the "pxe" command, while existing in the "general.h" file, breaks on compiling and is also not yet documented, thus the "pxe" command is excluded.
RUN sed -i 's|//#define\tCONSOLE_FRAMEBUFFER|#define\tCONSOLE_FRAMEBUFFER|g' /build/src/config/console.h && \
    sed -Ei "s/^#undef([ \t]*DOWNLOAD_PROTO_(HTTPS|FTP|SLAM|NFS)[ \t]*)/#define\1/" /build/src/config/general.h && \
    sed -Ei "s/^\/\/#undef([ \t]*SANBOOT_PROTO_(ISCSI|AOE|IB_SRP|FCP|HTTP)[ \t]*)/#define\1/" /build/src/config/general.h && \
    sed -Ei "s/^\/\/(#define[ \t]*(NSLOOKUP|TIME|DIGEST|LOTEST|VLAN|REBOOT|POWEROFF|IMAGE_TRUST|PCI|PARAM|NEIGHBOUR|PING|CONSOLE|IPSTAT|PROFSTAT|NTP|CERT)_CMD)/\1/" /build/src/config/general.h

# Destination folder for compiled files
WORKDIR /ipxe/

RUN echo -e '#!ipxe\n\ndhcp\nchain menu.ipxe' > /build/src/chain.ipxe

# Compile embedded chain.ipxe for USB/ISO boot
RUN make -C /build/src/ bin/ipxe.lkrn EMBED=chain.ipxe -j8 && \
    make -C /build/src/ bin-x86_64-efi/ipxe.efi EMBED=chain.ipxe -j8 && \
    mkdir -p /ipxe/bin/ && \
    mkdir -p /ipxe/bin-x86_64-efi/ && \
    cp /build/src/bin/ipxe.lkrn /ipxe/bin/ipxe.lkrn.chain && \
    cp /build/src/bin-x86_64-efi/ipxe.efi /ipxe/bin-x86_64-efi/ipxe.efi.chain && \
    make -C /build/src/ clean

# Compile the files in "bin/"
ARG IPXE_BIN="bin/ipxe.dsk bin/ipxe.lkrn bin/ipxe.iso bin/ipxe.usb bin/ipxe.pxe bin/undionly.kpxe bin/rtl8139.rom bin/8086100e.mrom bin/80861209.rom bin/10500940.rom bin/10ec8139.rom bin/1af41000.rom bin/8086100f.mrom bin/808610d3.mrom bin/10222000.rom bin/15ad07b0.rom bin/3c509.rom bin/intel.rom bin/intel.mrom"
# _bin="bin/${IPXE_BIN// / bin\/}" \
RUN [ -z "${IPXE_BIN}" ] || ( \
    _bin="${IPXE_BIN}" \
    && make -C /build/src/ ${_bin} -j8 \
    && mkdir -p bin/ \
    && for file in ${_bin} ;do ln -v /build/src/${file} /ipxe/${file} ;done \
    )

# Compile the files in "bin-i386-efi/"
ARG IPXE_EFI="bin-i386-efi/ipxe.efi bin-i386-efi/ipxe.usb bin-i386-efi/ipxe.efidrv bin-i386-efi/ipxe.efirom bin-i386-efi/snponly.efi"
# _efi="bin-i386-efi/${IPXE_EFI// / bin-i386-efi\/}" \
RUN [ -z "${IPXE_EFI}" ] || ( \
    _efi="${IPXE_EFI}" \
    && make -C /build/src/ ${_efi} -j8 \
    && mkdir -p bin-i386-efi/ \
    && for file in ${_efi} ;do ln -v /build/src/${file} /ipxe/${file} ;done \
    )

# Compile the files in "bin-x86_64-efi/"
ARG IPXE_EFI64="bin-x86_64-efi/ipxe.efi bin-x86_64-efi/ipxe.usb bin-x86_64-efi/ipxe.efidrv bin-x86_64-efi/ipxe.efirom"
# _efi64="bin-x86_64-efi/${IPXE_EFI64// / bin-x86_64-efi\/}" \
RUN [ -z "${IPXE_EFI64}" ] || ( \
    _efi64="${IPXE_EFI64}" \
    && make -C /build/src/ ${_efi64} -j8 \
    && mkdir -p bin-x86_64-efi/ \
    && for file in ${_efi64} ;do ln -v /build/src/${file} /ipxe/${file} ;done \
    )

# Compile the files in "bin-x86_64-pcbios/"
ARG IPXE_PCBIOS64="bin-x86_64-pcbios/8086100e.mrom bin-x86_64-pcbios/intel.rom bin-x86_64-pcbios/ipxe.usb bin-x86_64-pcbios/ipxe.pxe bin-x86_64-pcbios/undionly.kpxe"
# EXTRA_CFLAGS="-fno-pie" fixes gcc+ issue that causes the error "cc1: error: code model kernel does not support PIC mode"
# This is due to gcc 6+ versions having PIE (position independent executables) enabled by default.
# This flag must only be set for the bin-x86_64-pcbios/ build targets.
# _bin64="bin-x86_64-pcbios/${IPXE_PCBIOS64// / bin-x86_64-pcbios\/}" \
RUN [ -z "${IPXE_PCBIOS64}" ] || ( \
    _bin64="${IPXE_PCBIOS64}" \
    && make -C /build/src/ EXTRA_CFLAGS="-fno-pie" ${_bin64} -j8 \
    && mkdir -p bin-x86_64-pcbios/ \
    && for file in ${_bin64} ;do ln -v /build/src/${file} /ipxe/${file} ;done \
    )

FROM ubuntu:20.04 as iPXEubuntuCompile
RUN apt update && apt install -y \
    git \
    build-essential \
    liblzma-dev \
    mkisofs \
    gcc-aarch64-linux-gnu \
    mtools

# Define build argument for iPXE branch to clone/checkout
ARG IPXE_BRANCH="v1.21.1"

# Clone the iPXE repo
RUN git clone --branch "${IPXE_BRANCH}" --single-branch "https://github.com/ipxe/ipxe.git" /build/

# Enable Console Frambuffer
# Enable Download via HTTPS, FTP, SLAM, NFS
# Enable SANBoot via iSCSI, AoE, Infiniband SCSI RDMA, Fibre Channel, HTTP SAN
# Enable additional iPXE commands: nslookup, time, digest, lotest, vlan, reboot, poweroff, image_trust, pci, param, neighbour, ping, console, ipstat, profstat, ntp, cert
# Note that the "digest" command is not yet documented and the "pxe" command, while existing in the "general.h" file, breaks on compiling and is also not yet documented, thus the "pxe" command is excluded.
RUN sed -i 's|//#define\tCONSOLE_FRAMEBUFFER|#define\tCONSOLE_FRAMEBUFFER|g' /build/src/config/console.h && \
    sed -Ei "s/^#undef([ \t]*DOWNLOAD_PROTO_(HTTPS|FTP|SLAM|NFS)[ \t]*)/#define\1/" /build/src/config/general.h && \
    sed -Ei "s/^\/\/#undef([ \t]*SANBOOT_PROTO_(ISCSI|AOE|IB_SRP|FCP|HTTP)[ \t]*)/#define\1/" /build/src/config/general.h && \
    sed -Ei "s/^\/\/(#define[ \t]*(NSLOOKUP|TIME|DIGEST|LOTEST|VLAN|REBOOT|POWEROFF|IMAGE_TRUST|PCI|PARAM|NEIGHBOUR|PING|CONSOLE|IPSTAT|PROFSTAT|NTP|CERT)_CMD)/\1/" /build/src/config/general.h && \
    sed -i 's|bash util/genefidsk|bash genefidsk|g' /build/src/Makefile.efi


# Destination folder for compiled files
WORKDIR /ipxe/

# Compile the files in "bin-arm64-efi/"
SHELL ["/bin/bash", "-c"]
ARG IPXE_ARM_EFI64="bin-arm64-efi/ipxe.efi bin-arm64-efi/ipxe.usb bin-arm64-efi/snponly.efi"
# _arm64="bin-arm64-efi/${IPXE_ARM_EFI64// / bin-arm64-efi\/}" \
RUN [ -z "${IPXE_ARM_EFI64}" ] || ( \
    _arm64="${IPXE_ARM_EFI64}" \
    && PATH=${PATH}:/build/src/util/:/build/src/ \
    && make CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 -C /build/src/ ${_arm64} -j8 \
    && mkdir -p bin-arm64-efi/ \
    && for file in ${_arm64} ;do ln -v /build/src/${file} /ipxe/${file} ;done \
    )

FROM alpine:3.14
RUN apk --no-cache add \
    dnsmasq \
    nmap \
    nmap-scripts \
    rsync \
    wget \
    && mkdir -p /srv/tftp/efi64 \
    && mkdir -p /srv/tftp/efi32 \
    && mkdir -p /srv/tftp/legacy

# HTTP Legacy BIOS syslinux binaries
COPY --from=pxeFileProvider64 /usr/share/syslinux/lpxelinux.0 /srv/tftp/
COPY --from=pxeFileProvider64 /usr/share/syslinux/menu.c32 /srv/tftp/
COPY --from=pxeFileProvider64 /usr/share/syslinux/ldlinux.c32 /srv/tftp/
COPY --from=pxeFileProvider64 /usr/share/syslinux/libmenu.c32 /srv/tftp/
COPY --from=pxeFileProvider64 /usr/share/syslinux/libutil.c32 /srv/tftp/
COPY --from=pxeFileProvider64 /usr/share/syslinux/vesamenu.c32 /srv/tftp/
COPY --from=pxeFileProvider64 /usr/share/syslinux/libcom32.c32 /srv/tftp/
COPY --from=pxeFileProvider64 /usr/share/syslinux/linux.c32 /srv/tftp/

# TFTP Legacy BIOS syslinux binaries
COPY --from=pxeFileProvider64 /usr/share/syslinux/pxelinux.0 /srv/tftp/legacy/
COPY --from=pxeFileProvider64 /usr/share/syslinux/menu.c32 /srv/tftp/legacy/
COPY --from=pxeFileProvider64 /usr/share/syslinux/ldlinux.c32 /srv/tftp/legacy/
COPY --from=pxeFileProvider64 /usr/share/syslinux/libmenu.c32 /srv/tftp/legacy/
COPY --from=pxeFileProvider64 /usr/share/syslinux/libutil.c32 /srv/tftp/legacy/
COPY --from=pxeFileProvider64 /usr/share/syslinux/vesamenu.c32 /srv/tftp/legacy/
COPY --from=pxeFileProvider64 /usr/share/syslinux/libcom32.c32 /srv/tftp/legacy/
COPY --from=pxeFileProvider64 /usr/share/syslinux/linux.c32 /srv/tftp/legacy/

# UEFI64 syslinux binaries
COPY --from=pxeFileProvider64 /usr/share/syslinux/efi64/syslinux.efi /srv/tftp/efi64/
COPY --from=pxeFileProvider64 /usr/share/syslinux/efi64/menu.c32 /srv/tftp/efi64/
COPY --from=pxeFileProvider64 /usr/share/syslinux/efi64/ldlinux.e64 /srv/tftp/efi64/
COPY --from=pxeFileProvider64 /usr/share/syslinux/efi64/libmenu.c32 /srv/tftp/efi64/
COPY --from=pxeFileProvider64 /usr/share/syslinux/efi64/libutil.c32 /srv/tftp/efi64/
COPY --from=pxeFileProvider64 /usr/share/syslinux/efi64/vesamenu.c32 /srv/tftp/efi64/
COPY --from=pxeFileProvider64 /usr/share/syslinux/efi64/libcom32.c32 /srv/tftp/efi64/
COPY --from=pxeFileProvider64 /usr/share/syslinux/efi64/linux.c32 /srv/tftp/efi64/

# UEFI32 syslinux binaries
COPY --from=pxeFileProvider32 /usr/share/syslinux/efi32/syslinux.efi /srv/tftp/efi32/
COPY --from=pxeFileProvider32 /usr/share/syslinux/efi32/menu.c32 /srv/tftp/efi32/
COPY --from=pxeFileProvider32 /usr/share/syslinux/efi32/ldlinux.e32 /srv/tftp/efi32/
COPY --from=pxeFileProvider32 /usr/share/syslinux/efi32/libmenu.c32 /srv/tftp/efi32/
COPY --from=pxeFileProvider32 /usr/share/syslinux/efi32/libutil.c32 /srv/tftp/efi32/
COPY --from=pxeFileProvider32 /usr/share/syslinux/efi32/vesamenu.c32 /srv/tftp/efi32/
COPY --from=pxeFileProvider32 /usr/share/syslinux/efi32/libcom32.c32 /srv/tftp/efi32/
COPY --from=pxeFileProvider32 /usr/share/syslinux/efi32/linux.c32 /srv/tftp/efi32/

# iPXE binaries
COPY --from=iPXEcompile /ipxe/bin/ /srv/tftp/ipxe/legacy/
COPY --from=iPXEcompile /ipxe/bin-x86_64-efi/ /srv/tftp/ipxe/efi64/
COPY --from=iPXEcompile /ipxe/bin-i386-efi/ /srv/tftp/ipxe/efi32/
COPY --from=iPXEcompile /ipxe/bin-x86_64-pcbios/ /srv/tftp/ipxe/pcbios/
COPY --from=iPXEubuntuCompile /ipxe/bin-arm64-efi/ /srv/tftp/ipxe/arm64/

# Old method of grabbing binaries
# RUN cd /srv/tftp && wget --mirror -X freedos/ -X icons/ -X helenos/ -X fedora/ -X test/ --reject 1mb --reject "index.html*" --reject "memtest.*" --reject "memtest*.*" https://boot.ipxe.org/ \
#     && mv boot.ipxe.org ipxe

COPY init.sh /usr/local/bin/init.sh

EXPOSE 53 53/UDP
EXPOSE 69 69/UDP

ENTRYPOINT [ "/usr/local/bin/init.sh" ]
