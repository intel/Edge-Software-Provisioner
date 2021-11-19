# Copyright (C) 2020 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

FROM certbot/certbot:v1.21.0
LABEL maintainer "Bryan J Rodriguez <bryan.j.rodriguez@intel.com>"

RUN apk --no-cache add \
      bash \
      inotify-tools \
      tini && \
    apk --no-cache -U upgrade

# assume that by going to certbot 1.21 we will get Alpine 3.14
RUN apk add krb5 apk-tools --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/v3.14/main && \
    apk -U upgrade busybox --repository=http://dl-cdn.alpinelinux.org/alpine/v3.14/main

COPY init /usr/local/bin/
COPY scripts/ /opt/esp/scripts/

WORKDIR /opt/esp

ENTRYPOINT ["tini", "--"]
CMD ["/usr/local/bin/init"]