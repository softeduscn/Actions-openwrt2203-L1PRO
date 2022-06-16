
local m, s
local global = 'sysmonitor'
local uci = luci.model.uci.cursor()

m = Map("sysmonitor",translate("System Monitor"))
m:append(Template("sysmonitor/status"))

s = m:section(TypedSection, "sysmonitor", translate("System Settings"))
s.anonymous = true

o=s:option(Flag,"enable", translate("Enable"))
o.rmempty=false

o=s:option(Flag,"webdav", translate("Enable webdav"))
o.rmempty=false

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

o = s:option(Value, "gateway", translate("Gateway Address"))
--o.description = translate("IP for gateway(192.168.1.1)")
o.datatype = "or(host)"
o.rmempty = false

o = s:option(Value, "vpnip", translate("VPN IP Address"))
--o.description = translate("IP for VPN Server(192.168.1.110)")
o.datatype = "or(host)"
o.rmempty = false

return m
