#!/bin/bash

# OpenClaw 加速更新脚本
# 适用于：已通过 setup.sh 安装好的服务器，执行 openclaw update 时走国内镜像加速
#
# 用法：sudo bash update.sh
# 也可以指定版本：OPENCLAW_VERSION=2026.3.2 sudo bash update.sh

ACTUAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo ~$ACTUAL_USER)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

NPM_MIRROR="https://registry.npmmirror.com"

echo -e "${GREEN}>>> OpenClaw 加速更新工具${NC}"
echo -e "npm 镜像: ${CYAN}$NPM_MIRROR${NC}"

# --- 1. 确保 npm 镜像已设置 ---
echo -e "\n${CYAN}[1/3] 设置 npm 镜像...${NC}"
npm config set registry "$NPM_MIRROR"
echo "registry=$NPM_MIRROR" > /root/.npmrc
if [ "$ACTUAL_USER" != "root" ]; then
    echo "registry=$NPM_MIRROR" > "$USER_HOME/.npmrc"
    chown "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME/.npmrc"
fi
# pnpm 同步设置
pnpm config set registry "$NPM_MIRROR" 2>/dev/null || true
if [ "$ACTUAL_USER" != "root" ]; then
    sudo -u "$ACTUAL_USER" pnpm config set registry "$NPM_MIRROR" 2>/dev/null || true
fi

# --- 2. 执行更新 ---
echo -e "\n${CYAN}[2/3] 执行 openclaw update...${NC}"

if [ -n "$OPENCLAW_VERSION" ]; then
    # 指定版本时直接用 npm 安装，跳过 openclaw update（update 不支持指定版本）
    echo -e "${YELLOW}指定版本模式: $OPENCLAW_VERSION${NC}"
    # 检测当前安装方式
    if command -v pnpm &>/dev/null && pnpm list -g openclaw 2>/dev/null | grep -q openclaw; then
        echo -e "检测到 pnpm 全局安装，使用 pnpm 升级..."
        sudo -u "$ACTUAL_USER" pnpm add -g "openclaw@$OPENCLAW_VERSION"
    else
        echo -e "使用 npm 升级..."
        npm install -g "openclaw@$OPENCLAW_VERSION"
    fi
else
    # 无指定版本：走 openclaw update（npm 镜像已设置，会自动走加速）
    echo -e "使用 openclaw update 升级到最新版..."
    if command -v openclaw &>/dev/null; then
        openclaw update
    else
        echo -e "${RED}openclaw 命令未找到，请先运行 setup.sh 安装。${NC}"
        exit 1
    fi
fi

# --- 3. 完成 ---
echo -e "\n${CYAN}[3/3] 更新完成，检查版本...${NC}"
openclaw --version 2>/dev/null || echo -e "${YELLOW}版本检查失败，请手动执行 openclaw --version${NC}"

echo -e "\n${GREEN}完成！${NC}"
echo -e "${YELLOW}提示：${NC}"
echo -e "- 如需重启 Gateway：${CYAN}openclaw gateway restart${NC}"
echo -e "- 如使用 pm2 管理：${CYAN}pm2 restart openclaw${NC}"
