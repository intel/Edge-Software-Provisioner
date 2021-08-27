# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

FROM alpine:3.12 as pxeFileProvider64
RUN apk --no-cache add syslinux

FROM alpine:3.12 as pxeFileProvider32
RUN echo "x86" > /etc/apk/arch && apk --no-cache add syslinux

FROM alpine:3.12
RUN apk --no-cache add dnsmasq nmap nmap-scripts wget \
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

RUN cd /srv/tftp && wget --mirror -X freedos/ -X icons/ -X helenos/ -X fedora/ -X test/ --reject 1mb --reject "index.html*" --reject "memtest.*" --reject "memtest*.*" https://boot.ipxe.org/ \
    && mv boot.ipxe.org ipxe

COPY init.sh /usr/local/bin/init.sh

EXPOSE 53 53/UDP
EXPOSE 69 69/UDP

ENTRYPOINT [ "/usr/local/bin/init.sh" ]