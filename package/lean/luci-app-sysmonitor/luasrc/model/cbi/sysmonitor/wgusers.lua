f = SimpleForm("sysmonitor")
f.reset = false
f.submit = false
f:append(Template("sysmonitor/wg_users"))
return f
