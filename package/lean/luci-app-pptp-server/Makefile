# Copyright (C) 2018-2020 Lienol <lawlienol@gmail.com>
#
# This is free software, licensed under the Apache License, Version 2.0 .
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI support for PPTP VPN Server
LUCI_DEPENDS:=+pptpd +kmod-mppe +ppp +kmod-nf-nathelper-extra
LUCI_PKGARCH:=all
PKG_VERSION:=1
PKG_RELEASE:=5-20200608

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
