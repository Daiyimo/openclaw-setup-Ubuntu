#!/bin/bash
set -e

# ============================================================
#  OpenClaw v2026.2.19 一键安装脚本 (Ubuntu 24.04+)
#  通过 gh-proxy.com 加速从 GitHub 下载源码并编译安装
# ============================================================

OPENCLAW_VERSION="v2026.2.19"
INSTALL_DIR="/opt/openclaw"
PROXY="https://gh-proxy.com"
SOURCE_URL="${PROXY}/https://github.com/openclaw/openclaw/archive/refs/tags/${OPENCLAW_VERSION}.tar.gz"
# 备用直连地址（gh-proxy 不可用时使用）
FALLBACK_URL="https://github.com/openclaw/openclaw/archive/refs/tags/${OPENCLAW_VERSION}.tar.gz"
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
timedatectl set-timezone Asia/Shanghai

info "更新系统软件包..."
apt update && apt upgrade -y

info "安装基础工具..."
apt install -y curl wget git vim unzip tar build-essential

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
info "npm 版本:     $(npm -v)"

# ============================================================
# 3. 安装 pnpm
# ============================================================
if command -v pnpm &>/dev/null; then
    info "pnpm $(pnpm -v) 已安装，跳过"
else
    info "安装 pnpm..."
    npm install -g pnpm
fi

info "pnpm 版本:    $(pnpm -v)"

# ============================================================
# 4. 配置 SSH（允许 Root 登录 + 密码认证）
# ============================================================
info "配置 SSH..."
SSHD_CONFIG="/etc/ssh/sshd_config"

sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/'        "$SSHD_CONFIG"
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG"

systemctl restart sshd || systemctl restart ssh
info "SSH 配置完成"

# ============================================================
# 5. 下载 OpenClaw 源码
# ============================================================
info "从 GitHub 下载 OpenClaw ${OPENCLAW_VERSION} 源码（通过 gh-proxy 加速）..."

TEMP_DIR=$(mktemp -d)
TARBALL="${TEMP_DIR}/openclaw.tar.gz"

curl -L --fail --progress-bar "${SOURCE_URL}" -o "${TARBALL}" \
    || { warn "gh-proxy 下载失败，尝试直连 GitHub..."; \
         curl -L --fail --progress-bar "${FALLBACK_URL}" -o "${TARBALL}"; } \
    || error "下载失败，请检查网络连接"

info "下载完成，正在解压..."
mkdir -p "${INSTALL_DIR}"
tar -xzf "${TARBALL}" -C "${INSTALL_DIR}" --strip-components=1

rm -rf "${TEMP_DIR}"
info "源码已解压到 ${INSTALL_DIR}"

# ============================================================
# 6. 安装依赖并构建
# ============================================================
info "安装项目依赖（pnpm install）..."
cd "${INSTALL_DIR}"
pnpm install

info "构建 Web UI..."
pnpm ui:build

info "构建项目..."
pnpm build

# ============================================================
# 7. 启动引导
# ============================================================
echo ""
echo "========================================"
echo -e "  ${GREEN}OpenClaw ${OPENCLAW_VERSION} 安装完成！${NC}"
echo "========================================"
echo ""
echo "安装目录: ${INSTALL_DIR}"
echo ""
echo "接下来请执行以下命令完成初始化："
echo ""
echo "  cd ${INSTALL_DIR}"
echo "  pnpm openclaw onboard --install-daemon"
echo ""
echo "启动 Gateway："
echo ""
echo "  pnpm openclaw gateway --port 18789 --verbose"
echo ""
echo "或使用全局安装方式："
echo ""
echo "  npm install -g openclaw@${OPENCLAW_VERSION}"
echo "  openclaw onboard --install-daemon"
echo "  openclaw gateway --port 18789 --verbose"
echo ""
