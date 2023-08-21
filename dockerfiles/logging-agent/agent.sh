#!/bin/bash

# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

OUTPUT_FILE="/tmp/machine-scrape.log"
SERIAL_FILE="/tmp/serial_number"

# Get external IP
external_ip=$(curl -s http://whatismyip.akamai.com/ --connect-timeout 5)

# Get internal IP
internal_ip=$(hostname -I | awk '{print $1}')

# Get PCI tree
pci_tree=$(lspci)

# Get motherboard model v
motherboard_model=$(dmidecode -s baseboard-product-name)

# Get firmware version v
firmware_version=$(dmidecode -s bios-version)

# Get hard drives info
hard_drives=$(lsblk)

# Get serial number v
serial_number=$(dmidecode -s system-serial-number)

if [ -z "$serial_number" ]; then
    echo "not_available" > $SERIAL_FILE
else
    echo "$serial_number" > $SERIAL_FILE
fi

# Write the information to the log file
echo "External IP: $external_ip" > $OUTPUT_FILE
echo "Internal IP: $internal_ip" >> $OUTPUT_FILE
echo "PCI tree:" >> $OUTPUT_FILE
echo "$pci_tree" >> $OUTPUT_FILE
echo "Motherboard model: $motherboard_model" >> $OUTPUT_FILE
echo "Firmware version: $firmware_version" >> $OUTPUT_FILE
echo "Hard drives info:" >> $OUTPUT_FILE
echo "$hard_drives" >> $OUTPUT_FILE
echo "Serial number: $serial_number" >> $OUTPUT_FILE