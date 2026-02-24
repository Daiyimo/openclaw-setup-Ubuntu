#!/bin/bash
set -e

# ============================================================
#  OpenClaw v2026.2.19 一键加速安装脚本 (Ubuntu 24.04+)
#  优化：采用二进制直装 + 国内双重镜像加速 (npmmirror)
# ============================================================

OPENCLAW_VERSION="v2026.2.19"
NODE_MAJOR=22

# --- 颜色输出 ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# --- 检查 root ---
if [ "$(id -u)" -ne 0 ]; then
    error "请使用 root 权限运行此脚本：sudo bash setup.sh"
fi

echo ""
echo "========================================"
echo "  OpenClaw ${OPENCLAW_VERSION} 极速安装版"
echo "  模式：二进制直装 (跳过不稳定 APT 源)"
echo "========================================"
echo ""

# 清理之前可能失败的残留文件
sudo rm -f /etc/apt/sources.list.d/nodesource.list

# ============================================================
# 1. 系统环境配置
# ============================================================
info "设置时区为 Asia/Shanghai..."
timedatectl set-timezone Asia/Shanghai

info "更新系统软件包..."
apt update && apt upgrade -y

info "安装基础工具..."
apt install -y curl wget git vim unzip tar build-essential xz-utils

# ============================================================
# 2. 安装 Node.js 22.x (通过国内二进制镜像)
# ============================================================
if command -v node &>/dev/null && [[ "$(node -v)" == v${NODE_MAJOR}.* ]]; then
    info "Node.js $(node -v) 已安装，跳过"
else
    info "正在从国内镜像 (npmmirror) 下载 Node.js 二进制包..."
    
    # 自动识别系统架构
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then ARCH="x64"; fi
    if [ "$ARCH" = "aarch64" ]; then ARCH="arm64"; fi
    
    # 获取最新的 22.x 版本号
    NODE_V="v22.14.0" 
    
    cd /tmp
    DOWNLOAD_URL="https://npmmirror.com/mirrors/node/$NODE_V/node-$NODE_V-linux-$ARCH.tar.xz"
    
    info "下载地址: $DOWNLOAD_URL"
    wget -c "$DOWNLOAD_URL" -O node-pkg.tar.xz
    
    info "解压并安装到 /usr/local..."
    tar -xJf node-pkg.tar.xz
    # 排除掉 readme 和 license 文件，只拷贝核心目录
    cp -rn node-$NODE_V-linux-$ARCH/{bin,include,lib,share} /usr/local/
    
    # 清理缓存
    rm -rf node-pkg.tar.xz node-$NODE_V-linux-$ARCH
fi

info "Node.js 版本: $(node -v)"
info "npm 版本:     $(npm -v)"

# ============================================================
# 3. 配置 npm 加速
# ============================================================
info "设置 npm 全局使用国内镜像源..."
npm config set registry https://registry.npmmirror.com -g

# ============================================================
# 4. 配置 SSH
# ============================================================
info "配置 SSH 登录权限..."
SSHD_CONFIG="/etc/ssh/sshd_config"
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/'      "$SSHD_CONFIG"
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG"
systemctl restart sshd || systemctl restart ssh

# ============================================================
# 5. 安装 OpenClaw
# ============================================================
info "正在安装 OpenClaw ${OPENCLAW_VERSION}..."
npm install -g "openclaw@${OPENCLAW_VERSION}" --registry=https://registry.npmmirror.com \
    || error "OpenClaw 安装失败"

info "OpenClaw 已安装: $(openclaw --version)"

# ============================================================
# 6. 初始化
# ============================================================
info "正在执行 OpenClaw 初始化..."
openclaw onboard --install-daemon

# ============================================================
# 7. 完成
# ============================================================
echo ""
echo "========================================"
echo -e "  ${GREEN}安装成功！${NC}"
echo "  Node.js 和 OpenClaw 均已通过国内镜像完成。"
echo "========================================"
echo ""
echo "你可以通过以下命令启动 Gateway："
echo "  openclaw gateway"
echo ""
