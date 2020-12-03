#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

mkdir -p prep/ && \
cd prep/ && \
gunzip -c < ../$(basename ../*.yml | sed 's/\.[^.]*$//')-initrd.img | cpio -i -d && \
rsync -rtc ../files/ ./ && \
find . | cpio -H newc -o | gzip > ../$(basename ../*.yml | sed 's/\.[^.]*$//')-initrd.img && \
cd - && \
rm -fr prep/
