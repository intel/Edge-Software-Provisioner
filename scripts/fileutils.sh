#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

# This file contains functions and global variables intended to make
# file management easier within this application's scripts.

# If running this file alone, uncomment these lines
# source "textutils.sh"
# source "yamlparse.sh"

# These are helper variables to quickly identify where things will be stored
# These variables are used globally throughout this application's scripts
export WEB_ROOT="$(pwd)/data/usr/share/nginx/html"
export WEB_FILES="${WEB_ROOT}/files"
export WEB_PROFILE="${WEB_ROOT}/profile"
export TFTP_ROOT="$(pwd)/data/srv/tftp"
export TFTP_IMAGES="${TFTP_ROOT}/images"
export TEMPLATE_FILES="$(pwd)/template"
export EMBEDDED_FILES="$(pwd)/data/embedded"

parseConfig() {
    local builderConfig="conf/config.yml"
    if [[ -f ${builderConfig} ]]; then
        # the file exists, go ahead and try to parse it
        # printDatedOkMsg "Found Profile, parsing..."
        logOkMsg "Found builderConfig, parsing..."
        # Parse the config.yml config file
        source "scripts/yamlparse.sh"
        eval $(yamlParse "${builderConfig}" "builder_config_")
        printDatedOkMsg "Loaded config successfully."
        logOkMsg "Loaded config successfully."
    else
        printDatedErrMsg "Can't find configuration in ${builderConfig}"
        logFatalErrMsg "Can't find configuration in ${builderConfig}"
        exit 1
    fi
}

# Cleans up backup files that are identical.
# The pattern is defined in copySampleFile, and looks like this:
# someFileName_2019-03-19_11:34:47
cleanDuplicateBackups() {
    local sourceFile=$1
    local targetFile=$2

    # Unbound variable error needs to be temporarily ignored
    set +u
    declare -A fileArray

    # The globstar option allows recursive directory printing
    # when using **
    # shopt -s globstar

    # for file in **; do
    for file in $( find template/ -type f | grep ${sourceFile} | grep -v modified ); do
        # If the file does not exist, continue the loop
        [[ -f "${file}" ]] || continue

        # We don't want to aggressively delete everything,
        # so this filters out any files that were matched by **
        # but don't match the backup file naming convention's pattern.
        echo ${file} | grep -q "${targetFile}_*-*-*_*:*:*" || continue

        # Proceed to md5sum
        read checkSum _ < <(md5sum "${file}")
        if ((fileArray[${checkSum}]++)); then
            rm ${file}
            logOkMsg "cleaned up duplicate backup file ${file}"
        fi
    done

    for file in $( find data/etc/ -type f | grep ${sourceFile} | grep -v modified ); do
        # If the file does not exist, continue the loop
        [[ -f "${file}" ]] || continue

        # We don't want to aggressively delete everything,
        # so this filters out any files that were matched by **
        # but don't match the backup file naming convention's pattern.
        echo ${file} | grep -q "${targetFile}_*-*-*_*:*:*" || continue

        # Proceed to md5sum
        read checkSum _ < <(md5sum "${file}")
        if ((fileArray[${checkSum}]++)); then
            rm ${file}
            logOkMsg "cleaned up duplicate backup file ${file}"
        fi
    done

    for file in $( find data/srv/ -type f | grep ${sourceFile} | grep -v modified ); do
        # If the file does not exist, continue the loop
        [[ -f "${file}" ]] || continue

        # We don't want to aggressively delete everything,
        # so this filters out any files that were matched by **
        # but don't match the backup file naming convention's pattern.
        echo ${file} | grep -q "${targetFile}_*-*-*_*:*:*" || continue

        # Proceed to md5sum
        read checkSum _ < <(md5sum "${file}")
        if ((fileArray[${checkSum}]++)); then
            rm ${file}
            logOkMsg "cleaned up duplicate backup file ${file}"
        fi
    done

    # Unset the globstar option because it could break other stuff.
    # shopt -u globstar
    set -u
}

# Will check if the target file already exists, and take a backup if it does
copySampleFile() {
    local sourceFile=$1
    local targetFile=$2

    # Check if the target file exists and take a backup if it does
    if [[ "${SKIP_BACKUPS}" == "false" ]]; then
        if [[ -f "${targetFile}" ]]; then
            local BACKUP_TIME=$(date +"%F_%T")
            local BACKUP_FILE="${targetFile}_${BACKUP_TIME}"
            set +e
            logMsg  "$(cp ${targetFile} ${BACKUP_FILE} 2>&1)"
            set -e
            if [ $? -eq 0 ]; then
                logOkMsg "backed up ${targetFile} to ${BACKUP_FILE}"
            else
                logErrMsg "problem backing up ${targetFile} to ${BACKUP_FILE}"
                exit 1
            fi
        fi
    else
        logMsg "User chose to skip backing up files (was going to copy ${sourceFile} to ${targetFile})"
    fi

    set  +e
    logMsg "$(cp ${sourceFile} ${targetFile} 2>&1)"
    set -e
    if [ $? -eq 0 ]; then
        logOkMsg "copied ${sourceFile} to ${targetFile}"
    else
        logErrMsg "problem copying ${sourceFile} to ${targetFile}"
        exit 1
    fi

    cleanDuplicateBackups ${sourceFile} ${targetFile}
}

# Will look for a given Directory, and create it if it doesn't exist
makeDirectory() {
    local desired=$1
    # make sure that the directory exists
    if [ ! -d ${desired} ]; then
        # the directory doesn't exist, make it
        mkdir -p ${desired}
        if [ $? -ne 0 ]; then
            # there was a problem creating the directory
            printDatedErrMsg "problem creating '${desired}'"
            logErrMsg "problem creating '${desired}'"
            exit 1
        else
            logOkMsg "made ${desired}"
        fi
    else
        logOkMsg "found '${desired}'"
    fi
}

downloadPrivateDockerImage() {
    local registry=$1
    local username=$2
    local password=$3
    local sourceName=$4
    local targetName=$5
    local destinationFile=$6
    local dockerAlreadyLoggedIn=$7  # Default is empty; if anything else, it will not log in

    # make sure the destinationDirectory exists
    makeDirectory $(dirname "${destinationFile}")

    # Note if we have the image already
    docker inspect ${targetName} >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        # we already have the image so skip it
        logMsg "Desired image ${targetName} exists${T_RESET}"
        printMsg "${T_OK_ICON} Desired image ${targetName} exists${T_RESET}"
    fi

    # check if dockerAlreadyLoggedIn is set
    # This is used for custom logins to a Docker registry,
    # for example, the output of:
    # aws ecr get-login --registry-id xxxxxxxx | sed "s/\-e\ none//g"
    if [[ -z "${dockerAlreadyLoggedIn}" ]]; then
        # login to the registry
        # printMsg "${T_INFO_ICON} ${C_GRAY}Login to registry ${registry}..."
        logMsg "Login to registry ${registry}..."
        # this is potentially a long running process, show the spinner
        run "Login to registry ${registry}..." \
            "docker login -u ${username} -p ${password} ${registry}" \
            ${LOG_FILE}
    fi

    if [ $? -eq 0 ]; then
        # pull the image
        printMsg "${T_INFO_ICON} ${C_GRAY}Logged in to registry, pulling image... ${T_RESET}"
        logMsg "Logged in to registry, pulling image.. ${sourceName}..."
        # this is potentially a long running process, show the spinner
        run "Downloading ${registry}/${sourceName}" \
            "docker pull ${registry}/${sourceName}" \
            ${LOG_FILE}

        if [ $? -eq 0 ]; then
            # re-tag the image with the given target name
            logMsg "Pulled image, re-tag and save as ${targetName}..."

            # this is potentially a long running process, show the spinner
            run "Pulled image, re-tag and save as ${targetName}..." \
                "docker tag ${registry}/${sourceName} ${targetName} >/dev/null 2>&1 && \
                docker save ${targetName} | gzip >${destinationFile} && \
                printMsg "${T_OK_ICON} Success save ${sourceName} as ${targetName} in ${destinationFile} ${T_RESET}" && \
                logMsg "Success save ${sourceName} as ${targetName} and put in ${destinationFile}" " \
                ${LOG_FILE}
        else
            printDatedErrMsg "Problem pulling ${sourceName} from registry ${registry}"
            logMsg "ERROR Problem pulling ${sourceName} from registry ${registry}"
            exit 1
        fi
    else
        printDatedErrMsg "Problem on login to registry ${registry}"
        logMsg "ERROR Problem on login to registry ${registry}"
        exit 1
    fi
}

downloadPublicDockerImage() {
    local sourceName=$1
    local targetName=$2
    local destinationFile=$3

    # make sure the destinationDirectory exists
    makeDirectory $(dirname "${destinationFile}")

    # Note if we have the image already
    docker inspect ${targetName} >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        # we already have the image so skip it
        logMsg "Desired image ${targetName} exists${T_RESET}"
        printMsg "${T_OK_ICON} Desired image ${targetName} exists${T_RESET}"
    fi

    # pull the image
    # this is potentially a long running process, show the spinner
    run "Downloading ${sourceName}" \
        "docker pull ${sourceName}" \
        ${LOG_FILE}

    if [ $? -eq 0 ]; then
        # re-tag the image with the given target name
        logMsg "Pulled image, re-tag and save as ${targetName}..."

        # this is potentially a long running process, show the spinner
        run "Pulled image, re-tag and save as ${targetName}..." \
            "docker tag ${sourceName} ${targetName} >/dev/null 2>&1 && \
                docker save ${targetName} | gzip >${destinationFile} && \
                printMsg "${T_OK_ICON} Success save ${sourceName} as ${targetName} in ${destinationFile} ${T_RESET}" && \
                logMsg "Success save ${sourceName} as ${targetName} and put in ${destinationFile}" " \
            ${LOG_FILE}
    else
        printDatedErrMsg "Problem pulling ${sourceName}"
        logMsg "ERROR Problem pulling ${sourceName}"
        exit 1
    fi
}

downloadBaseOSFile() {
    local message=$1
    local url=$2
    local profileName=$3
    local filename=$4
    local target_dir="/srv/tftp/images/${profileName}"

    run "${message}" \
        "docker run --rm ${DOCKER_RUN_ARGS} -v ${TFTP_IMAGES}/${profileName}:/tmp/files -w /tmp/files builder-wget wget ${url} -c -O ${filename}" \
        ${LOG_FILE}
}

downloadPublicFile() {
    local message=$1
    local source=$2
    local directory=$3
    local fileName=$4
    local token=$5

    if [[ -z "${token}" || ${token} == "None" ]]; then
        # If the token is not given, don't supply any token headers
        run "${message}" \
            "docker run --rm ${DOCKER_RUN_ARGS} -v ${directory}:/tmp/files -w /tmp/files builder-wget wget ${source} -c -O ${fileName}" \
            ${LOG_FILE}
    else
        # The token is defined, so supply the token headers
        run "${message}" \
            "docker run --rm ${DOCKER_RUN_ARGS} -v ${directory}:/tmp/files -w /tmp/files builder-wget wget --header 'Authorization: token ${token}' ${source} -c -O ${fileName}" \
            ${LOG_FILE}
    fi
}

downloadS3File() {
    local message=$1
    local region=$2
    local accessKey=$3
    local secretKey=$4
    local bucket=$5
    local key=$6 # aka object
    local directory=$7
    local fileName=$8

    local workingdir=$(pwd)

    AWS_DEFAULT_REGION=${region} \
    AWS_ACCESS_KEY_ID=${accessKey} \
    AWS_SECRET_ACCESS_KEY=${secretKey} \
    run "${message}" \
        "docker run --rm ${DOCKER_RUN_ARGS} --env AWS_ACCESS_KEY_ID=${accessKey} --env AWS_SECRET_ACCESS_KEY=${secretKey} --env AWS_DEFAULT_REGION=${region} -v ${directory}:/tmp/files builder-aws-cli aws s3api get-object --bucket ${bucket} --key ${key} /tmp/files/${fileName}" \
        ${LOG_FILE}
}

mountISO() {
    local iso=$1
    local mount_path=$2

    mkdir -p ${mount_path}

    if RESULT=$(mount -o loop ${iso} ${mount_path} 2>&1); then
        printDatedMsg "  Mounted $(basename ${iso})"
        logMsg "Mounted ${iso} to ${mount_path}"
    else
        printDatedMsg "  ERROR: Failed to mount $(basename ${iso}), see builder.log."
        logMsg "ERROR: Failed to mount ${iso} to ${mount_path} with the following error: ${RESULT}"
    fi
}

umountAllISO() {
    local mount_path=$1
    
    for path in $(cat /proc/mounts | grep ${mount_path} | awk '{print $2}'); do  
        # printDatedMsg "  Unmounting: ${path}"
        logMsg "umount: ${path}"
        umount ${path}
    done
}

mirrorGitRepo() {
    local url=$1
    local branch=$2
    local username=$3
    local token=$4
    local args=$5
    local repo_name=$6
    local profile_name=$7

    local workingdir=./tmp_repo
    mkdir -p ${workingdir}

    local ourl=${url}
    if [ -z "${username}" ]; then
        local auth="${username}:${token}@"
        local url=$(echo ${url} | sed "s#http://#http://${auth})#" | sed "s#https://#https://${auth}#")
    fi

    if [ -z "${branch}" ]; then
        local branch="master"
    fi

    if [ -z "${repo_name}" ]; then
        local repo_name=$(echo $(basename $url) | sed 's#\.git##')
    fi

    if [ -z "${args}" ]; then
        local args="--depth=1"
    fi

    if curl --head --silent --fail http://mirror:mirror@${builder_config_host_ip}:3003/mirror/${profile_name}___${repo_name}/raw/branch/master/README.md > /dev/null; then
        local message="  Updating mirror ${ourl}"
        run "${message}" \
            "cd ${workingdir} && \
            git clone ${args} -b ${branch} ${url} ${repo_name} && \
            cd - && cd ${workingdir}/${repo_name} && \
            rm -fr .git/ && \
            cd ../ && \
            git clone http://mirror:mirror@${builder_config_host_ip}:3003/mirror/${profile_name}___${repo_name}.git && \
            docker run -t --rm -v $(pwd):/work alpine sh -c 'apk update && apk add --no-cache rsync && \
            cd work/ && \
            rsync -rtc --stats --progress --exclude=.git/ ${repo_name}/ ${profile_name}___${repo_name}/' && \
            cd ${profile_name}___${repo_name}/ && \
            git add . && \
            git commit -m 'mirror'; \
            git push" \
            ${LOG_FILE}
    else
        local message="  Mirroring ${ourl}"
        run "${message}" \
            "cd ${workingdir} && \
            git clone ${args} -b ${branch} ${url} ${repo_name} && \
            cd - && cd ${workingdir}/${repo_name} && \
            rm -fr .git/ && \
            git init && \
            git add . && \
            git commit -m \"mirror\" && \
            git remote add origin http://mirror:mirror@${builder_config_host_ip}:3003/mirror/${profile_name}___${repo_name} && \
            git push -u origin master" \
            ${LOG_FILE}
    fi
    run "  Cleaning temporary repo files" \
        "rm -fr ${workingdir}" \
        ${LOG_FILE}
}

processBuild() {
    local container=$1
    local entrypoint=$2
    local cmd=$3
    local profile_name=$4
    # local container_name=$( echo "builder_$profile_name" | sed -r 's#[:/]#-#g')
    local container_name="build"
    local i=0

    mkdir -p ${WEB_FILES}/${profile_name}/build
    mkdir -p ${EMBEDDED_FILES}/${profile_name}

    if [ -d ${WEB_PROFILE}/${profile_name}_base/build ]; then
        local BASE_BIND="-v ${WEB_PROFILE}/${profile_name}_base/build:/opt/base"
    else
        local BASE_BIND=""
    fi

    if [ ! -z "${entrypoint}" ]; then
        local ENTRYPOINT_CLI="--entrypoint='${entrypoint}'"
    else
        local ENTRYPOINT_CLI=""
    fi

    local message="  Running Build process, this could take a very long time.  In another terminal run 'docker logs ${container_name} -f' to watch progress."
    run "${message}" \
        "docker rm -f build-docker > /dev/null 2>&1; \
        docker run -d --privileged --name build-docker ${DOCKER_RUN_ARGS} -v $(pwd)/data/tmp/build:/var/run -v $(pwd)/data/lib/docker:/var/lib/docker docker:19.03.12-dind && \
        sleep 7 && docker restart build-docker && \
        echo 'Waiting for Docker'; \
        i=0; \
        while (! docker -H unix:///$(pwd)/data/tmp/build/docker.sock ps ); do 
            i=$((i+1)); \
            echo -n '.'; \
            sleep 0.5; \
            if [ $i -eq 20 ]; then docker restart build-docker; fi; \
            if [ $i -eq 40 ]; then docker restart build-docker; fi; \
            if [ $i -eq 60 ]; then echo 'build-docker will not start.  Please review docker logs build-docker.  Run this build again will sometimes fix the problem.'; false; exit; fi; \
        done; \
        echo 'ready' && \
        docker run --rm --privileged --name ${container_name} ${DOCKER_RUN_ARGS} --env DOCKER_RUN_ARGS='${DOCKER_RUN_ARGS}' ${ENTRYPOINT_CLI} \
            -v /run/docker.sock:/opt/run/sys.sock \
            -v $(pwd)/data/tmp/build:/var/run \
            -v $(pwd)/data/persist:/opt/persist \
            ${BASE_BIND} \
            -v ${WEB_PROFILE}/${profile_name}/build:/opt/build \
            -v ${WEB_FILES}/${profile_name}/build:/opt/output:shared \
            -v ${EMBEDDED_FILES}/${profile_name}:/opt/embedded \
            ${container} ${cmd}; \
        echo 'Finished with build, Cleaning up build docker container...'; \
        docker rm -f build-docker > /dev/null 2>&1 || true; \
        docker rm -f ${container_name} > /dev/null 2>&1|| true" \
        ${LOG_FILE}
}

processEmbedded() {
    local profile_name=$1
    local uos_profile_path=${TFTP_IMAGES}/uos/${profile_name}

    mkdir -p ${uos_profile_path}
    mkdir -p ${WEB_PROFILE}/${profile_name}
    mkdir -p ${EMBEDDED_FILES}/${profile_name}
    cp ${TFTP_IMAGES}/uos/initrd ${uos_profile_path}/

    local message="  Embedding files into uOS.  In another terminal run 'docker logs esp_embedding -f' to watch progress."
    run "${message}" \
        "docker run --rm --privileged --name esp_embedding ${DOCKER_RUN_ARGS} \
            -v ${uos_profile_path}:/opt/images \
            -v ${WEB_PROFILE}/${profile_name}/embedded:/opt/profile_embedded \
            -v ${EMBEDDED_FILES}/${profile_name}:/opt/embedded \
            alpine:3.12 sh -c 'apk update && \
                apk add rsync gzip && \
                mkdir -p prep/ && \
                cd prep/ && \
                gunzip -c < /opt/images/initrd | cpio -i -d 2> /dev/null || true && \
                rsync -rtc /opt/profile_embedded/ ./ && \
                rsync -rtc /opt/embedded/ ./ && \
                find . | cpio -H newc -o | gzip > /opt/images/initrd' \
        echo 'Finished with embedding files into uOS, Cleaning up build docker container...'; \
        docker rm -f esp_embedding > /dev/null 2>&1 || true" \
        ${LOG_FILE}
}
