#!/bin/bash
set -e

# ============================================================
#  OpenClaw v2026.2.19 一键加速安装脚本 (Ubuntu 24.04+)
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
echo "  OpenClaw ${OPENCLAW_VERSION} 加速安装版"
echo "  镜像站：清华大学 TUNA / npmmirror"
echo "========================================"
echo ""

# ============================================================
# 1. 系统环境配置
# ============================================================
info "设置时区为 Asia/Shanghai..."
timedatectl set-timezone Asia/Shanghai

info "更新系统软件包..."
apt update && apt upgrade -y

info "安装基础工具..."
apt install -y curl wget git vim unzip tar build-essential gnupg

# ============================================================
# 2. 安装 Node.js 22.x (使用清华镜像)
# ============================================================
if command -v node &>/dev/null && [[ "$(node -v)" == v${NODE_MAJOR}.* ]]; then
    info "Node.js $(node -v) 已安装，跳过"
else
    info "配置 NodeSource 国内镜像源..."
    # 导入密钥
    sudo mkdir -p /usr/share/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -y -o /usr/share/keyrings/nodesource.gpg || true
    
    # 写入清华大学镜像源
    echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://mirrors.tuna.tsinghua.edu.cn/nodesource/deb_${NODE_MAJOR}.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
    
    info "正在从国内镜像安装 Node.js..."
    apt update
    apt install -y nodejs
fi

info "Node.js 版本: $(node -v)"

# ============================================================
# 3. 配置 npm 加速
# ============================================================
info "配置 npm 使用国内镜像源 (npmmirror)..."
npm config set registry https://registry.npmmirror.com -g

# ============================================================
# 4. 配置 SSH（允许 Root 登录）
# ============================================================
info "配置 SSH..."
SSHD_CONFIG="/etc/ssh/sshd_config"
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/'      "$SSHD_CONFIG"
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG"
systemctl restart sshd || systemctl restart ssh
info "SSH 配置完成"

# ============================================================
# 5. 全局安装 OpenClaw
# ============================================================
info "通过 npm 镜像安装 OpenClaw ${OPENCLAW_VERSION}..."
# 这里加上了 registry 参数确保万无一失
npm install -g "openclaw@${OPENCLAW_VERSION}" --registry=https://registry.npmmirror.com \
    || error "npm 安装失败，请检查网络连接"

info "OpenClaw 已安装: $(openclaw --version)"

# ============================================================
# 6. 初始化 OpenClaw
# ============================================================
info "正在执行 OpenClaw 初始化..."
openclaw onboard --install-daemon

# ============================================================
# 7. 完成
# ============================================================
echo ""
echo "========================================"
echo -e "  ${GREEN}OpenClaw 安装完成！速度已通过镜像加速。${NC}"
echo "========================================"
echo ""
echo "启动 Gateway："
echo "  openclaw gateway"
echo ""
