#!/bin/bash

# --- 权限与用户信息获取 ---
ACTUAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo ~$ACTUAL_USER)
# 预设锁定版本
export OPENCLAW_VERSION="2026.2.19"

# 定义颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# ============================================================
# 加速配置
# 国内服务器访问 npmjs.org / NodeSource 较慢，统一切换镜像源。
# npm 镜像：npmmirror.com（阿里云官方维护，与 npmjs.org 实时同步）
# NodeSource 镜像：通过 gh-proxy 代理拉取安装脚本
# ============================================================
NPM_MIRROR="https://registry.npmmirror.com"

apply_npm_mirror() {
    echo -e "${CYAN}[加速] 设置 npm 镜像 -> $NPM_MIRROR${NC}"
    npm config set registry "$NPM_MIRROR"
    # 同步写入 root 和实际用户的 .npmrc，确保 sudo 场景也生效
    echo "registry=$NPM_MIRROR" > /root/.npmrc
    if [ "$ACTUAL_USER" != "root" ]; then
        echo "registry=$NPM_MIRROR" > "$USER_HOME/.npmrc"
        chown "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME/.npmrc"
    fi
    echo -e "${GREEN}[加速] npm 镜像已设置。openclaw update 将自动走此镜像。${NC}"
}

echo -e "${GREEN}>>> 1. 基础环境配置 (构建工具/时区/SSH)...${NC}"
timedatectl set-timezone Asia/Shanghai

# 增加 build-essential (防止 node-gyp 编译失败)
apt update && apt upgrade -y
apt install -y chrony openssh-server curl git vim build-essential

# 时间同步配置
systemctl unmask chrony.service > /dev/null 2>&1
systemctl enable chrony && systemctl start chrony
chronyc -a makestep

# SSH 与 Vim 优化
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh
echo -e "set number\nsyntax on\nset tabstop=4" > ~/.vimrc
[ "$ACTUAL_USER" != "root" ] && echo -e "set number\nsyntax on\nset tabstop=4" > "$USER_HOME/.vimrc"

echo -e "\n${GREEN}>>> 2. 安装 Node.js 22 & 包管理器...${NC}"
# 通过 gh-proxy 代理拉取 NodeSource 安装脚本（国内加速）
curl -fsSL https://gh-proxy.com/https://raw.githubusercontent.com/nodesource/distributions/main/scripts/deb/setup_22.x | bash -
apt install -y nodejs

# 设置 npm 镜像（安装 npm/pnpm/pm2 前执行，全程走镜像）
apply_npm_mirror

npm install -g npm@latest pnpm@latest pm2@latest

# pnpm 也设置镜像
pnpm config set registry "$NPM_MIRROR" 2>/dev/null || true

# --- 核心优化：修复 pnpm 路径并持久化 ---
if [ "$ACTUAL_USER" != "root" ]; then
    echo -e "${CYAN}正在配置 $ACTUAL_USER 的 pnpm 全局环境...${NC}"
    sudo -u "$ACTUAL_USER" pnpm setup
    sudo -u "$ACTUAL_USER" pnpm config set global-bin-dir "$USER_HOME/.local/bin"
    sudo -u "$ACTUAL_USER" pnpm config set registry "$NPM_MIRROR"
    export PATH="$USER_HOME/.local/bin:$PATH"
    grep -qF ".local/bin" "$USER_HOME/.bashrc" || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$USER_HOME/.bashrc"
fi

echo -e "\n${YELLOW}>>> 2.5 获取自定义配置仓库...${NC}"
[ ! -d "setup_repo" ] && sudo -u "$ACTUAL_USER" git clone https://gh-proxy.com/https://github.com/Daiyimo/openclaw-setup-Ubuntu.git setup_repo

echo -e "\n${YELLOW}>>> 3. 处理 OpenClaw 安装脚本...${NC}"
curl -fsSL https://openclaw.ai/install.sh -o openclaw_install.sh
chown "$ACTUAL_USER:$ACTUAL_USER" openclaw_install.sh

# 【关键优化】强制修改官方脚本中的版本逻辑 (尝试匹配并替换)
sed -i "s/VERSION=\"latest\"/VERSION=\"$OPENCLAW_VERSION\"/g" openclaw_install.sh 2>/dev/null
sed -i "s/version=\"latest\"/version=\"$OPENCLAW_VERSION\"/g" openclaw_install.sh 2>/dev/null

echo -e "\n${GREEN}-------------------------------------------${NC}"
echo -e "设备 IP: ${CYAN}$(ip addr | grep -E "inet 19(2|8)" | head -n 1 | awk '{print $2}' | cut -d/ -f1)${NC}"
echo -e "执行用户: ${YELLOW}$ACTUAL_USER${NC}"
echo -e "锁定版本: ${CYAN}$OPENCLAW_VERSION${NC}"
echo -e "npm 镜像: ${CYAN}$NPM_MIRROR${NC}"
echo -e "-------------------------------------------${NC}"

echo -e "${YELLOW}请选择安装方式：${NC}"
echo "1) 官方脚本安装 (已通过 sed 尝试锁定版本)"
echo "2) pnpm 锁定版本安装 (推荐，最快)"
echo "3) npm 锁定版本安装 (最稳)"
echo "n) 暂不安装"
read -p "选项 [1/2/3/n]: " choice

case $choice in
    1)
        sudo -E -u "$ACTUAL_USER" bash openclaw_install.sh
        ;;
    2)
        sudo -u "$ACTUAL_USER" pnpm add -g "openclaw@$OPENCLAW_VERSION"
        ;;
    3)
        sudo -u "$ACTUAL_USER" npm install -g "openclaw@$OPENCLAW_VERSION"
        ;;
    *)
        echo -e "${RED}跳过安装。${NC}"
        exit 0
        ;;
esac

# --- 4. 善后处理 ---
echo -e "\n${GREEN}>>> 4. 最后的检查...${NC}"
sudo -u "$ACTUAL_USER" pm2 --version > /dev/null 2>&1

echo -e "${GREEN}安装完成！${NC}"
echo -e "${YELLOW}重要提示：${NC}"
echo -e "1. 请执行 ${CYAN}source ~/.bashrc${NC} 来激活命令。"
echo -e "2. 建议使用 ${CYAN}pm2 start openclaw${NC} 来运行程序。"
echo -e "3. 升级 OpenClaw：${CYAN}openclaw update${NC}（已自动走 npmmirror 加速）。"
