#!/bin/bash

# --- 权限与用户信息获取 ---
# 获取调用 sudo 的原始用户名，如果是直接 root 登录则仍为 root
ACTUAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo ~$ACTUAL_USER)

# 定义颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}>>> 1. 基础环境配置 (Vim/时区/SSH/更新)...${NC}"
# 设置时区
timedatectl set-timezone Asia/Shanghai
echo -e "${CYAN}当前系统时区: $(cat /etc/timezone)${NC}"

# 更新系统并安装基础工具
apt update && apt upgrade -y
apt install -y chrony openssh-server curl git vim

# 修正：在 Ubuntu Noble 等新版本中，使用 chrony 而非 chronyd
systemctl unmask chrony.service > /dev/null 2>&1
systemctl enable chrony
systemctl start chrony
# 强制校验时间
chronyc -a makestep

# Vim 基础优化 (应用到原始用户和 root)
echo -e "set number\nsyntax on\nset tabstop=4" > ~/.vimrc
[ "$ACTUAL_USER" != "root" ] && echo -e "set number\nsyntax on\nset tabstop=4" > "$USER_HOME/.vimrc"

# SSH 配置
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh
echo -e "${CYAN}基础工具与 SSH 配置已完成。${NC}"

echo -e "\n${GREEN}>>> 2. 安装 Node.js 22 & 更新包管理器...${NC}"
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt install -y nodejs
npm install -g npm@latest pnpm@latest

echo -e "${CYAN}环境版本: Node $(node -v) | NPM $(npm -v) | pnpm $(pnpm -v)${NC}"

# --- 2.5 获取自定义 OpenClaw 配置仓库 (以普通用户身份) ---
echo -e "\n${YELLOW}>>> 2.5 获取自定义配置仓库...${NC}"
if [ ! -d "setup_repo" ]; then
    # 使用 sudo -u 确保文件夹所有权属于普通用户
    sudo -u "$ACTUAL_USER" git clone https://gh-proxy.com/https://github.com/Daiyimo/openclaw-setup-Ubuntu.git setup_repo
    echo -e "${GREEN}仓库已克隆至 setup_repo 目录 (所有者: $ACTUAL_USER)${NC}"
else
    echo -e "${CYAN}setup_repo 目录已存在，跳过克隆。${NC}"
fi

echo -e "\n${YELLOW}>>> 3. 获取 OpenClaw 安装脚本...${NC}"
# 下载 OpenClaw 安装脚本并赋予权限
curl -fsSL https://openclaw.ai/install.sh -o openclaw_install.sh
chown "$ACTUAL_USER:$ACTUAL_USER" openclaw_install.sh

echo -e "\n${GREEN}-------------------------------------------${NC}"
echo -e "环境准备就绪！设备内网 IP: ${CYAN}$(ip addr | grep -E "inet 19(2|8)" | head -n 1 | awk '{print $2}' | cut -d/ -f1)${NC}"
echo -e "当前执行用户: ${YELLOW}$ACTUAL_USER${NC}"
echo -e "OpenClaw 安装脚本已就绪，可自动适配最新版本。"
echo -e "${GREEN}-------------------------------------------${NC}"

# 交互安装 OpenClaw
echo -e "${YELLOW}请选择 OpenClaw 安装方式 (将以 $ACTUAL_USER 身份执行)：${NC}"
echo "1) 使用官方脚本安装 (推荐)"
echo "2) 使用 pnpm 全局安装"
echo "3) 使用 npm 全局安装"
echo "n) 暂不安装"

read -p "请输入选项 [1/2/3/n]: " choice

case $choice in
    1)
        sudo -u "$ACTUAL_USER" bash openclaw_install.sh
        ;;
    2)
        sudo -u "$ACTUAL_USER" pnpm add -g openclaw
        ;;
    3)
        sudo -u "$ACTUAL_USER" npm install -g openclaw
        ;;
    *)
        echo -e "${RED}已跳过 OpenClaw 安装。${NC}"
        ;;
esac

echo -e "\n${GREEN}脚本运行完毕，祝你开发顺利，$ACTUAL_USER！${NC}"
