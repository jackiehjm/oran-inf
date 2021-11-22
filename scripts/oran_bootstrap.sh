#!/bin/bash
#
# Copyright (C) 2021 Wind River Systems, Inc.
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

help_info () {
cat << ENDHELP
This script is used to run the StarlingX bootstrap and do pre/post
configurations.
Usage:
$(basename $0) [-w WORKSPACE_DIR] [-n] [-h]
where:
    -w WORKSPACE_DIR is the path for the project
    -n dry-run only for bitbake
    -h this help info
ENDHELP
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

# Default for vbox VM
OAM_DEV="enp0s3"
OAM_NETWORK=10.10.10
OAM_IP=3

STX_MODE="simplex"
STX_PASSWD="Li69nux*"
HTTP_PROXY="http://147.11.252.42:9090"

SCRIPTS_DIR=`dirname $0`
SCRIPTS_DIR=`readlink -f $SCRIPTS_DIR`

while getopts "d:i:m:p:x:h" OPTION; do
    case ${OPTION} in
        d)
            OAM_DEV=${OPTARG}
            ;;
        i)
            OAM_NETWORK=`echo ${OPTARG}|cut -d. -f1-3`
            OAM_IP=`echo ${OPTARG}|cut -d. -f4`
	m)
	    STX_MODE=${OPTARG}
            ;;
        p)
            STX_PASSWD=${OPTARG}
            ;;
        x)
            HTTP_PROXY=${OPTARG}
            ;;
        h)
            help_info
            exit
            ;;
    esac
done


echo_info "Config OAM interface"
export CONTROLLER0_OAM_CIDR=${OAM_NETWORK}.${OAM_IP}/24
export OAM_GATEWAY=${OAM_NETWORK}.1
export FLOATING_IP=${OAM_NETWORK}.${OAM_IP}
sudo ip address add $CONTROLLER0_OAM_CIDR dev $OAM_DEV
sudo ip link set up dev $OAM_DEV
sudo ip route add default via $OAM_GATEWAY dev $OAM_DEV


echo_info "Create localhost.yml"
cat <<EOF > localhost.yml
system_mode: ${STX_MODE}
external_oam_subnet: ${OAM_NETWORK}.0/24
external_oam_gateway_address: ${OAM_NETWORK}.1
external_oam_floating_address: ${FLOATING_IP}

docker_http_proxy: ${HTTP_PROXY}
docker_https_proxy: ${HTTP_PROXY}

admin_password: ${STX_PASSWD}
ansible_become_pass: ${PASSWD}

EOF


