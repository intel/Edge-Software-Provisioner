#!/bin/bash

# Copyright (C) 2022 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

# This file contains the logic for handling the secret configurations like tokens, passwords....

source "scripts/yamlparse.sh"

SECRETS="conf/secrets.yml"

getSecretInfo() {
    if [[ -f ${SECRETS} ]];then
      eval $(yamlParse "${SECRETS}" "secret_config_")
    fi
}

renderSecretTemplate() {
    local fileName=$1

    for (( i = 0; i < "${#secret_config_tokens__token[@]}"; i += 1)); do
        sed -i -e "s/${secret_config_tokens__placeholder[i]}/${secret_config_tokens__token[i]}/g" ${fileName}
    done
}
