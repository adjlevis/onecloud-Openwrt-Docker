#!/bin/bash
set -e

# ============================================================
# 🧩 基本配置
# ============================================================
ROOTFS_URL="https://dl.openwrt.ai/releases/targets/amlogic/meson8b/kwrt-10.30.2025-amlogic-meson8b-thunder-onecloud-rootfs.tar.gz"
OUTPUT_DIR="release/openwrt"
WORK_DIR="$(pwd)"

echo "📥 开始下载预构建 rootfs..."
mkdir -p bin/rootfs files "$OUTPUT_DIR"

cd bin/rootfs
curl -LO "$ROOTFS_URL"
cd "$WORK_DIR"

echo "✅ rootfs 下载完成。"

# ============================================================
# 📦 解压 rootfs
# ============================================================
echo "📂 解压 rootfs 到 files/..."
tar -xzf bin/rootfs/*.tar.gz -C files/ || true

# ============================================================
# ⚙️ 写入旁路由网络配置
# ============================================================
echo "🧰 写入旁路由网络配置..."
mkdir -p files/etc/config

cat <<'NETCONF' > files/etc/config/network
config interface 'lan'
  option proto 'static'
  option ipaddr '192.168.2.2'
  option netmask '255.255.255.0'
  option gateway '192.168.2.1'
  option dns '192.168.2.1'
NETCONF

cat <<'DHCP' > files/etc/config/dhcp
config dhcp 'lan'
  option ignore '1'
DHCP

echo "✅ 已配置为旁路由 (IP=192.168.2.2, 网关=192.168.2.1, DHCP=关闭)"

# ============================================================
# 🌐 添加 OpenClash 插件
# ============================================================
echo "🌐 下载并集成 OpenClash 插件..."
mkdir -p files/tmp/openclash
git clone --depth=1 https://github.com/vernesong/OpenClash.git tmp_openclash
cp -rf tmp_openclash/luci-app-openclash/files/* files/ || true
rm -rf tmp_openclash
echo "✅ OpenClash 已添加完成。"

# ============================================================
# 🎨 替换默认主题为 Argon
# ============================================================
echo "🎨 下载 luci-theme-argon 主题..."
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon.git tmp_argon
cp -rf tmp_argon/files/* files/ || true
rm -rf tmp_argon

echo "⚙️ 修改默认主题为 Argon..."
mkdir -p files/etc/config
cat <<'UCI' > files/etc/config/luci
config core main
	option lang auto
	option mediaurlbase '/luci-static/argon'
	option resourcebase '/luci-static/resources'
	option ubuspath '/ubus/'
UCI

echo "✅ 默认主题已设置为 luci-theme-argon。"

# ============================================================
# 🧱 制作 EXT4 镜像（EMMC 线刷包）
# ============================================================
IMG_FILE="${OUTPUT_DIR}/thunder-onecloud-emmc-ext4.img"
MNT_DIR="./mnt_ext4"

echo "🧱 创建 EXT4 镜像文件..."
IMG_SIZE_MB=512
dd if=/dev/zero of="$IMG_FILE" bs=1M count=$IMG_SIZE_MB status=progress

echo "⚙️ 格式化为 EXT4..."
mkfs.ext4 -F "$IMG_FILE"

echo "📦 挂载镜像并写入 rootfs..."
sudo mkdir -p "$MNT_DIR"
sudo mount -o loop "$IMG_FILE" "$MNT_DIR"
sudo rsync -aHAX files/ "$MNT_DIR"/

# ============================================================
# 🔐 设置默认 root 密码为 “root”
# ============================================================
echo "🔐 设置默认 root 密码为 'root'..."
echo "root:root" | sudo chroot "$MNT_DIR" chpasswd || echo "⚠️ 无法在 chroot 环境设置密码，将在镜像挂载时写入 shadow 文件。"

# 如果 chroot 失败则直接修改 /etc/shadow
if [ -f "$MNT_DIR/etc/shadow" ]; then
  echo "🧩 手动写入 /etc/shadow..."
  sed -i "s|^root:[^:]*:|root:\$1\$root\$jPp4oTg4l0jYkMxS2KZpF/:|" "$MNT_DIR/etc/shadow" || true
else
  echo "⚠️ 未找到 /etc/shadow，跳过密码设置。"
fi

sync
sudo umount "$MNT_DIR"
sudo rm -rf "$MNT_DIR"

echo "✅ EXT4 镜像制作完成: $IMG_FILE"

# ============================================================
# 📦 压缩镜像
# ============================================================
echo "📦 压缩镜像..."
gzip -f "$IMG_FILE"
echo "✅ 输出文件: ${IMG_FILE}.gz"

echo "🎉 构建流程全部完成！"
