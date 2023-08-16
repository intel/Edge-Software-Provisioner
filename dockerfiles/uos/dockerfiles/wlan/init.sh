#!/bin/bash

# Copyright (C) 2021 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

# --- Get kernel parameters ---
kernel_params=$(cat /proc/cmdline)

if [[ $kernel_params == *"wpacountry="* ]]; then
	tmp="${kernel_params##*wpacountry=}"
	COUNTRY="${tmp%% *}"
fi

if [[ $kernel_params == *"wpassid="* ]]; then
	tmp="${kernel_params##*wpassid=}"
	 SSID="${tmp%% *}"
fi

if [[ $kernel_params == *"wpapsk="* ]]; then
	tmp="${kernel_params##*wpapsk=}"
	PSK="${tmp%% *}"
fi

configdir="/run/wpa_supplicant"
configfile="/etc/wpa_supplicant/wpa_supplicant.conf"
configfileTemplate="/opt/wpa_supplicant.conf.template"

mkdir -p /etc/wpa_supplicant

cp ${configfileTemplate} ${configfile}

sed -i -e "s/@@COUNTRY@@/${COUNTRY}/g" ${configfile}

if [ -d "/sys/class/ieee80211" ] && [ "$(ls -A /sys/class/ieee80211 2>/dev/null )" ]; then
  # Note: Can't use wpa_supplicant without WPA; have to disable it then e.g.,
  # iwconfig wlan0 essid "ietf-hotel"

  if ( ip link show mlan0 > /dev/null 2>&1 ); then 
    # workaround for mlan0 driver of Advantech
    (ip link set mlan0 down ; ip link set mlan0 name wlan0) || /bin/true
  fi
  if (! ip link show wlan0 | grep up > /dev/null ); then
    ip link set wlan0 up
  fi

  if [ -n "${SSID}" ] && [ -n "${PSK}" ]; then
    cp ${configfileTemplate} ${configfile}

    sed -i -e "s/@@COUNTRY@@/${COUNTRY}/g" ${configfile}
    sed -i -e "s/@@SSID@@/${SSID}/g" ${configfile}
    sed -i -e "s/@@PSK@@/${PSK}/g" ${configfile}

    if [ -d "${configdir}" ] && [ -f "${configfile}" ]; then
      wpa_supplicant -Dwext -iwlan0 -c "${configfile}" -d -B && \
      sleep 1.5 && \
      udhcpc -i wlan0 && \
      cat /etc/resolv.conf > /etc/system-resolv.conf
    fi
  fi
fi

while inotifywait -e modify ${configfile}; do 
  echo "${configfile} has changed. Restarting services"
  if [ -d "/sys/class/ieee80211" ] && [ "$(ls -A /sys/class/ieee80211 2>/dev/null )" ]; then
    # Note: Can't use wpa_supplicant without WPA; have to disable it then e.g.,
    # iwconfig wlan0 essid "ietf-hotel"

    if ( ip link show mlan0 > /dev/null 2>&1 ); then 
      # workaround for mlan0 driver of Advantech
      (ip link set mlan0 down ; ip link set mlan0 name wlan0) || /bin/true
    fi
    if (! ip link show wlan0 | grep up > /dev/null ); then
      ip link set wlan0 up
    fi
    if [ -z "$(pgrep -x "wpa_supplicant")" ]; then
      wpa_supplicant -Dwext -iwlan0 -c "${configfile}" -d -B && \
      sleep 1.5 && \
      udhcpc -i wlan0 && \
      cat /etc/resolv.conf > /etc/system-resolv.conf
    else
      killall -s HUP wpa_supplicant && \
      sleep 1.5 && \
      udhcpc -i wlan0 && \
      cat /etc/resolv.conf > /etc/system-resolv.conf
    fi
  else
    echo "No wireless devices found.  Sleeping until restarted."
  fi
done