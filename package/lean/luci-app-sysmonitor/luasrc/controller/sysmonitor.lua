-- Copyright (C) 2017
-- Licensed to the public under the GNU General Public License v3.

module("luci.controller.sysmonitor", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/sysmonitor") then
		return
	end
	entry({"admin", "sys"}, firstchild(), "SYS", 10).dependent = false
   	entry({"admin", "sys","sysmonitor"}, alias("admin", "sys","sysmonitor", "settings"),_("SYSMonitor"), 20).dependent = true
	entry({"admin", "sys", "sysmonitor","settings"}, cbi("sysmonitor/setup"), _("General Settings"), 30).dependent = true
	entry({"admin", "sys", "sysmonitor", "wgusers"},cbi("sysmonitor/wgusers"),_("WGusers"), 50).leaf = true
	entry({"admin", "sys", "sysmonitor", "log"},cbi("sysmonitor/log"),_("Log"), 60).leaf = true

	entry({"admin", "sys", "sysmonitor", "minidlna_status"}, call("action_minidlna_status")).leaf = true
	entry({"admin", "sys", "sysmonitor", "ip_status"}, call("action_ip_status")).leaf = true
	entry({"admin", "sys", "sysmonitor", "wg_status"}, call("action_wg_status")).leaf = true
	entry({"admin", "sys", "sysmonitor", "wireguard_status"}, call("action_wireguard_status")).leaf = true
	entry({"admin", "sys", "sysmonitor", "ipsec_status"}, call("action_ipsec_status")).leaf = true
	entry({"admin", "sys", "sysmonitor", "pptp_status"}, call("action_pptp_status")).leaf = true
	entry({"admin", "sys", "sysmonitor", "service_status"}, call("action_service_status")).leaf = true

	entry({"admin", "sys", "sysmonitor", "refresh"}, call("refresh")).leaf = true
	entry({"admin", "sys", "sysmonitor", "get_log"}, call("get_log")).leaf = true
	entry({"admin", "sys", "sysmonitor", "clear_log"}, call("clear_log")).leaf = true
	entry({"admin", "sys", "sysmonitor", "wanswitch"}, call("wanswitch")).leaf = true
	
	entry({"admin", "sys", "sysmonitor", "wg_users"}, call("wg_users")).leaf = true
	entry({"admin", "sys", "sysmonitor", "rs_webdev"}, call("rs_webdev")).leaf = true
	entry({"admin", "sys", "sysmonitor", "rs_samba"}, call("rs_samba")).leaf = true
	entry({"admin", "sys", "sysmonitor", "rs_ftp"}, call("rs_ftp")).leaf = true
	entry({"admin", "sys", "sysmonitor", "rs_nfs"}, call("rs_nfs")).leaf = true
	entry({"admin", "sys", "sysmonitor", "service_ddns"}, call("service_ddns")).leaf = true
	entry({"admin", "sys", "sysmonitor", "smartdns_cache"}, call("smartdns_cache")).leaf = true
	entry({"admin", "sys", "sysmonitor", "service_shadowsocksr"}, call("shadowsocksr")).leaf = true
	entry({"admin", "sys", "sysmonitor", "service_passwall"}, call("passwall")).leaf = true
	entry({"admin", "sys", "sysmonitor", "service_smartdns"}, call("service_smartdns")).leaf = true
	entry({"admin", "sys", "sysmonitor", "service_button"}, call("service_button")).leaf = true
end

function get_log()
	luci.http.write(luci.sys.exec("[ -f '/var/log/sysmonitor.log' ] && cat /var/log/sysmonitor.log"))
end

function clear_log()
	luci.sys.exec("echo '' > /var/log/sysmonitor.log")
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor","log"))
end

function service_button()
	button='<button class="button1"><a href="/cgi-bin/luci/admin/services/ttyd" target="_blank">Terminal</a></button>'
	button_ddns=''
	if nixio.fs.access("/etc/init.d/ddns") then
		button_ddns=' <button class="button1"><a href="/cgi-bin/luci/admin/sys/sysmonitor/service_ddns">DDNS</a></button>'
	end
	button_aria2=''
	if nixio.fs.access("/etc/init.d/aria2") then
		button_aria2=' <button class=button1><a href="/ariang/"  target="_blank">Aria2</a></button>'
	end
 	button_lighttpd=''
	if nixio.fs.access("/etc/init.d/lighttpd") then
		button_lighttpd=' <button class=button1><a href="/cgi-bin/luci/admin/sys/sysmonitor/rs_webdev">WEBDEV</a></button>'
	end
	button_ftp=''
	if nixio.fs.access("/etc/init.d/vsftpd") then
		button_ftp=' <button class=button1><a href="/cgi-bin/luci/admin/sys/sysmonitor/rs_ftp">FTP</a></button>'
	end
	button_samba=''
	if nixio.fs.access("/etc/init.d/samba4") then
 		button_samba=' <button class=button1><a href="/cgi-bin/luci/admin/sys/sysmonitor/rs_samba">SAMBA</a></button>'
	end
	button_nfs=''
	if nixio.fs.access("/etc/init.d/nfsd") then
		button_nfs=' <button class=button1><a href="/cgi-bin/luci/admin/sys/sysmonitor/rs_nfs">NFS</a></button>'
	end
	buttondns=''
	if nixio.fs.access("/etc/init.d/smartdns") then
		buttondns=' <button class="button1"><a href="/cgi-bin/luci/admin/sys/sysmonitor/service_smartdns">SmartDNS</a></button>'
	end
	buttons=''
	if nixio.fs.access("/etc/init.d/shadowsocksr") then
		buttons=' <button class="button1"><a href="/cgi-bin/luci/admin/sys/sysmonitor/service_shadowsocksr">Shadowsocksr</a></button>'
	end
	buttonp=''
	if nixio.fs.access("/etc/init.d/passwall") then
		buttonp=' <button class="button1"><a href="/cgi-bin/luci/admin/sys/sysmonitor/service_passwall">Passwall</a></button>'
	end
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		service_button = button..button_ddns..button_aria2..button_lighttpd..button_ftp..button_samba..button_nfs..buttondns..buttons..buttonp
	})
end

function action_ip_status()
	ip6='IP6: ['..luci.sys.exec("/usr/share/sysmonitor/sysapp.sh getip6")..']'
	iplan ='<br>LAN: '..luci.sys.exec("uci get network.lan.ipaddr")..' gateway:'..luci.sys.exec("uci get network.lan.gateway")..' <font color=9699cc>dns:'..luci.sys.exec("uci get network.lan.dns")..'</font>'
	ipwan ='<br>WAN:'..luci.sys.exec("uci get network.wan.ipaddr")..' gateway:'..luci.sys.exec("uci get network.wan.gateway")..' <font color=9699cc>dns:'..luci.sys.exec("uci get network.wan.dns")..'</font>'

	luci.http.prepare_content("application/json")
	luci.http.write_json({
	ip_state = ip6..iplan..ipwan
	})
end

function action_minidlna_status()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		minidlna_state = luci.sys.exec("/usr/share/sysmonitor/sysapp.sh minidlna_status")
	})
end

function action_ipsec_status()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		ipsec_state = luci.sys.exec("/usr/share/sysmonitor/sysapp.sh ipsec")
	})
end

function action_pptp_status()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		pptp_state = luci.sys.exec("/usr/share/sysmonitor/sysapp.sh pptp")
	})
end

function action_service_status()
	gateway = luci.sys.exec("uci get network.lan.gateway")
	vpnl = luci.sys.exec("uci get sysmonitor.sysmonitor.vpnip")
	if ( gateway == vpnl ) then
		vpnl = "<font color=green>"..vpnl.."->VPN </font>"
	else
		vpnl=""
	end
	ddns=''
	if nixio.fs.access("/etc/init.d/ddns") then
	tmp = tonumber(luci.sys.exec("ps |grep dynamic_dns|grep -v grep|wc -l"))
	if ( tmp == 0 ) then
		color="red"
	else
		color="green"
	end
	ddns = ' <font color='..color..'>DDNS<a href="/cgi-bin/luci/admin/services/ddns" target="_blank">--></a></font>'
	end
	webdev=''
	if nixio.fs.access("/etc/init.d/lighttpd") then
	tmp = tonumber(luci.sys.exec("ps |grep lighttpd|grep -v grep|wc -l"))
	if ( tmp == 0 ) then
		color="red"
	else
		color="green"
	end
	webdev = ' <font color='..color..'>Webdev</font>'
	end
	ftp=''
	if nixio.fs.access("/etc/init.d/vsftpd") then
	tmp = tonumber(luci.sys.exec("ps |grep vsftpd|grep -v grep|wc -l"))
	if ( tmp == 0 ) then
		color="red"
	else
		color="green"
	end
	ftp = ' <font color='..color..'>FTP</font>'
	end
	samba=''
	if nixio.fs.access("/etc/init.d/samba4") then
	tmp = tonumber(luci.sys.exec("ps |grep smbd|grep -v grep|wc -l"))
	if ( tmp == 0 ) then
		color="red"
	else
		color="green"

	end
	samba = ' <font color='..color..'>Sambar<a href="/cgi-bin/luci/admin/services/samba4" target="_blank">--></a></font>'
	end
	nfs=''
	if nixio.fs.access("/etc/init.d/nfsd") then
	tmp = tonumber(luci.sys.exec("ps |grep nfsd|grep -v grep|wc -l"))
	if ( tmp == 0 ) then
		color="red"
	else
		color="green"
	end
	nfs = ' <font color='..color..'>NFS<a href="/cgi-bin/luci/admin/services/nfs" target="_blank">--></a></font>'
	end
	smartdns=''
	if nixio.fs.access("/etc/init.d/smartdns") then
	tmp = tonumber(luci.sys.exec("ps |grep smartdns|grep -v grep|wc -l"))
	if ( tmp == 0 ) then
		color="red"
	else
		color="green"
	end
	smartdns = ' <font color='..color..'>SmartDNS<a href="/cgi-bin/luci/admin/services/smartdns" target="_blank">--></a></font>'
	end
	vpn = luci.sys.exec("/usr/share/sysmonitor/sysapp.sh getvpn")
	if ( vpn == '' ) then
		vpn = ' <font color=red>VPN</font>'
	else
		vpn = ' <font color=green>VPN-'..vpn..'<a href="/cgi-bin/luci/admin/services/'..string.lower(vpn)..'" target="_blank">--></a></font>'
	end	luci.http.prepare_content("application/json")
	luci.http.write_json({
		service_state = vpnl..ddns..webdev..ftp..samba..nfs..smartdns..vpn
	})
end

function refresh()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor"))
	luci.sys.exec("touch /tmp/sysmonitor")	
end

function wanswitch()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor", "settings"))
	luci.sys.exec("/usr/share/sysmonitor/sysapp.sh wanswitch")
end

function rs_webdev()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor", "settings"))
	luci.sys.exec("/etc/init.d/lighttpd restart")
end

function rs_samba()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor", "settings"))
	luci.sys.exec("/etc/init.d/samba4 restart")
end

function rs_ftp()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor", "settings"))
	luci.sys.exec("/etc/init.d/vsftpd restart")
end

function rs_nfs()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor", "settings"))
	luci.sys.exec("/etc/init.d/nfs restart")
end

function service_ddns()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor"))
	luci.sys.exec("/usr/share/sysmonitor/sysapp.sh service_ddns")	
end

function shadowsocksr()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor", "settings"))
	luci.sys.exec("/usr/share/sysmonitor/sysapp.sh shadowsocksr")
end

function passwall()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor", "settings"))
	luci.sys.exec("/usr/share/sysmonitor/sysapp.sh passwall")
end

function smartdns_cache()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor", "settings"))
	luci.sys.exec("/usr/share/sysmonitor/sysapp.sh smartdns_cache")
end

function service_smartdns()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor"))
	luci.sys.exec("/usr/share/sysmonitor/sysapp.sh service_smartdns")	
end

function wg_users()
	luci.http.write(luci.sys.exec("[ -f '/var/log/wg_users' ] && cat /var/log/wg_users"))
end

function action_wireguard_status()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		wireguard_state = luci.sys.exec("/usr/share/sysmonitor/sysapp.sh wg")
	})
end
