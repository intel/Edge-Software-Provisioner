# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

FROM alpine:3.9

RUN apk --no-cache update && \
    apk --no-cache add ca-certificates wget && \
    rm -rf /var/cache/apk/*

WORKDIR /data
