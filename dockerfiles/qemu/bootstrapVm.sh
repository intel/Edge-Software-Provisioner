#!/bin/bash
# // ========================================================
# // bootsrapVm.sh,v by GitHub DOB 2018/05/30

# // Copyright (c) 2018 Intel
# // All rights reserved.
# // Developer: Bryan Rodriguez - bryan.j.rodriguez@intel.com
# // ========================================================

set -e

[ -n "$DEBUG" ] && set -x

# Create the kvm node (required --privileged)
if [ ! -e /dev/kvm ]; then
  set +e
  mknod /dev/kvm c 10 $(grep '\<kvm\>' /proc/misc | cut -f 1 -d' ')
  set -e
fi

# If we were given arguments, override the default configuration
if [ $# -gt 0 ]; then
  exec /usr/bin/qemu-system-x86_64 $@
  exit $?
fi

if [ -z "$NAME" ]; then
  NAME=${HOSTNAME}
fi

if [ -z "$NETWORK_BRIDGE" ]; then
    echo "the environment variable NETWORK_BRIDGE cannot be empty"
    exit 1
fi

# disk image check
if [ "$IMAGE_CREATE" == "1" ]; then
  qemu-img create -f ${IMAGE_FORMAT} ${IMAGE} ${IMAGE_SIZE}
elif [ "${IMAGE:0:4}" != "rbd:" ] && [ ! -f "$IMAGE" ]; then
  echo "IMAGE not found: ${IMAGE}"; exit 1;
fi
if [ ! -f ${IMAGE} ]; then
  if [ "${ISO:0:1}" != "/" ] || [ -z "$IMAGE" ]; then
    echo "Disk Image: ${IMAGE} does not exist"
    exit 1
  fi
fi

if [ -n "$CPU" ]; then
  echo "[cpu]"
  FLAGS_CPU="${CPU}"
  echo "parameter: ${FLAGS_CPU}"
else
  FLAGS_CPU="qemu64"
fi

if [ -n "$ISO" ]; then
  echo "[iso]"
  if [ "${ISO:0:1}" != "/" ] && [ "${ISO:0:4}" != "rbd:" ]; then
    basename=$(basename $ISO)
    if [ ! -f "/data/isos/${basename}" ] || [ "$ISO_DOWNLOAD" != "0" ]; then
      wget -O- "$ISO" > /data/isos/${basename}
    fi
    ISO=/data/isos/${basename}
  fi
  FLAGS_ISO="-drive file=${ISO},media=cdrom,index=2"
  if [ "${ISO:0:4}" != "rbd:" ] && [ ! -f "$ISO" ]; then
    echo "ISO file not found: $ISO"
    exit 1
  fi
  echo "parameter: ${FLAGS_ISO}"
fi

if [ -n "$ISO2" ]; then
  echo "[iso2]"
  if [ "${ISO2:0:1}" != "/" ] && [ "${ISO2:0:4}" != "rbd:" ]; then
    basename=$(basename $ISO2)
    if [ ! -f "/data/isos/${basename}" ] || [ "$ISO_DOWNLOAD" != "0" ]; then
      wget -O- "$ISO2" > /data/isos/${basename}
    fi
    ISO=/data/isos/${basename}
  fi
  FLAGS_ISO2="-drive file=${ISO2},media=cdrom,index=3"
  if [ "${ISO2:0:4}" != "rbd:" ] && [ ! -f "$ISO2" ]; then
    echo "ISO2 file not found: $ISO2"
    exit 1
  fi
  echo "parameter: ${FLAGS_ISO2}"
fi

echo "[disk image]"
if [ "$DISK_DEVICE" == "scsi" ]; then
  FLAGS_DISK_IMAGE="-device virtio-scsi-pci,id=scsi -drive file=${IMAGE},aio=native,cache.direct=on,if=none,id=hd,cache=${IMAGE_CACHE},discard=${IMAGE_DISCARD},index=1 -device scsi-hd,drive=hd"
elif [ "$DISK_DEVICE" == "ide" ]; then
  FLAGS_DISK_IMAGE="-device ide-hd,bus=ide.0,unit=0,drive=hd,id=drive,bootindex=1 -drive file=${IMAGE},aio=native,cache.direct=on,if=none,id=hd,cache=${IMAGE_CACHE},format=${IMAGE_FORMAT},index=1"
elif [ "$DISK_DEVICE" == "virtio" ]; then
  FLAGS_DISK_IMAGE="-device virtio-blk-pci,scsi=off,bus=pci.0,drive=hd,id=drive,bootindex=1 -drive file=${IMAGE},aio=native,cache.direct=on,if=none,id=hd,cache=${IMAGE_CACHE},format=${IMAGE_FORMAT},index=1"
# elif [ "$DISK_DEVICE" == "virtio" ]; then
#   FLAGS_DISK_IMAGE="-drive file=${IMAGE},if=virtio,aio=native,cache.direct=on"
elif [ -n "$DISK_DEVICE" ]; then
  FLAGS_DISK_IMAGE=${DISK_DEVICE}
else
  FLAGS_DISK_IMAGE="-drive file=${IMAGE},if=${DISK_DEVICE},cache=${IMAGE_CACHE},format=${IMAGE_FORMAT},index=1"
fi
if [ -n "${DISK_AHCI}" ]; then
  if [ ${DISK_AHCI} == "true" ]; then
    FLAGS_DISK_IMAGE+=" -device ich9-ahci,id=ahci -device ide-drive,drive=drive,bus=ahci.0"
  fi
fi
echo "parameter: ${FLAGS_DISK_IMAGE}"

if [ -n "$FLOPPY" ]; then
  echo "[floppy image]"
  FLAGS_FLOPPY_IMAGE="-fda ${FLOPPY}"
  echo "parameter: ${FLAGS_FLOPPY_IMAGE}"
fi

echo "[network]"
if [ "$NETWORK" == "bridge" ]; then
  hexchars="0123456789ABCDEF"
  NETWORK_MAC="${NETWORK_MAC:-$(echo 52:54:00$(for i in {1..6} ; do echo -n ${hexchars:$(( $RANDOM % 16 )):1} ; done | sed -e 's/\(..\)/:\1/g'))}"
  if [ "${NETWORK_BRIDGE}" != "br0" ]; then
    echo "allow ${NETWORK_BRIDGE}" >> /etc/qemu/bridge.conf
  fi
  iptables -C FORWARD -i ${NETWORK_BRIDGE} -o ${NETWORK_BRIDGE} -j ACCEPT 2> /dev/null || true
  FLAGS_NETWORK="-netdev bridge,br=${NETWORK_BRIDGE},id=net0 -device ${NETWORK_DEVICE},netdev=net0,mac=${NETWORK_MAC}"
elif [ "$NETWORK" == "tap" ]; then
  NETWORK_IF="${NETWORK_IF:-eth0}"
  TAP_IFACE=tap0
  IP=`ip addr show dev $NETWORK_IF | grep "inet " | awk '{print $2}' | cut -f1 -d/`
  NAMESERVER=`grep nameserver /etc/resolv.conf | cut -f2 -d ' '`
  NAMESERVERS=`echo ${NAMESERVER[*]} | sed "s/ /,/g"`
  NETWORK_IP="${NETWORK_IP:-$(echo 172.$((RANDOM%(31-16+1)+16)).$((RANDOM%256)).$((RANDOM%(254-2+1)+2)))}"
  NETWORK_SUB=`echo $NETWORK_IP | cut -f1,2,3 -d\.`
  NETWORK_GW="${NETWORK_GW:-$(echo ${NETWORK_SUB}.1)}"
  tunctl -t $TAP_IFACE
  dnsmasq --user=root \
    --dhcp-range=$NETWORK_IP,$NETWORK_IP \
    --dhcp-option=option:router,$NETWORK_GW \
    --dhcp-option=option:dns-server,$NAMESERVERS
  ifconfig $TAP_IFACE $NETWORK_GW up
  iptables -t nat -A POSTROUTING -o $NETWORK_IF -j MASQUERADE
  iptables -I FORWARD 1 -i $TAP_IFACE -j ACCEPT
  iptables -I FORWARD 1 -o $TAP_IFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
  if [ "$VNC" == "tcp" ]; then
    iptables -t nat -A PREROUTING -p tcp -d $IP ! --dport `expr 5900 + $VNC_ID` -j DNAT --to-destination $NETWORK_IP
    iptables -t nat -A PREROUTING -p udp -d $IP -j DNAT --to-destination $NETWORK_IP
    iptables -t nat -A PREROUTING -p icmp -d $IP -j DNAT --to-destination $NETWORK_IP
  else
    iptables -t nat -A PREROUTING -d $IP -j DNAT --to-destination $NETWORK_IP
  fi
  # FLAGS_NETWORK="-net nic,model=${NETWORK_DEVICE} -net tap,ifname=tap0,script=no,downscript=no,vhost=on"
  FLAGS_NETWORK="-device ${NETWORK_DEVICE},netdev=net0 -netdev tap,id=net0,ifname=tap0,script=no,downscript=no,vhost=on"
elif [ "$NETWORK" == "macvtap" ]; then
  NETWORK_IF="${NETWORK_IF:-eth0}"
  NETWORK_BRIDGE="${NETWORK_BRIDGE:-vtap0}"
  hexchars="0123456789ABCDEF"
  NETWORK_MAC="${NETWORK_MAC:-$(echo 52:54:00$(for i in {1..6} ; do echo -n ${hexchars:$(( $RANDOM % 16 )):1} ; done | sed -e 's/\(..\)/:\1/g'))}"
  set +e
  ip link add link $NETWORK_IF name $NETWORK_BRIDGE address $NETWORK_MAC type macvtap mode bridge
  if [[ $? -ne 0 ]]; then
    echo "Warning! Bridge interface already exists"
  fi
  set -e
  FLAGS_NETWORK="-netdev tap,fd=3,id=net0,vhost=on -net nic,vlan=0,netdev=net0,macaddr=$NETWORK_MAC,model=virtio"
  exec 3<> /dev/tap`cat /sys/class/net/$NETWORK_BRIDGE/ifindex`
  if [ ! -z "$NETWORK_IF2" ]; then
    NETWORK_BRIDGE2="${NETWORK_BRIDGE2:-vtap1}"
    NETWORK_MAC2="${NETWORK_MAC2:-$(echo 52:54:00$(for i in {1..6} ; do echo -n ${hexchars:$(( $RANDOM % 16 )):1} ; done | sed -e 's/\(..\)/:\1/g'))}"
    set +e
    ip link add link $NETWORK_IF2 name $NETWORK_BRIDGE2 address $NETWORK_MAC2 type macvtap mode bridge
    if [[ $? -ne 0 ]]; then
      echo "Warning! Bridge interface 2 already exists"
    fi
    set -e
    FLAGS_NETWORK="${FLAGS_NETWORK} -netdev tap,fd=4,id=net1,vhost=on -net nic,vlan=1,netdev=net1,macaddr=$NETWORK_MAC2,model=virtio-net-pci"
    exec 4<> /dev/tap`cat /sys/class/net/$NETWORK_BRIDGE2/ifindex`
  fi
elif [ "$NETWORK" == "none" ]; then
  FLAGS_NETWORK="-nic none"
else
  NETWORK="user"
  REDIR=""
  if [ ! -z "$TCP_PORTS" ]; then
    OIFS=$IFS
    IFS=","
    for port in $TCP_PORTS; do
      REDIR+=",hostfwd=tcp::${port}-:${port}"
    done
    IFS=$OIFS
  fi
  
  if [ ! -z "$UDP_PORTS" ]; then
    OIFS=$IFS
    IFS=","
    for port in $UDP_PORTS; do
      REDIR+=",hostfwd=udp::${port}-:${port}"
    done
    IFS=$OIFS
  fi

  if [ ! -z "${HOSTFWD}" ]; then
    REDIR+="${HOSTFWD}"
  fi

  FLAGS_NETWORK="-nic user,model=${NETWORK_DEVICE}${REDIR}"
fi
echo "Using ${NETWORK}"
echo "parameter: ${FLAGS_NETWORK}"

echo "[Video]"
if [ "$VNC" == "tcp" ] && [ "$VIDEO" == "vnc" ]; then
  FLAGS_VIDEO="-vnc ${VNC_IP}:${VNC_ID} -vga cirrus"
elif [ "$VNC" == "reverse" ] && [ "$VIDEO" == "vnc" ]; then
  FLAGS_VIDEO="-vnc ${VNC_IP}:${VNC_PORT},reverse -vga cirrus"
elif [ "$VNC" == "sock" ] && [ "$VIDEO" == "vnc" ]; then
  FLAGS_VIDEO="-vnc unix:${VNC_SOCK} -vga cirrus"
elif [ "$VIDEO" == "spice" ] && [ -n "$SPICE_OPTIONS" ]; then
  FLAGS_VIDEO="-spice $SPICE_OPTIONS"
elif [ "$VIDEO" == "spice" ] && [ "$SPICE" == "tcp" ]; then
  FLAGS_VIDEO="-spice port=${SPICE_PORT},addr=${SPICE_IP},disable-ticketing -vga qxl"
elif [ "$VIDEO" == "spice" ] && [ "$SPICE" == "sock" ]; then
  FLAGS_VIDEO="-spice unix,addr=${SPICE_SOCK},disable-ticketing -vga qxl"
elif [ "$VIDEO" == "virgl" ]; then
  xhost +
  FLAGS_VIDEO="-device virtio-vga,virgl=on -display sdl,gl=on"
elif [ "$VIDEO" == "custom" ]; then
  FLAGS_VIDEO="${CUSTOM_VIDEO}"
else
  FLAGS_VIDEO="-nographic"
fi
echo "parameter: ${FLAGS_VIDEO}"

echo "[GPU]"
if [ "${GPU}" == "gvt" ]; then
  if [ -d /sys/devices/pci0000:00/0000:00:02.0/mdev_supported_types/i915-GVTg_V5_4 ]; then
    for GVT_PATH in $(find /sys/devices/pci0000:00/0000:00:02.0/*-????-????-????-* -maxdepth 0 -type d 2> /dev/null); do
      if ps auxww | grep ${GVT_PATH} | grep -v grep > /dev/null; then
        echo "${GVT_PATH} is in use."
      else
        echo "${GVT_PATH} is not in use. Being removed..."
          echo 1 > ${GVT_PATH}/remove 2> /dev/null || true;
        echo "[ok]"
      fi
    done
    GVT_COUNT=$(find /sys/devices/pci0000:00/0000:00:02.0/*-????-????-????-* -maxdepth 0 -type d 2> /dev/null | wc -l)
    if [ ${GVT_COUNT} -lt 1 ]; then
      UUID=$(uuidgen) &&
      echo ${UUID} > /sys/devices/pci0000:00/0000:00:02.0/mdev_supported_types/i915-GVTg_V5_4/create 2> /dev/null || true
      FLAGS_GPU="-device vfio-pci,sysfsdev=/sys/devices/pci0000:00/0000:00:02.0/${UUID},x-igd-opregion=on"
      if [ ! -z "$GPU_OPTIONS" ]; then
        FLAGS_GPU+=${GPU_OPTIONS}
      else
        FLAGS_GPU+=",display=on,ramfb=on,driver=vfio-pci-nohotplug"
      fi
      if [ "$VIDEO" != "custom" ]; then
        if [ "$VIDEO" == "spice" ] && [ -z "$SPICE_OPTIONS" ]; then
          FLAGS_VIDEO="${FLAGS_VIDEO/-spice /-spice gl=on,}"
          FLAGS_VIDEO="${FLAGS_VIDEO/-vga qxl/-vga none}"
        fi
        if [ "$VIDEO" == "vnc" ]; then
          FLAGS_VIDEO="${FLAGS_VIDEO/-vnc /-spice gl=on,}"
          FLAGS_VIDEO="${FLAGS_VIDEO/-vga qxl/-cirrus none}"
        fi
      fi
    else
      echo "WARNING: Max number of GVT devices created, starting with no GPU acceleration."
    fi
  else
    echo "WARNING: GVT was requested but it is not available on this device, starting with no GPU acceleration."
  fi
fi
echo "parameter: ${FLAGS_GPU}"

echo "[USB HUB]"
if [ "${USB_HUB}" == "none" ]; then
  FLAGS_USBHUB=""
elif [ ! -z "${USB_HUB}" ]; then
  FLAGS_USBHUB="${USB_HUB}"
else
  FLAGS_USBHUB="-device ich9-usb-ehci1,id=usb -device ich9-usb-uhci1,masterbus=usb.0,firstport=0,multifunction=on -device ich9-usb-uhci2,masterbus=usb.0,firstport=2 -device ich9-usb-uhci3,masterbus=usb.0,firstport=4 -chardev spicevmc,name=usbredir,id=usbredirchardev1 -device usb-redir,chardev=usbredirchardev1,id=usbredirdev1 -chardev spicevmc,name=usbredir,id=usbredirchardev2 -device usb-redir,chardev=usbredirchardev2,id=usbredirdev2 -chardev spicevmc,name=usbredir,id=usbredirchardev3 -device usb-redir,chardev=usbredirchardev3,id=usbredirdev3"
fi
echo "parameter: ${FLAGS_USBHUB}"

echo "[Audio]"
if [ "${AUDIO}" == "none" ]; then
  FLAGS_AUDIO=""
elif [ -n "${AUDIO}" ]; then
  FLAGS_AUDIO="-audiodev ${AUDIO}"
else
  if [ -d /dev/snd ]; then
    FLAGS_AUDIO="-device intel-hda,id=sound0 -device hda-duplex,id=sound0-codec0,cad=0"
  fi
fi
echo "parameter: ${FLAGS_AUDIO}"

echo "[Keyboard]"
if [ -n "$KEYBOARD" ]; then
  FLAGS_KEYBOARD="-k ${KEYBOARD}"
else
  FLAGS_KEYBOARD="-k en-us"
fi
echo "parameter: ${FLAGS_KEYBOARD}"

echo "[Mouse]"
if [ "$MOUSE" == "none" ]; then
  FLAGS_MOUSE=""
elif [ ! -z "$MOUSE" ]; then
  FLAGS_MOUSE="${MOUSE}"
else
  FLAGS_MOUSE="-usb -device usb-tablet"
fi
echo "parameter: ${FLAGS_MOUSE}"

VT_ENABLED_COUNT=$(egrep -c '(vmx)' /proc/cpuinfo)
if [ ${VT_ENABLED_COUNT} -gt 0 ]; then
  echo "[KVM]"
  VT_ENABLED="-enable-kvm"
  echo "parameter: ${VT_ENABLED}"
else
  echo "[KVM]"
  SYSTEM_TYPE=$(cat /proc/cpuinfo  | grep -o hypervisor | head -n1)
  if [ "${SYSTEM_TYPE}" == "" ]; then
    echo "WARNING: VTx Extensions are not enabled on this system.  This is usually done in the BIOS."
  fi
fi

echo "[Monitor]"
if [ "${MONITOR}" == "none" ]; then
  FLAGS_MONITOR=""
elif [ ! -z "${MONITOR}" ]; then
  FLAGS_MONITOR="-monitor ${MONITOR}"
else
  FLAGS_MONITOR="-monitor unix:/var/run/${NAME}-monitor.sock,server,nowait"
fi
echo "parameter: ${FLAGS_MONITOR}"

echo "[Balloon]"
if [ "${BALLOON}" == "none" ]; then
  FLAGS_BALLOON=""
elif [ ! -z "${BALLOON}" ]; then
  FLAGS_BALLOON="-device ${BALLOON}"
else
  FLAGS_BALLOON="-device virtio-balloon"
fi
echo "parameter: ${FLAGS_BALLOON}"

echo "[boot]"
if [ -n "$BOOT" ]; then
  FLAGS_BOOT="-boot ${BOOT}"
fi
echo "parameter: ${FLAGS_BOOT}"

echo "[Bios]"
if [ "${BIOS}" == "efi" ]; then
  FLAGS_BIOS="-bios /usr/share/ovmf/bios.bin -boot menu=on"
elif [ -n "${BIOS}" ]; then
  FLAGS_BIOS="-bios ${BOOT}"
fi
echo "parameter: ${FLAGS_BIOS}"

FLAGS_DEFAULTS="-pidfile /run/${NAME}.pid -object rng-random,id=rng0,filename=/dev/urandom -device virtio-rng-pci,rng=rng0"

EXEC="/usr/bin/qemu-system-x86_64 ${VT_ENABLED} \
  -m ${RAM} -smp ${SMP} -cpu ${FLAGS_CPU} ${FLAGS_MOUSE} \
  -name ${NAME} \
  ${FLAGS_VIDEO} \
  ${FLAGS_GPU} \
  ${FLAGS_DISK_IMAGE} \
  ${FLAGS_FLOPPY_IMAGE} \
  ${FLAGS_ISO} \
  ${FLAGS_ISO2} \
  ${FLAGS_NETWORK} \
  ${FLAGS_USBHUB} \
  ${FLAGS_AUDIO} \
  ${FLAGS_KEYBOARD} \
  ${FLAGS_MOUSE} \
  ${FLAGS_BALLOON} \
  ${FLAGS_BOOT} \
  ${FLAGS_BIOS} \
  ${FLAGS_MONITOR} \
  ${FLAGS_DEFAULTS} \
  ${ADD_FLAGS}"

set -x
eval "${EXEC}" || true
if [ -n "${UUID}" ]; then
  echo 1 > /sys/bus/pci/devices/0000:00:02.0/${UUID}/remove 2> /dev/null || true;
fi
