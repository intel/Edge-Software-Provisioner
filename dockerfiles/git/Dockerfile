# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

FROM alpine:3.14

RUN apk --no-cache add ca-certificates git openssh-client && \
    apk --no-cache -U upgrade && \
    rm -rf /var/cache/apk/*

ENV GIT_SSH_COMMAND="ssh -vv -o ForwardAgent=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
ENV SSH_AUTH_SOCK="/ssh-agent"


WORKDIR /data
