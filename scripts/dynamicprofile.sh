#!/bin/bash

# Copyright (C) 2021 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

# This file contains the logic for the dynamic profile use case.

export DYN_PROF_DATA="data/dyn-profile"
export DYN_PROF_IPFILE="localIp"


getIp() {

    if [[ -z "${builder_config_interface+x}" ]]; then
        echo $(ip route get 8.8.8.8 | awk '{for(i=1;i<=NF;i++) if ($i=="src") print $(i+1)}')
    else
        echo $(ip route |grep ${builder_config_interface} |grep src |awk '{for(i=1;i<=NF;i++) if ($i=="src") print $(i+1)}')
    fi
}

setDynamicProfileArgs() {

    local ipAddr=$(getIp)
    local kernelArgs=""
    local proxyArgs=""
    local noproxyArgs=""
    local ttyArg="console=tty0"
    local httpserverArg="httpserver=${ipAddr}"
    local uosInitrdKernelArg="initrd=http://${ipAddr}/tftp/images/uos/initrd"
    local httpFilesPathArg="httppath=/files/##PROFILE##"
    local dynamicprofile="true"

    local kernelPath="http://${ipAddr}/tftp/images/uos/vmlinuz"
    local pxeMenuFile="${TFTP_ROOT}/pxelinux.cfg/default"
    local pxeLegacyMenuFile="${TFTP_ROOT}/pxelinux.cfg_legacy/default"

    local kernelLine="    KERNEL ${kernelPath}"
    echo "${kernelLine}" >> ${pxeMenuFile}
    kernelArgs="${uosInitrdKernelArg} ${ttyArg} dynamicprofile=true ${httpserverArg} ${httpFilesPathArg} ${kernelArgs}"
    
    # If proxy args exist, add kernel parameters to pass along the proxy settings
    if [ ! -z "${HTTPS_PROXY+x}" ] || [ ! -z "${HTTP_PROXY+x}" ]; then
        if [ ! -z "${HTTPS_PROXY+x}" ]; then
            proxyArgs="proxy=${HTTPS_PROXY}"
        else
            proxyArgs="proxy=${HTTP_PROXY}"
        fi
    fi
    if [ ! -z "${FTP_PROXY+x}" ]; then
        proxyArgs="${proxyArgs} proxysocks=${FTP_PROXY}"
    fi
    if [ ! -z "${NO_PROXY+x}" ] || [ ! -z "${no_proxy+x}" ]; then
        if [ ! -z "${NO_PROXY+x}" ]; then
            noproxyArgs="noproxy=${NO_PROXY}"
        else
            noproxyArgs="noproxy=${no_proxy}"
        fi
    fi
    if [ ! -z "${proxyArgs}" ]; then
        kernelArgs="${kernelArgs} ${proxyArgs}"
    fi
    if [ ! -z "${noproxyArgs}" ]; then
        kernelArgs="${kernelArgs} ${noproxyArgs}"
    fi
    # profileQueries="profileQueries="
    # if [[ ${builder_config_dynamic_profile__hw_queries[@]} != 0 ]];then
    #     local i=0
    #     for query in ${builder_config_dynamic_profile__hw_queries[@]}; do
    #         if [[ ${i} != 0 ]];then
    #             profileQueries="${profileQueries},"
    #         fi
    #         profileQueries="${profileQueries}${query}"
	#     i=$((i+1))
    #     done
    #     kernelArgs="${kernelArgs} ${profileQueries}"
    # fi
    local appendLine="    APPEND ${kernelArgs}"
    echo "${appendLine}" >> ${pxeMenuFile}

    cat ${pxeMenuFile} \
    | sed 's#KERNEL http://[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/tftp/#KERNEL /#g' \
    | sed 's#APPEND initrd=http://[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/tftp/#APPEND initrd=/#g' \
    | sed 's#LINUX http://[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/tftp/#LINUX /#g' \
    | sed 's#INITRD http://[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/tftp/#INITRD /#g' \
     > ${pxeLegacyMenuFile}

    if [[ ! -d "${DYN_PROF_DATA}" ]]; then
        mkdir -p ${DYN_PROF_DATA}
    fi

    echo "HOST_IP=$(getIp)" >> ${ENV_FILE}
}

exportProfileInfo() {

    if [[ -z "${builder_config_dynamic_profile_url+x}" ]];then
        builder_config_dynamic_profile_url="/conf/dynamic_profiles.json"
    fi

    if [[ ! -d "${DYN_PROF_DATA}" ]]; then
        mkdir -p ${DYN_PROF_DATA}
    fi

    echo "DYN_URL=${builder_config_dynamic_profile_url}" >> ${ENV_FILE}
    if [[ "${builder_config_dynamic_profile_token+x}" != "" && "${builder_config_dynamic_profile_user+x}" != "" ]]; then
	echo "DYN_URL_USER=${builder_config_dynamic_profile_user}" >> ${ENV_FILE}
	echo "DYN_URL_TOKEN=${builder_config_dynamic_profile_token}" >> ${ENV_FILE}
    fi

}
