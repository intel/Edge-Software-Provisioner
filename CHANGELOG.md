# Change Log
All notable changes to this project will be documented in this file.
 
The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased][1.0.0] - 2019-04-24
### Initial internal publication
- An easy way to provision target systems that are bare metal or virtual machines using a just-in-time provisioning process over PXE

## [1.2.0] - 2020-04-01
### Added
- Created a proper README.md file
- Samba service is now availble to allow Windows Profiles to mount ESP directory
- Introduced Edge Software Provisioner Utility Operating System called ESP UOS
- Now automatically detects network settings if omitted in conf/config.yml

### Changed
- Updated error handling

## [1.3.0] - 2020-11-04
### Added
- Bash yaml parsing
- ISO PXE Booting

### Changed
- Fixed Samba mmounting 
- Set the Linuxkit version to v0.8

## [1.5.0] - 2021-01-26
### Added
- Rebranded product name
- In-line caching of RPMs, DEBs, TAR and other package management applications
- You can now pre-build certain tasks, for example compile a kernel or mirror a repo on ESP
- Mirroring GitHub repos on ESP
- Virtual PXE - can test profiles or create VMs directly in ESP.  Can be used in a Jenkins pipeline for testing ESP Profiles
- Added multiple kernel support
- Input validation types for profile configuration

### Changed
- Improved Nginx and web services
- Improved UOS
- Kernel version
- Error handling to console
- README.md
- Improved UOS process
- Fixed ISO mounting and unmounting
- Improved support for different system BIOS and uEFI

## [1.5.1] - 2021-02-09
### Added
- Let's Encrypt to generate public certificates
- Introduced TLS for all ESP services

### Changed
- Fixed miscellaneous bugs

## [1.6.0] - 2021-02-09
### Added
- Ability to change kernel from different Linux distros, defaults to Clear Linux
- Proxy support to docker-compose.yml
- Github mirror to docker-compose.yml
- Podman support for Red Hat

### Changed
- Gitea is built during the build.sh process instead of run.sh
- Default config.yml to latest LTS Ubuntu
- Fixed miscellaneous bugs

## [1.6.1] - 2021-05-27
### Changed
- UOS now ignores self-signed certificate on ESP
- Gitea startup processes

## [1.6.2] - 2021-06-30
### Changed
- UOS Display  name
- login support to UOS when there is an error

## [2.0.0] - 2021-08-27
### Added
- Create Bootable USB to provision devices with no PXE support or ethernet. See “Bootable USB” in the README.md.
- Flash USB Utility to protect from overwriting the wrong drive.
- Utility OS has been rebranded to Micro OS – uOS.
- uOS now supports WiFI and Mobile Cell phone network deployments.
- TLS encryption enabled using self-signed certificate including optional Let’s Encrypt for Web Services.
- All other services except PXE Boot are TLS enabled.
- New ESP one line start command; instead of having to build ESP container images every install, you can start ESP from a single command line. See step 8 of “Quick Installation Guide” in the README.md.
- ESP Core service now monitors for config.yml file changes and automatically runs build.sh command when a change occurs
- ESP supports the ability to provision target devices while being disconnected from the internet.
- Ubuntu Profile now supports config.yml variables network=[default|bridged|network-manager], wifissid= and wifipsk=
- Ubuntu Profile will now search for a Debian mirror on ESP to pull packages directly.
- Virtual PXE now supports building VMs inside a container for distribution and execution on Docker. See ./vpxe.sh -h

### Changed
- uOS Kernel Selection – you can now choose different kernels for the uOS kernel. See ./build.sh -h
- Updated Podman to support network proxies
- Fixed miscellaneous bugs

## [2.0.1] - 2021-10-08
### Added
- "--skip-memory" to makeusb.sh to skip memory check for systems with small off memory.

### Changed
- Fixed typo in the help
- Fixed build ESP containers behind proxy
- Upgraded container base version of nginx, gitea, core and certbot to address CVEs
- Fixed Docker-in-Docker /dev/null deletion on build failing behind proxy
- Fixed detection of failure of docker-builder program to restart
- Fixed makeusb.sh creating legacy BIOS USB images not booting correctly in QEMU
- Fixed squid caching of Linux distro packages
- Fixed miscellaneous bugs

## [2.0.2] - 2021-10-12
### Changed
- Fixed Certbot cert renewal detection
- Fixed Gitea database initialization
- Fixed Podman run for Gitea
- Fixed Podman run for Certbot

## [2.0.3] - 2021-11-19
### Added
- Environment variable for NO_PROXY during build.sh
- Ability to specify Git TAG Names for branches in config.yml

### Changed
- Fixed /dev/null being deleted
- Fixed CVE is in Dockerfiles
- Fixed missing DOCKER_RUN_ARGS
- Fixed Miscellaneous typos

## [2.5.0] - 2022-06-17
### Added
- Dynamic Profiles - The Dynamic Profile feature allows ESP to install software on a target machine without any user interaction.  See https://github.com/intel/Edge-Software-Provisioner#dynamic-profile
- Build Red Hat kernels into ESP uOS using Podman.  See ./build.sh -k
- Now can designate the interface ESP to listen on for all DHCP requests.  See https://github.com/intel/Edge-Software-Provisioner/blob/master/conf/config.yml
- Signed Kernels and Secure Boot ESP uOS will be released in the next version
- Can dynamically inject secretes using environment variables.  See https://github.com/intel/Edge-Software-Provisioner/blob/master/conf/secrets.sample.yml
- Additional support for air-gapped environments
- The ability to resume an ESP Profile deployment after failure instead of starting all over.  To enable, add kernel parameter "resume=true" in the profile config.yml
- Can specify an ethernet interface for ESP to listen on when running on system with more than one ethernet interface. See https://github.com/intel/Edge-Software-Provisioner/blob/master/conf/config.yml

### Changed
- Updated all kernels to 5.17 and introduced an Intel kernel for latest hardware
- Fixed missing /dev/null when Docker cleans up mounts
- Proxy problems fixed - missing "no_proxy" values were not being passed to all containers
- Ensure previously mounted ISO images are properly unmounted
- Fixed Nginx bugs that stopping bootstrapping in different situations
- Enhanced Code Quality

### Known Issue
- Virtual PXE (vpxe.sh) may cause a kernel panic under a nested VM.  Work around is to build a different kernel.  For example, `./build.sh -k ubuntu -P`




[1.5.1]: https://github.com/intel/Edge-Software-Provisioner/compare/v1.5...v1.5.1
[1.6.0]: https://github.com/intel/Edge-Software-Provisioner/compare/v1.5.1...v1.6
[1.6.1]: https://github.com/intel/Edge-Software-Provisioner/compare/v1.6...v1.6.1
[1.6.2]: https://github.com/intel/Edge-Software-Provisioner/compare/v1.6.1...v1.6.2
[2.0.0]: https://github.com/intel/Edge-Software-Provisioner/compare/v1.6.2...v2.0
[2.0.1]: https://github.com/intel/Edge-Software-Provisioner/compare/v2.0...v2.0.1
[2.0.2]: https://github.com/intel/Edge-Software-Provisioner/compare/v2.0.1...v2.0.2
[2.0.3]: https://github.com/intel/Edge-Software-Provisioner/compare/v2.0.2...v2.0.3
[2.5.0]: https://github.com/intel/Edge-Software-Provisioner/compare/v2.0.3...v2.5