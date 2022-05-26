# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

FROM alpine:3.14

# Versions: https://pypi.python.org/pypi/awscli#downloads
ENV AWS_CLI_VERSION 1.18.223

RUN apk --no-cache add \
        python3 \
        py3-pip \
        py3-setuptools \
        ca-certificates \
        groff \
        less && \
        apk --no-cache -U upgrade && \
    pip3 --no-cache-dir install awscli==${AWS_CLI_VERSION} && \
    rm -rf /var/cache/apk/*

WORKDIR /data
