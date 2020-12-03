# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

FROM alpine:3.9

# Versions: https://pypi.python.org/pypi/awscli#downloads
ENV AWS_CLI_VERSION 1.16.109

RUN apk --no-cache update && \
    apk --no-cache add python py-pip py-setuptools ca-certificates groff less && \
    pip --no-cache-dir install awscli==${AWS_CLI_VERSION} && \
    rm -rf /var/cache/apk/*

WORKDIR /data
