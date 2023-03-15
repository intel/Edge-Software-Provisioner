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
    if [[ -z "${builder_config_interface+x}" ]]; then
        echo $(ip route get 8.8.8.8 | awk '{for(i=1;i<=NF;i++) if ($i=="src") print $(i+1)}')
    else
        echo $(ip a show dev ${builder_config_interface} | grep "inet " | awk '$1 ~ /^inet/ { sub("/.*", "", $2); print $2 }')
    fi
}

getMyDefaultRoute() {
    if [[ -z "${builder_config_interface+x}" ]]; then
        echo $(ip route show | grep -i 'default via'| awk '{print $3 }')
    else
        ifDefaultRoute=$(ip route show dev ${builder_config_interface} | grep -i 'default via'| awk '{print $3 }')
        if [[ -z "${ifDefaultRoute=x}" ]]; then
            # if no route is set for this interface then use the IP Address for this interface
            echo $(getMyIp)
        else
            echo ${ifDefaultRoute}
        fi
    fi
}

getMyBroadcast() {
    if [[ -z "${builder_config_interface+x}" ]]; then
        echo $(ip -o -4 addr list $(ip route show 0.0.0.0/0 | awk '{print $5}') | grep brd | sed -e 's/^.* brd \([0-9\.]*\) .*$/\1/' )
    else
        echo $(ip -o -4 addr list ${builder_config_interface} | grep brd | sed -e 's/^.* brd \([0-9\.]*\) .*$/\1/')
    fi
}

getMySubnet() {
    echo $(echo $(getMyIp) | awk -F'.' '{print $1,$2,$3}' OFS='.' )
}

detectDHCP() {
    if [[ -z "${builder_config_interface+x}" ]]; then
        local ip=$(docker run -it --rm --net=host --entrypoint="" builder-dnsmasq sh -c 'nmap --script broadcast-dhcp-discover 2> /dev/null | grep Identifier | awk "{print \$4}" | head -n 1' )
        echo ${ip} | tr -d '\r' 2> /dev/null
    else
        local ip=$(docker run -it --rm --net=host -e INTERFACE=${builder_config_interface} --entrypoint="" builder-dnsmasq sh -c 'nmap -e ${INTERFACE} --script broadcast-dhcp-discover 2> /dev/null | grep Identifier | awk "{print \$4}" | head -n 1' )
        echo ${ip} | tr -d '\r' 2> /dev/null
    fi
}

getESPDnsmasqProcess() {
    local dnsmasq_process_id=$(netstat -tunlp |grep dnsmasq |grep :67 | awk "{print \$6}" | sed "s#\/.*##")
    local regex='^[0-9]+$'
    if [[ ! -z ${dnsmasq_process_id+x} ]] && [[ ${dnsmasq_process_id} =~ ${regex} ]]; then
        local espDir=$(realpath  $(dirname -- "${BASH_SOURCE}" ) | sed "s#scripts##")
        local mountinfo=$(cat /proc/${dnsmasq_process_id}/mountinfo |grep ${espDir})
        if [[ ${mountinfo} != "" ]]; then
            echo ${dnsmasq_process_id}
        else
            # No local proccess ID found, returning empty value
            echo ""
        fi
    else
        # No local proccess ID found, returning empty value
        echo ""
    fi
}

# Checks for empty network-related configuration items in
# the conf/config.yml file and sets defaults if any
# are not set.
verifyNetworkConfig() {

    local ipAddr=$(getMyIp)
    local ipRoute=$(getMyDefaultRoute)
    local broadcast=$(getMyBroadcast)
    local subnet=$(getMySubnet)
    local dnsmasq_pid=$(getESPDnsmasqProcess)
    if [[ "${SKIP_NET}" == "false" ]]; then
        local DHCPserver=$(detectDHCP)
    else
        local DHCPserver=""
    fi

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
        if [[ "${SKIP_NET}" == "false" ]]; then
            printDatedInfoMsg "Auto-determined dhcp_range=${builder_config_dhcp_range}"
        fi
        logInfoMsg "Using default dhcp_range_minimum=${builder_config_dhcp_range} - Set dhcp_range in conf/config.yml and re-run this script if this value is not desired."
    fi

    # Ensure the network's broadcast is set
    if [[ -z "${builder_config_network_broadcast_ip+x}" ]]; then
        builder_config_network_broadcast_ip="${broadcast}"
        if [[ "${SKIP_NET}" == "false" ]]; then
            printDatedInfoMsg "Auto-determined network_broadcast_ip=${builder_config_network_broadcast_ip}"
        fi
        logInfoMsg "Using default network_broadcast_ip=${builder_config_network_broadcast_ip} - Set network_broadcast_ip in conf/config.yml and re-run this script if this value is not desired."
    fi

    # Ensure the network's gateway IP is set
    if [[ -z "${builder_config_network_gateway_ip+x}" ]]; then
        builder_config_network_gateway_ip="${ipRoute}"
        if [[ "${SKIP_NET}" == "false" ]]; then
            printDatedInfoMsg "Auto-determined network_gateway_ip=${builder_config_network_gateway_ip}"
        fi
        logInfoMsg "Using default network_gateway_ip=${builder_config_network_gateway_ip} - Set network_gateway_ip in conf/config.yml and re-run this script if this value is not desired."
    fi

    # Ensure the host IP address is set
    if [[ -z "${builder_config_host_ip+x}" ]]; then
        builder_config_host_ip="${ipAddr}"
        if [[ "${SKIP_NET}" == "false" ]]; then
            printDatedInfoMsg "Auto-determined host_ip=${builder_config_host_ip}"
        fi
        logInfoMsg "Using default host_ip=${builder_config_host_ip} - Set host_ip in conf/config.yml and re-run this script if this value is not desired."
    else
        if [[ "${ipAddr}" != "${builder_config_host_ip}" ]]; then
            if [[ "${SKIP_NET}" == "false" ]]; then
                printDatedInfoMsg "${C_L_YELLOW}Warning:${T_RESET} Using a user-specified value for host_ip=${C_L_YELLOW}${builder_config_host_ip}${T_RESET} which is different from this device's default outbound route IP of ${C_L_YELLOW}${ipAddr}${T_RESET}"
            fi
            logInfoMsg "Warning: Using a user-specified value for host_ip=${builder_config_host_ip} which is different from this device's default outbound route IP of ${ipAddr}"
        fi
    fi

    # Ensure the dnsmasq primary DNS is set
    if [[ -z "${builder_config_network_dns_primary+x}" ]]; then
        builder_config_network_dns_primary="8.8.4.4"
        if [[ "${SKIP_NET}" == "false" ]]; then
            printDatedInfoMsg "Auto-determined network_dns_primary=${builder_config_network_dns_primary}"
        fi
        logInfoMsg "Using default network_dns_primary=${builder_config_network_dns_primary} - Set network_dns_primary in conf/config.yml and re-run this script if this value is not desired."
    fi

    # Ensure the dnsmasq secondary DNS is set
    if [[ -z "${builder_config_network_dns_secondary+x}" ]]; then
        builder_config_network_dns_secondary="8.8.8.8"
        if [[ "${SKIP_NET}" == "false" ]]; then
            printDatedInfoMsg "Auto-determined network_dns_secondary=${builder_config_network_dns_secondary}"
        fi
        logInfoMsg "Using default network_dns_secondary=${builder_config_network_dns_secondary} - Set network_dns_secondary in conf/config.yml and re-run this script if this value is not desired."
    fi

    # No network interface specfied, using default network device
    if [[ -z "${builder_config_interface+x}" ]]; then
        if [[ "${SKIP_NET}" == "false" ]]; then
            printDatedInfoMsg "No network device defined by user, using default network device. Set interface in conf/config.yml and re-run this script if this value is not desired."
        fi
        logInfoMsg "No network device defined by user, using default network device. Set interface in conf/config.yml and re-run this script if this value is not desired."
    fi

    if [[ "${SKIP_NET}" == "false" ]]; then
        printDatedOkMsg "Network configuration determined."
    fi
    logOkMsg "Network configuration determined."
}

renderSystemNetworkTemplates() {
    # Get the IP and subnet of the current system
    # local ipAddr=$(getMyIp)
    # local ipRoute=$(getMyDefaultRoute)
    # local subnet=$(getMySubnet)
    # local broadcast=$(getMyBroadcast)
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
    if [[ ${DYNAMIC_PROFILE} == "false" ]];then
        local tmpPxeMenuFile=$(getTmpPxeMenuLocation)
        local tmpIpxeMenuFile=$(getTmpIpxeMenuLocation)
    else
        local tmpPxeMenuFile="template/pxelinux.cfg/default.dynamic"
        local tmpIpxeMenuFile="template/ipxe/menu.ipxe.head"
    fi

    # Copy template files
    copySampleFile ${tmpDnsMasqConf} ${tmpDnsMasqConf}.modified
    copySampleFile ${tmpPxeMenuFile} ${tmpPxeMenuFile}.modified
    copySampleFile ${tmpIpxeMenuFile} ${tmpIpxeMenuFile}.modified

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
    local interfacePlaceholder=("@@INTERFACE_BINDING@@" "@@ESP_INTERFACE_BINDING@@" "@@RNI_INTERFACE_BINDING@@")
    local ipMappingPlaceholder=("@@IP_MAPPING@@" "@@ESP_IP_MAPPING@@" "@@RNI_IP_MAPPING@@")

    # Replace all the potential variables in the staged files.
    # Note that profile-scoped variables are not accessible here.
    # In order to gain access to that scope use the renderTemplate
    # functionality
    local stgFiles=("${tmpDnsMasqConf}.modified" "${tmpPxeMenuFile}.modified" "${tmpIpxeMenuFile}.modified")
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
            if [[ -z "${builder_config_interface+x}" ]]; then
                sed -i -e "s/${interfacePlaceholder[i]}//g" ${stgFile}
            else
                sed -i -e "s/${interfacePlaceholder[i]}/interface=${builder_config_interface}\nbind-interfaces/g" ${stgFile}
            fi
            if [[ ! -z "${builder_config_ip_mapping__mac+x}" ]]; then
                local ipMapping=""
                for ((j = 0; j < "${#builder_config_ip_mapping__mac[@]}"; j += 1)); do
                    local dhcphost="dhcp-host=${builder_config_ip_mapping__mac[j]},${builder_config_ip_mapping__ip[j]}"
                    ipMapping="$ipMapping$dhcphost\n"
                done
                sed -i -e "s/${ipMappingPlaceholder[i]}/${ipMapping}/g" ${stgFile}
	        else
                sed -i -e "s/${ipMappingPlaceholder[i]}//g" ${stgFile}
            fi
        done
        logInfoMsg "Applied network config to ${stgFile}"
    done

    # # Check to see if there are any ipxe profiles
    # # if not skip ipxe menu
    # local autogen_str='# Auto-generated'
    # local tmpIxeMenuFile=$(getTmpIpxeMenuLocation)
    # local autogenCount=$(cat ${tmpIxeMenuFile} | grep "${autogen_str}" | wc -l)
    # if [ ${autogenCount} -lt 1 ]; then
    #     sed -i "s|menu-timeout 20000|menu-timeout 1|" ${WEB_ROOT}/tmp_menu.ipxe
    #     sed -i "s|set menu-default exit|set menu-default linuxmenu|" ${WEB_ROOT}/tmp_menu.ipxe
    # fi

    # Copy the modified config files to the real locations
    # If we are skipping 
    if [[ "${SKIP_NET}" == "false" ]]; then
        copySampleFile ${tmpDnsMasqConf}.modified ${dnsMasqConf}
    fi
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

    if [[ -z ${secret_config_tokens__token+x} ]]; then
        logMsg "No secret tokens found, nothing to do here"
    else
        local tmpFileName="${fileName}.modified"
        renderSecretTemplate ${tmpFileName}
    fi

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
