# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

FROM fluent/fluent-bit:latest as fluentbit

FROM debian:bullseye-slim as builder

# Install required packages
RUN apt-get update && \
    # The agent.sh dependencies
    apt-get install -y dmidecode util-linux pciutils curl && \
    # The Fluent-Bit dependencies
    apt-get install -y libyaml-0-2 libpq5 && \
    rm -rf /var/lib/apt/lists/*

# Copy the agent script into the container
COPY agent.sh /usr/bin/agent.sh
RUN chmod +x /usr/bin/agent.sh

COPY --from=fluentbit /fluent-bit /fluent-bit
COPY fluent-bit.conf /fluent-bit/fluent-bit.conf

# Run the agent script and Start the Fluent Bit service
CMD ["sh", "-c", "/usr/bin/agent.sh && SERIAL_NUMBER=$(cat /tmp/serial_number) /fluent-bit/bin/fluent-bit -c /fluent-bit/fluent-bit.conf"]