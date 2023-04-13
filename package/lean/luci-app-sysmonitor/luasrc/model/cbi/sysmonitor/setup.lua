
local m, s
local global = 'sysmonitor'
local uci = luci.model.uci.cursor()
ip = luci.sys.exec("/usr/share/sysmonitor/sysapp.sh getip")

m = Map("sysmonitor",translate("System Status"))
m:append(Template("sysmonitor/status"))

n = Map("sysmonitor",translate("System Services"))
n:append(Template("sysmonitor/service"))

s = n:section(TypedSection, "sysmonitor", translate("System Settings"))
s.anonymous = true

o=s:option(Flag,"enable", translate("Enable"))
o.rmempty=false


if nixio.fs.access("/etc/init.d/ddns") then
o=s:option(Flag,"ddns", translate("DDNS Enable"))
o.rmempty=false
end

if nixio.fs.access("/etc/init.d/shadowsocksr") then
o=s:option(Flag,"vpns", translate("SSR Enable"))
o.rmempty=false
end

if nixio.fs.access("/etc/init.d/passwall") then
o=s:option(Flag,"vpnp", translate("Passwall Enable"))
o.rmempty=false
end


if nixio.fs.access("/etc/init.d/smartdns") then
o=s:option(Flag,"smartdns", translate("SmartDNS Enable"))
o.rmempty=false

o = s:option(Value, "smartdnsPORT", translate("SmartDNS PORT"))
o:value("53")
o:value("6053")
o.default = "53"
o.rmempty = false
end

--[[
if nixio.fs.access("/etc/init.d/smartdns") then
o=s:option(Flag,"smartdnsAD", translate("SmartDNS-AD Enable"))
o.rmempty=false
end
]]--

o=s:option(Flag,"ftp", translate("Enable ftp"))
o.rmempty=false

o=s:option(Flag,"samba", translate("Enable samba"))
o.rmempty=false

o = s:option(ListValue, "samba_rw", translate("Samba rw"))
o:value("0", translate("read only"))
o:value("1", translate("read & write"))
o = s:option(Value, "samba_rw_dir", translate("Samba RW directory"))
--o:depends("samba_rw", "0")
o.rmempty=false

o=s:option(Flag,"nfs", translate("Enable nfs"))
o.rmempty=false

o = s:option(ListValue, "nfs_rw", translate("NFS rw"))
o:value("0", translate("read only"))
o:value("1", translate("read & write"))
o = s:option(Value, "nfs_rw_dir", translate("NFS RW directory"))
--o:depends("nfs_rw", "0")
o.rmempty=false

o=s:option(Flag,"minidlna", translate("Enable minidlna"))
o.rmempty=false

o = s:option(Value, "minidlna_dir", translate("minidlna directory"))
o.rmempty=false

o = s:option(Value, "gateway", translate("Gateway Address"))
--o.description = translate("IP for gateway(192.168.1.1)")
o:value("192.168.1.1")
o.default = "192.168.1.1"
o.datatype = "or(host)"
o.rmempty = false

o = s:option(Value, "vpnip", translate("VPN IP Address"))
--o.description = translate("IP for VPN Server(192.168.1.110)")
o:value("192.168.1.110")
o.default = "192.168.1.110"
o.datatype = "or(host)"
o.rmempty = false

o = s:option(DynamicList, "dns", translate("DNS List"))
o.datatype = "or(host)"
o.rmempty = false

o = s:option(Value, "time", translate("Check time"))
o.rmempty = false

return m, n

