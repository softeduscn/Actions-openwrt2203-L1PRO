#
# Copyright (C) 2016-2017 GitHub 
#
# This is free software, licensed under the GNU General Public License v3.
# See /LICENSE for more information.

include $(TOPDIR)/rules.mk

PKG_NAME:=default-settings
PKG_VERSION:=2
PKG_RELEASE:=28
PKG_LICENSE:=GPLv3
PKG_LICENSE_FILES:=LICENSE

include $(INCLUDE_DIR)/package.mk

define Package/default-settings
  SECTION:=luci
  CATEGORY:=LuCI
  TITLE:=LuCI support for Default Settings
  PKGARCH:=all
  DEPENDS:=+luci-base +@LUCI_LANG_zh_Hans +@LUCI_LANG_en +automount +ipv6helper +perl +perl-http-date +perlbase-getopt +perlbase-time +perlbase-unicode +perlbase-utf8 +blkid +fdisk +lsblk +parted +attr +btrfs-progs +chattr +dosfstools +e2fsprogs +f2fs-tools +f2fsck +lsattr +mkf2fs +xfs-fsck +xfs-mkfs +bsdtar +pigz +gawk +getopt +losetup +tar +uuidgen
endef

define Package/default-settings/description
	Language Support Packages.
endef

define Build/Compile
endef

define Package/default-settings/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/zzz-default-settings $(1)/etc/uci-defaults/99-default-settings
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	po2lmo ./po/zh-cn/default.po $(1)/usr/lib/lua/luci/i18n/default.zh-cn.lmo
endef

$(eval $(call BuildPackage,default-settings))
