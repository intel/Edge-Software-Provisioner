#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

# This file contains the logic for managing profiles.

# If running this file alone, uncomment these lines
# source "textutils.sh"
# source "fileutils.sh"
# source "bulkfileutils.sh"
# source "yamlparse.sh"

parseProfileFilesYml() {
    local configFile=$1
    eval $(yamlParse "${configFile}" "files_config_")
}

# Determine if the the files.yml config (for a profile) exists
canLoadProfileFiles() {
    local configFile=$1
    local profileName=$2
    if [[ -f ${configFile} ]]; then
        logOkMsg "Profile ${profileName} has a conf/files.yml"
        echo "0"
    else
        printDatedInfoMsg "Did not find ${configFile} for profile ${profileName}"
        logInfoMsg "Did not find ${configFile} for profile ${profileName}"
        # we couldn't find the file so return error
        echo "1"
    fi
}

cloneProfile() {
    local git_remote_url=$1
    local git_branch_name=$2
    local git_base_branch_name=$3
    local git_username=$4
    local git_token=$5
    local name=$6
    local base_name=${name}_base
    local custom_git_arguments=$7
    local iteration=$8

    custom_git_arguments=$(validateEmptyInput ${custom_git_arguments})
    git_username=$(validateEmptyInput ${git_username})
    git_token=$(validateEmptyInput ${git_token})

    local git_clone_target="${git_remote_url}"

    if [[ "${git_token}" != "" && "${git_username}" != "" ]]; then
	    if [[ "${git_remote_url}" == "https://"* ]]; then
            logInfoMsg "Clone - Git commands using HTTPS Protocol"
            git_clone_target=$(echo "${git_remote_url}" | sed "s#https://#https://${git_username}:${git_token}@#g")
        elif [[ "${git_remote_url}" == "http://"* ]]; then
            logInfoMsg "Clone - Git commands using HTTP Protocol"
            git_clone_target=$(echo "${git_remote_url}" | sed "s#http://#http://${git_username}:${git_token}@#g")
        fi
    fi

    mkdir -p ${WEB_PROFILE}/${name}

    if [ -d ${WEB_PROFILE}/${name}/.git ]; then
        local git_current_remote_url=$(docker run --rm ${DOCKER_RUN_ARGS} -v ${WEB_PROFILE}/${name}:/tmp/profiles -w /tmp/profiles builder-git git remote get-url --all origin)
        local git_current_branch_name=$(docker run --rm ${DOCKER_RUN_ARGS} -v ${WEB_PROFILE}/${name}:/tmp/profiles -w /tmp/profiles builder-git git rev-parse --abbrev-ref HEAD)
        if [ "${git_clone_target}" != "${git_current_remote_url}" ] || [ "${git_branch_name}" != "${git_current_branch_name}" ]; then
            logMsg "Clone - Detected a configuration change in either the git remote or the git branch for the ${name} profile. Will re-create the repository from scratch in order to avoid git tree issues."
            rm -rf  ${WEB_PROFILE}/${name}
        fi
    fi

    if [ ! -d ${WEB_PROFILE}/${name}/.git ]; then
        if [ -n "${SSH_AUTH_SOCK-}" ]; then
            local docker_ssh_args="-v ${SSH_AUTH_SOCK}:/ssh-agent"
            logInfoMsg "Clone - Git authentication found SSH-Agent."
        fi

        if  [ -n "${git_token}" ] && [ -n "${git_username}" ]; then
            if [[ ${git_remote_url} == "git@"* ]]; then
                printAndLogDatedErrMsg "Clone - Git user/token was detected despite the use of SSH protocol in git_remote_url '${git_remote_url}'. Please use HTTPS if using Git user/token."
                exit 1
            fi
            logInfoMsg "Clone - Git authentication found Git user/token."
        fi

        if [ ! -n "${git_token}" ] && [ ! -n "${git_username}" ] && [ ! -n "${SSH_AUTH_SOCK-}" ]; then
            logInfoMsg "Clone - No Git authentication method found (git_username/git_token, or SSH-Agent)."
        fi

        run "  ${C_GREEN}${name}${T_RESET}: Cloning branch ${git_branch_name} on repo ${git_remote_url} with ssh-agent" \
            "docker run --rm --privileged ${DOCKER_RUN_ARGS} ${docker_ssh_args-} -v ${WEB_PROFILE}:/tmp/profiles -w /tmp/profiles builder-git git clone ${custom_git_arguments} -v --progress ${git_clone_target} --branch=${git_branch_name} ${name}" \
            ${LOG_FILE}
    else
        printDatedMsg "  Clone - ${C_GREEN}${name}${T_RESET} already exists."
        logOkMsg "Clone - ${name} already exists."
    fi

    if [[ $(validateEmptyInput "${git_base_branch_name}") == "" ]]; then
        printDatedMsg "  Clone - ${C_GREEN}${name}${T_RESET} doesn't have any base profile."
    else
        mkdir -p ${WEB_PROFILE}/${base_name}
        if [ -d ${WEB_PROFILE}/${base_name}/.git ]; then
            local git_current_remote_url=$(docker run --rm --privileged ${DOCKER_RUN_ARGS} -v ${WEB_PROFILE}/${base_name}:/tmp/profiles -w /tmp/profiles builder-git git remote get-url --all origin)
            local git_current_branch_name=$(docker run --rm --privileged ${DOCKER_RUN_ARGS} -v ${WEB_PROFILE}/${base_name}:/tmp/profiles -w /tmp/profiles builder-git git rev-parse --abbrev-ref HEAD)
            if [ "${git_clone_target}" != "${git_current_remote_url}" ] || [ "${git_base_branch_name}" != "${git_current_branch_name}" ]; then
                logMsg "Clone - Detected a configuration change in either the git remote or the git branch for the ${base_name} profile. Will re-create the repository from scratch in order to avoid git tree issues."
                rm -rf  ${WEB_PROFILE}/${base_name}
            fi
        fi

        if [ ! -d ${WEB_PROFILE}/${base_name}/.git ]; then
            if [ -n "${SSH_AUTH_SOCK-}" ]; then
                local docker_ssh_args="-v ${SSH_AUTH_SOCK}:/ssh-agent"
                printAndLogDatedInfoMsg "Clone - Git authentication found SSH-Agent."
            fi

            if  [ -n "${git_token}" ] && [ -n "${git_username}" ]; then
                if [[ ${git_remote_url} == "git@"* ]]; then
                    printAndLogDatedErrMsg "Clone - Git user/token was detected despite the use of SSH protocol in git_remote_url '${git_remote_url}'. Please use HTTPS if using Git user/token."
                    exit 1
                fi
                logInfoMsg "Clone - Git authentication found Git user/token."
            fi

            if [ ! -n "${git_token}" ] && [ ! -n "${git_username}" ] && [ ! -n "${SSH_AUTH_SOCK-}" ]; then
                logInfoMsg "Clone - No Git authentication method found (git_username/git_token, or SSH-Agent)."
            fi
            run "  ${C_GREEN}${base_name}${T_RESET}: Cloning branch ${git_base_branch_name} on repo ${git_remote_url}" \
                "docker run --rm --privileged ${DOCKER_RUN_ARGS} ${docker_ssh_args-} -v ${WEB_PROFILE}:/tmp/profiles -w /tmp/profiles builder-git git clone ${custom_git_arguments} -v --progress ${git_clone_target} --branch=${git_base_branch_name} ${base_name}" \
                ${LOG_FILE}
        else
            printDatedMsg "  Clone - ${C_GREEN}${base_name}${T_RESET} already exists."
            logOkMsg "Clone - ${base_name} already exists."
        fi
    fi
}

resetProfile() {
    # Not all of these arguments may be used by this function, but this
    # follows a consistent format. See the "profilesActions" function
    local git_remote_url=$1
    local git_branch_name=$2
    local git_base_branch_name=$3
    local git_username=$4
    local git_token=$5
    local name=$6
    local base_name=${6}_base
    local custom_git_arguments=$7
    local iteration=$8

    custom_git_arguments=$(validateEmptyInput ${custom_git_arguments})
    git_username=$(validateEmptyInput ${git_username})
    git_token=$(validateEmptyInput ${git_token})

    local git_clone_target=$(echo ${git_remote_url} | sed "s#https://#https://${git_username}:${git_token}@#g")

    if [ -d ${WEB_PROFILE}/${name}/.git ]; then
        run "  ${C_GREEN}${name}${T_RESET}: Resetting branch ${git_branch_name}" \
            "docker run --rm --privileged ${DOCKER_RUN_ARGS} -v ${WEB_PROFILE}/${name}:/tmp/profiles/${name} -w /tmp/profiles/${name} builder-git git reset --hard HEAD" \
            ${LOG_FILE}
    else
        printDatedMsg "Profile ${C_GREEN}${name}${T_RESET} either is improperly configured or does not exist."
        printDatedMsg "Unable to reset it."
        printDatedMsg "Please check ${WEB_PROFILE}/${name}."
    fi

    if [[ $(validateEmptyInput "${git_base_branch_name}") == "" ]]; then
        printDatedMsg "  Reset - ${C_GREEN}${name}${T_RESET} doesn't have any base profile."
    else
        if [ -d ${WEB_PROFILE}/${base_name}/.git ]; then
            run "  ${C_GREEN}${base_name}${T_RESET}: Resetting branch ${git_base_branch_name}" \
                "docker run --rm --privileged ${DOCKER_RUN_ARGS} -v ${WEB_PROFILE}/${base_name}:/tmp/profiles/${base_name} -w /tmp/profiles/${base_name} builder-git git reset --hard HEAD" \
                ${LOG_FILE}
        else
            printDatedMsg "Profile ${C_GREEN}${base_name}${T_RESET} either is improperly configured or does not exist."
            printDatedMsg "Unable to reset it."
            printDatedMsg "Please check ${WEB_PROFILE}/${base_name}."
        fi
    fi
}

pullProfile() {
    # Not all of these arguments may be used by this function, but this
    # follows a consistent format. See the "profilesActions" function
    local git_remote_url=$1
    local git_branch_name=$2
    local git_base_branch_name=$3
    local git_username=$4
    local git_token=$5
    local name=$6
    local base_name=${6}_base
    local custom_git_arguments=$7
    local iteration=$8

    custom_git_arguments=$(validateEmptyInput ${custom_git_arguments})
    git_username=$(validateEmptyInput ${git_username})
    git_token=$(validateEmptyInput ${git_token})

    git_base_branch_name=$(validateEmptyInput "${git_base_branch_name}")

    local git_clone_target=$(echo ${git_remote_url} | sed "s#https://#https://${git_username}:${git_token}@#g")

    if [ -d ${WEB_PROFILE}/${name}/.git ]; then
        if [ -n "${SSH_AUTH_SOCK-}" ]; then
            local docker_ssh_args="-v ${SSH_AUTH_SOCK}:/ssh-agent"
            logInfoMsg "Pull - Git authentication found SSH-Agent."
        fi

        if  [ -n "${git_token}" ] && [ -n "${git_username}" ]; then
            if [[ ${git_remote_url} == "git@"* ]]; then
                printAndLogDatedErrMsg "Pull - Git user/token was detected despite the use of SSH protocol in git_remote_url '${git_remote_url}'. Please use HTTPS if using Git user/token."
                exit 1
            fi
            logInfoMsg "Pull - Git authentication found Git user/token."
        fi

        if [ ! -n "${git_token}" ] && [ ! -n "${git_username}" ] && [ ! -n "${SSH_AUTH_SOCK-}" ]; then
            logInfoMsg "No Git authentication method found (git_username/git_token, or SSH-Agent)."
        fi
        run "  ${C_GREEN}${name}${T_RESET}: Pulling latest from ${git_branch_name} on repo ${git_remote_url}" \
            "docker run --rm --privileged ${DOCKER_RUN_ARGS} ${docker_ssh_args-} -v ${WEB_PROFILE}/${name}:/tmp/profiles/${name} -w /tmp/profiles/${name} builder-git sh -c 'git fetch origin ${git_branch_name} && git reset --hard ${git_branch_name} && git pull origin ${git_branch_name}'" \
            ${LOG_FILE}
    else
        printDatedErrMsg "Profile ${name} either is improperly configured or does not exist."
        printDatedErrMsg "Unable to pull latest changes from upstream."
        printDatedErrMsg "Please check ${WEB_PROFILE}/${name}."
        logErrMsg "Profile ${name} either is improperly configured or does not exist."
        logErrMsg "Unable to pull latest changes from upstream."
        logErrMsg "Please check ${WEB_PROFILE}/${name}."
        exit 1
    fi

    if [[ ${git_base_branch_name} == "" ]]; then
        printDatedMsg "  Pull - ${C_GREEN}${name}${T_RESET} doesn't have any base profile."
    else
        if [ -d ${WEB_PROFILE}/${base_name}/.git ]; then
            if [ -n "${SSH_AUTH_SOCK-}" ]; then
                local docker_ssh_args="-v ${SSH_AUTH_SOCK}:/ssh-agent"
                logInfoMsg "Pull - Git authentication found SSH-Agent."
            fi

            if  [ -n "${git_token}" ] && [ -n "${git_username}" ]; then
                if [[ ${git_remote_url} == "git@"* ]]; then
                    printAndLogDatedErrMsg "Pull - Git user/token was detected despite the use of SSH protocol in git_remote_url '${git_remote_url}'. Please use HTTPS if using Git user/token."
                    exit 1
                fi
                logInfoMsg "Pull - Git authentication found Git user/token."
            fi

            if [ ! -n "${git_token}" ] && [ ! -n "${git_username}" ] && [ ! -n "${SSH_AUTH_SOCK-}" ]; then
                logInfoMsg "Pull - No Git authentication method found (git_username/git_token, or SSH-Agent)."
            fi
            run "  ${C_GREEN}${base_name}${T_RESET}: Pulling latest from ${git_base_branch_name} on repo ${git_remote_url}" \
                "docker run --rm --privileged ${DOCKER_RUN_ARGS} ${docker_ssh_args-} -v ${WEB_PROFILE}/${base_name}:/tmp/profiles/${base_name} -w /tmp/profiles/${base_name} builder-git sh -c 'git fetch origin ${git_base_branch_name} && git reset --hard ${git_base_branch_name} && git pull origin ${git_base_branch_name}'" \
                ${LOG_FILE}
        else
            printDatedErrMsg "Profile ${base_name} either is improperly configured or does not exist."
            printDatedErrMsg "Unable to pull latest changes from upstream."
            printDatedErrMsg "Please check ${WEB_PROFILE}/${base_name}."
            logErrMsg "Profile ${base_name} either is improperly configured or does not exist."
            logErrMsg "Unable to pull latest changes from upstream."
            logErrMsg "Please check ${WEB_PROFILE}/${base_name}."
            exit 1
        fi
    fi
}

deleteProfile() {
    # Not all of these arguments may be used by this function, but this
    # follows a consistent format. See the "profilesActions" function
    local git_remote_url=$1
    local git_branch_name=$2
    local git_base_branch_name=$3
    local git_username=$4
    local git_token=$5
    local name=$6
    local base_name=${6}_base
    local custom_git_arguments=$7
    local iteration=$8

    custom_git_arguments=$(validateEmptyInput ${custom_git_arguments})
    git_username=$(validateEmptyInput ${git_username})
    git_token=$(validateEmptyInput ${git_token})

    git_base_branch_name=$(validateEmptyInput "${git_base_branch_name}")

    local git_clone_target=$(echo ${git_remote_url} | sed "s#https://#https://${git_username}:${git_token}@#g")

    if [ ! -d ${WEB_PROFILE}/${name}/.git ]; then
        printDatedOkMsg "Profile ${name} already does not exist."
        logOkMsg "Profile ${name} already does not exist."
    else
        run "Deleting profile ${name}" \
            "rm -rf ${WEB_PROFILE}/${name}" \
            ${LOG_FILE}
    fi

    if [[ ${git_base_branch_name} == "" ]]; then
        printDatedMsg "  Delete - ${C_GREEN}${name}${T_RESET} doesn't have any base profile."
    else
        if [ ! -d ${WEB_PROFILE}/${base_name}/.git ]; then
            printDatedOkMsg "Profile ${base_name} already does not exist."
            logOkMsg "Profile ${base_name} already does not exist."
        else
            run "Deleting profile ${base_name}" \
                "rm -rf ${WEB_PROFILE}/${base_name}" \
                ${LOG_FILE}
        fi
    fi
}

downloadProfile() {
    # Not all of these arguments may be used by this function, but this
    # follows a consistent format. See the "profilesActions" function
    local git_remote_url=$1
    local git_branch_name=$2
    local git_base_branch_name=$3
    local git_username=$4
    local git_token=$5
    local name=$6
    local base_name=${6}_base
    local custom_git_arguments=$7
    local iteration=$8

    custom_git_arguments=$(validateEmptyInput ${custom_git_arguments})
    git_username=$(validateEmptyInput ${git_username})
    git_token=$(validateEmptyInput ${git_token})

    printBanner "Downloading files for profile: ${C_GREEN}${name}${T_RESET}"

    # Check if we can load the profile's files.yml first.
    local foundProfileFiles=$(canLoadProfileFiles "${WEB_PROFILE}/${name}/conf/files.yml" "${name}")
    if [[ ${foundProfileFiles} == "0" ]]; then
        # Now load the profile's files.yml variables into memory.
        parseProfileFilesYml "${WEB_PROFILE}/${name}/conf/files.yml"

        # Create the profile's files directory if it doesn't exist
        makeDirectory "${WEB_FILES}/${name}"
        logInfoMsg "Files (except base OS files) for this profile will be stored under ${WEB_FILES}/${name}, and will be accessible via HTTP at http://${builder_config_host_ip}/files/${name}/destination_file"
        logInfoMsg "Base OS files for this profile will be stored under ${TFTP_IMAGES}/${name}, and will be accessible via HTTP at http://${builder_config_host_ip}/tftp/${name}/filename"

        if [[ "${SKIP_FILES}" == "true" ]]; then
            printDatedInfoMsg "User decided to skip downloading files."
            logInfoMsg "User decided to skip downloading files."
        else
            # Download all files specified in ./conf/files.yml
            printDatedMsg "(1/9) Downloading ${name} ${C_MAGENTA}Base OS Files..."
            downloadBaseOSFiles ${name}
            printDatedMsg "(2/9) Downloading ${name} ${C_MAGENTA}General Files..."
            downloadGeneralFiles ${name}
            printDatedMsg "(3/9) Downloading ${name} ${C_MAGENTA}S3 Files..."
            downloadS3Files ${name}
            printDatedMsg "(4/9) Downloading ${name} ${C_MAGENTA}Public Docker Registry Files..."
            downloadPublicDockerImages ${name}
            printDatedMsg "(5/9) Downloading ${name} ${C_MAGENTA}Private Docker Registry Files..."
            downloadPrivateDockerRegistryImages ${name}
            printDatedMsg "(6/9) Downloading ${name} ${C_MAGENTA}Docker AWS Files..."
            downloadPrivateDockerAWSImages ${name}
            printDatedMsg "(7/9) ${C_MAGENTA}Mirroring Git Repos${T_RESET} for ${name}..."
            mirrorGitRepos ${name}
            if [[ "${SKIP_PROFILE_BUILDS}" == "false" ]]; then
                printDatedMsg "(8/9) ${C_MAGENTA}Building custom files${T_RESET} for ${name}..."
                processBuilds ${name}
            else
                printDatedMsg "(8/9) Skipping building custom files for ${name}..."
                logMsg "User decided to skip the execution of profile-specific build scripts for ${name}."
            fi
            if [[ "${SKIP_PROFILE_EMBEDDED}" == "false" ]]; then
                printDatedMsg "(9/9) ${C_MAGENTA}Embedding custom files in uOS${T_RESET} for ${name}..."
                processEmbeddeds ${name}
            else
                printDatedMsg "(9/9) Skipping embedding custom files in uOS for ${name}..."
                logMsg "User decided to skip the execution of profile-specific embedding files for ${name}."
            fi
        fi
    else
        printDatedInfoMsg "This profile contains no files to download."
        logInfoMsg "This profile contains no files to download."
    fi

    logInfoMsg "Finished downloading files for ${name} profile."
}

buildProfile() {
    # Not all of these arguments may be used by this function, but this
    # follows a consistent format. See the "profilesActions" function
    local git_remote_url=$1
    local git_branch_name=$2
    local git_base_branch_name=$3
    local git_username=$4
    local git_token=$5
    local profile_name=$6
    local base_name=${6}_base
    local custom_git_arguments=$7
    local iteration=$8
    local container_name="builder"

    custom_git_arguments=$(validateEmptyInput ${custom_git_arguments})
    git_username=$(validateEmptyInput ${git_username})
    git_token=$(validateEmptyInput ${git_token})

    local commandToRun="${WEB_PROFILE}/${profile_name}/build.sh"
    if [ -f  ${commandToRun} ]; then
        printDatedMsg "  Running build.sh for profile ${C_GREEN}${profile_name}${T_RESET}"
        logInfoMsg "  Running build.sh for profile ${profile_name}"

        # we now run the build.sh and pass in the "${WEB_PROFILE}/${profile_name}/"
        # this helps if we have to figure out where our profile is stored
        # we also pass in "${WEB_FILES}/${profile_name} so that the build script
        # can download / generate files and make them available"
        if [ -d ${WEB_PROFILE}/${profile_name}_base/build ]; then
            local BASE_BIND="-v ${WEB_PROFILE}/${profile_name}_base/build:/opt/base"
        else
            local BASE_BIND=""
        fi
        returnCode=""
        local message="  Running Build process, this could take a very long time.  In another terminal run 'docker logs ${container_name} -f' to watch progress."
        run "${message}" \
            "docker rm -f builder-docker > /dev/null 2>&1; \
            docker run -t --rm --privileged --name ${container_name} --entrypoint= -v /var/run:/var/run -v /tmp:/tmp -v $(pwd)/data/persist:/opt/persist ${BASE_BIND} -v ${WEB_PROFILE}/${profile_name}:${WEB_PROFILE}/${profile_name} -v ${WEB_FILES}/${profile_name}:${WEB_FILES}/${profile_name} docker:19.03.12 sh -c 'apk add bash rsync git coreutils; ${WEB_PROFILE}/${profile_name}/build.sh ${WEB_PROFILE}/${profile_name} ${WEB_FILES}/${profile_name}'; \
            echo 'Finished with build, Cleaning up builder docker container...'; \
            docker rm -f builder-docker > /dev/null 2>&1 || true; \
            docker rm -f ${container_name} > /dev/null 2>&1|| true" \
            ${LOG_FILE}

            # docker run -d --privileged --name builder-docker ${DOCKER_RUN_ARGS} -v $(pwd)/data/tmp/builder:/var/run -v $(pwd)/data/lib/docker:/var/lib/docker docker:19.03.12-dind && \
            # echo 'Waiting for Docker'; \
            # while (! docker -H unix:///$(pwd)/data/tmp/builder/docker.sock ps > /dev/null 2>&1); do echo -n '.'; sleep 0.5; done; echo 'ready' && \

        # eval "${commandToRun}" "${WEB_PROFILE}/${profile_name}/" "${WEB_FILES}/${profile_name}" |& tee -a "${LOG_FILE}"
        returnCode=${PIPESTATUS[0]}

        if [ ${returnCode} -eq 0 ]; then
            printDatedOkMsg "  Success running build.sh for profile ${C_GREEN}${profile_name}${T_RESET}"
            logOkMsg "  Success running build.sh for profile ${profile_name}"
        else
            printDatedErrMsg "  build.sh for profile ${profile_name} returned error code ${returnCode}"
            if [ ! -x "${commandToRun}" ]; then
                printDatedMsg "  is ${profile_name}/build.sh executable?"
                logErrMsg "  is ${profile_name}/build.sh executable?"
            fi

            logFatalErrMsg "  build.sh for profile ${profile_name} returned error code ${returnCode}"
            # the logFatalErrMsg will automatically exit and preview the log
        fi
    else
        printDatedMsg "  No build.sh found for profile ${C_GREEN}${profile_name}${T_RESET}, skipping"
        logInfoMsg "  No build.sh found for profile ${profile_name}, skipping"
    fi
}

resetGlobalProfileConfigVariables() {
    # Reset these variables.
    # If any variables are added to config.yml in profiles, add them here
    # if it's needed - it's only needed if the variable can be undefined
    # and we fill in a default value.
    #
    # Why? When iterating over multiple profiles and attempting to generate
    # multiple entries in the PXE menu, the yaml parsing script will read in
    # each of the below variables with a name like "profile_config_kernel_filename".
    # Due to limitations with the Bash scripting language, we can't dynamically
    # name and refer to arrays created by the yaml parsing script. In a perfect
    # world, the set of variables that get created from this yaml file would be
    # something like this:
    #   profile_rancher_config__kernel_filename
    #   profile_rancher_config__kernel_arguments
    # Then, we would refer to these variables later like this:
    #   ${profile_${name}_config__kernel_filename}
    #   ${profile_${name}_config__kernel_arguments}
    # When using for loops, this becomes impossible, for example:
    #   ${#profile_${name}_config_some_array{@}}
    # These examples just don't work in bash.
    #
    # So as a result, we have to reuse variable names when parsing configs for
    # multiple profiles. If a user wants to leave a variable undefined, and the
    # code supports that, we have to reset the variables each time.
    profile_config_kernel_arguments=
}

loadProfileConfig() {
    local name=${1}
    # If the profile has a conf/config.yml file,
    # then attempt tp parse the conf/config.yml file into bash variables.
    if [[ -f "${WEB_PROFILE}/${name}/conf/config.yml" ]]; then
        # If testing this script, uncomment this next line
        # source "scripts/yamlparse.sh"
        eval $(yamlParse "${WEB_PROFILE}/${name}/conf/config.yml" "profile_config_")
    else
        logInfoMsg "Profile ${name} did not have a conf/config.yml file. Will attempt to continue with generating the PXE menu using defaults."
    fi
}

getKernelFromProfileFilesYml() {
    if [ -z "${files_config_base_os_files__url+x}" ]; then
        # If the base_os_files section doesn't exist, return false
        echo "false"
        return 0
    else
        for ((j = 0; j < "${#files_config_base_os_files__url[@]}"; j += 1)); do
            local filename=${files_config_base_os_files__filename[j]}
            local type=${files_config_base_os_files__type[j]}

            if [[ "${type}" == "kernel" ]]; then
                echo "${filename}"
                return 0
            fi
        done
    fi
    echo "false"
}

getInitrdFromProfileFilesYml() {
    if [ -z "${files_config_base_os_files__url+x}" ]; then
        # If the base_os_files section doesn't exist, return false
        echo "false"
        return 0
    else
        for ((j = 0; j < "${#files_config_base_os_files__url[@]}"; j += 1)); do
            local filename=${files_config_base_os_files__filename[j]}
            local type=${files_config_base_os_files__type[j]}

            if [[ "${type}" == "initrd" ]]; then
                echo "${filename}"
                return 0
            fi
        done
    fi
    echo "false"
}

areKernelAndInitrdInProfileFilesYml() {
    local foundKernel="false"
    local foundInitrd="false"

    if [ -z "${files_config_base_os_files__url+x}" ]; then
        # If the base_os_files section doesn't exist, return false
        echo "false"
        return 0
    else
        for ((j = 0; j < "${#files_config_base_os_files__url[@]}"; j += 1)); do
            local filename=${files_config_base_os_files__filename[j]}
            local type=${files_config_base_os_files__type[j]}

            if [[ "${type}" == "kernel" ]]; then
                foundKernel="true"
            elif [[ "${type}" == "initrd" ]]; then
                foundInitrd="true"
            fi

        done
        if [[ "${foundKernel}" == "true" && "${foundInitrd}" == "true" ]]; then
            echo "true"

            # Exit the function so that the final "echo false" statement
            # is not executed.
            return 0
        fi
    fi

    echo "false"
    return 0
}

getIsoFromProfileFilesYml() {
    if [ -z "${files_config_base_os_files__url+x}" ]; then
        # If the base_os_files section doesn't exist, return false
        echo "false"
        return 0
    else
        for ((j = 0; j < "${#files_config_base_os_files__url[@]}"; j += 1)); do
            local filename=${files_config_base_os_files__filename[j]}
            local type=${files_config_base_os_files__type[j]}

            if [[ "${type}" == "iso" ]]; then
                echo "${filename}"
                return 0
            fi
        done
    fi
    echo "false"
}

isIsoInProfileFilesYml() {
    local foundIso="false"

    if [ -z "${files_config_base_os_files__url+x}" ]; then
        # If the base_os_files section doesn't exist, return false
        echo "false"
        return 0
    else
        for ((j = 0; j < "${#files_config_base_os_files__url[@]}"; j += 1)); do
            local filename=${files_config_base_os_files__filename[j]}
            local type=${files_config_base_os_files__type[j]}

            if [[ "${type}" == "iso" ]]; then
                echo "true"
                return 0
            fi

        done
    fi

    echo "false"
    return 0
}

genProfilePxeMenu() {
    # Not all of these arguments may be used by this function, but this
    # follows a consistent format. See the "profilesActions" function
    local git_remote_url=$1
    local git_branch_name=$2
    local git_base_branch_name=$3
    local git_username=$4
    local git_token=$5
    local name=$6
    local base_name=${6}_base
    local custom_git_arguments=$7
    local iteration=$8

    custom_git_arguments=$(validateEmptyInput ${custom_git_arguments})
    git_username=$(validateEmptyInput ${git_username})
    git_token=$(validateEmptyInput ${git_token})

    local autogen_str='# Auto-generated'

    resetGlobalProfileConfigVariables
    loadProfileConfig ${name}

    # Load the profile's conf/files.yml file
    local foundProfileFiles=$(canLoadProfileFiles "${WEB_PROFILE}/${name}/conf/files.yml" "${name}")
    if [[ ${foundProfileFiles} == "0" ]]; then
        # Now load the profile's files.yml variables into memory.
        parseProfileFilesYml "${WEB_PROFILE}/${name}/conf/files.yml"
    fi

    # Begin the header for this menu item
    addLineToPxeMenu ''
    addLineToPxeMenu "\"${autogen_str}\""

    # Determine the keyboard shortcut that corresponds for this menu item
    # based on the number of times the string appears in the file
    # i.e. 1, 2, 3
    local tmpPxeMenuFile=$(getTmpPxeMenuLocation)
    local autogenCount=$(cat ${tmpPxeMenuFile} | grep "${autogen_str}" | wc -l)

    # if --boot-profile is set update the defaul PXE Menu to this profile
    if [ "${BOOT_PROFILE}" == "${name}" ]; then
        replaceDefaultPXEboot ${autogenCount}
    fi

    # Continue to add lines to the menu, incorporating the above variable
    addLineToPxeMenu "\"LABEL ${autogenCount}\""

    # The keyboard shortcut is autogenCount + 0, so calculate it
    # It used to be n + 1, but we moved the local boot option to the bottom,
    # and so an offset is no longer necessary
    local autogenCountInc=$(( ${autogenCount} + 0 ))
    addLineToPxeMenu "\"    MENU LABEL ^${autogenCountInc}) ${name}\""

    local kernelArgs=""
    local proxyArgs=""
    local ttyArg="console=tty0"
    local httpserverArg="httpserver=@@HOST_IP@@"
    local bootstrapArg="bootstrap=http://@@HOST_IP@@/profile/${name}/bootstrap.sh"
    local uosInitrdKernelArg="initrd=http://@@HOST_IP@@/tftp/images/uos/initrd"
    local httpFilesPathArg="httppath=/files/${name}"

    if [[ ${git_base_branch_name} == 'None' ||  ${git_base_branch_name} == "" ]]; then
        local baseBranchArg="basebranch=None"
    else
        local baseBranchArg="basebranch=http://@@HOST_IP@@/profile/${base_name}"
    fi

    kernelArgs="${ttyArg} ${httpserverArg} ${bootstrapArg} ${baseBranchArg} ${httpFilesPathArg} ${kernelArgs}"

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
    if [ ! -z "${proxyArgs}" ]; then
        kernelArgs="${kernelArgs} ${proxyArgs}"
    fi

    # If kernel & initrd are both specified in the profile's files.yml,
    # then use them. Otherwise, use UOS. In both cases, use the kernel args
    # that are passed by the user.
    profileContainsKernelAndInitrd=$(areKernelAndInitrdInProfileFilesYml)
    profileContainsIso=$(isIsoInProfileFilesYml)
    kernelFilename=$(getKernelFromProfileFilesYml)
    initrdFilename=$(getInitrdFromProfileFilesYml)
    isoFilename=$(getIsoFromProfileFilesYml)

    if [[ "${profileContainsKernelAndInitrd}" == "true" ]]; then
        local kernelPath="http://@@HOST_IP@@/tftp/images/${name}/${kernelFilename}"
        addLineToPxeMenu "\"    KERNEL ${kernelPath}\""
        kernelArgs="initrd=http://@@HOST_IP@@/tftp/images/${name}/${initrdFilename} ${kernelArgs}"
    elif [[ "${profile_config_kernel_type-}" == "ipxe" ]]; then
        addLineToPxeMenu "\"    KERNEL http://@@HOST_IP@@/tftp/images/ipxe/ipxe.lkrn \""
        mkdir -p ${WEB_ROOT}/ipxe/${name}
        cat ${TEMPLATE_FILES}/ipxe/boot.ipxe.${profile_config_ipxe_template}.template | sed "s#@@HOST_IP@@#${builder_config_host_ip}#g" | sed "s#@@PROFILE_NAME@@#${name}#g" > ${WEB_ROOT}/ipxe/${name}/boot.ipxe
    elif [[ "${profileContainsIso}" == "true" ]] || [[ "${profile_config_kernel_type-}" == "memdisk" ]]; then
  	    addLineToPxeMenu "\"    LINUX http://@@HOST_IP@@/tftp/images/iso/memdisk vmalloc=16G \""
        addLineToPxeMenu "\"    INITRD http://@@HOST_IP@@/tftp/images/${name}/${isoFilename} \""
    elif [[ -f "${TFTP_IMAGES}/uos/${name}/initrd" ]]; then
        # Use Embedded Micro OS (uOS).
        local kernelPath="http://@@HOST_IP@@/tftp/images/uos/vmlinuz"
        addLineToPxeMenu "\"    KERNEL ${kernelPath}\""
        kernelArgs="initrd=http://@@HOST_IP@@/tftp/images/uos/${name}/initrd ${kernelArgs}"
    else
        # Use Micro OS (uOS).
        local kernelPath="http://@@HOST_IP@@/tftp/images/uos/vmlinuz"
        addLineToPxeMenu "\"    KERNEL ${kernelPath}\""
        kernelArgs="${uosInitrdKernelArg} ${kernelArgs}"
    fi

    if [[ "${profile_config_kernel_type-}" == "ipxe" ]]; then
        kernelArgs="dhcp && chain http://@@HOST_IP@@/ipxe/${name}/boot.ipxe"
    elif [[ "${profileContainsIso}" == "true" ]] || [[ "${profile_config_kernel_type-}" == "memdisk" ]]; then
        kernelArgs="iso raw"
    elif [[ -n "${profile_config_kernel_arguments-}" ]]; then
        kernelArgs="${kernelArgs} ${profile_config_kernel_arguments}"
    fi

    # Perform the @@PROFILE_NAME@@ template rendering for this profile's
    # kernel args here.
    profileNamePlaceholder="@@PROFILE_NAME@@"
    kernelArgs=$(echo "${kernelArgs}" | sed "s/${profileNamePlaceholder}/${name}/g")
    
    addLineToPxeMenu "\"    APPEND ${kernelArgs}\""

    addLineToPxeMenu ''

    printDatedOkMsg "Added ${name} profile to PXE boot menu successfully."
    logMsg "Added ${name} profile to PXE boot menu successfully."
}

genProfileVirtualPxeMenu() {
    # Not all of these arguments may be used by this function, but this
    # follows a consistent format. See the "profilesActions" function
    local git_remote_url=$1
    local git_branch_name=$2
    local git_base_branch_name=$3
    local git_username=$4
    local git_token=$5
    local name=$6
    local base_name=${6}_base
    local custom_git_arguments=$7
    local iteration=$8

    custom_git_arguments=$(validateEmptyInput ${custom_git_arguments})
    git_username=$(validateEmptyInput ${git_username})
    git_token=$(validateEmptyInput ${git_token})

    loadProfileConfig ${name}

    # Load the profile's conf/files.yml file
    local foundProfileFiles=$(canLoadProfileFiles "${WEB_PROFILE}/${name}/conf/files.yml" "${name}")
    if [[ ${foundProfileFiles} == "0" ]]; then
        # Now load the profile's files.yml variables into memory.
        parseProfileFilesYml "${WEB_PROFILE}/${name}/conf/files.yml"
    fi

    # The keyboard shortcut is autogenCount + 0, so calculate it
    # It used to be n + 1, but we moved the local boot option to the bottom,
    # and so an offset is no longer necessary
    local autogenCountInc=$(( ${iteration} + 1 ))
    line="\" ${autogenCountInc}) ${name}\""
    echo "${line}" | awk -F\" '{ print $2 }'
}

getProfileNumber() {
    # Not all of these arguments may be used by this function, but this
    # follows a consistent format. See the "profilesActions" function
    local git_remote_url=$1
    local git_branch_name=$2
    local git_base_branch_name=$3
    local git_username=$4
    local git_token=$5
    local name=$6
    local base_name=${6}_base
    local custom_git_arguments=$7
    local iteration=$8

    custom_git_arguments=$(validateEmptyInput ${custom_git_arguments})
    git_username=$(validateEmptyInput ${git_username})
    git_token=$(validateEmptyInput ${git_token})

    loadProfileConfig ${name}

    # Load the profile's conf/files.yml file
    local foundProfileFiles=$(canLoadProfileFiles "${WEB_PROFILE}/${name}/conf/files.yml" "${name}")
    if [[ ${foundProfileFiles} == "0" ]]; then
        # Now load the profile's files.yml variables into memory.
        parseProfileFilesYml "${WEB_PROFILE}/${name}/conf/files.yml"
    fi

    # The keyboard shortcut is autogenCount + 0, so calculate it
    # It used to be n + 1, but we moved the local boot option to the bottom,
    # and so an offset is no longer necessary
    local autogenCountInc=$(( ${iteration} + 1 ))
    echo ${autogenCountInc}
}

genProfileVirtualPxeBoot() {
    # Not all of these arguments may be used by this function, but this
    # follows a consistent format. See the "profilesActions" function
    local git_remote_url=$1
    local git_branch_name=$2
    local git_base_branch_name=$3
    local git_username=$4
    local git_token=$5
    local name=$6
    local base_name=${6}_base
    local custom_git_arguments=$7
    local profile_number=$8

    custom_git_arguments=$(validateEmptyInput ${custom_git_arguments})
    git_username=$(validateEmptyInput ${git_username})
    git_token=$(validateEmptyInput ${git_token})

    # local autogen_str='# Auto-generated'

    # resetGlobalProfileConfigVariables
    loadProfileConfig ${name}

    # Load the profile's conf/files.yml file
    local foundProfileFiles=$(canLoadProfileFiles "${WEB_PROFILE}/${name}/conf/files.yml" "${name}")
    if [[ ${foundProfileFiles} == "0" ]]; then
        # Now load the profile's files.yml variables into memory.
        parseProfileFilesYml "${WEB_PROFILE}/${name}/conf/files.yml"
    fi

    line="\"Booting profile ${name}...\""
    echo "${line}" | awk -F\" '{ print $2 }'
    
    local kernelArgs=""
    local proxyArgs=""
    local ttyArg="console=ttyS0"
    local httpserverArg="httpserver=@@HOST_IP@@"
    local bootstrapArg="bootstrap=http://@@HOST_IP@@/profile/${name}/bootstrap.sh"
    local httpFilesPathArg="httppath=/files/${name}"

    if [[ ${git_base_branch_name} == 'None' || ${git_base_branch_name} == "" ]]; then
        local baseBranchArg="basebranch=None"
    else
        local baseBranchArg="basebranch=http://@@HOST_IP@@/profile/${base_name}"
    fi

    kernelArgs="${ttyArg} ${httpserverArg} ${bootstrapArg} ${baseBranchArg} ${httpFilesPathArg} ${kernelArgs}"

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
    if [ ! -z "${proxyArgs}" ]; then
        kernelArgs="${kernelArgs} ${proxyArgs}"
    fi

    # If kernel & initrd are both specified in the profile's files.yml,
    # then use them. Otherwise, use UOS. In both cases, use the kernel args
    # that are passed by the user.
    profileContainsKernelAndInitrd=$(areKernelAndInitrdInProfileFilesYml)
    profileContainsIso=$(isIsoInProfileFilesYml)
    kernelFilename=$(getKernelFromProfileFilesYml)
    initrdFilename=$(getInitrdFromProfileFilesYml)
    isoFilename=$(getIsoFromProfileFilesYml)

    if [[ "${profileContainsKernelAndInitrd}" == "true" ]]; then
        local kernelPath="data/srv/tftp/images/${name}/${kernelFilename}"
        local initrdPath="data/srv/tftp/images/${name}/${initrdFilename}"
    elif [[ "${profileContainsIso}" == "true" ]]; then
        local kernelPath="data/srv/tftp/images/iso/memdisk"
        local initrdPath="data/srv/tftp/images/${name}/${isoFilename}"
    else
        # Use Micro OS (uOS).
        local kernelPath="data/srv/tftp/images/uos/vmlinuz"
        local initrdPath="data/srv/tftp/images/uos/initrd"
    fi

    if [[ -n "${profile_config_kernel_arguments-}" ]]; then
        kernelArgs="${kernelArgs} ${profile_config_kernel_arguments}"
    fi

    # Perform the @@PROFILE_NAME@@ template rendering for this profile's
    # kernel args here.
    profileNamePlaceholder="@@PROFILE_NAME@@"
    kernelArgs=$(echo "${kernelArgs}" | sed "s/${profileNamePlaceholder}/${name}/g")

    # addLineToVirtualPxeMenu "\"    APPEND ${kernelArgs}\""

    if [ -f ./output/${name}/vdisk.${DISK_FORMAT} ]; then
        read -p "  Virtual disk './output/${name}/vdisk.${DISK_FORMAT}' already exists. Would you like to continue and overwrite? [y/n]: " answer
        validateInput custom "${answer}" "Please enter 'y' or 'n': ${answer}" "^(y|n)$"

        if [ ${answer} = "y" ]; then
            rm ./output/${name}/vdisk.${DISK_FORMAT}
        else
            exit
        fi
    fi

    mkdir -p ./output/${name}
    echo ${kernelArgs} > ./output/${name}/uos-cmdline
    cp ${kernelPath} ./output/${name}/uos-kernel
    cp ${initrdPath} ./output/${name}/uos-initrd.img

    local hostipPlaceholder=("@@HOST_IP@@" "@@ESP_IP@@" "@@RNI_IP@@" "@@EDGEBUILDER_IP@@")

    # Replace all the potential variables in the staged file.
    for i in {0..2}
    do
        sed -i -e "s/${hostipPlaceholder[i]}/${builder_config_host_ip}/g" ./output/${name}/uos-cmdline
    done
    sed -i -e  "s/release=dev/release=prod/" ./output/${name}/uos-cmdline

    KERNEL_PARAMS=$(cat ./output/${name}/uos-cmdline)

    logMsg "Booting ${name} profile with Virtual PXE."

    logMsg "Running command: docker run -it --rm --privileged --net=host --cap-add=ALL --name=builder-vpxe -v /dev:/dev -v /run:/run -v $(pwd)/output/${name}:/data:shared -e RAM=${MEMORY} -e CPU='host' -e SMP=4,sockets=1,cores=4,threads=1 -e NAME=vpxe -e DISK_DEVICE=\"-drive file=/data/vdisk.${DISK_FORMAT},format=${DISK_FORMAT},index=0,media=disk\" -e IMAGE_FORMAT=${DISK_FORMAT} -e IMAGE=/data/vdisk.${DISK_FORMAT} -e IMAGE_SIZE=${DISK_SIZE}G -e IMAGE_CREATE=1 -e VIDEO=none -e BIOS=${BIOS} -e ADD_FLAGS=\"-kernel /data/uos-kernel -initrd /data/uos-initrd.img -append '${KERNEL_PARAMS}'\" -e USB_HUB=none builder-qemu"

    docker run -it --rm --privileged --net=host --cap-add=ALL --name=builder-vpxe -v /dev:/dev -v /run:/run -v $(pwd)/output/${name}:/data:shared -e RAM=${MEMORY} -e CPU='host' -e SMP=4,sockets=1,cores=4,threads=1 -e NAME=vpxe -e DISK_DEVICE="-drive file=/data/vdisk.${DISK_FORMAT},format=${DISK_FORMAT},index=0,media=disk" -e IMAGE_FORMAT=${DISK_FORMAT} -e IMAGE=/data/vdisk.${DISK_FORMAT} -e IMAGE_SIZE=${DISK_SIZE}G -e IMAGE_CREATE=1 -e VIDEO=none -e BIOS=${BIOS} -e ADD_FLAGS="-kernel /data/uos-kernel -initrd /data/uos-initrd.img -append '${KERNEL_PARAMS}'" -e USB_HUB=none builder-qemu

    rm ./output/${name}/uos-cmdline ./output/${name}/uos-kernel ./output/${name}/uos-initrd.img
    sleep 2
    rm -fr ./output/${name}/uos-state

    logMsg "Completed booting ${name} profile."

    if [ "${OUTPUT}" = "container" ]; then
        printMsg ""
        run "Containerizing the VM - ${name}" \
            "docker build --rm ${DOCKER_BUILD_ARGS} --build-arg NAME=${name} --build-arg DISK_FORMAT=${DISK_FORMAT} --build-arg VIRTUAL_DISK:vdisk.${DISK_FORMAT} -t vm/${name,,} -f dockerfiles/vm/Dockerfile ./output/${name} && \
            rm ./output/${name}/vdisk.${DISK_FORMAT}" \
            ${LOG_FILE}
        printMsg ""
        printMsg ""
        printMsg ""
        printMsg "Docker image created: vm/${name,,}"
        docker images | grep vm/${name,,}
        printMsg ""
        printMsg "Example run command: docker run -d --privileged --net=host --name=VM -v /dev:/dev vm/${name,,}.  You cannot to the screen output via SPICE protocol at port 5901 or sockert /var/run/kvmvideo/spice.sock.  Visit https://github.com/intel/Edge-Software-Provisioner/tree/master/dockerfiles/qemu/README.md to see how to run the VM from Docker."
        printMsg ""
        printMsg ""
    else
        printMsg ""
        printMsg ""
        printMsg ""
        printMsg "Profile successfully created by Virtual PXE and can found here: ./output/${name}/vdisk.${DISK_FORMAT}"
        printMsg ""
        printMsg ""
        printMsg ""
    fi
}

genProfileUsbBoot() {
    # Not all of these arguments may be used by this function, but this
    # follows a consistent format. See the "profilesActions" function
    local git_remote_url=$1
    local git_branch_name=$2
    local git_base_branch_name=$3
    local git_username=$4
    local git_token=$5
    local name=$6
    local base_name=${6}_base
    local custom_git_arguments=$7
    local profile_number=$8
    local usb_path="data/usr/share/nginx/html/usb"

    custom_git_arguments=$(validateEmptyInput ${custom_git_arguments})
    git_username=$(validateEmptyInput ${git_username})
    git_token=$(validateEmptyInput ${git_token})

    # local autogen_str='# Auto-generated'

    # resetGlobalProfileConfigVariables
    loadProfileConfig ${name}

    # Load the profile's conf/files.yml file
    local foundProfileFiles=$(canLoadProfileFiles "${WEB_PROFILE}/${name}/conf/files.yml" "${name}")
    if [[ ${foundProfileFiles} == "0" ]]; then
        # Now load the profile's files.yml variables into memory.
        parseProfileFilesYml "${WEB_PROFILE}/${name}/conf/files.yml"
    fi
   
    local kernelArgs=""
    local proxyArgs=""
    local ttyArg="console=ttyS0"
    local httpserverArg="httpserver=@@HOST_IP@@"
    local bootstrapArg="bootstrap=http://@@HOST_IP@@/profile/${name}/bootstrap.sh"
    local httpFilesPathArg="httppath=/files/${name}"

    if [[ ${git_base_branch_name} == 'None' || ${git_base_branch_name} == "" ]]; then
        local baseBranchArg="basebranch=None"
    else
        local baseBranchArg="basebranch=http://@@HOST_IP@@/profile/${base_name}"
    fi

    kernelArgs="${ttyArg} ${httpserverArg} ${bootstrapArg} ${baseBranchArg} ${httpFilesPathArg} ${kernelArgs}"

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
    if [ ! -z "${proxyArgs}" ]; then
        kernelArgs="${kernelArgs} ${proxyArgs}"
    fi

    # If kernel & initrd are both specified in the profile's files.yml,
    # then use them. Otherwise, use UOS. In both cases, use the kernel args
    # that are passed by the user.
    profileContainsKernelAndInitrd=$(areKernelAndInitrdInProfileFilesYml)
    profileContainsIso=$(isIsoInProfileFilesYml)
    kernelFilename=$(getKernelFromProfileFilesYml)
    initrdFilename=$(getInitrdFromProfileFilesYml)
    isoFilename=$(getIsoFromProfileFilesYml)

    local usb_path="data/usr/share/nginx/html/usb"
    local img_path="data/srv/tftp/images"
    local memdiskPath="data/srv/tftp/images/iso/memdisk"
    local ymlPath="dockerfiles/uos/uos-wifi.yml"
    local syslinuxTemplate="template/pxelinux.cfg/default.head"
    local tmp_path="data/tmp"
    local uosBuildPath="$(pwd)/dockerfiles/uos"

    if [[ -n "${profile_config_kernel_arguments-}" ]]; then
        kernelArgs="${kernelArgs} ${profile_config_kernel_arguments}"
    fi

    # Perform the @@PROFILE_NAME@@ template rendering for this profile's
    # kernel args here.
    profileNamePlaceholder="@@PROFILE_NAME@@"
    kernelArgs=$(echo "${kernelArgs}" | sed "s/${profileNamePlaceholder}/${name}/g")

    mkdir -p ${usb_path}/${name}
    mkdir -p ${tmp_path}
    echo ${kernelArgs} > ${usb_path}/${name}/uos-cmdline
    cp ${ymlPath} ${TFTP_IMAGES}/uos/usb/uos.yml

    local hostipPlaceholder=("@@HOST_IP@@" "@@ESP_IP@@" "@@RNI_IP@@" "@@EDGEBUILDER_IP@@")

    # Replace all the potential variables in the staged file.
    for i in {0..2}
    do
        sed -i -e "s/${hostipPlaceholder[i]}/${builder_config_host_ip}/g" ${usb_path}/${name}/uos-cmdline
    done
    sed -i -e  "s/release=dev/release=prod/" ${usb_path}/${name}/uos-cmdline
    sed -i -e  "s/console=ttyS0/console=tty0/" ${usb_path}/${name}/uos-cmdline

    KERNEL_PARAMS=$(cat ${usb_path}/${name}/uos-cmdline)

    if [ "${USB_RANDOM}" == "true" ]; then
        _uuid=$(docker run alpine sh -c 'apk add util-linux > /dev/null 2>&1 && uuidgen')
        IMG_NAME="${_uuid}"
    else
        IMG_NAME="uos-${USB_BIOS}"
    fi

    if [ -f ${usb_path}/${name}/${IMG_NAME}.img ]; then
        read -p "  USB IMG '${usb_path}/${name}/${IMG_NAME}.img' already exists. Would you like to remove the file and build a new image? [y/n]: " answer
        validateInput custom "${answer}" "Please enter 'y' or 'n': ${answer}" "^(y|n)$"

        if [ ${answer} = "y" ]; then
            rm ${usb_path}/${name}/${IMG_NAME}.img
        fi
    fi

    if [ ! -f ${usb_path}/${name}/${IMG_NAME}.img ]; then

        if [[ "${profileContainsKernelAndInitrd}" == "true" ]]; then
            local kernelPath="data/srv/tftp/images/${name}/${kernelFilename}"
            local initrdPath="data/srv/tftp/images/${name}/${initrdFilename}"
            local syslinuxKernel="/${kernelFilename}"
            local syslinuxInitrd="/${initrdFilename}"
        elif [[ "${profileContainsIso}" == "true" ]]; then
            local kernelPath="data/srv/tftp/images/iso/memdisk"
            local initrdPath="data/srv/tftp/images/${name}/${isoFilename}"
            local syslinuxKernel="/memdisk"
            local syslinuxInitrd="/${isoFilename}"
        else
            # Use Micro OS (uOS).
            logMsg "Preparing bootable USB stick for ${name} profile."
            logMsg "Running command: docker run -i --rm --privileged --net host --name builder-usb -v /var/run/docker.sock:/var/run/docker.sock -v $(pwd)/${usb_path}/${name}:/uos:shared builder-uos:$(docker images | grep builder-uos | awk '{print $2}' | head -1) -c \"cd /uos && /usr/bin/linuxkit build -format kernel+initrd /uos/uos.yml\""

            run "Preparing bootable USB stick for ${name} profile." \
                "docker run -i --rm --privileged --net host --name builder-usb \
                -v /var/run/docker.sock:/var/run/docker.sock \
                -v ${uosBuildPath}:/uos:shared \
                -v ${TFTP_IMAGES}/uos/usb:/target:shared \
                builder-uos:$(docker images | grep builder-uos | awk '{print $2}' | head -1) -c \
                    \"cd /uos && \
                    /usr/bin/linuxkit build -format kernel+initrd /uos/uos-wifi.yml && \
                    mv /uos/uos-wifi-initrd.img /target/initrd && \
                    mv /uos/uos-wifi-kernel /target/vmlinuz\"" \
                ${LOG_FILE}

            local kernelPath="data/srv/tftp/images/uos/usb/vmlinuz"
            local initrdPath="data/srv/tftp/images/uos/usb/initrd"
            local syslinuxKernel="/vmlinuz"
            local syslinuxInitrd="/initrd"
            
            if [ "$(ls -A ${EMBEDDED_FILES}/${name} 2> /dev/null )" ] || [ "$(ls -A ${WEB_PROFILE}/${name}/embedded 2> /dev/null)" ]; then
                mkdir -p ${TFTP_IMAGES}/uos/usb/${name}
                message="Embedding files into uOS for ${name}."
                run "${message}" \
                    "docker run --rm --privileged ${DOCKER_RUN_ARGS} --name esp_embedding \
                        -v ${TFTP_IMAGES}/uos/usb:/opt/images:shared \
                        -v ${WEB_PROFILE}/${name}/embedded:/opt/profile_embedded:ro \
                        -v ${EMBEDDED_FILES}/${name}:/opt/embedded:ro \
                        alpine:3.12 sh -c 'apk update && \
                            apk add rsync gzip cpio && \
                            mkdir -p prep/ && \
                            cd prep/ && \
                            zcat /opt/images/initrd | cpio -idmu && \
                            rsync -rtc /opt/profile_embedded/ ./ && \
                            rsync -rtc /opt/embedded/ ./ && \
                            find . | cpio -H newc -o | gzip > /opt/images/${name}/initrd' \
                    echo 'Finished with embedding files into uOS, Cleaning up build docker container...'; \
                    docker rm -f esp_embedding > /dev/null 2>&1 || true" \
                    ${LOG_FILE}
                local initrdPath="data/srv/tftp/images/uos/usb/${name}/initrd"
                local syslinuxInitrd="/initrd"
            fi
        fi

        # Create syslinux.cfg menu
        cp ${syslinuxTemplate} ${tmp_path}/syslinux.cfg
        sed -i 's#ONTIMEOUT local#ONTIMEOUT 1#g' ${tmp_path}/syslinux.cfg
        sed -i 's#TIMEOUT 200#TIMEOUT 20#g' ${tmp_path}/syslinux.cfg
        echo "" >> ${tmp_path}/syslinux.cfg
        echo "LABEL 1" >> ${tmp_path}/syslinux.cfg
        echo "    MENU LABEL ${name}" >> ${tmp_path}/syslinux.cfg
        echo "    KERNEL ${syslinuxKernel}" >> ${tmp_path}/syslinux.cfg
        echo "    APPEND initrd=${syslinuxInitrd} ${KERNEL_PARAMS}" >> ${tmp_path}/syslinux.cfg

        KERNEL_SIZE=$(du -bcs ${kernelPath} | grep total | awk '{print $1}')
        INITRD_SiZE=$(du -bcs ${initrdPath} | grep total | awk '{print $1}')

        printDatedMsg "Building bootable USB stick for ${name} profile."
        logMsg "Building bootable USB stick for ${name} profile."
        if [ "${USB_BIOS}" == "efi" ]; then
            docker run -it --rm --privileged ${DOCKER_RUN_ARGS} -v /dev:/dev:shared -v $(pwd)/data:/data -v $(pwd)/${usb_path}/${name}:/usb alpine sh -c "apk add util-linux syslinux coreutils parted rsync e2fsprogs > /dev/null && \
                IMG_SIZE=\$((${KERNEL_SIZE} + ${INITRD_SiZE} + 52428800)) && \
                truncate --size \${IMG_SIZE} /usb/temp.img && \
                TEMP_IMG_DEV=\$(losetup --find --show /usb/temp.img) && \
                dd bs=440 count=1 conv=notrunc if=/usr/share/syslinux/gptmbr.bin of=\${TEMP_IMG_DEV} > /dev/null 2>&1 && \
                parted --script \${TEMP_IMG_DEV} mklabel gpt mkpart ESP fat32 1MiB 100% set 1 esp on && \
                mkfs -t vfat \${TEMP_IMG_DEV}p1 && \
                mount \${TEMP_IMG_DEV}p1 /mnt && \
                cp ${kernelPath} /mnt/ && \
                cp ${initrdPath} /mnt/ && \
                cp /usr/share/syslinux/memdisk /mnt/ && \
                mkdir -p /mnt/EFI/BOOT/ && \
                cp -r /usr/share/syslinux/efi64/* /mnt/EFI/BOOT/ && \
                cp -r /usr/share/syslinux/efi64/syslinux.efi /mnt/EFI/BOOT/BOOTX64.EFI && \
                cp ${tmp_path}/syslinux.cfg /mnt/EFI/BOOT/syslinux.cfg && \
                umount /mnt && \
                partx -d \${TEMP_IMG_DEV} && \
                losetup -d \${TEMP_IMG_DEV} && \
                mv /usb/temp.img /usb/${IMG_NAME}.img"
            umount /dev/console
        else
            docker run -it --rm --privileged ${DOCKER_RUN_ARGS} -v /dev:/dev:shared -v $(pwd)/data:/data -v $(pwd)/${usb_path}/${name}:/usb alpine sh -c "apk add util-linux syslinux coreutils parted rsync e2fsprogs e2fsprogs-extra > /dev/null && \
                IMG_SIZE=\$((${KERNEL_SIZE} + ${INITRD_SiZE} + 52428800)) && \
                truncate --size \${IMG_SIZE} /usb/temp.img && \
                TEMP_IMG_DEV=\$(losetup --find --show /usb/temp.img) && \
                parted --script \${TEMP_IMG_DEV} mklabel msdos mkpart primary fat32 1MiB 100% set 1 boot on && \
                mkfs -t vfat \${TEMP_IMG_DEV}p1 > /dev/null 2>&1 && \
                syslinux -i \${TEMP_IMG_DEV}p1 && \
                mount \${TEMP_IMG_DEV}p1 /mnt && \
                cp ${kernelPath} /mnt/ && \
                cp ${initrdPath} /mnt/ && \
                cp /usr/share/syslinux/memdisk /mnt/ && \
                cp /usr/share/syslinux/*.c32 /mnt/ && \
                cp ${tmp_path}/syslinux.cfg /mnt/syslinux.cfg && \
                umount /mnt && \
                partx -d \${TEMP_IMG_DEV} && \
                losetup -d \${TEMP_IMG_DEV} && \
                dd if=/usr/share/syslinux/altmbr.bin bs=439 count=1 conv=notrunc of=/usb/temp.img > /dev/null 2>&1 && \
                printf '\1' | dd bs=1 count=1 seek=439 conv=notrunc of=/usb/temp.img > /dev/null 2>&1 && \
                sfdisk -A /usb/temp.img 1 > /dev/null 2>&1 && \
                mv /usb/temp.img /usb/${IMG_NAME}.img"
            umount /dev/console
        fi
    fi

    if [ "${USB_RANDOM}" == "true" ]; then
        mv ${usb_path}/${name}/uos-${USB_BIOS}.img ${usb_path}/${name}/${IMG_NAME}.img
    fi

    USB_IMG_SIZE=$(du -b ${usb_path}/${name}/${IMG_NAME}.img | awk '{print $1}')

    if [ "${USB_DEV}" != "" ]; then
        logMsg "docker run -it --rm --privileged ${DOCKER_RUN_ARGS} -v /dev:/dev -v $(pwd):/usb alpine sh -c \"apk add pv coreutils bash findutils lsblk > /dev/null && cd /usb && ./flashusb.sh -i ${usb_path}/${name}/${IMG_NAME}.img -b ${USB_BIOS} -d ${USB_DEV}\""
        docker run -it --rm --privileged ${DOCKER_RUN_ARGS} -v /dev:/dev -v $(pwd):/usb alpine sh -c "apk add pv coreutils bash findutils lsblk > /dev/null && cd /usb && ./flashusb.sh -i ${usb_path}/${name}/${IMG_NAME}.img -b ${USB_BIOS} -d ${USB_DEV}"
    else
        printMsg ""
        printMsg "Use the following command to flash the img to the USB Device."
        printMsg "wget --no-check-certificate -qO - https://${builder_config_host_ip}/flashusb.sh > /tmp/flashusb.sh && bash /tmp/flashusb.sh -u https://${builder_config_host_ip}/usb/${name}/${IMG_NAME}.img -b ${USB_BIOS}"
    fi

    printMsg ""
    printDatedMsg "Completed building bootable USB for ${name} profile."
    logMsg "Completed building bootable USB for ${name} profile."
    printMsg ""
}

genAllProfileUsbBoot() {
    local name="all"
    local usb_path="data/usr/share/nginx/html/usb"
    local img_path="data/srv/tftp/images"
    local memdiskPath="data/srv/tftp/images/iso/memdisk"
    local kernelPath="data/srv/tftp/images/uos/vmlinuz"
    local initrdPath="data/srv/tftp/images/uos/initrd"
    local ymlPath="dockerfiles/uos/uos-wifi.yml"
    local uosBuildPath="$(pwd)/dockerfiles/uos"

    mkdir -p ${usb_path}/${name}
    mkdir -p ${TFTP_IMAGES}/uos/usb
    touch ${TFTP_IMAGES}/uos/usb/uos-cmdline
    # cp ${ymlPath} ${TFTP_IMAGES}/uos/usb/uos.yml

    if [ "${USB_RANDOM}" == "true" ]; then
        _uuid=$(docker run alpine sh -c 'apk add util-linux > /dev/null 2>&1 && uuidgen')
        IMG_NAME="${_uuid}"
    else
        IMG_NAME="uos-${USB_BIOS}"
    fi

    if [ -f ${usb_path}/${name}/${IMG_NAME}.img ]; then
        read -p "  USB IMG '${usb_path}/${name}/${IMG_NAME}.img' already exists. Would you like to remove the file and build a new image? [y/n]: " answer
        validateInput custom "${answer}" "Please enter 'y' or 'n': ${answer}" "^(y|n)$"

        if [ ${answer} = "y" ]; then
            rm ${usb_path}/${name}/${IMG_NAME}.img
        fi
    fi

    if [ ! -f ${usb_path}/${name}/${IMG_NAME}.img ]; then

        logMsg "Preparing bootable USB stick for ${name} profiles."
        logMsg "Running command: docker run -i --rm --privileged --net host --name builder-usb -v /var/run/docker.sock:/var/run/docker.sock -v $(pwd)/${usb_path}/${name}:/uos:shared builder-uos:$(docker images | grep builder-uos | awk '{print $2}' | head -1) -c \"cd /uos && /usr/bin/linuxkit build -format kernel+initrd /uos/uos.yml\""

        run "Preparing bootable USB stick for ${name} profiles." \
            "docker run -i --rm --privileged --net host --name builder-usb \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v ${uosBuildPath}:/uos:shared \
            -v ${TFTP_IMAGES}/uos/usb:/target:shared \
            builder-uos:$(docker images | grep builder-uos | awk '{print $2}' | head -1) -c \
                \"cd /uos && \
                /usr/bin/linuxkit build -format kernel+initrd /uos/uos-wifi.yml && \
                mv /uos/uos-wifi-initrd.img /target/initrd && \
                mv /uos/uos-wifi-kernel /target/vmlinuz\"" \
            ${LOG_FILE}

        for profile_name in $(ls ${WEB_PROFILE}/ | grep -v base); do        
            if [ "$(ls -A ${EMBEDDED_FILES}/${profile_name} 2> /dev/null )" ] || [ "$(ls -A ${WEB_PROFILE}/${profile_name}/embedded 2> /dev/null)" ]; then
                mkdir -p ${TFTP_IMAGES}/uos/usb/${profile_name}
                message="Embedding files into uOS for ${profile_name}."
                run "${message}" \
                    "docker run --rm --privileged ${DOCKER_RUN_ARGS} --name esp_embedding \
                        -v ${TFTP_IMAGES}/uos/usb:/opt/images:shared \
                        -v ${WEB_PROFILE}/${profile_name}/embedded:/opt/profile_embedded:ro \
                        -v ${EMBEDDED_FILES}/${profile_name}:/opt/embedded:ro \
                        alpine:3.12 sh -c 'apk update && \
                            apk add rsync gzip cpio && \
                            mkdir -p prep/ && \
                            cd prep/ && \
                            zcat /opt/images/initrd | cpio -idmu && \
                            rsync -rtc /opt/profile_embedded/ ./ && \
                            rsync -rtc /opt/embedded/ ./ && \
                            find . | cpio -H newc -o | gzip > /opt/images/${profile_name}/initrd' \
                        echo 'Finished with embedding files into uOS, Cleaning up build docker container...'; \
                        docker rm -f esp_embedding > /dev/null 2>&1 || true" \
                    ${LOG_FILE}
            fi
        done

        USB_IMG_SIZE=$(du -bcs ${TFTP_IMAGES}/uos/usb/* | grep total | awk '{print $1}')
        BOOT_IMAGES_SiZE=$(du -bcs --exclude=iso* --exclude=uos* ${img_path}/* | grep total | awk '{print $1}')

        printDatedMsg "Building bootable USB stick for ${name} profiles."
        logMsg "Building bootable USB stick for ${name} profiles."
        if [ "${USB_BIOS}" == "efi" ]; then
            docker run -it --rm --privileged ${DOCKER_RUN_ARGS} -v /dev:/dev:shared -v $(pwd)/data:/data -v $(pwd)/${usb_path}/${name}:/usb alpine sh -c "apk add util-linux syslinux coreutils parted rsync e2fsprogs > /dev/null && \
                IMG_SIZE=\$((${USB_IMG_SIZE} + ${BOOT_IMAGES_SiZE} + 52428800)) && \
                truncate --size \${IMG_SIZE} /usb/temp.img && \
                TEMP_IMG_DEV=\$(losetup --find --show /usb/temp.img) && \
                dd bs=440 count=1 conv=notrunc if=/usr/share/syslinux/gptmbr.bin of=\${TEMP_IMG_DEV} > /dev/null 2>&1 && \
                parted --script \${TEMP_IMG_DEV} mklabel gpt mkpart ESP fat32 1MiB 100% set 1 esp on && \
                mkfs -t vfat \${TEMP_IMG_DEV}p1 && \
                mount \${TEMP_IMG_DEV}p1 /mnt && \
                rsync -rt ${img_path}/uos/usb/ /mnt/ && \
                rsync -rt --exclude=iso/ --exclude=uos/ ${img_path}/ /mnt/ && \
                cp /usr/share/syslinux/memdisk /mnt/ && \
                mkdir -p /mnt/EFI/BOOT/ && \
                cp -r /usr/share/syslinux/efi64/* /mnt/EFI/BOOT/ && \
                cp -r /usr/share/syslinux/efi64/syslinux.efi /mnt/EFI/BOOT/BOOTX64.EFI && \
                cp /data/srv/tftp/pxelinux.cfg/default /mnt/EFI/BOOT/syslinux.cfg && \
                sed -i 's#http://${builder_config_host_ip}/tftp/images/uos/vmlinuz#/vmlinuz#g' /mnt/EFI/BOOT/syslinux.cfg && \
                sed -i 's#http://${builder_config_host_ip}/tftp/images/uos/initrd#/initrd#g' /mnt/EFI/BOOT/syslinux.cfg && \
                sed -i 's#http://${builder_config_host_ip}/tftp/images/uos/\\([a-zA-Z_]\\+\\)/initrd#/\\1/initrd#g' /mnt/EFI/BOOT/syslinux.cfg && \
                sed -i 's#http://${builder_config_host_ip}/tftp/images/iso/memdisk#/memdisk#g' /mnt/EFI/BOOT/syslinux.cfg && \
                sed -i 's#http://${builder_config_host_ip}/tftp/images/#/#g' /mnt/EFI/BOOT/syslinux.cfg && \
                umount /mnt && \
                partx -d \${TEMP_IMG_DEV} && \
                losetup -d \${TEMP_IMG_DEV} && \
                mv /usb/temp.img /usb/${IMG_NAME}.img"
            umount /dev/console
        else
            docker run -it --rm --privileged ${DOCKER_RUN_ARGS} -v /dev:/dev:shared -v $(pwd)/data:/data -v $(pwd)/${usb_path}/${name}:/usb alpine sh -c "apk add util-linux syslinux coreutils parted rsync e2fsprogs e2fsprogs-extra > /dev/null && \
                IMG_SIZE=\$((${USB_IMG_SIZE} + ${BOOT_IMAGES_SiZE} + 52428800)) && \
                truncate --size \${IMG_SIZE} /usb/temp.img && \
                TEMP_IMG_DEV=\$(losetup --find --show /usb/temp.img) && \
                dd bs=440 count=1 conv=notrunc if=/usr/share/syslinux/mbr.bin of=\${TEMP_IMG_DEV} > /dev/null 2>&1 && \
                parted --script \${TEMP_IMG_DEV} mklabel msdos mkpart primary fat32 1MiB 100% set 1 boot on && \
                mkfs -t vfat \${TEMP_IMG_DEV}p1 > /dev/null 2>&1 && \
                syslinux -i \${TEMP_IMG_DEV}p1 && \
                mount \${TEMP_IMG_DEV}p1 /mnt && \
                rsync -rt ${img_path}/uos/usb/ /mnt/ && \
                rsync -rt --exclude=iso/ --exclude=uos/ ${img_path}/ /mnt/ && \
                cp /usr/share/syslinux/memdisk /mnt/ && \
                cp /usr/share/syslinux/*.c32 /mnt/ && \
                cp /data/srv/tftp/pxelinux.cfg/default /mnt/syslinux.cfg && \
                sed -i 's#http://${builder_config_host_ip}/tftp/images/uos/vmlinuz#/vmlinuz#g' /mnt/syslinux.cfg && \
                sed -i 's#http://${builder_config_host_ip}/tftp/images/uos/initrd#/initrd#g' /mnt/syslinux.cfg && \
                sed -i 's#http://${builder_config_host_ip}/tftp/images/uos/\\([a-zA-Z_]\\+\\)/initrd#/\\1/initrd#g' /mnt/syslinux.cfg && \
                sed -i 's#http://${builder_config_host_ip}/tftp/images/iso/memdisk#/memdisk#g' /mnt/syslinux.cfg && \
                sed -i 's#http://${builder_config_host_ip}/tftp/images/#/#g' /mnt/syslinux.cfg && \
                umount /mnt && \
                partx -d \${TEMP_IMG_DEV} && \
                losetup -d \${TEMP_IMG_DEV} && \
                mv /usb/temp.img /usb/${IMG_NAME}.img"
            umount /dev/console
        fi
    fi

    USB_IMG_SIZE=$(du -b ${usb_path}/${name}/${IMG_NAME}.img | awk '{print $1}')

    if [ "${USB_DEV}" != "" ]; then

        logMsg "docker run -it --rm --privileged ${DOCKER_RUN_ARGS} -v /dev:/dev -v $(pwd):/usb alpine sh -c \"apk add pv coreutils bash findutils lsblk > /dev/null && cd /usb && ./flashusb.sh -i ${usb_path}/${name}/${IMG_NAME}.img -b ${USB_BIOS} -d ${USB_DEV}\""
        docker run -it --rm --privileged ${DOCKER_RUN_ARGS} -v /dev:/dev -v $(pwd):/usb alpine sh -c "apk add pv coreutils bash findutils lsblk > /dev/null && cd /usb && ./flashusb.sh -i ${usb_path}/${name}/${IMG_NAME}.img -b ${USB_BIOS} -d ${USB_DEV}"
    else
        printMsg ""
        printMsg "Use the following command to flash the img to the USB Device."
        printMsg "wget --no-check-certificate -qO - https://${builder_config_host_ip}/flashusb.sh > /tmp/flashusb.sh && bash /tmp/flashusb.sh -u https://${builder_config_host_ip}/usb/${name}/${IMG_NAME}.img -b ${USB_BIOS}"
    fi

    printMsg ""
    printDatedMsg "Completed building bootable USB for ${name} profiles."
    logMsg "Completed building bootable USB for ${name} profiles."
    printMsg ""

}

renderProfileTemplates() {
    # Not all of these arguments may be used by this function, but this
    # follows a consistent format. See the "profilesActions" function
    local git_remote_url=$1
    local git_branch_name=$2
    local git_base_branch_name=$3
    local git_username=$4
    local git_token=$5
    local name=$6
    local base_name=${6}_base
    local custom_git_arguments=$7
    local iteration=$8

    custom_git_arguments=$(validateEmptyInput ${custom_git_arguments})
    git_username=$(validateEmptyInput ${git_username})
    git_token=$(validateEmptyInput ${git_token})

    # Set globstar option in bash.
    # This enables us to use ** to recursively list
    # all files under a directory, space-separated
    # so that we can iterate over them in a loop.
    shopt -s globstar

    # Iterate over all files and check if they are buildertemplates.
    # If any are found, render them.
    for file in ${WEB_PROFILE}/${name}/**; do
        if [[ "${file}" == *".buildertemplate" || \
                "${file}" == *".ebtemplate" || \
                "${file}" == *".esptemplate" ]]; then
            logInfoMsg "Found ${file}, will proceed to render it"
            renderTemplate ${file} ${name}
        fi
    done

    # Unset the variable so it doesn't interfere with anything else.
    shopt -u globstar
}


# Usage: Pass in an arbitrary function as an argument to profilesActions
# This makes it easier to do tasks against every profile.
profilesActions() {
    local passedFunction=$1

    if [ -z "${builder_config_profiles__name+x}" ]; then
        printDatedErrMsg "No Profiles available"
        logFatalErrMsg "No Profiles available"
        exit 1
    else
        for ((j = 0; j < "${#builder_config_profiles__name[@]}"; j += 1)); do

            # if [ -z "${builder_config_profiles__git_base_branch_name+x}" ]; then
            #     logInfoMsg "Profile did not have a base profile"
            #     local git_base_branch_name=""
            # else
            #     local git_base_branch_name=${builder_config_profiles__git_base_branch_name[j]}
            # fi

            local git_remote_url=${builder_config_profiles__git_remote_url[j]}
            local git_branch_name=${builder_config_profiles__profile_branch[j]}
            local git_base_branch_name=${builder_config_profiles__profile_base_branch[j]}
            local git_username=${builder_config_profiles__git_username[j]:-"None"}
            local git_token=${builder_config_profiles__git_token[j]:-"None"}
            local name=${builder_config_profiles__name[j]}
            local custom_git_arguments=${builder_config_profiles__custom_git_arguments[j]}

            # if build.sh switch --profile is used 
            if [ ! -z "${SINGLE_PROFILE}" ] && [ "${passedFunction}" != "genProfilePxeMenu" ] ; then
                if [ "${SINGLE_PROFILE}" == "${name}" ]; then
                    # found profile name and will continue
                    if [ "${passedFunction}" != "getProfileNumber" ]; then
                        printBanner "Running ${passedFunction} for profile ${name}..."
                    fi
                else
                    if [ "${passedFunction}" != "getProfileNumber" ]; then
                        printBanner "Skipping profile ${name}..."
                        logMsg "Skipping profile ${name}..."
                    fi
                    continue
                fi
            fi

            (
                ${passedFunction} \
                    ${git_remote_url} \
                    ${git_branch_name} \
                    ${git_base_branch_name} \
                    ${git_username} \
                    ${git_token} \
                    ${name} \
                    ${custom_git_arguments} \
                    ${j}
            )

            if [[ $? -ne 0 ]]; then
                # Note that no log output is needed here,
                # because the function that gets passed to this
                # function should contain a sequence to log and "exit 1"
                # if a failure occurs.
                # Since ${passedFunction} is being run inside its own shell,
                # running "exit 1" in that shell does not quit this script.
                # So it has to be quit here.
                exit 1
            fi
        done
    fi
}

# Used fro Virtual PXE to boot VM based Profile selection
bootProfile() {
    local passedFunction=$1
    local j=$(expr $2 - 1)

    if [ -z "${builder_config_profiles__name+x}" ]; then
        printDatedErrMsg "No Profiles to download"
        logFatalErrMsg "No Profiles to download"
        exit 1
    else
        if [ -z "${builder_config_profiles__git_remote_url[j]+x}" ]; then
            printErrMsg "  Profile does not exist."
            exit;
        fi
        local git_remote_url=${builder_config_profiles__git_remote_url[j]}
        local git_branch_name=${builder_config_profiles__profile_branch[j]}
        local git_base_branch_name=${builder_config_profiles__profile_base_branch[j]}
        local git_username=${builder_config_profiles__git_username[j]:-"None"}
        local git_token=${builder_config_profiles__git_token[j]:-"None"}
        local name=${builder_config_profiles__name[j]}
        local custom_git_arguments=${builder_config_profiles__custom_git_arguments[j]}

        (
            ${passedFunction} \
                ${git_remote_url} \
                ${git_branch_name} \
                ${git_base_branch_name} \
                ${git_username} \
                ${git_token} \
                ${name} \
                ${custom_git_arguments} \
                ${j}
        )

        if [[ $? -ne 0 ]]; then
            # Note that no log output is needed here,
            # because the function that gets passed to this
            # function should contain a sequence to log and "exit 1"
            # if a failure occurs.
            # Since ${passedFunction} is being run inside its own shell,
            # running "exit 1" in that shell does not quit this script.
            # So it has to be quit here.
            exit 1
        fi
    fi
}

# Used for Make USB script
makeUsbProfile() {
    local passedFunction=$1
    local profile_name=$2

    if [ -z "${builder_config_profiles__name+x}" ]; then
        printDatedErrMsg "No Profiles available"
        logFatalErrMsg "No Profiles available"
        exit 1
    else
        for ((j = 0; j < "${#builder_config_profiles__name[@]}"; j += 1)); do

            local git_remote_url=${builder_config_profiles__git_remote_url[j]}
            local git_branch_name=${builder_config_profiles__profile_branch[j]}
            local git_base_branch_name=${builder_config_profiles__profile_base_branch[j]}
            local git_username=${builder_config_profiles__git_username[j]:-"None"}
            local git_token=${builder_config_profiles__git_token[j]:-"None"}
            local name=${builder_config_profiles__name[j]}
            local custom_git_arguments=${builder_config_profiles__custom_git_arguments[j]}

            # if build.sh switch --profile is used 
            if [ "${profile_name}" == "${name}" ]; then
                printBanner "Running USB builder for profile ${name}..."
                logMsg "Running ${passedFunction} for profile ${name}..."
            else
                logMsg "Skipping profile ${name}..."
                continue
            fi

            (
                ${passedFunction} \
                    ${git_remote_url} \
                    ${git_branch_name} \
                    ${git_base_branch_name} \
                    ${git_username} \
                    ${git_token} \
                    ${name} \
                    ${custom_git_arguments} \
                    ${j}
            )

            if [[ $? -ne 0 ]]; then
                # Note that no log output is needed here,
                # because the function that gets passed to this
                # function should contain a sequence to log and "exit 1"
                # if a failure occurs.
                # Since ${passedFunction} is being run inside its own shell,
                # running "exit 1" in that shell does not quit this script.
                # So it has to be quit here.
                exit 1
            fi
        done
    fi
}

syncProfiles() {
    printDatedMsg "${T_BOLD}Clone${T_RESET} profiles"
    profilesActions cloneProfile
    printDatedMsg "${T_BOLD}Reset${T_RESET} profiles"
    profilesActions resetProfile
    printDatedMsg "${T_BOLD}Pull${T_RESET} latest from profiles"
    profilesActions pullProfile

    profilesActions renderProfileTemplates

    if [[ "${SKIP_PROFILE_BUILDS}" == "false" ]]; then
        profilesActions buildProfile
    else
        logMsg "User decided to skip the execution of profile-specific build scripts."
    fi

    # Now we need to download files associated with the profile
    profilesActions downloadProfile
}

startGitea() {
    if docker ps | grep $(basename $(pwd))_mirror_1 > /dev/null; then
        printDatedInfoMsg "Gitea already running"
        logInfoMsg "Gitea already running"
    else 
        local message="Starting Gitea"
        if podman -v >/dev/null 2>&1; then
            run "${message}" \
                "scripts/espctl.sh up mirror && sleep 5" \
                "${LOG_FILE}"
        else
            run "${message}" \
                "docker-compose up -d mirror && sleep 5" \
                "${LOG_FILE}"
        fi
    fi
}