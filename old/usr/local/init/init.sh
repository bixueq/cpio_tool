#!/bin/sh
echo "init start ..."
NONRESET=`get_reset`
PARTLABEL="/dev/disk/by-partlabel"
REACH="$PARTLABEL/reach"
LOG="$PARTLABEL/log"
OPT1="$PARTLABEL/lvopt1"
OPT2="$PARTLABEL/lvopt2"
REACH_DIR="/usr/local/reach"
REACHKIT="$REACH_DIR/script/reachkit.sh"
HTML="$REACH_DIR/html"
MINIFS_MD5SUM_F=$REACH_DIR/.minifs_md5sum
MINIFS_MD5SUM=/run/.minifs_md5sum
LOG_DIR="/var/log"
OPT_DIR="/opt"
CHENCKDISK="/usr/local/sbin/check_mkfs.sh"
minifs_md5sum()
{
	echo "start minifs_md5sum ..."
	md5sum /dev/mtd2|awk '{printf("%sminifs@reach.com", $1}'|md5sum|awk '{print $1}' > $MINIFS_MD5SUM
}

minifs()
{
	echo "start minifs ..."
	mkdir -p /run/nginx/logs
	nginx -c /usr/local/etc/nginx/nginx.conf -p /run/nginx&
	fcgiwrap -c 2 -s tcp:127.0.0.1:8081 &
	cgisysctrl&
	chmod 777 $CHENCKDISK
	$CHENCKDISK &
	echo "minifs end."
}

reachapp()
{
	echo "start reachapp ..."
	mkdir -p /var/log/nginx/logs
	cd /usr/local/reach/script;./reachkit.sh
	echo "reachapp init end ."
	exit 0
}

minifs_md5sum_reachapp()
{
	minifs_md5sum
	diff $MINIFS_MD5SUM $MINIFS_MD5SUM_F > /dev/null
	if [ $? == 0 ];then
		reachapp
	else
		echo "ERROR: $MINIFS_MD5SUM $MINIFS_MD5SUM_F"
	fi
}
VGOPT="vgopt"
LVOPT="lvopt"
DISKVG="/dev/$VGOPT"
DISKLV="$DISKVG/$LVOPT"
vgchange -ay $DISKVG
if [[ -L $OPT1 && -L $LOG && -L $REACH && -L $DISKLV ]];then
	echo "mount $REACH $REACH_DIR ..."
	mount $REACH $REACH_DIR
	echo "mount $LOG $LOG_DIR ..."
	mount $LOG $LOG_DIR
	echo "vgchange $VGOPT ..."
	echo "mount $DISKLV $OPT_DIR ..."
	mount $DISKLV $OPT_DIR
	if [ $NONRESET == "1" ];then
		if [[ -f $REACHKIT && -d $HTML ]];then
			reachapp
		else
			echo "ERROR: $REACHKIT OR $HTML not find ."
			ls -l $REACH_DIR
		fi
	else
		echo "RESET ..."
	fi
else
	echo "ERROR: OPT:$OPT1 LOG:$LOG REACH:$REACH DISKVG:$DISKVG"
	ls -l $PARTLABEL
	ls -l $DISKVG
fi
minifs
echo "init end."
