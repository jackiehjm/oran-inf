#!/bin/bash
#
# Copyright (C) 2022 Wind River Systems, Inc.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

# Ensure we fail the job if any steps fail.
set -e -o pipefail

#########################################################################
# Variables
#########################################################################

SRC_ORAN_BRANCH="master"
SRC_STX_BRANCH="r/stx.5.0"

SRC_ORAN_URL="https://gerrit.o-ran-sc.org/r/pti/rtp"

SCRIPTS_DIR=$(dirname $(readlink -f $0))
TIMESTAMP=`date +"%Y%m%d_%H%M%S"`

#########################################################################
# Common Functions
#########################################################################

help_info () {
cat << ENDHELP
Usage:
$(basename $0) [-w WORKSPACE_DIR] [-n] [-u] [-h]
where:
    -w WORKSPACE_DIR is the path for the project
    -n dry-run only for bitbake
    -u update the repo if it exists
    -h this help info
examples:
$0
$0 -w workspace_1234
ENDHELP
}

echo_step_start() {
    [ -n "$1" ] && msg_step=$1
    echo "#########################################################################################"
    echo "## STEP START: ${msg_step}"
    echo "#########################################################################################"
}

echo_step_end() {
    [ -n "$1" ] && msg_step=$1
    echo "#########################################################################################"
    echo "## STEP END: ${msg_step}"
    echo "#########################################################################################"
    echo
}

echo_info () {
    echo "INFO: $1"
}

echo_error () {
    echo "ERROR: $1"
}

echo_cmd () {
    echo
    echo_info "$1"
    echo "CMD: ${RUN_CMD}"
}

#########################################################################
# Parse cmd options
#########################################################################

DRYRUN=""

while getopts "w:b:e:r:unh" OPTION; do
    case ${OPTION} in
        w)
            WORKSPACE=`readlink -f ${OPTARG}`
            ;;
        n)
            DRYRUN="-n"
            ;;
        u)
            SKIP_UPDATE="No"
	    ;;
        h)
            help_info
            exit
            ;;
    esac
done

if [ -z ${WORKSPACE} ]; then
    echo_info "No workspace specified, a directory 'workspace' will be created in current directory as the workspace"
    WORKSPACE=`readlink -f workspace`
fi

#########################################################################
# Functions for each step
#########################################################################
PROJECT=prj_oran_stx_centos
SRC_DIR=${WORKSPACE}/src
PRJ_BUILD_DIR=${WORKSPACE}/${PROJECT}

prepare_workspace () {
    msg_step="Create workspace for the build"
    echo_step_start

    mkdir -p ${PRJ_BUILD_DIR} ${SRC_DIR} 

    echo_info "The following directories are created in your workspace(${WORKSPACE}):"
    echo_info "For all layers source: ${SRC_DIR}"
    echo_info "For StarlingX build project: ${PRJ_BUILD_DIR}"

    echo_step_end
}

create_env () {

    ENV_FILENAME=env.${PROJECT}

    cat <<EOF > ${WORKSPACE}/${ENV_FILENAME}

export LC_ALL=en_US.UTF-8
export PROJECT=${PROJECT}
export SRC_BUILD_ENVIRONMENT=tis-r6-pike
export MY_LOCAL_DISK=${SRC_DIR}
export MY_REPO_ROOT_DIR=\${MY_LOCAL_DISK}
export MY_REPO=\${MY_REPO_ROOT_DIR}/cgcs-root
export CGCSDIR=\${MY_REPO}/stx
export MY_WORKSPACE=${WORKSPACE}/\${PROJECT}
export MY_BUILD_ENVIRONMENT=\${USER}-\${PROJECT}-\${SRC_BUILD_ENVIRONMENT}
export MY_BUILD_ENVIRONMENT_FILE=\${MY_BUILD_ENVIRONMENT}.cfg
export MY_BUILD_ENVIRONMENT_FILE_STD=\${MY_BUILD_ENVIRONMENT}-std.cfg
export MY_BUILD_ENVIRONMENT_FILE_RT=\${MY_BUILD_ENVIRONMENT}-rt.cfg
export MY_BUILD_ENVIRONMENT_FILE_STD_B0=\${MY_WORKSPACE}/std/configs/\${MY_BUILD_ENVIRONMENT}-std/\${MY_BUILD_ENVIRONMENT}-std.b0.cfg
export MY_BUILD_ENVIRONMENT_FILE_RT_B0=\${MY_WORKSPACE}/rt/configs/\${MY_BUILD_ENVIRONMENT}-rt/\${MY_BUILD_ENVIRONMENT}-rt.b0.cfg
export MY_BUILD_DIR=\${WORKSAPCE}/\${PROJECT}
export MY_SRC_RPM_BUILD_DIR=\${MY_BUILD_DIR}/rpmbuild
export MY_BUILD_CFG=\${MY_WORKSPACE}/\${MY_BUILD_ENVIRONMENT_FILE}
export MY_BUILD_CFG_STD=\${MY_WORKSPACE}/std/\${MY_BUILD_ENVIRONMENT_FILE_STD}
export MY_BUILD_CFG_RT=\${MY_WORKSPACE}/rt/\${MY_BUILD_ENVIRONMENT_FILE_RT}
export PATH=\${MY_REPO}/build-tools:\${MY_LOCAL_DISK}/bin:\${CGCSDIR}/stx-update/extras/scripts:\${PATH}
export CGCSPATCH_DIR=\${CGCSDIR}/stx-update/cgcs-patch
export BUILD_ISO_USE_UDEV=1

# WRCP/WRA/WRO do not support layered builds at this time.
export LAYER=""

# StarlingX since 4.0 supports layered builds (compiler, distro, flock) as an option.
# Note: Only flock layer builds an iso at this time.
# Note: You may leave LAYER="", this will build everything, also known as a 'monolithic' build.
# export LAYER=compiler
# export LAYER=distro
# export LAYER=flock

# Upstream issue seems to have been corrected
# export REPO_VERSION="--repo-branch=repo-1"
REPO_VERSION=

# In order to avoid running out of space in your home directory
export XDG_CACHE_HOME=\${MY_LOCAL_DISK}/.cache;
export XDG_DATA_HOME=\${MY_LOCAL_DISK}

#/bin/title "\${HOSTNAME} \${PROJECT}"

alias patch_build=\${MY_REPO}/stx/update/extras/scripts/patch_build.sh

mkdir -p \${MY_REPO_ROOT_DIR}
mkdir -p \${MY_WORKSPACE}

alias cdrepo="cd \$MY_REPO_ROOT_DIR"
alias cdbuild="cd \$MY_BUILD_DIR"

pushd \${MY_REPO_ROOT_DIR}

EOF

    echo "Env file created at $ENV_FILENAME"

}


#########################################################################
# Main process
#########################################################################

prepare_workspace
create_env
