#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

# This file contains functions and logic to handle templating in the application.
# See documentation on buildertemplates and the supported @@VARIABLES@@.

# If running this file alone, uncomment these lines
# source "textutils.sh"
# source "yamlparse.sh"
# source "fileutils.sh"
# It's probably a good idea to run this as well:
# parseConfig

getMyIp() {
    echo $(ip route get 8.8.8.8 | awk '{for(i=1;i<=NF;i++) if ($i=="src") print $(i+1)}')
}

getMyDefaultRoute() {
    echo $(ip route show | grep -i 'default via'| awk '{print $3 }')
}

getMyBroadcast() {
    echo $(ip -o -4 addr list $(ip route show 0.0.0.0/0 | awk '{print $5}') | grep brd |  awk '{print $6}')
}

getMySubnet() {
    echo $(echo $(getMyIp) | awk -F'.' '{print $1,$2,$3}' OFS='.' )
}

detectDHCP() {
    local ip=$(docker run -it --rm --net=host --entrypoint="" builder-dnsmasq sh -c 'nmap --script broadcast-dhcp-discover 2> /dev/null | grep Identifier | awk "{print \$4}"' )
    echo ${ip} | tr -d '\r' 2> /dev/null
}

# Checks for empty network-related configuration items in
# the conf/config.yml file and sets defaults if any
# are not set.
verifyNetworkConfig() {

    local ipAddr=$(getMyIp)
    local ipRoute=$(getMyDefaultRoute)
    local broadcast=$(getMyBroadcast)
    local subnet=$(getMySubnet)
    local DHCPserver=$(detectDHCP)

    # Ensure the DHCP range min is set
    if [[ -z "${builder_config_dhcp_range_minimum+x}" ]]; then
        builder_config_dhcp_range_minimum="${subnet}.100"
        # printDatedInfoMsg "Auto-determined dhcp_range_minimum=${builder_config_dhcp_range_minimum}"
        logInfoMsg "Using default dhcp_range_minimum=${builder_config_dhcp_range_minimum} - Set dhcp_range_minimum in conf/config.yml and re-run this script if this value is not desired."
    fi

    # Ensure the DHCP range max is set
    if [[ -z "${builder_config_dhcp_range_maximum+x}" ]]; then
        builder_config_dhcp_range_maximum="${subnet}.250"
        # printDatedInfoMsg "Auto-determined dhcp_range_maximum=${builder_config_dhcp_range_maximum}"
        logInfoMsg "Using default dhcp_range_maximum=${builder_config_dhcp_range_maximum} - Set dhcp_range_maximum in conf/config.yml and re-run this script if this value is not desired."
    fi

    # Ensure the DHCP range is set
    if [[ -z "${builder_config_dhcp_range+x}" ]]; then
        if [[ ${DHCPserver} =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && [[ "${DHCPserver}" != "${ipAddr}" ]]; then
            builder_config_dhcp_range="${DHCPserver},proxy"
            builder_config_pxe_comment=""
        else
            builder_config_dhcp_range="${builder_config_dhcp_range_minimum},${builder_config_dhcp_range_maximum},6h"
            builder_config_pxe_comment="#"
        fi
        printDatedInfoMsg "Auto-determined dhcp_range=${builder_config_dhcp_range}"
        logInfoMsg "Using default dhcp_range_minimum=${builder_config_dhcp_range} - Set dhcp_range in conf/config.yml and re-run this script if this value is not desired."
    fi

    # Ensure the network's broadcast is set
    if [[ -z "${builder_config_network_broadcast_ip+x}" ]]; then
        builder_config_network_broadcast_ip="${broadcast}"
        printDatedInfoMsg "Auto-determined network_broadcast_ip=${builder_config_network_broadcast_ip}"
        logInfoMsg "Using default network_broadcast_ip=${builder_config_network_broadcast_ip} - Set network_broadcast_ip in conf/config.yml and re-run this script if this value is not desired."
    fi

    # Ensure the network's gateway IP is set
    if [[ -z "${builder_config_network_gateway_ip+x}" ]]; then
        builder_config_network_gateway_ip="${ipRoute}"
        printDatedInfoMsg "Auto-determined network_gateway_ip=${builder_config_network_gateway_ip}"
        logInfoMsg "Using default network_gateway_ip=${builder_config_network_gateway_ip} - Set network_gateway_ip in conf/config.yml and re-run this script if this value is not desired."
    fi

    # Ensure the host IP address is set
    if [[ -z "${builder_config_host_ip+x}" ]]; then
        builder_config_host_ip="${ipAddr}"
        printDatedInfoMsg "Auto-determined host_ip=${builder_config_host_ip}"
        logInfoMsg "Using default host_ip=${builder_config_host_ip} - Set host_ip in conf/config.yml and re-run this script if this value is not desired."
    else
        if [[ "${ipAddr}" != "${builder_config_host_ip}" ]]; then
            printDatedInfoMsg "${C_L_YELLOW}Warning:${T_RESET} Using a user-specified value for host_ip=${C_L_YELLOW}${builder_config_host_ip}${T_RESET} which is different from this device's default outbound route IP of ${C_L_YELLOW}${ipAddr}${T_RESET}"
            logInfoMsg "Warning: Using a user-specified value for host_ip=${builder_config_host_ip} which is different from this device's default outbound route IP of ${ipAddr}"
        fi
    fi

    # Ensure the dnsmasq primary DNS is set
    if [[ -z "${builder_config_network_dns_primary+x}" ]]; then
        builder_config_network_dns_primary="8.8.4.4"
        printDatedInfoMsg "Auto-determined network_dns_primary=${builder_config_network_dns_primary}"
        logInfoMsg "Using default network_dns_primary=${builder_config_network_dns_primary} - Set network_dns_primary in conf/config.yml and re-run this script if this value is not desired."
    fi

    # Ensure the dnsmasq secondary DNS is set
    if [[ -z "${builder_config_network_dns_secondary+x}" ]]; then
        builder_config_network_dns_secondary="8.8.8.8"
        printDatedInfoMsg "Auto-determined network_dns_secondary=${builder_config_network_dns_secondary}"
        logInfoMsg "Using default network_dns_secondary=${builder_config_network_dns_secondary} - Set network_dns_secondary in conf/config.yml and re-run this script if this value is not desired."
    fi

    printDatedOkMsg "Network configuration determined."
    logOkMsg "Network configuration determined."
}

renderSystemNetworkTemplates() {
    # Get the IP and subnet of the current system
    local ipAddr=$(getMyIp)
    local ipRoute=$(getMyDefaultRoute)
    local subnet=$(getMySubnet)
    local broadcast=$(getMyBroadcast)
    # local DHCPserver=$(detectDHCP)

    # make directories if they don't exist
    local dnsMasqConfDir="data/etc"
    local pxeMenuFileDir="data/srv/tftp/pxelinux.cfg"
    local pxeMenuLegacyFileDir="data/srv/tftp/pxelinux.cfg_legacy"
    makeDirectory ${dnsMasqConfDir}
    makeDirectory ${pxeMenuFileDir}
    makeDirectory ${pxeMenuLegacyFileDir}

    # Set file locations
    local dnsMasqConf="${dnsMasqConfDir}/dnsmasq.conf"
    local pxeMenuFile="${pxeMenuFileDir}/default"
    local pxeLegacyMenuFile="${pxeMenuLegacyFileDir}/default"
    # Set template file locations
    local tmpDnsMasqConf="template/dnsmasq/dnsmasq.conf"
    local tmpPxeMenuFile=$(getTmpPxeMenuLocation)

    # Copy template files
    copySampleFile ${tmpDnsMasqConf} ${tmpDnsMasqConf}.modified
    copySampleFile ${tmpPxeMenuFile} ${tmpPxeMenuFile}.modified

    # Replace the template variables with their appropriate values
    local dhcpRangeMinimumPlaceholder=("@@DHCP_MIN@@" "@@ESP_DHCP_MIN@@" "@@RNI_DHCP_MIN@@" "@@EDGEBUILDER_DHCP_MIN@@")
    local dhcpRangeMaximumPlaceholder=("@@DHCP_MAX@@" "@@ESP_DHCP_MAX@@" "@@RNI_DHCP_MAX@@" "@@EDGEBUILDER_DHCP_MAX@@")
    local dhcpRangePlaceholder=("@@DHCP_RANGE@@" "@@ESP_DHCP_RANGE@@" "@@RNI_DHCP_RANGE@@" "@@EDGEBUILDER_DHCP_RANGE@@")
    local networkBroadcastIpPlaceholder=("@@NETWORK_BROADCAST_IP@@" "@@ESP_NETWORK_BROADCAST_IP@@" "@@RNI_NETWORK_BROADCAST_IP@@" "@@EDGEBUILDER_NETWORK_BROADCAST_IP@@")
    local networkGatewayIpPlaceholder=("@@NETWORK_GATEWAY_IP@@" "@@ESP_NETWORK_GATEWAY_IP@@" "@@RNI_NETWORK_GATEWAY_IP@@" "@@EDGEBUILDER_NETWORK_GATEWAY_IP@@")
    local hostipPlaceholder=("@@HOST_IP@@" "@@ESP_IP@@" "@@RNI_IP@@" "@@EDGEBUILDER_IP@@")
    local networkDnsPrimaryPlaceholder=("@@NETWORK_DNS_PRIMARY@@" "@@ESP_NETWORK_DNS_PRIMARY@@" "@@RNI_NETWORK_DNS_PRIMARY@@" "@@EDGEBUILDER_NETWORK_DNS_PRIMARY@@")
    local networkDnsSecondaryPlaceholder=("@@NETWORK_DNS_SECONDARY@@" "@@ESP_NETWORK_DNS_SECONDARY@@" "@@RNI_NETWORK_DNS_SECONDARY@@" "@@EDGEBUILDER_NETWORK_DNS_SECONDARY@@")
    local pxeCommentPlaceholder=("@@PXE_COMMENT@@" "@@ESP_PXE_COMMENT@@" "@@RNI_PXE_COMMENT@@" "@@EDGEBUILDER_PXE_COMMENT@@")

    # Replace all the potential variables in the staged files.
    # Note that profile-scoped variables are not accessible here.
    # In order to gain access to that scope use the renderTemplate
    # functionality
    local stgFiles=("${tmpDnsMasqConf}.modified" "${tmpPxeMenuFile}.modified")
    for stgFile in ${stgFiles[@]}; do
        for i in {0..2}
        do
            sed -i -e "s/${dhcpRangeMinimumPlaceholder[i]}/${builder_config_dhcp_range_minimum}/g" ${stgFile}
            sed -i -e "s/${dhcpRangeMaximumPlaceholder[i]}/${builder_config_dhcp_range_maximum}/g" ${stgFile}
            sed -i -e "s/${dhcpRangePlaceholder[i]}/${builder_config_dhcp_range}/g" ${stgFile}
            sed -i -e "s/${networkBroadcastIpPlaceholder[i]}/${builder_config_network_broadcast_ip}/g" ${stgFile}
            sed -i -e "s/${networkGatewayIpPlaceholder[i]}/${builder_config_network_gateway_ip}/g" ${stgFile}
            sed -i -e "s/${hostipPlaceholder[i]}/${builder_config_host_ip}/g" ${stgFile}
            sed -i -e "s/${networkDnsPrimaryPlaceholder[i]}/${builder_config_network_dns_primary}/g" ${stgFile}
            sed -i -e "s/${networkDnsSecondaryPlaceholder[i]}/${builder_config_network_dns_secondary}/g" ${stgFile}
            sed -i -e "s/${pxeCommentPlaceholder[i]}/${builder_config_pxe_comment}/g" ${stgFile}
        done
        logInfoMsg "Applied network config to ${stgFile}"
    done

    # Copy the modified config files to the real locations
    copySampleFile ${tmpDnsMasqConf}.modified ${dnsMasqConf}
    copySampleFile ${tmpPxeMenuFile}.modified ${pxeMenuFile}
    cat ${pxeMenuFile} \
    | sed 's#KERNEL http://[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/tftp/#KERNEL /#g' \
    | sed 's#APPEND initrd=http://[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/tftp/#APPEND initrd=/#g' \
    | sed 's#LINUX http://[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/tftp/#LINUX /#g' \
    | sed 's#INITRD http://[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/tftp/#INITRD /#g' \
     > ${pxeLegacyMenuFile}

    # Clean up the modified templates
    rm ${tmpDnsMasqConf}.modified
    rm ${tmpPxeMenuFile}.modified

    # Because the PXE menu generation process is a bit more involved,
    # there is another PXE menu artifact that needs to be cleaned up.
    # This function will clean it up.
    cleanupTmpPxeMenu

    printDatedOkMsg "Successfully applied this system's network configuration to the configs."
}

renderTemplate() {
    local fileName=$1
    local profileName=$2

    # Check if the filename is a buildertemplate or not.
    local fileNameCheck="false"
    if [[ "${fileName}" == *".buildertemplate" || \
            "${fileName}" == *".ebtemplate" || \
            "${fileName}" == *".esptemplate" ]]; then
        fileNameCheck="true"
    fi

    if [[ "${fileNameCheck}" == "false" ]]; then
        printDatedErrMsg "renderTemplate: ${fileName} was not a .buildertemplate file. This function should not be called on files that are not buildertemplates. Exiting"
        logErrMsg "renderTemplate: ${fileName} was not a .buildertemplate file. This function should not be called on files that are not buildertemplates. Exiting"
        exit 1
    fi

    # Copy the .buildertemplate file to .buildertemplate.modified,
    # and stage the changes in that file.
    copySampleFile ${fileName} ${fileName}.modified

    # Replace the template variables with their appropriate values
    local dhcpRangeMinimumPlaceholder=("@@DHCP_MIN@@" "@@ESP_DHCP_MIN@@" "@@RNI_DHCP_MIN@@" "@@EDGEBUILDER_DHCP_MIN@@")
    local dhcpRangeMaximumPlaceholder=("@@DHCP_MAX@@" "@@ESP_DHCP_MAX@@" "@@RNI_DHCP_MAX@@" "@@EDGEBUILDER_DHCP_MAX@@")
    local dhcpRangePlaceholder=("@@DHCP_RANGE@@" "@@ESP_DHCP_RANGE@@" "@@RNI_DHCP_RANGE@@" "@@EDGEBUILDER_DHCP_RANGE@@")
    local networkBroadcastIpPlaceholder=("@@NETWORK_BROADCAST_IP@@" "@@ESP_NETWORK_BROADCAST_IP@@" "@@RNI_NETWORK_BROADCAST_IP@@" "@@EDGEBUILDER_NETWORK_BROADCAST_IP@@")
    local networkGatewayIpPlaceholder=("@@NETWORK_GATEWAY_IP@@" "@@ESP_NETWORK_GATEWAY_IP@@" "@@RNI_NETWORK_GATEWAY_IP@@" "@@EDGEBUILDER_NETWORK_GATEWAY_IP@@")
    local hostipPlaceholder=("@@HOST_IP@@" "@@ESP_IP@@" "@@RNI_IP@@" "@@EDGEBUILDER_IP@@")
    local networkDnsPrimaryPlaceholder=("@@NETWORK_DNS_PRIMARY@@" "@@ESP_NETWORK_DNS_PRIMARY@@" "@@RNI_NETWORK_DNS_PRIMARY@@" "@@EDGEBUILDER_NETWORK_DNS_PRIMARY@@")
    local networkDnsSecondaryPlaceholder=("@@NETWORK_DNS_SECONDARY@@" "@@ESP_NETWORK_DNS_SECONDARY@@" "@@RNI_NETWORK_DNS_SECONDARY@@" "@@EDGEBUILDER_NETWORK_DNS_SECONDARY@@")
    local profileNamePlaceholder="@@PROFILE_NAME@@"

    # Replace all the potential variables in the staged file.
    for i in {0..2}
    do
        sed -i -e "s/${dhcpRangeMinimumPlaceholder[i]}/${builder_config_dhcp_range_minimum}/g" ${fileName}.modified
        sed -i -e "s/${dhcpRangeMaximumPlaceholder[i]}/${builder_config_dhcp_range_maximum}/g" ${fileName}.modified
        sed -i -e "s/${dhcpRangePlaceholder[i]}/${builder_config_dhcp_range}/g" ${fileName}.modified
        sed -i -e "s/${networkBroadcastIpPlaceholder[i]}/${builder_config_network_broadcast_ip}/g" ${fileName}.modified
        sed -i -e "s/${networkGatewayIpPlaceholder[i]}/${builder_config_network_gateway_ip}/g" ${fileName}.modified
        sed -i -e "s/${hostipPlaceholder[i]}/${builder_config_host_ip}/g" ${fileName}.modified
        sed -i -e "s/${networkDnsPrimaryPlaceholder[i]}/${builder_config_network_dns_primary}/g" ${fileName}.modified
        sed -i -e "s/${networkDnsSecondaryPlaceholder[i]}/${builder_config_network_dns_secondary}/g" ${fileName}.modified
    done
    sed -i -e "s/${profileNamePlaceholder}/${profileName}/g" ${fileName}.modified

    # Get the name of the actual file by using awk to split the file name.
    # Example:
    # if fileName is dyn-ks.yml.buildertemplate, renderedFilename will be dyn-ks.yml

    local renderedFilename=""

    case "${fileName}" in
        *".esptemplate")
            # renderedFilename=$(docker run --rm -t alpine:3.9 echo "${fileName}.modified" | awk '{split($0, a, ".esptemplate.modified"); print a[1]}')
            renderedFilename=$(echo "${fileName}.modified" | awk '{split($0, a, ".esptemplate.modified"); print a[1]}')
            ;;
        *".buildertemplate")
            # renderedFilename=$(docker run --rm -t alpine:3.9 echo "${fileName}.modified" | awk '{split($0, a, ".buildertemplate.modified"); print a[1]}')
            renderedFilename=$(echo "${fileName}.modified" | awk '{split($0, a, ".buildertemplate.modified"); print a[1]}')
            ;;
        *".ebtemplate")
            # renderedFilename=$(docker run --rm -t alpine:3.9 echo "${fileName}.modified" | awk '{split($0, a, ".ebtemplate.modified"); print a[1]}')
            renderedFilename=$(echo "${fileName}.modified" | awk '{split($0, a, ".ebtemplate.modified"); print a[1]}')
            ;;
        *)
            logErrMsg "renderTemplate: Could not match the fileName to any known templating suffix"
            ;;
    esac

    # Copy the .buildertemplate.modified file to the original fileName.
    copySampleFile ${fileName}.modified ${renderedFilename}

    # Cleanup the staging file
    rm ${fileName}.modified
    logInfoMsg "Rendered ${renderedFilename}"
}
