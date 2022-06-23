#!/bin/bash

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
		umount /var/ftp/$n
		rmdir /var/ftp/$n 
	done
}

lighttpd() {
	ip=$(ip -o -4 addr list br-lan | cut -d ' ' -f7|cut -d'/' -f1)
	ip6=$(ip -o -6 addr list br-lan | cut -d ' ' -f7 | cut -d'/' -f1 |head -n1)
	if [ -n "$ip6" ]; then
		echo $ip6 > /www/ip6.html
		dnsname="music111.ddnsfree.com"
		sed -i '/\$SERVER\["socket"]/d' /etc/lighttpd/lighttpd.conf
		sed -i '/server.network-backend/a\$SERVER["socket"] == "[sqmshcn]:80" {}' /etc/lighttpd/lighttpd.conf
		sed -i  "s|sqmshcn|$ip6|" /etc/lighttpd/lighttpd.conf
		/etc/init.d/lighttpd restart &
		echolog "Update ip6: "$ip6
		sed -i "/$dnsname/d" /etc/hosts
		echo $ip6' '$dnsname >> /etc/hosts
		/etc/init.d/dnsmasq restart &
		[ $(uci_get_by_name $NAME sysmonitor samba 0) == 1 ] && /etc/init.d/samba4 restart &
	else
		ip6=$ip
		echo "" > /www/ip6.html
	fi
	echo $ip > /www/ip.html
cat > /mnt/.index.htm <<EOF
<!DOCTYPE html>
<html>
<head>
<style>
table, td {
 	border: 1px solid black;
	text-align :center;
}
</style>
</head>
<script>
		var time = 9 ;
		function showTime (){	
			time--;
			if(time<=0){
				//clearInterval(id);
				location.href = "http://[$ip6]:8080";
			}
			var sp = document.getElementById("time");
			sp.innerHTML = "after " +time+ " select outside(ip6) network";
		}
		var id = setInterval(showTime,1000);	
</script>

<body>
<h2 align="center">Selecr network to manager</h2>
<h2 align="center" id = "time">after 9 select outside(ip6) network</h2>
<table style="width:50%" align="center">
  <tr>
    <td><a href="http://$ip:8080/">Inside(ip4) network</a></td>
    <td><a href="http://[$ip6]:8080/">Outside(ip6) network</a></td>
  </tr>
</table>
</body>
</html>
EOF
}

minidlna_chk() {
	str=$(uci_get_by_name $NAME sysmonitor minidlna_dir 0)','
	str=$(echo $str|sed 's/,,/,/g')
	num=$(echo $str|awk -F"," '{print NF-1}')
	a=1
	while [ $a -le $num ]
	do
 	  	dir=$(echo $str|cut -d',' -f $a)
		[ $dir == $1 ] && {
			echo $1
			exit
		}
   		a=`expr $a + 1`
	done
	echo ""
}

check_dir() {
	str=$(uci_get_by_name $NAME sysmonitor $1 0)','
	str=$(echo $str|sed 's/,,/,/g')
	num=$(echo $str|awk -F"," '{print NF-1}')
	a=1
	while [ $a -le $num ]
	do
 	  	dir=$(echo $str|cut -d',' -f $a)
		[ $dir == $2 ] && {
			echo $2
			exit
		}
   		a=`expr $a + 1`
	done
	echo ""
}

samba() {
	[ -f /tmp/music ] && exit
	touch /tmp/music
	[ ! -d /var/ftp ] && {
		mkdir /var/ftp
		mkdir /var/ftp/upload
		touch /var/ftp/welcome	
	}

	syspath='/mnt'
	unftp
	echo "" >/etc/config/nfs
	sed -i '/sambashare/,$d' /etc/config/samba4
	if [ $(uci_get_by_name $NAME sysmonitor samba 0) == 0 ]; then
		echolog "Samba stop....."
		/etc/init.d/samba stop &
	fi
	if [ $(uci_get_by_name $NAME sysmonitor nfs 0) == 0 ]; then
		echolog "NFS stop......"
		/etc/init.d/nfsd stop
		/etc/init.d/nfs stop &
	else
		/etc/init.d/nfsd start
	fi
	if [ $(uci_get_by_name $NAME sysmonitor ftp 0) == 0 ]; then
		echolog "FTP stop......"
		/etc/init.d/vsftpd stop &
	fi
	if [ $(uci_get_by_name $NAME sysmonitor minidlna 0) == 0 ]; then
		echolog "Minidlna stop......"
		/etc/init.d/minidlna stop &
	fi
	syssd=$(ls -F $syspath|grep '/$'| grep 'sd[a-z][1-9]')
	[ "$syssd" == "" ] && {
		status=$(cat /var/log/sysmonitor.log|sed '/^[  ]*$/d'|sed -n '$p'|grep "No Shares finded! please mount samba/cifs shares ...")
		[ ! -n "$status"  ] &&  echolog "No Shares finded! please mount samba/cifs shares ..."
		rm /tmp/music
		exit
	}
sed -i '/media_dir/d' /etc/config/minidlna

for m in $syssd
do

name=$(ls $syspath/$m |sed '/lost+found/d')
for n in $name
do
if [ -d "$syspath/$m$n" ]; then
	[ $(uci_get_by_name $NAME sysmonitor samba 0) == 1 ] && {
	right=$(uci_get_by_name $NAME sysmonitor samba_rw 0)
	if [ $right == 0 ]; then
		right='yes'
		status=$(check_dir samba_rw_dir $n)
		[ -n "$status" ] && right='no'
	else
		right='no'
	fi
cat >> /etc/config/samba4 <<EOF
config sambashare
	option name '$n'
	option path '$syspath/$m$n'
	option read_only '$right'
	option guest_ok 'yes'
	option dir_mask '0777'
	option create_mask '0777'
	option timemachine '1'
	option inherit_owner 'yes'

EOF
	echolog "Samba4 name: ["$n"]        path:["$syspath/$m$n"]"
	}

	[ $(uci_get_by_name $NAME sysmonitor nfs 0) == 1 ] && {
	right=$(uci_get_by_name $NAME sysmonitor nfs_rw 0)
	if [ $right == 0 ]; then
		right='ro'
		status=$(check_dir nfs_rw_dir $n)
		[ -n "$status" ] && right='rw'
	else
		right='rw'
	fi
cat >> /etc/config/nfs <<EOF
config share
	option clients '*'
	option options '$right,sync,root_squash,all_squash,insecure,no_subtree_check'
	option enabled '1'
	option path '$syspath/$m$n'

EOF
	echolog "NFS path: ["$syspath/$m$n"]"
	}
	[ $(uci_get_by_name $NAME sysmonitor minidlna 0) == 1 ] && {
		status=$(minidlna_chk $n)
		[ -n "$status" ] && {
			uci add_list minidlna.config.media_dir="$syspath/$m$n"
			echolog "minidlna path: ["$syspath/$m$n"]"
		}
	}
fi
done
	if [ $(uci_get_by_name $NAME sysmonitor ftp 0) == 1 ]; then
		mkdir /var/ftp/$m
		mount --bind $syspath/$m /var/ftp/$m
		echolog "Vsftpd share path: ["$syspath/$m"]"
	fi
done
	uci commit minidlna
	[ $(uci_get_by_name $NAME sysmonitor samba 0) == 1 ] && /etc/init.d/samba start &
	[ $(uci_get_by_name $NAME sysmonitor nfs 0) == 1 ] && /etc/init.d/nfs start &
	[ $(uci_get_by_name $NAME sysmonitor ftp 0) == 1 ] && /etc/init.d/vsftpd start &
	[ $(uci_get_by_name $NAME sysmonitor minidlna 0) == 1 ] && /etc/init.d/minidlna start &
	rm /tmp/music
}

minidlna_status() {
status=$(/usr/bin/wget -qO- 'http://127.0.0.1:8200')
status=$(echo ${status#*<tr><td>})
status=$(echo ${status%<h3>*})
status=$(echo $status|sed 's/<\/td><td>/(/g'|sed 's/<\/td><\/tr><tr>/)/g'|sed 's/<\/td><\/tr><\/table>/)/g'|sed 's/ /-/g'|sed 's/<td>/ /g')
echo $status
}

arg1=$1
shift
case $arg1 in

minidlna_status)
	minidlna_status
	;;
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
check_dir)
	check_dir $1 $2
	;;
esac
