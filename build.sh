#!/bin/bash
set -e

echo "🧩 生成 OpenWRT .config..."
cat <<EOF > openwrt/.config
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

echo "🧰 配置旁路由网络参数..."

# 关闭 DHCP、设置固定 IP 和网关
NETWORK_FILE="openwrt/package/base-files/files/bin/config_generate"

# 修改默认 LAN IP
sed -i 's/192\.168\.1\.1/192.168.2.2/' "$NETWORK_FILE"

# 添加静态网关、禁用 DHCP（通过修改 UCI 配置）
cat <<'NETCONFIG' >> "$NETWORK_FILE"

# 自定义旁路由网络配置（自动追加）
uci set network.lan.ipaddr='192.168.2.2'
uci set network.lan.netmask='255.255.255.0'
uci set network.lan.gateway='192.168.2.1'
uci set network.lan.dns='192.168.2.1'
uci set dhcp.lan.ignore='1'
uci commit network
uci commit dhcp
NETCONFIG

echo "✅ 已设置 LAN IP=192.168.2.2 网关=192.168.2.1 DHCP=关闭"

# 编译固件
cd openwrt
make image
