
module("luci.controller.ipsec-server", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/ipsec") then
		return
	end
	entry({"admin", "vpn"}, firstchild(), "VPN", 45).dependent = false
    entry({"admin", "vpn", "ipsec-server"},alias("admin", "vpn", "ipsec-server", "basic"),_("IPSec VPN Server"), 49).dependent = false
    entry({"admin", "vpn", "ipsec-server", "basic"},cbi("ipsec-server/ipsec-server"),_("Basic"), 10).leaf = true
    entry({"admin", "vpn", "ipsec-server", "user"},cbi("ipsec-server/userlist"),_("Users"), 20).leaf = true
    entry({"admin", "vpn", "ipsec-server", "online"},cbi("ipsec-server/online"),_("Online Users"), 30).leaf = true
	entry({"admin", "vpn", "ipsec-server","status"},call("act_status")).leaf = true
	entry({"admin", "vpn", "ipsec-server", "get_online"}, call("get_online")).leaf = true
	entry({"admin", "vpn", "ipsec-server", "users_status"}, call("users_status")).leaf = true
end

function act_status()
  local e={}
  e.running=luci.sys.call("ps -w |grep ipsec/starter|grep -v grep >/dev/null")==0
  luci.http.prepare_content("application/json")
  luci.http.write_json(e)
end

function get_online()
	luci.http.write(luci.sys.exec("[ -f '/var/log/ipsec_users' ] && cat /var/log/ipsec_users"))
end

function users_status()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		ipsec_state = luci.sys.exec("/usr/share/ipsec/getuser.sh")
	})
end
