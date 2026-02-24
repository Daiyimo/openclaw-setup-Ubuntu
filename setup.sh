#!/bin/bash
set -e

# ============================================================
#  OpenClaw v2026.2.19 环境安装脚本 (Ubuntu 24.04+)
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
echo "  OpenClaw ${OPENCLAW_VERSION} 环境安装"
echo "  模式：极速版 (手动初始化)"
echo "========================================"
echo ""

# 1. 彻底清理之前失败的残留 APT 源文件（解决你截图中的报错）
info "清理冲突的源文件..."
sudo rm -f /etc/apt/sources.list.d/nodesource.list

# ============================================================
# 1. 系统环境配置
# ============================================================
info "设置时区为 Asia/Shanghai..."
timedatectl set-timezone Asia/Shanghai

info "更新系统软件包列表..."
apt update

info "安装基础工具..."
apt install -y curl wget git vim unzip tar build-essential xz-utils

# ============================================================
# 2. 安装 Node.js 22.x (使用国内二进制镜像直装)
# ============================================================
if command -v node &>/dev/null && [[ "$(node -v)" == v${NODE_MAJOR}.* ]]; then
    info "Node.js $(node -v) 已安装，跳过"
else
    info "正在通过 npmmirror 下载 Node.js 二进制包 (跳过 APT)..."
    
    # 自动识别系统架构 (x64 或 arm64)
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then ARCH="x64"; fi
    if [ "$ARCH" = "aarch64" ]; then ARCH="arm64"; fi
    
    # 设定 Node.js 具体版本
    NODE_V="v22.14.0"
    
    cd /tmp
    DOWNLOAD_URL="https://npmmirror.com/mirrors/node/$NODE_V/node-$NODE_V-linux-$ARCH.tar.xz"
    
    info "下载地址: $DOWNLOAD_URL"
    # 使用 wget 直接下载，不检查证书以防万一
    wget --no-check-certificate -c "$DOWNLOAD_URL" -O node-pkg.tar.xz
    
    info "正在解压并部署到 /usr/local..."
    tar -xJf node-pkg.tar.xz
    
    # 将二进制文件拷贝到系统目录
    cp -rn node-$NODE_V-linux-$ARCH/{bin,include,lib,share} /usr/local/
    
    # 强制创建软链接确保全局可用
    ln -sf /usr/local/bin/node /usr/bin/node
    ln -sf /usr/local/bin/npm /usr/bin/npm
    
    # 清理安装包
    rm -rf node-pkg.tar.xz node-$NODE_V-linux-$ARCH
fi

info "Node.js 版本: $(node -v)"
info "npm 版本:     $(npm -v)"

# ============================================================
# 3. 配置 npm 加速 (关键步骤)
# ============================================================
info "配置 npm 全局使用国内镜像源..."
npm config set registry https://registry.npmmirror.com -g

# ============================================================
# 4. 配置 SSH
# ============================================================
info "配置 SSH 登录权限..."
SSHD_CONFIG="/etc/ssh/sshd_config"
if [ -f "$SSHD_CONFIG" ]; then
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/'      "$SSHD_CONFIG"
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG"
    systemctl restart sshd || systemctl restart ssh || true
fi

# ============================================================
# 5. 安装 OpenClaw 本体
# ============================================================
info "正在从国内镜像安装 OpenClaw ${OPENCLAW_VERSION}..."
npm install -g "openclaw@${OPENCLAW_VERSION}" --registry=https://registry.npmmirror.com \
    || error "OpenClaw 安装失败，请检查网络"

info "OpenClaw 已安装: $(openclaw --version)"

# ============================================================
# 6. 完成 (提示用户手动执行 onboard)
# ============================================================
echo ""
echo "========================================"
echo -e "  ${GREEN}环境安装成功！${NC}"
echo "========================================"
echo ""
echo "请手动执行以下命令进行初始化："
echo -e "  ${YELLOW}openclaw onboard --install-daemon${NC}"
echo ""
echo "启动 Gateway："
echo "  openclaw gateway"
echo ""
