#!/bin/sh

NAME=sysmonitor
APP_PATH=/usr/share/$NAME
SYSLOG='/var/log/sysmonitor.log'

echolog() {
	local d="$(date "+%Y-%m-%d %H:%M:%S")"
	echo -e "$d: $*" >>$SYSLOG
	number=$(cat $SYSLOG|wc -l)
	[ $number -gt 25 ] && sed -i '1,10d' $SYSLOG
}

mask() {
    num=$((4294967296 - 2 ** (32 - $1)))
    for i in $(seq 3 -1 0); do
        echo -n $((num / 256 ** i))
        num=$((num % 256 ** i))
        if [ "$i" -eq "0" ]; then
            echo
        else
            echo -n .
        fi
    done
}

uci_get_by_name() {
	local ret=$(uci get $1.$2.$3 2>/dev/null)
	echo ${ret:=$4}
}

uci_get_by_type() {
	local ret=$(uci get $1.@$2[0].$3 2>/dev/null)
	echo ${ret:=$4}
}

uci_set_by_name() {
	uci set $1.$2.$3=$4 2>/dev/null
	uci commit $1
}

uci_set_by_type() {
	uci set $1.@$2[0].$3=$4 2>/dev/null
	uci commit $1
}

ping_url() {
	local url=$1
	for i in $( seq 1 3 ); do
		status=$(ping -c 1 -W 1 $url | grep -o 'time=[0-9]*.*' | awk -F '=' '{print$2}'|cut -d ' ' -f 1)
		[ "$status" == "" ] && status=0
		[ "$status" != 0 ] && break
	done
	echo $status
}


getip() {
	echo $(ip -o -4 addr list br-lan | cut -d ' ' -f7 | cut -d'/' -f1)

}

getip6() {
	echo $(ip -o -6 addr list br-lan | cut -d ' ' -f7 | cut -d'/' -f1 |head -n1)
}

getgateway() {
	echo $(route |grep default|sed 's/default[[:space:]]*//'|sed 's/[[:space:]].*$//')
}

unftp() {
	name=$(ls -F /var/ftp|grep '/$'|sed '/upload/d')
	for n in $name
	do
		umount $n
		rmdir /var/ftp/$n 
	done
}

lighttpd() {
	ip=$(ip -o -4 addr list br-lan | cut -d ' ' -f7|cut -d'/' -f1)
cat > /mnt/.index.htm <<EOF
<HTML>
      <HEAD>
      <META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=gb2312" />
      <META HTTP-EQUIV="refresh" CONTENT="0;url=http://$ip:8080/" />
      </HEAD>
</HTML>
EOF
	echo $ip > /www/ip.html
	ipv6=$(ip -o -6 addr list br-lan | cut -d ' ' -f7 | cut -d'/' -f1 |head -n1)
	echo $ipv6 > /www/ip6.html
	sed -i '/\$SERVER\["socket"]/d' /etc/lighttpd/lighttpd.conf
	sed -i '/server.network-backend/a\$SERVER["socket"] == "[sqmshcn]:80" {}' /etc/lighttpd/lighttpd.conf
	sed -i  "s|sqmshcn|$ipv6|" /etc/lighttpd/lighttpd.conf
	/etc/init.d/lighttpd restart &
	echolog "Update ip6: "$ipv6
}

samba() {
	syspath='/mnt'
	syssd=$(ls -F $syspath|grep '/$'| grep 'sd[a-z][1-9]')
	[ "$syssd" == "" ] && {
		status=$(cat /var/log/sysmonitor.log|sed '/^[  ]*$/d'|sed -n '$p'|grep "No usb devices finded! please insert")
		[ ! -n "$status"  ] &&  echolog "No usb devices finded! please insert ..."
		unftp
		/etc/init.d/nfs restart
		/etc/init.d/samba4 restart
		exit
	}
#	syspath=$syspath/$syssd
#	name=$(ls $syspath |sed '/System Volume/d')
#	[ "$name" == "" ] && {
#		status=$(cat /var/log/sysmonitor.log|sed '/^[  ]*$/d'|sed -n '$p'|grep "No samba/nfs share directory")
#		[ ! -n "$status"  ] &&  echolog "No samba/nfs/vsftpd share directory..."
#		unftp
#		/etc/init.d/nfs restart
#		/etc/init.d/samba4 restart
#		exit
#	}
unftp
echo "" > /etc/config/nfs
sed -i '/sambashare/,$d' /etc/config/samba4
for m in $syssd
do

name=$(ls $syspath/$m |sed '/lost+found/d')
for n in $name
do
if [ -d "$syspath/$m$n" ]; then
cat >> /etc/config/samba4 <<EOF
config sambashare
	option name '$n'
	option path '$syspath/$m$n'
	option read_only 'no'
	option guest_ok 'yes'
	option dir_mask '0777'
	option create_mask '0777'
	option timemachine '1'
	option inherit_owner 'yes'

EOF
	echolog "Samba4 name: ["$n"]        path:["$syspath/$m$n"]"
cat >> /etc/config/nfs <<EOF
config share
	option clients '*'
	option options 'rw,sync,root_squash,all_squash,insecure,no_subtree_check'
	option enabled '1'
	option path '$syspath/$m$n'

EOF
	echolog "NFS path: ["$syspath/$m$n"]"
fi
done
	[ ! -d /var/ftp/$m ] && {
	mkdir /var/ftp/$m
	mount --bind $syspath/$m /var/ftp/$m
	}
	echolog "Vsftpd path: ["$syspath/$m"]"
done
	#[ ! -d "/var/ftp/upload" ] && mkdir /var/ftp/upload
	#chmod 777 /var/ftp/upload
	/etc/init.d/samba4 restart &
	/etc/init.d/vsftpd restart &
	/etc/init.d/nfs restart &
}


arg1=$1
shift
case $arg1 in

lighttpd)
	lighttpd
	;;
samba)
	samba
	;;
getip)
	getip
	;;
getip6)
	getip6
	;;
getgateway)
	getgateway
	;;
esac
