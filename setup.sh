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
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt install -y nodejs
npm install -g npm@latest pnpm@latest pm2@latest

# --- 核心优化：修复 pnpm 路径并持久化 ---
if [ "$ACTUAL_USER" != "root" ]; then
    echo -e "${CYAN}正在配置 $ACTUAL_USER 的 pnpm 全局环境...${NC}"
    # 自动初始化 pnpm
    sudo -u "$ACTUAL_USER" pnpm setup
    # 显式指定全局 Bin 目录
    sudo -u "$ACTUAL_USER" pnpm config set global-bin-dir "$USER_HOME/.local/bin"
    # 确保该目录立即进入当前执行环境的 PATH
    export PATH="$USER_HOME/.local/bin:$PATH"
    # 写入 bashrc 防止重启失效 (去重写入)
    grep -qF ".local/bin" "$USER_HOME/.bashrc" || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$USER_HOME/.bashrc"
fi

echo -e "\n${YELLOW}>>> 2.5 获取自定义配置仓库...${NC}"
[ ! -d "setup_repo" ] && sudo -u "$ACTUAL_USER" git clone https://gh-proxy.com/https://github.com/Daiyimo/openclaw-setup-Ubuntu.git setup_repo

echo -e "\n${YELLOW}>>> 3. 处理 OpenClaw 安装脚本...${NC}"
curl -fsSL https://openclaw.ai/install.sh -o openclaw_install.sh
chown "$ACTUAL_USER:$ACTUAL_USER" openclaw_install.sh

# 【关键优化】强制修改官方脚本中的版本逻辑 (尝试匹配并替换)
# 即使脚本不支持变量，我们也通过 sed 暴力修改脚本内的 version 赋值
sed -i "s/VERSION=\"latest\"/VERSION=\"$OPENCLAW_VERSION\"/g" openclaw_install.sh 2>/dev/null
sed -i "s/version=\"latest\"/version=\"$OPENCLAW_VERSION\"/g" openclaw_install.sh 2>/dev/null

echo -e "\n${GREEN}-------------------------------------------${NC}"
echo -e "设备 IP: ${CYAN}$(ip addr | grep -E "inet 19(2|8)" | head -n 1 | awk '{print $2}' | cut -d/ -f1)${NC}"
echo -e "执行用户: ${YELLOW}$ACTUAL_USER${NC}"
echo -e "锁定版本: ${CYAN}$OPENCLAW_VERSION${NC}"
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
# 自动尝试为用户刷新 PATH
sudo -u "$ACTUAL_USER" pm2 --version > /dev/null 2>&1

echo -e "${GREEN}安装完成！${NC}"
echo -e "${YELLOW}重要提示：${NC}"
echo -e "1. 请执行 ${CYAN}source ~/.bashrc${NC} 来激活命令。"
echo -e "2. 建议使用 ${CYAN}pm2 start openclaw${NC} 来运行程序。"
