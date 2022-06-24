#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

# old method used to detect yml file
# $(basename ../*.yml | sed 's/\.[^.]*$//')

mkdir -p prep/ && \
cd prep/ && \
gunzip -c < ../uos-initrd.img | cpio -i -d && \
rsync -rtc ../files/ ./ && \
find . | cpio -H newc -o | pv | xz -T0 --check=crc32 > ../uos-initrd.img && \
cd - && \
rm -fr prep/
