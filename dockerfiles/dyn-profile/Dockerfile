# Copyright (C) 2022 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

FROM alpine:3.14 as build
LABEL maintainer "Bryan J Rodriguez <bryan.j.rodriguez@intel.com>"

RUN apk --update --no-cache add go

COPY profile_service.go /build/profile_service.go
RUN cd /build && go build profile_service.go

FROM alpine:3.14

RUN apk --update --no-cache add \
      ca-certificates \
      tini \
      curl \
      wget \
    && update-ca-certificates

COPY --from=build /build/profile_service /usr/local/bin/profile_service

RUN chmod a+x /usr/local/bin/profile_service

ENTRYPOINT ["/usr/local/bin/profile_service"] 
