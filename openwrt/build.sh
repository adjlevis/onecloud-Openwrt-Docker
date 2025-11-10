#!/bin/bash
set -e

# ============================================================
# ⚙️ 基本配置
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
# 🌐 网络配置（旁路由模式）
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
# 🌐 集成 OpenClash 插件
# ============================================================
echo "🌐 下载并集成 OpenClash 插件..."
git clone --depth=1 https://github.com/vernesong/OpenClash.git tmp_openclash
cp -rf tmp_openclash/luci-app-openclash/files/* files/ || true
rm -rf tmp_openclash
echo "✅ OpenClash 已添加完成。"

# ============================================================
# 🐋 集成 Docker 中文界面 (luci-app-dockerman)
# ============================================================
echo "🐋 下载并集成 luci-app-dockerman..."
git clone --depth=1 https://github.com/lisaac/luci-app-dockerman.git tmp_docker
cp -rf tmp_docker/files/* files/ || true
rm -rf tmp_docker
echo "✅ Docker 中文管理界面已添加。"

# ============================================================
# 🎨 默认主题设置为 Argon
# ============================================================
echo "🎨 下载 luci-theme-argon..."
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon.git tmp_argon
cp -rf tmp_argon/files/* files/ || true
rm -rf tmp_argon

echo "⚙️ 设置默认主题为 Argon..."
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
# 🔐 设置默认 root 密码
# ============================================================
echo "🔐 设置默认 root 密码为 'root'..."
mkdir -p files/etc
if [ ! -f files/etc/shadow ]; then
  echo "root:\$1\$root\$jPp4oTg4l0jYkMxS2KZpF/:19383:0:99999:7:::" > files/etc/shadow
fi
echo "✅ 已设置 root 登录密码为 'root'。"

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

# ============================================================
# 🧾 生成发布说明
# ============================================================
VERSION=$(basename "$ROOTFS_URL" | grep -oE 'kwrt-[0-9\.]+')
RELEASE_NOTE="${OUTPUT_DIR}/release_note.md"

echo "🧾 生成发布说明..."
cat <<EOF > "$RELEASE_NOTE"
# 🚀 OpenWRT OneCloud 旁路由版

**版本:** ${VERSION}  
**构建时间:** $(date +"%Y-%m-%d %H:%M:%S")

---

## 🧩 已集成功能
- ✅ OpenClash (vernesong/OpenClash)
- ✅ Docker 中文管理界面 (lisaac/luci-app-dockerman)
- ✅ Argon 默认主题 (jerrykuku/luci-theme-argon)
- ✅ 旁路由模式 (静态IP)

---

## ⚙️ 默认网络配置
| 项目 | 值 |
|------|------|
| IP 地址 | 192.168.2.2 |
| 子网掩码 | 255.255.255.0 |
| 网关 | 192.168.2.1 |
| DNS | 192.168.2.1 |
| DHCP | 关闭 |

---

## 🔐 Web 后台登录
| 项目 | 内容 |
|------|------|
| 地址 | [http://192.168.2.2](http://192.168.2.2) |
| 用户名 | root |
| 密码 | root |

---

## 💾 文件信息
| 文件名 | 大小 | 说明 |
|--------|------|------|
| thunder-onecloud-emmc-ext4.img.gz | $(du -h "${IMG_FILE}.gz" | awk '{print $1}') | EMMC 线刷镜像 |

---

📢 **说明:**  
该镜像适合 OneCloud 设备刷入 EMMC 使用，基于 kwrt RootFS，集成 OpenClash + Docker + Argon UI，无需手动安装。

EOF

echo "✅ 已生成发布说明: $RELEASE_NOTE"

# ============================================================
# ✅ 结束
# ============================================================
echo "🎉 构建流程全部完成！"
