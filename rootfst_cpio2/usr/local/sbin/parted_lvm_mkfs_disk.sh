#!/bin/sh
MOPT="/opt"
MLOG="/var/log"
MREACH="/usr/local/reach"
PARTLABEL="/dev/disk/by-partlabel"
OPT="$PARTLABEL/lvopt1"
OPT2="$PARTLABEL/lvopt2"
LOG="$PARTLABEL/log"
REACH="$PARTLABEL/reach"
DISKA="/dev/sda"
DISKA1="/dev/sda1"
DISKA2="/dev/sda2"
DISKA3="/dev/sda3"
DISKB="/dev/sdb"
DISKB1="/dev/sdb1"
VGOPT="vgopt"
LVOPT="lvopt"
DISKLV="/dev/$VGOPT/$LVOPT"
ATADISKB=`parted -lm|awk -F"[ :]" '/sdb/{print $7}'`
DISKSUCCESS="/run/mkfsDiskSuccess"
DISKFAIL="/run/mkfsDiskFail"
check_fuser_kill()
{
	MR=`find $1 -type d`
	if [ "$MR" != "" ];then
		echo $MR
		RF=`echo $MR|xargs fuser`
		if [ "$RF" != "" ];then
			echo $RF
			echo $RF|xargs kill -9
		fi
	fi
}
n=1;                                                            
while :                                                         
do 
	killall -9 syslogd klogd udevd
#	check_fuser_kill $MREACH
#	check_fuser_kill $MLOG
#	check_fuser_kill $MOPT
	nice -n -20 umount $MREACH
	nice -n -20 umount $MLOG
	nice -n -20 umount $MOPT

	nice -n -20 dd if=/dev/zero of=$DISKA bs=512K count=1
	partprobe
	nice -n -20 parted $DISKA -s mklabel gpt 
	nice -n -20 parted $DISKA -s -- mkpart reach 2048s 10GB 
	nice -n -20 parted $DISKA -s -- mkpart log 10GB 25GB
	nice -n -20 parted $DISKA -s -- mkpart lvopt1 25GB -1 
	nice -n -20 dd if=/dev/zero of=$OPT bs=512K count=10
	partprobe
	if [[ -b "$DISKB" && $ATADISKB == "ATA" ]];then
		nice -n -20 dd if=/dev/zero of=$DISKB bs=512K count=1
		partprobe
		nice -n -20 parted /dev/sdb -s mklabel gpt
		nice -n -20 parted /dev/sdb -s -- mkpart lvopt2 2048s -1
		nice -n -20 dd if=/dev/zero of=$OPT2 bs=512K count=10

		partprobe
		nice -n -20 pvcreate -y $DISKA3 $DISKB1
		nice -n -20 vgcreate -y -s 16384m $VGOPT $DISKA3 $DISKB1
	else
		nice -n -20 pvcreate -y $DISKA3
		nice -n -20 vgcreate -y -s 16384m $VGOPT $DISKA3
	fi
	FREEPE=`vgdisplay|awk '/Free/{print $5}'`
	nice -n -20 lvcreate -y -n $LVOPT -l $FREEPE $VGOPT
	partprobe
	if [[ $n -eq 2 || -L $DISKLV ]]; then
		echo "$DISKLV ..."
		break                                             
	fi                                                         
	n=`expr $n + 1`  
done
nice -n -20 mkfs.ext4 -m 0 -F $DISKA1
nice -n -20 mkfs.ext4 -m 0 -F $DISKA2
nice -n -20 mkfs.ext4 -m 0 -F $DISKLV
udevd&
VGOK=`vgdisplay | wc -l`
if [ $VGOK -eq 0 ]; then
	touch $DISKFAIL
	exit 1
fi
i=1;
while :
do
	sleep 3
	partprobe
	if [[ -L $LOG && -L $REACH && -L $DISKLV ]];then
		mkdir -p /usr/local/reach
		nice -n -20 mount $REACH $MREACH
		mkdir -p /var/log
		nice -n -20 mount $LOG $MLOG
		mkdir -p /var/log/recserver
		mkdir -p /opt
		nice -n -20 mount $DISKLV /opt
		mkdir -p /opt/Rec
		chmod 755 /opt/Rec -R
		chmod 755 /var/log -R
		chmod 755 /usr/local/reach -R
		touch $DISKSUCCESS
		exit 0
	else
		echo "ERROR: OPT:$OPT LOG:$LOG REACH:$REACH DISKLV:$DISKLV"
		ls -l $PARTLABEL $DISKLV
		if [ $i -eq 3 ]; then	
			touch $DISKFAIL
			exit 1
		fi
		i=`expr $i + 1`
	fi
done
