#!/bin/bash
set -e

# ============================================================
#  OpenClaw v2026.2.19 最终加速版 (不依赖 APT 仓库)
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

# 1. 彻底清理之前失败的残留 APT 源文件（消除你截图中的报错）
info "正在清理残留的错误源配置..."
rm -f /etc/apt/sources.list.d/nodesource.list

# 2. 系统环境配置
info "更新软件包列表并安装基础工具..."
apt update
apt install -y curl wget git vim unzip tar build-essential xz-utils

# ============================================================
# 3. 安装 Node.js 
# ============================================================
if command -v node &>/dev/null && [[ "$(node -v)" == v${NODE_MAJOR}.* ]]; then
    info "Node.js $(node -v) 已安装，跳过"
else
    info "正在通过 npmmirror 下载 Node.js 二进制包..."
    
    # 识别架构 (x64/arm64)
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then ARCH="x64"; fi
    if [ "$ARCH" = "aarch64" ]; then ARCH="arm64"; fi
    
    # 锁定版本
    NODE_V="v22.14.0"
    
    cd /tmp
    DOWNLOAD_URL="https://npmmirror.com/mirrors/node/$NODE_V/node-$NODE_V-linux-$ARCH.tar.xz"
    
    info "下载地址: $DOWNLOAD_URL"
    wget --no-check-certificate -c "$DOWNLOAD_URL" -O node-pkg.tar.xz
    
    info "正在部署 Node.js 到 /usr/local..."
    tar -xJf node-pkg.tar.xz
    
    # 强制覆盖并安装
    cp -rn node-$NODE_V-linux-$ARCH/{bin,include,lib,share} /usr/local/
    
    # 建立软链接确保全局可用
    ln -sf /usr/local/bin/node /usr/bin/node
    ln -sf /usr/local/bin/npm /usr/bin/npm
    
    rm -rf node-pkg.tar.xz node-$NODE_V-linux-$ARCH
fi

info "Node.js 版本: $(node -v)"

# ============================================================
# 4. 配置 npm 加速并安装 OpenClaw
# ============================================================
info "配置 npm 国内镜像源..."
npm config set registry https://registry.npmmirror.com -g

info "配置 SSH 权限..."
SSHD_CONFIG="/etc/ssh/sshd_config"
if [ -f "$SSHD_CONFIG" ]; then
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/'      "$SSHD_CONFIG"
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG"
    systemctl restart sshd || systemctl restart ssh || true
fi

info "正在安装 OpenClaw 本体..."
npm install -g "openclaw@${OPENCLAW_VERSION}" --registry=https://registry.npmmirror.com \
    || error "OpenClaw 安装失败"

# ============================================================
# 5. 完成
# ============================================================
echo ""
echo "========================================"
echo -e "  ${GREEN}安装环境成功！${NC}"
echo "========================================"
echo ""
echo "请通知客户手动执行以下命令初始化："
echo -e "  ${YELLOW}openclaw onboard --install-daemon${NC}"
echo ""
