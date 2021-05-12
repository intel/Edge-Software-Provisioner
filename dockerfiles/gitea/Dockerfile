# Copyright (C) 2020 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

FROM gitea/gitea:1.12.6
#@sha256:0facddc4a9a1e384db5edb0a3586aa55d80a48a000a068c5864f25628c347727
LABEL maintainer "Bryan J Rodriguez <bryan.j.rodriguez@intel.com>"

RUN apk update && apk add --no-cache \
      bash

COPY init.sh /usr/local/bin/init.sh

ENTRYPOINT [ "/usr/local/bin/init.sh" ]