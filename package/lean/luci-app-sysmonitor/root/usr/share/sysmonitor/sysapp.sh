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


ipsec_users() {
	if [ -f "/usr/sbin/ipsec" ]; then
		users=$(/usr/sbin/ipsec status|grep xauth|grep ESTABLISHED|wc -l)
		usersl2tp=$(top -bn1|grep options.xl2tpd|grep -v grep|wc -l)
		let "users=users+usersl2tp"
		[ "$users" == 0 ] && users='None'
	else
		users='None'
	fi
	echo $users
}

pptp_users() {
	if [ -f "/usr/sbin/pppd" ]; then
		users=$(top -bn1|grep options.pptpd|grep -v grep|wc -l)
#		let users=users-1
		[ "$users" == 0 ] && users='None'
	else
		users='None'
	fi
	echo $users
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
#	name=$(ls -F /var/ftp|grep '/$'|sed '/upload/d')
	name=$(ls -F /var/ftp|grep '/$')
	for n in $name
	do
		umount /var/ftp/$n
		rmdir /var/ftp/$n 
	done
}

lighttpd() {
cat > /mnt/.index.php <<EOF
<?php  
\$host = getenv("HTTP_HOST");
header("location: http://\$host:8080/");
?>
EOF
	ip=$(ip -o -4 addr list br-lan | cut -d ' ' -f7|cut -d'/' -f1)
	ip6=$(ip -o -6 addr list br-lan | cut -d ' ' -f7 | cut -d'/' -f1 |head -n1)
	if [ -n "$ip6" ]; then
		echo $ip6 > /www/ip6.html
		sed -i '/\$SERVER\["socket"]/d' /etc/lighttpd/lighttpd.conf
		sed -i '/server.groupname/a\$SERVER["socket"] == "[sqmshcn]:80" {}' /etc/lighttpd/lighttpd.conf
		sed -i  "s|sqmshcn|$ip6|" /etc/lighttpd/lighttpd.conf
		/etc/init.d/lighttpd start
		echolog "Update ip6: "$ip6
		/etc/init.d/dnsmasq restart
		[ $(uci_get_by_name $NAME sysmonitor samba 0) == 1 ] && /etc/init.d/samba4 restart
	else
		ip6=$ip
		echo "" > /www/ip6.html
	fi
	echo $ip > /www/ip.html
}

minidlna_chk() {
	str=$(uci_get_by_name $NAME sysmonitor minidlna_dir 0)','
	str=$(echo $str|sed 's/,,/,/g')
	num=$(echo $str|awk -F"," '{print NF-1}')
	a=1
	while [ $a -le $num ]
	do
 	  	dir=$(echo $str|cut -d',' -f $a)
		result=$(echo $dir|grep -)
		if [[ "$result" != "" ]]; then
			media=$(echo ${dir^}|cut -d'-' -f 1)'-'
			dir=$(echo $dir|cut -d'-' -f 2)
		else
			media=''
		fi
		[ $dir == $1 ] && {
			echo $media$dir
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
#		mkdir /var/ftp/upload
#		touch /var/ftp/welcome	
	}

	syspath='/mnt'
	unftp
	echo "" >/etc/config/nfs
	sed -i '/sambashare/,$d' /etc/config/samba4
	if [ $(uci_get_by_name $NAME sysmonitor samba 0) == 0 ]; then
		echolog "Samba stop....."
		/etc/init.d/samba4 stop &
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
	option force_root '1'
	option inherit_owner 'yes'

EOF
	echolog "Samba name: ["$n"]        path:["$syspath/$m$n"]"
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
			result=$(echo $status|grep -)
			if [[ "$result" != "" ]]; then
				media=$(echo $status|cut -d'-' -f 1)','
				status=$(echo $status|cut -d'-' -f 2)
			else
				media=''
			fi
			uci add_list minidlna.config.media_dir="$media$syspath/$m$status"
			echolog "minidlna path: ["$media$syspath/$m$status"]"
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
	[ $(uci_get_by_name $NAME sysmonitor samba4 0) == 1 ] && /etc/init.d/samba4 start &
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

service_ddns() {
	if [ "$(ps |grep dynamic_dns|grep -v grep|wc -l)" == 0 ]; then
		uci set sysmonitor.sysmonitor.ddns=1
	else
		uci set sysmonitor.sysmonitor.ddns=0
	fi
	uci commit sysmonitor
	/etc/init.d/sysmonitor restart
}

wg_users() {
file='/var/log/wg_users'
/usr/bin/wg >$file
m=$(sed -n '/peer/=' $file | sort -r -n )
k=$(cat $file|wc -l)
let "k=k+1"
s=$k
for n in $m
do 
	let "k=s-n"
	if [ $k -le 3 ] ;then 
		let "s=s-1"
		tmp='sed -i '$n,$s'd '$file
		$tmp
	else
		let "i=n+3"
		tmp='sed -n '$i'p '$file
		tmp=$($tmp|cut -d' ' -f6)
		[ "$tmp" == "hour," ] && tmp="hours,"
		[ "$tmp" == "minute," ] && tmp="minutes,"	
		case $tmp in
		hours,)
			let "s=s-1"
			tmp='sed -i '$n,$s'd '$file
			$tmp
			;;
		minutes,)
			tmp='sed -n '$i'p '$file
			tmp=$($tmp|cut -d' ' -f5)
			if [ $tmp -ge 3 ] ;then
				let "s=s-1"
				tmp='sed -i '$n,$s'd '$file
				$tmp
			fi
			;;
		esac
	fi
	s=$n
done
users=$(cat $file|sed '/GWLcAE1Of.*$/d'|grep peer|wc -l)
[ "$users" -eq 0 ] && users='None'
echo $users
}

getvpn() {
	vpn=''
	[ "$(ps |grep /etc/passwall |grep -v grep |wc -l)" != 0 ] && vpn='Passwall'
	[ "$(ps |grep /etc/ssrplus|grep -v grep |wc -l)" != 0 ] && vpn='Shadowsocksr'
	echo $vpn	
}

smartdns_cache() {
	[ -f /tmp/smartdns.cache ] && rm /tmp/smartdns.cache
	[ $(ps |grep smartdns|grep -v grep|wc -l) -gt 0 ] && /etc/init.d/smartdns restart
}

service_smartdns() {
	if [ "$(uci get sysmonitor.sysmonitor.smartdns)" == 0 ]; then
		uci set sysmonitor.sysmonitor.smartdns=1
	else
		uci set sysmonitor.sysmonitor.smartdns=0
	fi
	uci commit sysmonitor
	set_smartdns
}

start_smartdns() {
	uci set sysmonitor.sysmonitor.smartdns=1
	uci commit sysmonitor
	uci set smartdns.@smartdns[0].enabled='1'
	uci set smartdns.@smartdns[0].seconddns_enabled='1'
	uci set smartdns.@smartdns[0].port=$(uci get sysmonitor.sysmonitor.smartdnsPORT)
	uci set smartdns.@smartdns[0].seconddns_port=$1
	uci commit smartdns
	/etc/init.d/smartdns start
}

set_smartdns() {
	if [ -f "/etc/init.d/smartdns" ]; then
		sed -i s/"#conf-file"/"conf-file"/ /etc/smartdns/custom.conf
		[ $(uci get sysmonitor.sysmonitor.smartdnsAD) == 0 ] && sed -i s/"conf-file"/"#conf-file"/ /etc/smartdns/custom.conf
		[ -f /tmp/smartdns.cache ] && rm /tmp/smartdns.cache
		if [ $(uci get sysmonitor.sysmonitor.smartdns) == 1 ];  then
			port='5335'
		#	sed -i '/address/d' /etc/smartdns/custom.conf
		#	echo "address /NAS/192.168.1.220" >> /etc/smartdns/custom.conf
			if [ -f "/etc/init.d/shadowsocksr" ]; then
				[ "$(uci get shadowsocksr.@global[0].pdnsd_enable)" -ne 0 ] && port='8653'		
			fi
			[ -f "/etc/init.d/passwall" ] && port='8653'	
			start_smartdns $port
		else
			if [ "$(ps |grep /etc/ssrplus|grep -v grep|wc -l)" != 0 ]; then
				if [ "$(uci get shadowsocksr.@global[0].pdnsd_enable)" -ne 0 ]; then
					touch /tmp/smartdns_stop
				else
					start_smartdns '5335'
				fi
			else
				if [ "$(ps |grep /etc/passwall|grep -v grep|wc -l)" != 0 ]; then
					if [ "$(uci get passwall.@global[0].dns_shunt)" == 'smartdns' ]; then
						start_smartdns '8653'
					else
						touch /tmp/smartdns_stop
					fi
				else
					touch /tmp/smartdns_stop
				fi
			fi
			if [ -f "/tmp/smartdns_stop" ]; then
				rm /tmp/smartdns_stop
				/etc/init.d/smartdns stop >/dev/null 2>&1
			fi

		fi
	fi
}

selvpn() {
case $1 in
p)
	[ $(uci get passwall.@global[0].enabled) == 1 ] && uci set sysmonitor.sysmonitor.vpnp=1
	uci set sysmonitor.sysmonitor.vpns=0		
	uci commit sysmonitor
	[ -f /etc/init.d/shadowsocksr ] && /etc/init.d/shadowsocksr stop
	[ "$(uci get passwall.@global[0].dns_shunt)" == 'smartdns' ] && start_smartdns '8653'
	;;
s)
	[ ! $(uci get shadowsocksr.@global[0].global_server) == 'nil' ] && uci set sysmonitor.sysmonitor.vpns=1
	uci set sysmonitor.sysmonitor.vpnp=0
	uci commit sysmonitor
	[ -f /etc/init.d/passwall ] && /etc/init.d/passwall stop
	[ "$(uci get shadowsocksr.@global[0].pdnsd_enable)" == 0 ] && start_smartdns '5335'
	;;
esac
}

passwall() {
	if [ "$(uci get sysmonitor.sysmonitor.vpnp)" == 0 ]; then
		uci set sysmonitor.sysmonitor.vpnp=1
		uci set sysmonitor.sysmonitor.vpns=0
	else
		uci set sysmonitor.sysmonitor.vpnp=0
	fi
	uci commit sysmonitor
	vpn
}

shadowsocksr() {
	if [ "$(uci get sysmonitor.sysmonitor.vpns)" == 0 ]; then
		uci set sysmonitor.sysmonitor.vpns=1
		uci set sysmonitor.sysmonitor.vpnp=0
	else
		uci set sysmonitor.sysmonitor.vpns=0
	fi
	uci commit sysmonitor
	vpn
}

vpn() {
	if [ $(uci get sysmonitor.sysmonitor.vpns) == 1 ];  then
		[ -f "/tmp/set_smartdns" ] && rm /tmp/set_smartdns
		if [ $(ps |grep /etc/ssrplus|grep -v grep|wc -l) -eq 0 ]; then
			[ -f "/etc/init.d/shadowsocksr" ] && /etc/init.d/shadowsocksr start &
			if [ "$(uci get shadowsocksr.@global[0].pdnsd_enable)" == "0" ]; then
				uci set sysmonitor.sysmonitor.smartdns=1
				uci commit sysmonitor
			fi
		fi
	else
		touch /tmp/set_smartdns
		[ $(ps |grep /etc/ssrplus|grep -v grep|wc -l) -gt 0 ] && /etc/init.d/shadowsocksr stop &
	fi
	if [ $(uci get sysmonitor.sysmonitor.vpnp) == 1 ];  then
		[ -f "/tmp/set_smartdns" ] && rm /tmp/set_smartdns
		if [ $(ps |grep /etc/passwall|grep -v grep|wc -l) -eq 0 ]; then
			[ -f "/etc/init.d/passwall" ] && /etc/init.d/passwall start &
			if [ "$(uci get passwall.@global[0].dns_shunt)" == 'smartdns' ]; then
				uci set sysmonitor.sysmonitor.smartdns=1
				uci commit sysmonitor
			fi
		fi
	else
		touch /tmp/set_smartdns
		[ $(ps |grep /etc/passwall|grep -v grep|wc -l) -gt 0 ] && /etc/init.d/passwall stop &
	fi
	if [ -f "/tmp/set_smartdns" ] ; then
		rm /tmp/set_smartdns
		set_smartdns
	fi
}

setdns() {
	dnslist=$(uci get sysmonitor.sysmonitor.dns)
	if [ "$dnslist" != "$(uci get network.lan.dns)" ]; then
		d=$(date "+%Y-%m-%d %H:%M:%S")
		echo $d": set dns:"$dnslist >> /var/log/sysmonitor.log
		uci del network.lan.dns
		uci del network.wan.dns
		for n in $dnslist
		do 		
			uci add_list network.lan.dns=$n
			uci add_list network.wan.dns=$n
		done
		uci commit network
		ifup lan
		ifup wan
		ifup wan6
		/etc/init.d/odhcpd restart
	fi
}

arg1=$1
shift
case $arg1 in
setdns)
	setdns
	;;
selvpn)
	selvpn $1
	;;
set_smartdns)
	set_smartdns
	;;
service_smartdns)
	service_smartdns
	;;
smartdns_cache)
	smartdns_cache
	;;
passwall)
	passwall
	;;
shadowsocksr)
	shadowsocksr
	;;
service_ddns)
	service_ddns
	;;
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
getvpn)
	getvpn
	;;
ipsec)
	ipsec_users
	;;
pptp)
	pptp_users
	;;
wg)
	wg_users
	;;
check_dir)
	check_dir $1 $2
	;;
minidlna_chk)
	minidlna_chk $1
	;;
esac



