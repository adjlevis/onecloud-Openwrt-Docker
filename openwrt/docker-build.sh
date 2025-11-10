#!/bin/bash
set -e
echo "🚀 启动 OpenWRT Docker 构建..."

docker run --rm \
  -v "$PWD/bin:/builder/bin" \
  -v "$PWD/files:/builder/files" \
  -v "$PWD/build.sh:/builder/build.sh" \
  -e OP_rootfs="${OP_rootfs:-512}" \
  -e OP_author="${OP_author:-GitHub Actions}" \
  openwrt/imagebuilder:armsr-armv7-openwrt-24.10 \
  bash /builder/build.sh
