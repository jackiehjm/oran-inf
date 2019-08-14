FILESEXTRAPATHS_prepend := "${THISDIR}/${BPN}:"

SRC_URI_append = " \
    file://0001-timers-Don-t-wake-ktimersoftd-on-every-tick.patch \
    file://0002-timers-Don-t-search-for-expired-timers-while-TIMER_S.patch \
"
