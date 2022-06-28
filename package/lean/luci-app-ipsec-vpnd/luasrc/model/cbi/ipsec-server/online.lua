f = SimpleForm("ipsec_server")
f.reset = false
f.submit = false
f:append(Template("ipsec/ipsec_online"))
return f
