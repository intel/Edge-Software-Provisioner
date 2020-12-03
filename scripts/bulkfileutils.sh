#!/bin/bash

# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

# This file contains functions that are intended to trigger the downloading
# or management of potentially large numbers of files. Functions in this file
# typically run functions from fileutils.sh in looped constructs.

# If running this file alone, uncomment these lines
# source "textutils.sh"
# source "yamlparse.sh"
# source "fileutils.sh"
# It's probably a good idea to run this as well:
# parseProfileFilesYml "${WEB_PROFILE}/${profileName}/conf/files.yml"

downloadBaseOSFiles() {
    local profileName=$1
    if [ -z "${files_config_base_os_files__url+x}" ]; then
        printDatedMsg "  ${T_INFO_ICON} No Base OS Files to download"
        logMsg "No Base OS Files to download"
    else
        for ((j = 0; j < "${#files_config_base_os_files__url[@]}"; j += 1)); do
            local url=${files_config_base_os_files__url[j]}
            local filename=${files_config_base_os_files__filename[j]}

            downloadBaseOSFile \
                "  Downloading: ${filename}" \
                "${url}" \
                "${profileName}" \
                "${filename}"
        done
    fi
}

downloadGeneralFiles() {
    local profileName=$1
    if [ -z "${files_config_general_files__url+x}" ]; then
        printDatedMsg "  ${T_INFO_ICON} No General Files to download"
        logMsg "No General Files to download"
    else
        umountAllISO "${WEB_FILES}/${profileName}"
        for ((j = 0; j < "${#files_config_general_files__url[@]}"; j += 1)); do
            local url=${files_config_general_files__url[j]}
            local destination_file=${files_config_general_files__destination_file[j]}
            local token=${files_config_general_files__token[j]}

            downloadPublicFile "  Downloading file ${url} to ${destination_file}" \
                ${url} \
                "${WEB_FILES}/${profileName}" \
                ${destination_file} \
                ${token}

            if [ -n "${files_config_general_files__mount_iso_path[j]+x}" ]; then
                local iso=${WEB_FILES}/${profileName}/${destination_file}
                local mount_iso_path=${WEB_FILES}/${profileName}/${files_config_general_files__mount_iso_path[j]}

                validateInput dirname "${mount_iso_path}" "'mount_iso_path' in files.yml of profile ${profileName} is not valid directory path: ${mount_iso_path}"

                mountISO ${iso} ${mount_iso_path}
            fi
        done
    fi
}

downloadS3Files() {
    local profileName=$1
    if [ -z "${files_config_s3_files__object+x}" ]; then
        printDatedMsg "  ${T_INFO_ICON} No S3 Files to download"
        logMsg "No S3 Files to download"
    else
        umountAllISO "${WEB_FILES}/${profileName}"
        for ((j = 0; j < "${#files_config_s3_files__object[@]}"; j += 1)); do
            local aws_access_key=${files_config_s3_files__aws_access_key[j]}
            local aws_secret_key=${files_config_s3_files__aws_secret_key[j]}
            local aws_region=${files_config_s3_files__aws_region[j]}
            local bucket=${files_config_s3_files__bucket[j]}
            local object=${files_config_s3_files__object[j]}
            local destination_file=${files_config_s3_files__destination_file[j]}

            downloadS3File "  Downloading AWS S3 object ${object} to ${WEB_FILES}/${profileName}/${destination_file}" \
                "${aws_region}" \
                "${aws_access_key}" \
                "${aws_secret_key}" \
                "${bucket}" \
                "${object}" \
                "${WEB_FILES}/${profileName}" \
                "${destination_file}"

            if [ -n "${files_config_s3_files__mount_iso_path[j]+x}" ]; then
                local iso=${WEB_FILES}/${profileName}/${destination_file}
                local mount_iso_path=${WEB_FILES}/${profileName}/${files_config_s3_files__mount_iso_path[j]}

                validateInput dirname "${mount_iso_path}" "'mount_iso_path' in files.yml of profile ${profileName} is not valid directory path: ${mount_iso_path}"

                mountISO ${iso} ${mount_iso_path}
            fi
        done
    fi
}

downloadPublicDockerImages() {
    local profileName=$1
    if [ -z "${files_config_public_docker_images__image+x}" ]; then
        printDatedMsg "  ${T_INFO_ICON} No Public Docker Images to download"
        logMsg "No Public Docker Images to download"
    else
        for ((j = 0; j < "${#files_config_public_docker_images__image[@]}"; j += 1)); do
            local image=${files_config_public_docker_images__image[j]}
            local tag=${files_config_public_docker_images__tag[j]}
            local destination_file=${files_config_public_docker_images__destination_file[j]}

            downloadPublicDockerImage \
                "${image}" \
                "${tag}" \
                "${WEB_FILES}/${profileName}/${destination_file}"
        done
    fi
}

downloadPrivateDockerAWSImages() {
    local profileName=$1
    if [ -z "${files_config_private_docker_aws_images__image+x}" ]; then
        printDatedMsg "  ${T_INFO_ICON} No Private Docker AWS Images to download"
        logMsg "No Private Docker AWS Images to download"
    else
        for ((j = 0; j < "${#files_config_private_docker_aws_images__image[@]}"; j += 1)); do
            local image=${files_config_private_docker_aws_images__image[j]}
            local docker_registry=${files_config_private_docker_aws_images__docker_registry[j]}
            local aws_access_key=${files_config_private_docker_aws_images__aws_access_key[j]}
            local aws_secret_key=${files_config_private_docker_aws_images__aws_secret_key[j]}
            local aws_region=${files_config_private_docker_aws_images__aws_region[j]}
            local aws_registry=${files_config_private_docker_aws_images__aws_registry[j]}
            local tag=${files_config_private_docker_aws_images__tag[j]}
            local destination_file=${files_config_private_docker_aws_images__destination_file[j]}

            # Log in to the AWS ECR
            $(
                docker run --rm \
                    --env AWS_ACCESS_KEY_ID=${aws_access_key} \
                    --env AWS_SECRET_ACCESS_KEY=${aws_secret_key} \
                    --env AWS_DEFAULT_REGION=${aws_region} \
                    builder-aws-cli \
                    sh -c "${AWS_CLI_PROXY} aws ecr get-login --registry-id ${aws_registry}" | sed "s/\-e\ none//g"
            )

            # Not all parameters are required to be passed in to
            # this function since we are already logged in
            downloadPrivateDockerImage \
                "${docker_registry}" \
                "None" \
                "None" \
                "${image}" \
                "${tag}" \
                "${WEB_FILES}/${profileName}/${destination_file}" \
                "Y"
        done
    fi
}

downloadPrivateDockerRegistryImages() {
    local profileName=$1
    if [ -z "${files_config_private_docker_registry_images__image+x}" ]; then
        printDatedMsg "  ${T_INFO_ICON} No Private Docker Images to download"
        logMsg "No Private Docker Images to download"
    else
        for ((j = 0; j < "${#files_config_private_docker_registry_images__image[@]}"; j += 1)); do
            local image=${files_config_private_docker_registry_images__image[j]}
            local tag=${files_config_private_docker_registry_images__tag[j]}
            local destination_file=${files_config_private_docker_registry_images__destination_file[j]}
            local docker_registry=${files_config_private_docker_registry_images__docker_registry[j]}
            local docker_username=${files_config_private_docker_registry_images__docker_username[j]}
            local docker_password=${files_config_private_docker_registry_images__docker_password[j]}

            downloadPrivateDockerImage \
                "${docker_registry}" \
                "${docker_username}" \
                "${docker_password}" \
                "${image}" \
                "${tag}" \
                "${WEB_FILES}/${profileName}/${destination_file}" \
                ''
        done
    fi
}

mirrorGitRepos() {
    local profileName=$1
    if [ -z "${files_config_git_repos__git_url+x}" ]; then
        printDatedMsg "  ${T_INFO_ICON} No Git Repos to mirror"
        logMsg "No Git Repos to mirror"
    else
        for ((j = 0; j < "${#files_config_git_repos__git_url[@]}"; j += 1)); do
            local url=${files_config_git_repos__git_url[j]}
            validateInput url "${url}" "'git_url' in files.yml of profile ${profileName} is not valid URL: ${url}"

            if [ -z "${files_config_git_repos__git_branch[j]+x}" ]; then
                local branch=""
            else
                local branch=${files_config_git_repos__git_branch[j]}
            fi
            if [ -z "${files_config_git_repos__git_username[j]+x}" ]; then
                local username=""
            else
                local username=${files_config_git_repos__git_username[j]}
            fi
            if [ -z "${files_config_git_repos__git_passowrd_or_token[j]+x}" ]; then
                local token=""
            else
                local token=${files_config_git_repos__git_passowrd_or_token[j]}
            fi
            if [ -z "${files_config_git_repos__custom_git_arguments[j]+x}" ]; then
                local args=""
            else
                local args=${files_config_git_repos__custom_git_arguments[j]}
            fi
            if [ -z "${files_config_git_repos__mirror_repo_name[j]+x}" ]; then
                local repo_name=""
            else
                local repo_name=${files_config_git_repos__mirror_repo_name[j]}
                validateInput filename "${repo_name}" "'mirror_repo_name' in files.yml of profile ${profileName} is not valid. The only characters allowed are a-z, A-Z, 0-9, - and _: ${repo_name}"
            fi

            mirrorGitRepo \
                "${url}" \
                "${branch}" \
                "${username}" \
                "${token}" \
                "${args}" \
                "${repo_name}" \
                "${profileName}"
        done
    fi
}

processBuilds() {
    local profileName=$1
    if [ -z "${files_config_build__container+x}" ]; then
        printDatedMsg "  ${T_INFO_ICON} No Build Process to execute"
        logMsg "No Build Process to execute"
    else
        for ((j = 0; j < "${#files_config_build__container[@]}"; j += 1)); do
            if [ -z "${files_config_build__container[j]+x}" ]; then
                local container="ubuntu:latest"
            else
                local container=${files_config_build__container[j]}
                validateInput container "${container}" "'container' in files.yml of profile ${profileName} is not valid container name: ${container}"
            fi
            if [ -z "${files_config_build__entrypoint[j]+x}" ]; then
                local entrypoint=""
            else
                local entrypoint="--entrypoint=\"${files_config_build__entrypoint[j]}\""
            fi
            if [ -z "${files_config_build__cmd[j]+x}" ]; then
                local cmd="sh -c"
            else
                local cmd=${files_config_build__cmd[j]}
            fi
            if [ -z "${files_config_build__execute[j]+x}" ]; then
                local execute=""
                local cmd=""
            else
                local execute=${files_config_build__execute[j]}
                validateInput filename "${execute}" "'execute' in 'build' section of files.yml of profile ${profileName} is not valid. The only characters allowed are a-z, A-Z, 0-9, ., - and _: ${execute}"
                if [ ! -f ${WEB_PROFILE}/${profileName}/build/${execute} ]; then
                    printErrMsg "  ${T_INFO_ICON} No build script to execute in the profile: ${WEB_PROFILE}/${profileName}/build/${execute}"
                    logMsg "No build script to execute in the profile: ${WEB_PROFILE}/${profileName}/build/${execute}"
                    exit
                fi
                cmd="${cmd} \"/opt/build/${execute}\""
            fi

            if [ ! -d ${WEB_PROFILE}/${profileName}/build ]; then
                printErrMsg "  ${T_INFO_ICON} No build directory in the profile: ${WEB_PROFILE}/${profileName}/build"
                logMsg "No build directory in the profile: ${WEB_PROFILE}/${profileName}/build"
                exit
            fi

            processBuild \
                "${container}" \
                "${entrypoint}" \
                "${cmd}" \
                "${profileName}"
        done
    fi
}
