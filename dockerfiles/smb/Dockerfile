# Copyright (C) 2021 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

FROM alpine:3.14
LABEL maintainer "Bryan J Rodriguez <bryan.j.rodriguez@intel.com>"

RUN apk --no-cache add \
      samba-common-tools \
      samba-client \
      samba-server \
      tini && \
    apk --no-cache -U upgrade

RUN mkdir /smbshare && \
    chmod 777 /smbshare

EXPOSE 445/tcp

ENTRYPOINT [ "tini", "--" ]
CMD ["/usr/sbin/smbd", "--foreground", "--no-process-group", "--log-stdout"]