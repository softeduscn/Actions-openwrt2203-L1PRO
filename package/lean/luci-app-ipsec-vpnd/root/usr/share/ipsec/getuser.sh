#!/bin/sh

/usr/sbin/ipsec status|grep xauth|grep ESTABLISHED > /tmp/log/ipsec_users
users=$(/usr/sbin/ipsec status|grep xauth|grep ESTABLISHED|wc -l)
usersl2tp=$(top -bn1|grep options.xl2tpd|grep -v grep|wc -l)
[ "$userl2tp" != 0 ] && top -bn1|grep options.xl2tpd|grep -v grep|cut -d' ' -f27- >>/tmp/log/ipsec_users
let "users=users+usersl2tp"
[ "$users" == 0 ] && users='--'
echo $users