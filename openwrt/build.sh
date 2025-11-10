#!/bin/bash
set -e

echo "🧩 生成 OpenWRT .config..."
cat <<EOF > .config
CONFIG_TARGET_amlogic=y
CONFIG_TARGET_amlogic_meson8b=y
CONFIG_TARGET_amlogic_meson8b_DEVICE_thunder-onecloud=y
CONFIG_TARGET_ROOTFS_PARTSIZE=${OP_rootfs}
CONFIG_TARGET_KERNEL_PARTSIZE=32
CONFIG_KERNEL_BUILD_USER="${OP_author}"
CONFIG_KERNEL_BUILD_DOMAIN="github.com"
CONFIG_DEVEL=y
CONFIG_CCACHE=y
CONFIG_PACKAGE_luci=y
CONFIG_LUCI_LANG_zh_Hans=y
EOF

echo "🧰 写入旁路由网络配置到 files/etc/config/network..."
mkdir -p files/etc/config

cat <<'NETCONF' > files/etc/config/network
config interface 'loopback'
	option ifname 'lo'
	option proto 'static'
	option ipaddr '127.0.0.1'
	option netmask '255.0.0.0'

config globals 'globals'
	option ula_prefix 'fd00:abcd::/48'

config interface 'lan'
	option ifname 'eth0'
	option proto 'static'
	option ipaddr '192.168.2.2'
	option netmask '255.255.255.0'
	option gateway '192.168.2.1'
	option dns '192.168.2.1'
NETCONF

cat <<'DHCP' > files/etc/config/dhcp
config dnsmasq
	option domainneeded '1'
	option localise_queries '1'
	option rebind_protection '1'
	option local '/lan/'
	option domain 'lan'
	option expandhosts '1'
	option authoritative '1'
	option readethers '1'
	option leasefile '/tmp/dhcp.leases'
	option resolvfile '/tmp/resolv.conf.d/resolv.conf.auto'

config dhcp 'lan'
	option interface 'lan'
	option ignore '1'

config odhcpd 'odhcpd'
	option maindhcp '0'
	option leasefile '/tmp/hosts/odhcpd'
	option leasetrigger '/usr/sbin/odhcpd-update'
	option loglevel '4'
DHCP

echo "✅ 已配置为旁路由模式 (IP=192.168.2.2 网关=192.168.2.1 DHCP=关闭)"
echo "🚀 开始构建固件镜像..."

make image PROFILE=thunder-onecloud FILES=files
