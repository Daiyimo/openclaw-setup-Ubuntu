#!/bin/bash

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

# Vim 基础优化
echo -e "set number\nsyntax on\nset tabstop=4" > ~/.vimrc

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

# --- 新增融合部分：克隆配置仓库 ---
echo -e "\n${YELLOW}>>> 2.5 获取自定义 OpenClaw 配置仓库...${NC}"
if [ ! -d "setup_repo" ]; then
    git clone https://gh-proxy.com/https://github.com/Daiyimo/openclaw-setup-Ubuntu.git setup_repo
    echo -e "${GREEN}仓库已克隆至 setup_repo 目录${NC}"
else
    echo -e "${CYAN}setup_repo 目录已存在，跳过克隆。${NC}"
fi
# ------------------------------

echo -e "\n${YELLOW}>>> 3. 获取 OpenClaw 安装脚本 (v2026.2.12+)...${NC}"
# 下载 OpenClaw 安装脚本
curl -fsSL https://openclaw.ai/install.sh -o openclaw_install.sh

echo -e "\n${GREEN}-------------------------------------------${NC}"
echo -e "环境准备就绪！设备内网 IP: ${CYAN}$(ip addr | grep -E "inet 19(2|8)" | head -n 1 | awk '{print $2}' | cut -d/ -f1)${NC}"
echo -e "OpenClaw v2026.2.12 特性：支持使用 ${YELLOW}--local-time${NC} 同步系统时区日志。"
echo -e "${GREEN}-------------------------------------------${NC}"

# 交互安装 OpenClaw
echo -e "${YELLOW}请选择 OpenClaw 安装方式：${NC}"
echo "1) 使用官方脚本安装 (推荐)"
echo "2) 使用 pnpm 全局安装"
echo "3) 使用 npm 全局安装"
echo "n) 暂不安装"

read -p "请输入选项 [1/2/3/n]: " choice

case $choice in
    1)
        bash openclaw_install.sh
        ;;
    2)
        pnpm add -g openclaw@latest
        ;;
    3)
        npm install -g openclaw@latest
        ;;
    *)
        echo -e "${RED}已跳过 OpenClaw 安装。${NC}"
        ;;
esac

echo -e "\n${GREEN}脚本运行完毕，祝你开发顺利！${NC}"
