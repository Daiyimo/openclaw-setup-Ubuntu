#!/bin/bash
set -e

# ============================================================
#  OpenClaw v2026.2.19 一键安装脚本 (Ubuntu 24.04+)
#  通过 npm 全局安装 OpenClaw 并自动完成初始化
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
echo "  OpenClaw ${OPENCLAW_VERSION} 一键安装"
echo "  适用于 Ubuntu 24.04+"
echo "========================================"
echo ""

# ============================================================
# 1. 系统环境配置
# ============================================================
info "设置时区为 Asia/Shanghai..."
timedatectl set-timezone Asia/Shanghai || warn "无法设置时区"

info "更新系统软件包..."
apt update && apt upgrade -y

info "安装基础工具及 SSH 服务..."
# 显式安装 openssh-server 以防系统精简版缺少该服务
apt install -y curl wget git vim unzip tar build-essential openssh-server

# ============================================================
# 2. 安装 Node.js 22.x
# ============================================================
if command -v node &>/dev/null && [[ "$(node -v)" == v${NODE_MAJOR}.* ]]; then
    info "Node.js $(node -v) 已安装，跳过"
else
    info "安装 Node.js ${NODE_MAJOR}.x..."
    curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash -
    apt install -y nodejs
fi

info "Node.js 版本: $(node -v)"
info "npm 版本:      $(npm -v)"

# ============================================================
# 3. 配置 SSH（允许 Root 登录 + 密码认证）
# ============================================================
info "正在配置 SSH 策略..."
SSHD_CONFIG="/etc/ssh/sshd_config"

# 确保服务已启动并开机自启
systemctl enable ssh
systemctl start ssh

# 自动修改配置，不再需要手动执行 nano
# 逻辑：如果配置行存在则替换，如果不存在则在文件末尾追加
grep -q "^PermitRootLogin" "$SSHD_CONFIG" && \
    sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' "$SSHD_CONFIG" || \
    echo "PermitRootLogin yes" >> "$SSHD_CONFIG"

grep -q "^PasswordAuthentication" "$SSHD_CONFIG" && \
    sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG" || \
    echo "PasswordAuthentication yes" >> "$SSHD_CONFIG"

# 重启服务使配置生效
systemctl restart ssh
info "SSH 配置已完成并已重启服务"

# ============================================================
# 4. 全局安装 OpenClaw
# ============================================================
info "通过 npm 全局安装 OpenClaw ${OPENCLAW_VERSION}..."
npm install -g "openclaw@${OPENCLAW_VERSION}" \
    || error "npm 安装失败，请检查网络连接"

info "OpenClaw 已安装: $(openclaw --version)"

# --- 查看全局 node_modules 及 extensions 路径 ---
GLOBAL_NODE_MODULES="$(npm root -g)"
info "全局 node_modules 路径: ${GLOBAL_NODE_MODULES}"

EXTENSIONS_DIR="${GLOBAL_NODE_MODULES}/openclaw/extensions"
if [ -d "${EXTENSIONS_DIR}" ]; then
    info "openclaw/extensions 路径: ${EXTENSIONS_DIR}"
    ls -la "${EXTENSIONS_DIR}"
else
    warn "未找到 openclaw/extensions 目录: ${EXTENSIONS_DIR}"
fi

# ============================================================
# 5. 初始化 OpenClaw（安装 daemon 服务）
# ============================================================
info "正在执行 OpenClaw 初始化..."
# 注意：这里如果提示设置 root 密码，请确保你已经手动设置过系统 root 密码
openclaw onboard --install-daemon

# ============================================================
# 6. 完成
# ============================================================
echo ""
echo "========================================"
echo -e "  ${GREEN}OpenClaw ${OPENCLAW_VERSION} 安装完成！${NC}"
echo "========================================"
echo ""
echo "启动 Gateway："
echo ""
echo "  openclaw gateway --port 18789 --verbose"
echo ""
