#!/bin/bash

# --- 配置区 ---
# 使用你提供的分支和文件名
BRANCH="2026.2.19"
FILENAME="OpenClaw-2026.2.19.zip"
# 构造 GitHub Proxy 下载链接（加速）
DOWNLOAD_URL="https://gh-proxy.com/https://raw.githubusercontent.com/Daiyimo/openclaw-setup-Ubuntu/${BRANCH}/${FILENAME}"
INSTALL_DIR="/opt/openclaw"

echo "开始安装 OpenClaw 版本: ${BRANCH}"

# 1. 环境准备
sudo apt update && sudo apt install -y curl wget unzip nodejs npm
sudo npm install -g pnpm

# 2. 下载指定的 ZIP 包
echo "正在从分支 ${BRANCH} 下载 ${FILENAME}..."
curl -L "${DOWNLOAD_URL}" -o "/tmp/${FILENAME}"

# 3. 解压并安装
echo "正在解压到 ${INSTALL_DIR}..."
sudo mkdir -p "${INSTALL_DIR}"
sudo unzip -o "/tmp/${FILENAME}" -d "${INSTALL_DIR}"

# 4. 进入目录执行后续安装逻辑 (根据你的项目结构调整)
cd "${INSTALL_DIR}"
# 假设 ZIP 内部还有一层文件夹，可以根据实际情况 cd 进入
# pnpm install
# ... 其他配置逻辑 ...

echo "安装完成！"
