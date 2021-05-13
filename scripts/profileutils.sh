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
            local git_current_remote_url=$(docker run --rm ${DOCKER_RUN_ARGS} -v ${WEB_PROFILE}/${base_name}:/tmp/profiles -w /tmp/profiles builder-git git remote get-url --all origin)
            local git_current_branch_name=$(docker run --rm ${DOCKER_RUN_ARGS} -v ${WEB_PROFILE}/${base_name}:/tmp/profiles -w /tmp/profiles builder-git git rev-parse --abbrev-ref HEAD)
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
            "docker run --rm --privileged ${DOCKER_RUN_ARGS} ${docker_ssh_args-} -v ${WEB_PROFILE}/${name}:/tmp/profiles/${name} -w /tmp/profiles/${name} builder-git sh -c 'git fetch origin ${git_branch_name} && git reset --hard origin/${git_branch_name} && git pull origin ${git_branch_name}'" \
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
                "docker run --rm --privileged ${DOCKER_RUN_ARGS} ${docker_ssh_args-} -v ${WEB_PROFILE}/${base_name}:/tmp/profiles/${base_name} -w /tmp/profiles/${base_name} builder-git sh -c 'git fetch origin ${git_base_branch_name} && git reset --hard origin/${git_base_branch_name} && git pull origin ${git_base_branch_name}'" \
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
            printDatedMsg "(1/8) Downloading ${name} ${C_MAGENTA}Base OS Files..."
            downloadBaseOSFiles ${name}
            printDatedMsg "(2/8) Downloading ${name} ${C_MAGENTA}General Files..."
            downloadGeneralFiles ${name}
            printDatedMsg "(3/8) Downloading ${name} ${C_MAGENTA}S3 Files..."
            downloadS3Files ${name}
            printDatedMsg "(4/8) Downloading ${name} ${C_MAGENTA}Public Docker Registry Files..."
            downloadPublicDockerImages ${name}
            printDatedMsg "(5/8) Downloading ${name} ${C_MAGENTA}Private Docker Registry Files..."
            downloadPrivateDockerRegistryImages ${name}
            printDatedMsg "(6/8) Downloading ${name} ${C_MAGENTA}Docker AWS Files..."
            downloadPrivateDockerAWSImages ${name}
            printDatedMsg "(7/8) ${C_MAGENTA}Mirroring Git Repos${T_RESET} for ${name}..."
            mirrorGitRepos ${name}
            if [[ "${SKIP_PROFILE_BUILDS}" == "false" ]]; then
                printDatedMsg "(8/8) ${C_MAGENTA}Building custom files${T_RESET} for ${name}..."
                processBuilds ${name}
            else
                printDatedMsg "(8/8) Skipping building custom files for ${name}..."
                logMsg "User decided to skip the execution of profile-specific build scripts for ${name}."
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
    local name=$6
    local base_name=${6}_base
    local custom_git_arguments=$7
    local iteration=$8

    custom_git_arguments=$(validateEmptyInput ${custom_git_arguments})
    git_username=$(validateEmptyInput ${git_username})
    git_token=$(validateEmptyInput ${git_token})

    local commandToRun="${WEB_PROFILE}/${name}/build.sh"
    if [ -f  ${commandToRun} ]; then
        printDatedMsg "  Running build.sh for profile ${C_GREEN}${name}${T_RESET}"
        logInfoMsg "  Running build.sh for profile ${name}"

        # we now run the build.sh and pass in the "${WEB_PROFILE}/${name}/"
        # this helps if we have to figure out where our profile is stored
        # we also pass in "${WEB_FILES}/${name} so that the build script
        # can download / generate files and make them available"
        eval "${commandToRun}" "${WEB_PROFILE}/${name}/" "${WEB_FILES}/${name}" |& tee -a "${LOG_FILE}"
        returnCode=${PIPESTATUS[0]}


        if [ ${returnCode} -eq 0 ]; then
            printDatedOkMsg "  Success running build.sh for profile ${C_GREEN}${name}${T_RESET}"
            logOkMsg "  Success running build.sh for profile ${name}"
        else
            printDatedErrMsg "  build.sh for profile ${name} returned error code ${returnCode}"
            if [ ! -x "${commandToRun}" ]; then
                printDatedMsg "  is ${name}/build.sh executable?"
                logErrMsg "  is ${name}/build.sh executable?"
            fi

            logFatalErrMsg "  build.sh for profile ${name} returned error code ${returnCode}"
            # the logFatalErrMsg will automatically exit and preview the log
        fi
    else
        printDatedMsg "  No build.sh found for profile ${C_GREEN}${name}${T_RESET}, skipping"
        logInfoMsg "  No build.sh found for profile ${name}, skipping"
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
    kernelFilename=$(getKernelFromProfileFilesYml)
    initrdFilename=$(getInitrdFromProfileFilesYml)

    if [[ "${profileContainsKernelAndInitrd}" == "true" ]]; then
        local kernelPath="http://@@HOST_IP@@/tftp/images/${name}/${kernelFilename}"
        addLineToPxeMenu "\"    KERNEL ${kernelPath}\""
        kernelArgs="initrd=http://@@HOST_IP@@/tftp/images/${name}/${initrdFilename} ${kernelArgs}"
    else
        # Use utility os (UOS).
        local kernelPath="http://@@HOST_IP@@/tftp/images/uos/vmlinuz"
        addLineToPxeMenu "\"    KERNEL ${kernelPath}\""
        kernelArgs="${uosInitrdKernelArg} ${kernelArgs}"
    fi

    if [[ -n "${profile_config_kernel_arguments-}" ]]; then
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
    kernelFilename=$(getKernelFromProfileFilesYml)
    initrdFilename=$(getInitrdFromProfileFilesYml)

    if [[ "${profileContainsKernelAndInitrd}" == "true" ]]; then
        local kernelPath="data/srv/tftp/images/${name}/${kernelFilename}"
        local initrdPath="data/srv/tftp/images/${name}/${initrdFilename}"
    else
        # Use utility os (UOS).
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

    logMsg "Booting ${name} profile with Virtual PXE."

    logMsg "Running command: docker run -it --rm --privileged --net host --name vpxe -v $(pwd)/output/${name}:/uos:shared uosbuilder:$(docker images | grep uosbuilder | awk '{print $2}') -c \"linuxkit -v run qemu -mem ${MEMORY} -disk file=/uos/vdisk.${DISK_FORMAT},size=${DISK_SIZE}G,format=${DISK_FORMAT} /uos/uos\""
    
    docker run -it --rm --privileged --net host --name vpxe -v $(pwd)/output/${name}:/uos:shared uosbuilder:$(docker images | grep uosbuilder | awk '{print $2}') -c "linuxkit -v run qemu -mem ${MEMORY} -disk file=/uos/vdisk.${DISK_FORMAT},size=${DISK_SIZE}G,format=${DISK_FORMAT} /uos/uos"

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
        printDatedErrMsg "No Profiles to download"
        logFatalErrMsg "No Profiles to download"
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
            if [ ! -z "${SINGLE_PROFILE}" ] && [ "${passedFunction}" != "genProfilePxeMenu" ]; then
                if [ "${SINGLE_PROFILE}" == "${name}" ]; then
                    # found profile name and will continue to sync
                    printBanner "Running ${passedFunction} for profile ${name}..."
                else
                    printBanner "Skipping profile ${name}..."
                    logMsg "Skipping profile ${name}..."
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
