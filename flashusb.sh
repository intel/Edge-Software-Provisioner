#!/bin/bash

# Copyright (C) 2020 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

set -u

# if [[ $(id -u) -ne 0 ]]; then
#     echo -e "\e[1m\e[31;1m Please run this script as root \e[0m"
#     exit 1
# fi

if (! which wget > /dev/null); then 
    echo -e "\e[1m\e[31;1m wget command not found.  Please install wget before proceeding. \e[0m"
    exit 1
fi

printHelp() {
    echo -e "\n Main Flash USB Utility"
    echo " You can specify one the following options:"
    echo " -u, --url                  URL of the USB Image"
    echo " -i, --image                Drive path to the USB Image"
    echo " -b, --bios                 Set USB bootable image to legacy BIOS or EFI, valid options [ efi | bios ].  Defaults to efi."
    echo " -d, --dev                  Path to usb devices, for example '/dev/sdc'. WARNING: this will wipe out the target device.  If omitted it will provide instructions how to flash a USB device."
    echo " -h, --help                 Show this help dialog"
    echo ""
    echo " Usage: $0 --image usb.img --bios efi"
    echo ""
    exit 0
}

export URL=""
export IMAGE=""
export BIOS="efi"
export DEV=""
export USB_IMG_SIZE=""
export DEV_MSG=""
while (( "$#" )); do
    case "$1" in
        "-u" | "--url"         )            export URL=$2
                                            shift 2;;
        "-i" | "--image"      )             export IMAGE=$2
                                            shift 2;;
        "-b" | "--bios"            )        export BIOS=$2
                                            shift 2;;
        "-d" | "--dev"             )        export DEV=$2
                                            shift 2;;
        "-v" | "--verbose"             )    export VERBOSE="true"
                                            shift 1;;
        "-h" | "--help"                )    printHelp;;
        "--"                           )    # end argument parsing
                                            shift
                                            break;;
        -* | --*=                      )    # unsupported flags
                                            echo "Error: Unsupported flag $1" >&2
                                            exit 1;;
        *                              )    # preserve positional arguments
                                            PARAMS="$PARAMS $1"
                                            shift;;
    esac
done

echo ""
echo "--------------------------------"
echo -e "| \e[1mWelcome to Flash USB Utility\e[0m |"
echo "--------------------------------"
echo ""

if [ -n "${URL}" ]; then
    if (! wget --no-check-certificate -q --method=HEAD ${URL}); then
        echo -e "\e[1m\e[31;1m URL: ${URL} is not accesible \e[0m"
        exit 1
    fi
    USB_IMG_SIZE=$(wget --no-check-certificate --spider --server-response -O - ${URL} 2>&1 | sed -ne '/Content-Length/{s/.*: //;p}')
fi

if [ -n "${IMAGE}" ]; then
    if [ ! -f ${IMAGE} ]; then
        echo -e "\e[1m\e[31;1m IMAGE: ${IMAGE} does not exist \e[0m"
        exit 1
    fi
    USB_IMG_SIZE=$(du -b ${IMAGE} | awk '{print $1}')
    if (! which pv > /dev/null); then 
        echo -e "\e[1m\e[31;1m We recommend installing 'pv' to get progress output of flashing the USB drive. Hit CTRL-C and install it or wait 5 seconds to continue. \e[0m"
        sleep 5
    else
        PV=$(which pv)
    fi
fi

if [ ! -n "${USB_IMG_SIZE}" ]; then
    $0 -h
    echo ""
    echo ""
    echo -e "\e[1m\e[31;1m Please specify a USB image. \e[0m"
    echo ""
    exit 1
fi

# if [ ! -n "${DEV}" ]; then
#     $0 -h
#     echo ""
#     echo ""
#     echo -e "\e[1m\e[31;1m Please specify a USB device path. \e[0m"
#     echo ""
#     exit 1
# fi

if [ -n "${DEV}" ]; then
    USB_DEV_BASE=$(basename ${DEV})
    if ( find /dev/disk/by-id/ -lname "*${USB_DEV_BASE}" 2> /dev/null | grep usb > /dev/null ); then
        USB_DRIVE=""
        _drive=$(find /dev/disk/by-id/ -ls | grep usb | grep -v part | grep ${USB_DEV_BASE} | awk '{print $11}')
        _dev=$(ls -l ${_drive} | awk '{print $NF}')
        _usb=$(echo ${_drive} | awk -F'-' '{print $3}')
        _hex=$(echo ${_usb} | awk -F'_' '{print $NF}')
        USB_DRIVE="${_usb/_${_hex}/}-(${_dev/..\/..\//\/dev/})"
    elif ( lsblk -p -S -o NAME,TRAN | grep usb | grep ${DEV} > /dev/null 2>&1 ); then
        USB_DRIVE="NO_USB_NAME-(${DEV})"
    else
        echo -e "\e[1m\e[31;1m The device specified '${DEV}' is not a USB device. \e[0m"
        echo ""
        echo " Discovering suitable USB devices on this system."
        DEV_MSG=${DEV}
        DEV=""
    fi
fi

if [ ! -n "${DEV}" ]; then
    if [ -d /dev/disk/by-id/ ]; then
        USB_NAMES=""
        for _drive in $(find /dev/disk/by-id/ | grep usb | grep -v part); do
            _dev=$(ls -l ${_drive} | awk '{print $NF}')
            _usb=$(echo ${_drive} | awk -F'-' '{print $3}')
            _hex=$(echo ${_usb} | awk -F'_' '{print $NF}')
            USB_NAMES="${USB_NAMES} ${_usb/_${_hex}/}-(${_dev/..\/..\//\/dev/})"
        done
        for _drive in $(lsblk -p -S -o NAME,TRAN | grep usb | awk '{print $1}'); do
            if [[ "${USB_NAMES}" != *"${_drive}"* ]]; then
                USB_NAMES="${USB_NAMES} NO_USB_NAME-(${_drive})"
            fi
        done
        NUM_USB=( ${USB_NAMES} )
        if [ ${#NUM_USB[@]} -gt 1 ]; then
            PS3="Select the USB Drive to flash: "
            USB_NAMES="${USB_NAMES} Quit"
            select USB_DRIVE in ${USB_NAMES}; do
                if [ "${USB_DRIVE}" != "" ]; then
                    if [ "${USB_DRIVE}" == "Quit" ]; then
                        exit
                    fi
                    break
                fi
            done
        elif [ ${#NUM_USB[@]} -lt 1 ]; then
            echo -e "\e[1m\e[31;1m There is no suitable USB devices plugged in. \e[0m"
            echo ""
            if [ -n "${DEV_MSG}" ]; then
                if ( pvs 2> /dev/null | grep ${DEV_MSG} > /dev/null 2>&1 ); then
                    local temp_vg=$(pvs | grep ${DEV_MSG} | awk '{print $2}')
                    if ( mount | grep /dev/mapper/${temp_vg} > /dev/null 2>&1 ); then
                        echo -e "\e[1m\e[31;1m   The device ${DEV} is mounted via LVM. \e[0m"
                    fi
                elif ( mount | grep ${DEV_MSG} > /dev/null 2>&1 ); then
                    echo -e "\e[1m\e[31;1m   The device ${DEV_MSG} is mounted and might be a system disk. \e[0m"
                    echo "Mount point: $(mount | grep ${DEV_MSG})"
                elif (! lsblk -pl | grep ${DEV_MSG} > /dev/null 2>&1 ); then
                    echo -e "\e[1m\e[31;1m   The device ${DEV_MSG} does not exist. \e[0m"
                fi
                echo ""
            fi
            echo "Legacy hardware treats USB drives as ATA drives instead of USB devices. This utility does it's best to protect you to make sure you flash the correct device."
            if [ -n "${DEV_MSG}" ]; then
                echo "If you feel this message is an error, please confirm this device '${DEV_MSG}' is correct and not mounted before continuing."
                echo "You can use the following commands if you are confident that this '${DEV_MSG}' is the correct device."
            else
                DEV_MSG="/dev/path/to/dev"
                echo "If you feel this message is an error, you can use the following commands to flash a usb device."
                echo "Find your USB device path, for example '/dev/sdf', confirm the device not mounted before continuing."
                echo "Replace '${DEV_MSG}' with correct device location in the command below."
            fi
            echo ""
            if [ -n "${URL}" ]; then
                echo "wget --show-progress --no-check-certificate -qO - ${URL} | dd obs=1M oflag=direct status=none of=${DEV_MSG}"
                MBR_LOCATION=$( echo $URL | awk -F'/' '{print $1}' )//$( echo $URL | awk -F'/' '{print $3}' )/mbr.bin
                if [ "${BIOS}" ]; then
                    echo "wget --show-progress --no-check-certificate -qO - ${MBR_LOCATION} | dd bs=440 count=1 conv=notrunc status=none of=${DEV_MSG}"
                fi
            fi

            if [ -n "${IMAGE}" ]; then
                if [ -n "${PV}" ]; then
                    echo "dd if=${IMAGE} status=none | pv -s ${USB_IMG_SIZE} | dd obs=1M oflag=direct status=none of=${DEV_MSG}"
                else
                    echo "dd if=${IMAGE} obs=1M oflag=direct status=none of=${DEV_MSG}"
                fi
                MBR_LOCATION="data/usr/share/nginx/html/mbr.bin"
                if [ "${BIOS}" ]; then
                    echo "dd bs=440 count=1 conv=notrunc status=none if=${MBR_LOCATION} of=${DEV_MSG}"
                fi
            fi
            echo ""
            exit 1
        else
            echo -e " Found suitable USB device: ${USB_NAMES#' '}"
            USB_DRIVE="${USB_NAMES#' '}"
        fi
        DEV=$( echo ${USB_DRIVE} | awk -F '(' '{print $2}' | awk -F')' '{print $1}' )
        USB_DEV_BASE=$(basename ${DEV})
    else
        echo -e "\e[1m\e[31;1m There is no suitable USB devices plugged in. \e[0m"
        echo ""
        exit 1
    fi
fi

if (! find /dev/disk/by-id/ -lname "*${USB_DEV_BASE}" | grep usb > /dev/null ) && (! lsblk -p -S -o NAME,TRAN | grep usb | grep ${DEV} > /dev/null 2>&1 ); then
    echo -e "\e[1m\e[31;1m The device specified '${DEV}' is not a USB device. \e[0m"
    echo ""
    echo "Here is a list of USB devices plugged in. NOTE: if the following list is empty, there is no suitable USB devices plugged in."
    lsblk -p -S -o NAME,TRAN | grep usb
    echo ""
    exit 1
fi

# Fail safe, the var must be populated
if [ "${USB_DRIVE}" == "" ]; then
    exit
fi

echo ""
echo -e "\e[1mWARNING:\e[0m you are about to flash drive '${USB_DRIVE}'."
echo ""
read -p "  Would like to continue? [y/n]: " answer
if [ ${answer} = "y" ]; then
    echo ""
else
    exit
fi

if [ -n "${URL}" ]; then
    wget --show-progress --no-check-certificate -qO - ${URL} | dd obs=1M oflag=direct status=none of=${DEV}
    MBR_LOCATION=$( echo $URL | awk -F'/' '{print $1}' )//$( echo $URL | awk -F'/' '{print $3}' )/mbr.bin
    if [ "${BIOS}" ]; then
        wget --no-check-certificate -qO - ${MBR_LOCATION} | dd bs=440 count=1 conv=notrunc status=none of=${DEV}
    fi
fi

if [ -n "${IMAGE}" ]; then
    if [ -n "${PV}" ]; then
        dd if=${IMAGE} status=none | pv -s ${USB_IMG_SIZE} | dd obs=1M oflag=direct status=none of=${DEV}
    else
        dd if=${IMAGE} obs=1M oflag=direct status=none of=${DEV}
    fi
    MBR_LOCATION="data/usr/share/nginx/html/mbr.bin"
    if [ "${BIOS}" ]; then
        dd bs=440 count=1 conv=notrunc status=none if=${MBR_LOCATION} of=${DEV}
    fi
fi

echo ""
echo "Flashing USB complete."
echo ""