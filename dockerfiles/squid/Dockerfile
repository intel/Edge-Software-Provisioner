# Copyright (C) 2020 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

# Original work cam from https://github.com/alatas/squid-alpine-ssl

FROM alpine:3.14
LABEL maintainer "Bryan J Rodriguez <bryan.j.rodriguez@intel.com>"

RUN apk --no-cache add \
      squid \
      openssl \
      ca-certificates && \
    apk --no-cache -U upgrade && \
    update-ca-certificates

COPY init /usr/local/bin/
COPY openssl.cnf /etc/ssl
COPY squid.conf /etc/squid/

ENV CN=squid.local \
    O=squid \
    OU=squid \
    C=US

EXPOSE 3128
EXPOSE 4128

ENTRYPOINT ["/usr/local/bin/init"]
