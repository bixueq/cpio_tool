#!/bin/sh
MKFS_RUN="/run/mkfs_run"
MKFS_SH="/usr/local/sbin/parted_lvm_mkfs_disk.sh"
while :
do
if [ -f $MKFS_RUN ]; then
	chmod 777 $MKFS_SH
	$MKFS_SH
	rm -f $MKFS_RUN
fi
sleep 1
done
