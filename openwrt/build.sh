#!/bin/bash
set -e

echo "🧩 检查 ImageBuilder 根目录..."
for d in /builder /openwrt /home/build /home/openwrt /workdir /; do
  if [ -f "$d/Makefile" ]; then
    cd "$d"
    echo "✅ 已进入 ImageBuilder 根目录: $d"
    break
  fi
done
if [ ! -f Makefile ]; then
  echo "❌ ERROR: 未找到 Makefile，镜像结构不对"
  exit 1
fi

echo "🧩 生成 .config..."
cat <<EOF > .config
CONFIG_TARGET_armsr=y
CONFIG_TARGET_armsr_armv7=y
CONFIG_TARGET_armsr_armv7_DEVICE_generic=y
CONFIG_TARGET_ROOTFS_PARTSIZE=${OP_rootfs}
CONFIG_TARGET_KERNEL_PARTSIZE=32
CONFIG_KERNEL_BUILD_USER="${OP_author}"
CONFIG_KERNEL_BUILD_DOMAIN="github.com"
CONFIG_DEVEL=y
CONFIG_CCACHE=y
CONFIG_PACKAGE_luci=y
CONFIG_LUCI_LANG_zh_Hans=y
EOF

echo "🧰 写入旁路由网络配置..."
mkdir -p files/etc/config

cat <<'NETCONF' > files/etc/config/network
config interface 'loopback'
  option device 'lo'
  option proto 'static'
  option ipaddr '127.0.0.1'
  option netmask '255.0.0.0'

config globals 'globals'
  option ula_prefix 'fd00:abcd::/48'

config device
  option name 'br-lan'
  option type 'bridge'
  list ports 'eth0'

config interface 'lan'
  option device 'br-lan'
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

echo "✅ 已配置旁路由：192.168.2.2 网关192.168.2.1 DHCP关"

echo "🏗️ 开始构建镜像..."
make image PROFILE=generic FILES=files

echo "✅ 构建完成，固件位于 bin/targets/armsr/armv7/"
