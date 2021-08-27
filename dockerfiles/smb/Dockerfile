# Copyright (C) 2021 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

FROM alpine:3.12
LABEL maintainer "Bryan J Rodriguez <bryan.j.rodriguez@intel.com>"

RUN apk update && apk add --no-cache \
      samba-common-tools \
      samba-client \
      samba-server \
      tini

RUN mkdir /smbshare && \
    chmod 777 /smbshare

EXPOSE 445/tcp

ENTRYPOINT [ "tini", "--" ]
CMD ["/usr/sbin/smbd", "--foreground", "--no-process-group", "--log-stdout"]