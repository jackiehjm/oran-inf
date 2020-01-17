#
# Copyright (C) 2019 Wind River Systems, Inc.
#

FILESEXTRAPATHS_prepend := "${THISDIR}/${BPN}:"

TARGET_SUPPORTED_KTYPES_append_nxp-lx2xxx = " preempt-rt"

SRC_URI_append_nxp-lx2xxx = " \
    file://yp-port-nxp-lx2xxx-CIG-patch-20200116.patch \
"
