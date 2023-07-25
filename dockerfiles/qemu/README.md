# KVM on Docker

## Usage
Boot windows vm
```
docker run -d \
    --privileged \
    --net=host \
    --name=qemu-win
    -v /dev:/dev \
    -v /mnt:/data/volumes \
    -e RAM=4096 \
    -e SMP=4,sockets=4,cores=1,threads=1 \
    -e NAME=wintest \
    -e DISK_DEVICE=ide \
    -e IMAGE_FORMAT=qcow2 \
    -e IMAGE=/data/volumes/win.img \
    -e NETWORK=bridge \
    -e NETWORK_BRIDGE=br0 \
    -e NETWORK_DEVICE=e1000 \
    -e VNC=tcp \
    -p 5900:5900
    esp-qemu
```


Boot with ISO
```
docker run \
    --privileged \
    --net=host \
    -v /dev:/dev \
    -v /mnt:/data/volumes \
    -e RAM=2048 \
    -e SMP=1,sockets=1,cores=1,threads=1 \
    -e IMAGE=/data/volumes/vm.img \
    -e ISO=http://host/path/cd.iso \
    -e ISO2=http://host/path/drivers.iso \
    -e ISO_DOWNLOAD=1 \
    -e VNC=tcp \
    -p 2222:22 \
    -p 8080:80 \
    -p 5900:5900 \
    esp-qemu
```


Boot with raw logical volumes
```
docker run \
    --privileged \
    --net=host \
    -v /dev:/dev \
    -e RAM=2048 \
    -e SMP=4,sockets=4,cores=1,threads=1 \
    -e IMAGE=/dev/mapper/vg00_lv \
    -e IMAGE_FORMAT=raw \
    -e ISO=rbd:data/cd-image \
    -e VNC=tcp \
    -p 2222:22 \
    -p 8080:80 \
    -p 5900:5900 \
    esp-qemu
```


Create new volume file
```
docker run \
    --privileged \
    --net=host \
    -v /dev:/dev \
    -v /mnt:/data/volumes \
    -e RAM=2048 \
    -e SMP=1,sockets=1,cores=1,threads=1 \
    -e IMAGE=/data/volumes/vm.img \
    -e IMAGE_CREATE=1 \
    -e VNC=tcp \
    -p 2222:22 \
    -p 8080:80 \
    -p 5900:5900 \
    esp-qemu
```


## Network modes

`-e NETWORK=bridge --net=host -e NETWORK_BRIDGE=docker0 -e NETWORK_MAC=01:02:03:04:05`
> Bridge mode will be enabled with docker0 interface. `--net=host` is required for this mode. Mac address is optional.

`-e NETWORK=tap`
> Enables NAT and port forwarding with tap device

`-e NETWORK=macvtap --net=host -e NETWORK_IF=eth0 -e NETWORK_BRIDGE=vtap0 -e NETWORK_MAC=01:02:03:04:05`
> Creates a macvtap device called vtap0 and will setup bridge with your external interface eth0. `--net=host` is required for this mode. Mac address is optional.

`-e NETWORK=user -e TCP_PORTS=22,80`
> Enables qemu user networking. Also redirects ports 22 and 80 to vm.


## VNC options

`-e VIDEO=vnc -e VNC=tcp -e VNC_IP=127.0.0.1 -e VNC_ID=1`
> VNC server will listen tcp connections on 127.0.0.1:5901

`-e VIDEO=vnc -e VNC=sock -e VNC_SOCK=/data/vnc.sock`
> VNC server will listen on unix socket at /data/vnc.sock

`-e VIDEO=vnc -e VNC=reverse -e VNC_IP=1.1.1.1 -e VNC_PORT=5500`
> Reverse VNC connection to 1.1.1.1:5500

`-e VIDEO=none`
> VNC server will be disabled


## Spice options
> Spice is a much better graphics accelerator than VNC.  Remember to install the spice agent into the guesthttps://www.spice-space.org/download.html

`-e VIDEO=spice -e SPICE=tcp -e SPICE_IP=127.0.0.1 -e SPICE_PORT=5902`
> SPICE server will listen tcp connections on 127.0.0.1:5902

`-e VIDEO=spice -e SPICE=sock -e SPICE_SOCK=/data/spice.sock`
> SPICE server will listen on unix socket at /data/spice.sock

`-e VIDEO=spice -e SPICE_OPTIONS='gl=on,unix,addr=/run/vm.sock -device virtio-vga,virgl=on'`
> SPICE will enable OpenGL and GVT on the local i7 Core GPU.  (fastest graphics possible)

`-e VIDEO=none`
> SPICE server will be disabled


## Environment Variable Options

`-e NAME vm0`
> Enter a name for the VM, this value cannot be empty. Default value is vm0.

`-e RAM 2048`
> Enter a value in megabytes for the virtual machine RAM. Default value is 2048.

`-e SMP 1,sockets=1,cores=1,threads=1`
> The is number of cpus, threads etc. Default value is 1,sockets=1,cores=1,threads=1.  See "-smp" in the QEMU manual: https://qemu.weilnetz.de/doc/

`-e CPU qemu64`
> This is the cpu type to use.  Default value is qemu64 for the fastest processing.  Below is a list of alternative CPUs to use.
```
Command to list CPU options: bash-4.4# qemu-system-x86_64 -cpu help
Available CPUs:
x86              486
x86  Broadwell-noTSX  Intel Core Processor (Broadwell, no TSX)
x86        Broadwell  Intel Core Processor (Broadwell)
x86           Conroe  Intel Celeron_4x0 (Conroe/Merom Class Core 2)
x86    Haswell-noTSX  Intel Core Processor (Haswell, no TSX)
x86          Haswell  Intel Core Processor (Haswell)
x86        IvyBridge  Intel Xeon E3-12xx v2 (Ivy Bridge)
x86          Nehalem  Intel Core i7 9xx (Nehalem Class Core i7)
x86       Opteron_G1  AMD Opteron 240 (Gen 1 Class Opteron)
x86       Opteron_G2  AMD Opteron 22xx (Gen 2 Class Opteron)
x86       Opteron_G3  AMD Opteron 23xx (Gen 3 Class Opteron)
x86       Opteron_G4  AMD Opteron 62xx class CPU
x86       Opteron_G5  AMD Opteron 63xx class CPU
x86           Penryn  Intel Core 2 Duo P9xxx (Penryn Class Core 2)
x86      SandyBridge  Intel Xeon E312xx (Sandy Bridge)
x86   Skylake-Client  Intel Core Processor (Skylake)
x86   Skylake-Server  Intel Xeon Processor (Skylake)
x86         Westmere  Westmere E56xx/L56xx/X56xx (Nehalem-C)
x86           athlon  QEMU Virtual CPU version 2.5+
x86         core2duo  Intel(R) Core(TM)2 Duo CPU     T7700  @ 2.40GHz
x86          coreduo  Genuine Intel(R) CPU           T2600  @ 2.16GHz
x86            kvm32  Common 32-bit KVM processor
x86            kvm64  Common KVM processor
x86             n270  Intel(R) Atom(TM) CPU N270   @ 1.60GHz
x86          pentium
x86         pentium2
x86         pentium3
x86           phenom  AMD Phenom(tm) 9550 Quad-Core Processor
x86           qemu32  QEMU Virtual CPU version 2.5+
x86           qemu64  QEMU Virtual CPU version 2.5+
x86             base  base CPU model type with no features enabled
x86             host  KVM processor with all supported host features (only available in KVM mode)
x86              max  Enables all features supported by the accelerator in the current host
```

`-e KEYBOARD ""`
> This is the keyboard type to use.  Default value is en-us.

`-e MOUSE ""`
> This is the mouse type to use.  Default value is '-usb -device usb-tablet' which works best for windows. For android value of 'none' works best.

`-e DISK_DEVICE ide`
> Options are ide, scsi, virtio, "" or a custom device string if you know what you are doing.  Default value is ide. See "-device" in the QEMU manual: https://qemu.weilnetz.de/doc/

`-e IMAGE /data/volumes/vm.img`
> Path to disk image.  Can be a docker bind mount or and image within the container. Default value is /data/volumes/vm.img.

`-e IMAGE_FORMAT qcow2`
> Disk image format; options are qcow2, qcow, cow, raw, cloop, vmdk, vdi, vhdx and vpc. Default value is qcow2.  See https://en.wikibooks.org/wiki/QEMU/Images to understand image types.

`-e IMAGE_SIZE 10G`
> Disk partition size in gigabytes.  Default value is 10G.

`-e IMAGE_CACHE none`
> Disk cache; options are none, writeback, unsafe, directsync and writethrough.   Default value is none (none is equal to writeback and direct). See "cache=cache" in the QEMU manual: https://qemu.weilnetz.de/doc/

`-e IMAGE_DISCARD unmap`
> Options are ignore and unmap.  See "discard=discard" in the QEMU manual: https://qemu.weilnetz.de/doc/

`-e IMAGE_CREATE 0`
> Options 0 or 1.  1 will create the disk image and used when installing OS for the first time. Default value is 0.

`-e ISO=http://host/path/cd.iso`
> Path to iso image for OS installation.  Use environment variable ISO_DOWNLOAD to download. 

`-e ISO_DOWNLOAD 0`
> Options 0 or 1. Will download ISO from environment variable ISO. Default value is 0.

`-e NETWORK user`
> Network device type; options are user, bridge, tap and macvtap.  Default value is user.  See https://wiki.qemu.org/Documentation/Networking and https://qemu.weilnetz.de/doc/ for types.

`-e NETWORK_BRIDGE br0`
> This is relevant when NETWORK type is bridge.  This is host bridge device.  Default value is br0.  Do not change unless you know what you are doing.

`-e NETWORK_MAC ""`
> Set your network MAC address.

`-e NETWORK_DEVICE e1000`
> This the network device emulation. Default value is e1000. See below for a list of options:
```
Network devices:
name "e1000", bus PCI, alias "e1000-82540em", desc "Intel Gigabit Ethernet"
name "e1000-82544gc", bus PCI, desc "Intel Gigabit Ethernet"
name "e1000-82545em", bus PCI, desc "Intel Gigabit Ethernet"
name "e1000e", bus PCI, desc "Intel 82574L GbE Controller"
name "i82550", bus PCI, desc "Intel i82550 Ethernet"
name "i82551", bus PCI, desc "Intel i82551 Ethernet"
name "i82557a", bus PCI, desc "Intel i82557A Ethernet"
name "i82557b", bus PCI, desc "Intel i82557B Ethernet"
name "i82557c", bus PCI, desc "Intel i82557C Ethernet"
name "i82558a", bus PCI, desc "Intel i82558A Ethernet"
name "i82558b", bus PCI, desc "Intel i82558B Ethernet"
name "i82559a", bus PCI, desc "Intel i82559A Ethernet"
name "i82559b", bus PCI, desc "Intel i82559B Ethernet"
name "i82559c", bus PCI, desc "Intel i82559C Ethernet"
name "i82559er", bus PCI, desc "Intel i82559ER Ethernet"
name "i82562", bus PCI, desc "Intel i82562 Ethernet"
name "i82801", bus PCI, desc "Intel i82801 Ethernet"
name "ne2k_isa", bus ISA
name "ne2k_pci", bus PCI
name "pcnet", bus PCI
name "rocker", bus PCI, desc "Rocker Switch"
name "rtl8139", bus PCI
name "tulip"
name "usb-bt-dongle", bus usb-bus
name "usb-net", bus usb-bus
name "virtio-net-device", bus virtio-bus
name "virtio-net-pci", bus PCI, alias "virtio-net"
name "virtio-net-pci-non-transitional", bus PCI, alias "virtio-net"
name "virtio-net-pci-transitional", bus PCI, alias "virtio-net"
name "vmxnet3", bus PCI, desc "VMWare Paravirtualized Ethernet v3"
```

`-e VIDEO none`
> Choose video type; options are spice, vnc, none and "". Default value is none.

`-e GPU none`
> Choose GPU type; the only options are gvt, and "". Default value is none.

`-e VNC none`
> Enable VNC console access; options are tcp, none, reverse, socket and "". Default value is none. See https://qemu.weilnetz.de/doc/

`-e VNC_IP ""`
> When environment variable VNC is tcp this value can be set of left blank to represent 0.0.0.0. Default value is "".

`-e VNC_ID 0`
> VNC ID number it is referring to port number.  Environment variable VNC_PORT + VNC_ID.  Default value is 0 effectively giving you port 5900.

`-e VNC_PORT 5900`
> VNC port base.  Default value is 5900.

`-e VNC_SOCK /var/run/kvmvideo/vnc.sock`
> VNC socket location.  Default value is /var/run/kvmvideo/vnc.sock.  Please remember to volume bind /var/run/kvmvideo/ externally so you can use socket function.

`-e SPICE_IP 127.0.0.1`
> Spice IP Address to listen on.  Default value is 127.0.0.1.

`-e SPICE_PORT 5900`
> Spice port to listen on.  Default value is 5900.

`-e SPICE_SOCK /var/run/kvmvideo/spice.sock`
> SPICE socket location.  Default value is /var/run/kvmvideo/spice.sock.  Please remember to volume bind /var/run/kvmvideo/ externally so you can use socket function.

`-e SPICE_OPTIONS ""`
> Custom Spice server options.  Default value is "".  Fastest graphics acceleration is 'gl=on,unix,addr=/run/vm.sock,disable-ticketing -device virtio-vga,virgl=on'.

`-e TCP_PORTS ""`
> When environment variable NETWORK is to user you can forward TCP ports from the host to the internal network port of the VM. This is a comma delimetted list of ports. Default value is "".

`-e UDP_PORTS ""`
> When environment variable NETWORK is to user you can forward UDP ports from the host to the internal network port of the VM. This is a comma delimetted list of ports. Default value is "".

`-e ADD_FLAGS ""`
> These are additional custom qemu flags you can add.