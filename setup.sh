#!/bin/bash

# 定义颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${GREEN}>>> 1. 基础环境配置 (时区/SSH/更新)...${NC}"
# 设置时区
timedatectl set-timezone Asia/Shanghai

# 更新系统并安装基础工具
apt update && apt upgrade -y
apt install -y chrony openssh-server curl git

# 时间同步
systemctl enable --now chronyd
chronyc -a makestep

# SSH 配置 (允许 Root 密码登录)
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh
echo -e "${CYAN}基础环境与 SSH 配置已完成。${NC}"

echo -e "\n${GREEN}>>> 2. 安装并更新 Node.js 环境...${NC}"
# 安装 Node.js 22
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt install -y nodejs

# 更新 NPM 到最新版本
echo -e "${YELLOW}正在更新 NPM 到最新版本...${NC}"
npm install -g npm@latest

# 安装并更新 pnpm
echo -e "${YELLOW}正在安装并更新 pnpm...${NC}"
curl -fsSL https://get.pnpm.io/install.sh | sh -
# 临时让当前 session 识别 pnpm (安装脚本通常会修改 .bashrc)
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# 确保 pnpm 是最新版
npm install -g pnpm@latest

echo -e "${CYAN}Node.js 版本: $(node -v)${NC}"
echo -e "${CYAN}NPM 版本: $(npm -v)${NC}"
echo -e "${CYAN}pnpm 版本: $(pnpm -v)${NC}"

echo -e "\n${YELLOW}>>> 3. 准备 OpenClaw 安装脚本...${NC}"
curl -fsSL https://openclaw.ai/install.sh -o openclaw_install.sh
echo -e "${CYAN}OpenClaw 安装脚本已下载至本地。${NC}"

echo -e "\n${GREEN}-------------------------------------------${NC}"
echo -e "环境已就绪。当前设备 IP: ${CYAN}$(ip addr | grep "inet 192" | awk '{print $2}' | cut -d/ -f1)${NC}"
echo -e "${GREEN}-------------------------------------------${NC}"

# 仅对 OpenClaw 进行交互确认
echo -e "${YELLOW}请选择 OpenClaw 的安装方式：${NC}"
echo "1) 使用官方脚本安装 (推荐)"
echo "2) 使用 pnpm 全局安装 (pnpm add -g openclaw@latest)"
echo "3) 使用 npm 全局安装 (npm install -g openclaw@latest)"
echo "n) 暂不安装"

read -p "请输入选项 [1/2/3/n]: " choice

case $choice in
    1)
        echo "正在运行官方安装脚本..."
        bash openclaw_install.sh
        ;;
    2)
        echo "正在通过 pnpm 安装 OpenClaw..."
        pnpm add -g openclaw@latest
        ;;
    3)
        echo "正在通过 npm 安装 OpenClaw..."
        npm install -g openclaw@latest
        ;;
    [nN])
        echo "已跳过 OpenClaw 安装。"
        ;;
    *)
        echo "无效输入，已跳过安装。"
        ;;
esac

echo -e "\n${GREEN}脚本运行完毕！${NC}"
