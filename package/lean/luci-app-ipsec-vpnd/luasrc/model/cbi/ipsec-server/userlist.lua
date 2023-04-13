mp = Map("ipsec", translate("L2TP/IPSec VPN Server"))
mp.description = translate(
                     "L2TP/IPSec VPN connectivity using the native built-in VPN Client on iOS or Andriod (IKEv1 with PSK and Xauth)")

s = mp:section(TypedSection, "users", translate("Users Manager"))
s.addremove = true
s.anonymous = true
s.template = "cbi/tblsection"

enabled = s:option(Flag, "enabled", translate("Enabled"))
enabled.rmempty = false
username = s:option(Value, "username", translate("User name"))
username.placeholder = translate("User name")
username.rmempty = true
password = s:option(Value, "password", translate("Password"))
password.rmempty = true

local apply = luci.http.formvalue("cbi.apply")
if apply then
	luci.sys.exec("/etc/init.d/ipsec start")
	luci.sys.exec("ipsec reload")
	luci.sys.exec("ipsec restart")
end

return mp
