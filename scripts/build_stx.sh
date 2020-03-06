#!/bin/bash
#
# Copyright (C) 2019 Wind River Systems, Inc.
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

SUPPORTED_BSP="intel-corei7-64 qemux86-64 qemuarm64"

SRC_ORAN_BRANCH="master"
SRC_STX_BRANCH="master"
SRC_YP_BRANCH="warrior"

SRC_ORAN_URL="https://gerrit.o-ran-sc.org/r/pti/rtp"

SRC_STX_URL="\
    https://github.com/zbsarashki/meta-stx \
    https://github.com/zbsarashki/meta-starlingX \
"

SRC_YP_URL="\
    git://git.yoctoproject.org/poky \
    git://git.openembedded.org/meta-openembedded \
    git://git.yoctoproject.org/meta-virtualization \
    git://git.yoctoproject.org/meta-cloud-services \
    git://git.yoctoproject.org/meta-security \
    git://git.yoctoproject.org/meta-intel \
    git://git.yoctoproject.org/meta-security \
    git://git.yoctoproject.org/meta-selinux \
    https://github.com/intel-iot-devkit/meta-iot-cloud \
    git://git.openembedded.org/meta-python2 \
    https://git.yoctoproject.org/git/meta-dpdk \
    git://git.yoctoproject.org/meta-anaconda \
"

SUB_LAYER_META_OE="\
    meta-oe \
    meta-perl \
    meta-python \
    meta-networking \
    meta-filesystems \
    meta-webserver \
    meta-initramfs \
    meta-initramfs \
    meta-gnome \
"

SUB_LAYER_META_CLOUD_SERVICES="meta-openstack"
SUB_LAYER_META_SECURITY="meta-security-compliance"

SCRIPTS_DIR=$(dirname $(readlink -f $0))
TIMESTAMP=`date +"%Y%m%d_%H%M%S"`

help_info () {
cat << ENDHELP
Usage:
$(basename $0) <-w WORKSPACE_DIR> [-b BSP] [-n] [-h] [-r Yes|No]
where:
    -w WORKSPACE_DIR is the path for the project
    -b BPS is one of supported BSP: "${SUPPORTED_BSP}"
       (default is intel-corei7-64 if not specified.)
    -n dry-run only for bitbake
    -h this help info
    -e EXTRA_CONF is the pat for extra config file
    -r whether to inherit rm_work (default is Yes)
    -s whether to skip update the repo if already exists
ENDHELP
}

echo_step_start() {
    echo "#########################################################################################"
    echo "## $1"
    echo "#########################################################################################"
}

echo_step_end() {
    echo "###################################### Done #############################################"
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

if [ $# -eq 0 ]; then
    echo "Missing options!"
    help_info
    exit
fi

check_yn_rm_work () {
    yn="$1"
    case ${yn} in
        [Yy]|[Yy]es)
            RM_WORK="Yes"
            ;;
        [Nn]|[Nn]o)
            RM_WORK="No"
            ;;
        *)
            echo "Invalid arg for -r option."
            help_info
            exit 1
            ;;
    esac
}

check_valid_bsp () {
    bsp="$1"
    for b in ${SUPPORTED_BSP}; do
        if [ "${bsp}" == "${b}" ]; then
            BSP_VALID="${bsp}"
            break
        fi
    done
    if [ -z "${BSP_VALID}" ]; then
        echo_error "${bsp} is not a supported BSP, the supported BSPs are: ${SUPPORTED_BSP}"
        exit 1
    fi
}


clone_update_repo () {
    REPO_BRANCH=$1
    REPO_URL=$2
    REPO_NAME=$3

    if [ -d ${REPO_NAME}/.git ]; then
        if [ "${SKIP_UPDATE}" == "Yes" ]; then
            echo_info "The repo ${REPO_NAME} exists, skip updating for the branch ${REPO_BRANCH}"
        else
            echo_info "The repo ${REPO_NAME} exists, updating for the branch ${REPO_BRANCH}"
            cd ${REPO_NAME}
            git checkout ${REPO_BRANCH}
            git pull
            cd -
        fi
    else
        RUN_CMD="git clone --branch ${REPO_BRANCH} ${REPO_URL} ${REPO_NAME}"
        echo_cmd "Cloning the source of repo '${REPO_NAME}':"
        ${RUN_CMD}
    fi
}

if [ $# -eq 0 ]; then
    echo "Missing options!"
    help_info
    exit
fi

DRYRUN=""
EXTRA_CONF=""
SKIP_UPDATE="No"
RM_WORK="Yes"
BSP="intel-corei7-64"

while getopts "w:b:e:r:nsh" OPTION; do
    case ${OPTION} in
        w)
            WORKSPACE=`readlink -f ${OPTARG}`
            ;;
        b)
            check_valid_bsp ${OPTARG}
            ;;
        e)
            EXTRA_CONF=`readlink -f ${OPTARG}`
            ;;
        n)
            DRYRUN="-n"
            ;;
        s)
            SKIP_UPDATE="Yes"
            ;;
        r)
            check_yn_rm_work ${OPTARG}
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

if [ -n "${BSP_VALID}" ]; then
    BSP="${BSP_VALID}"
fi

echo_step_start "Create workspace for the build"

SRC_LAYER_DIR=${WORKSPACE}/src_layers
SRC_ORAN_DIR=${SRC_LAYER_DIR}/oran
PRJ_BUILD_DIR=${WORKSPACE}/prj_oran_stx
SRC_META_PATCHES=${SRC_ORAN_DIR}/rtp/scripts/meta-patches/src_stx


mkdir -p ${PRJ_BUILD_DIR} ${SRC_ORAN_DIR}

echo_info "The following directories are created in your workspace(${WORKSPACE}):"
echo_info "For all layers source: ${SRC_LAYER_DIR}"
echo_info "For build project: ${PRJ_BUILD_DIR}"

echo_step_end

echo_step_start "Get the source code repos"

# Clone the oran layer if it's not already cloned
# Check if the script is inside the repo
if cd ${SCRIPTS_DIR} && git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    CLONED_ORAN_REPO=`dirname ${SCRIPTS_DIR}`
    echo_info "Use the cloned oran repo: ${CLONED_ORAN_REPO}"
    mkdir -p ${SRC_ORAN_DIR}/rtp
    cd ${SRC_ORAN_DIR}/rtp
    rm -rf meta-oran scripts
    ln -sf ${CLONED_ORAN_REPO}/meta-oran meta-oran
    ln -sf ${CLONED_ORAN_REPO}/scripts scripts
else
    echo_info "Cloning oran layer:"
    cd ${SRC_ORAN_DIR}
    clone_update_repo ${SRC_ORAN_BRANCH} ${SRC_ORAN_URL} rtp
fi

# Clone Yocto and StarlingX layers
echo_info "Cloning Yocto and StarlingX layers:"

cd ${SRC_LAYER_DIR}
for layer_url in ${SRC_STX_URL}; do
    layer_name=$(basename ${layer_url})
    clone_update_repo ${SRC_STX_BRANCH} ${layer_url} ${layer_name}
done
for layer_url in ${SRC_YP_URL}; do
    layer_name=$(basename ${layer_url})
    clone_update_repo ${SRC_YP_BRANCH} ${layer_url} ${layer_name}
done

echo_step_end

# Apply meta patches
for l in $(ls -1 ${SRC_META_PATCHES}); do
    echo_step_start "Apply meta patches for ${l}"
    cd ${SRC_LAYER_DIR}/${l}

    # backup current branch
    local_branch=$(git rev-parse --abbrev-ref HEAD)
    git branch -m "${local_branch}_${TIMESTAMP}"
    git checkout ${local_branch}

    for p in $(ls -1 ${SRC_META_PATCHES}/${l}); do
        echo_info "Apllying patch: ${SRC_META_PATCHES}/${l}/${p}"
        git am ${SRC_META_PATCHES}/${l}/${p}
    done
    echo_step_end
done

# Source the build env
echo_step_start "Source the build env"
cd ${SRC_LAYER_DIR}/poky
set ${PRJ_BUILD_DIR}
. ./oe-init-build-env ${PRJ_BUILD_DIR}
echo_step_end

echo_step_start "Add required layers to the build project"

# meta-oran is not compatibel with warrior for now
# Add the meta-oran layer
#cd ${PRJ_BUILD_DIR}
#RUN_CMD="bitbake-layers add-layer ${SRC_ORAN_DIR}/rtp/meta-oran"
#echo_cmd "Add the meta-oran layer into the build project"
#${RUN_CMD}

# Add the Yocto and StarlingX layers
SRC_LAYERS=""
for layer_url in ${SRC_YP_URL} ${SRC_STX_URL}; do
    layer_name=$(basename ${layer_url})
    case ${layer_name} in
    poky)
        continue
        ;;
    meta-openembedded)
        for sub_layer in ${SUB_LAYER_META_OE}; do
            SRC_LAYERS="${SRC_LAYERS} ${SRC_LAYER_DIR}/${layer_name}/${sub_layer}"
        done
        ;;
    meta-cloud-services)
        SRC_LAYERS="${SRC_LAYERS} ${SRC_LAYER_DIR}/${layer_name}"
        for sub_layer in ${SUB_LAYER_META_CLOUD_SERVICES}; do
            SRC_LAYERS="${SRC_LAYERS} ${SRC_LAYER_DIR}/${layer_name}/${sub_layer}"
        done
        ;;
    meta-security)
        SRC_LAYERS="${SRC_LAYERS} ${SRC_LAYER_DIR}/${layer_name}"
        for sub_layer in ${SUB_LAYER_META_SECURITY}; do
            SRC_LAYERS="${SRC_LAYERS} ${SRC_LAYER_DIR}/${layer_name}/${sub_layer}"
        done
        ;;
    *)
        SRC_LAYERS="${SRC_LAYERS} ${SRC_LAYER_DIR}/${layer_name}"
        ;;
        
    esac
done

echo ${SRC_LAYERS}

for src_layer in ${SRC_LAYERS}; do
    RUN_CMD="bitbake-layers add-layer ${src_layer}"
    echo_cmd "Add the ${src_layer} layer into the build project"
    ${RUN_CMD}
done 

echo_step_end

# Add extra configs into local.conf
echo_step_start "Add Add extra configs into local.conf"
cat << EOF >> conf/local.conf
########################
# Configs for StarlingX #
########################

DISTRO = "poky-stx"
MACHINE = "${BSP}"
PREFERRED_PROVIDER_virtual/kernel = "linux-yocto"

EXTRA_IMAGE_FEATURES = " \\
    debug-tweaks \\
    tools-sdk \\
    tools-debug \\
    package-management \\
"

# For anaconda installer
DISTRO_FEATURES_append = " anaconda-support"

# For images
IMAGE_FSTYPES += " tar.bz2 live wic.qcow2"
WKS_FILES = "stx-image-aio.wks"
LABELS_LIVE = "install"

EOF

if [ "${RM_WORK}" == "Yes" ]; then
    echo "INHERIT += 'rm_work'" >> conf/local.conf
fi


if [ "${EXTRA_CONF}" != "" ] && [ -f "${EXTRA_CONF}" ]; then
    cat ${EXTRA_CONF} >> conf/local.conf
fi
echo_step_end

echo_step_start "Build images"

# Build the StarlingX image
mkdir -p logs

RUN_CMD="bitbake ${DRYRUN} stx-image-aio"
echo_cmd "Build the stx-image-aio image"
bitbake ${DRYRUN} stx-image-aio 2>&1|tee logs/bitbake_stx-image-aio_${TIMESTAMP}.log

echo_step_end

echo_info "Build succeeded, you can get the image in ${PRJ_BUILD_DIR}/tmp/deploy/images/intel-corei7-64/stx-image-aio-intel-corei7-64.iso"
