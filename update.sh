#!/bin/bash

# OpenClaw 加速更新脚本
# 适用于：已通过 setup.sh 安装好的服务器，执行 openclaw update 时走国内镜像加速
#
# 用法：
#   sudo bash update.sh              # 升级到最新版
#   OPENCLAW_VERSION=2026.3.2 sudo bash update.sh  # 升级到指定版本

ACTUAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo ~$ACTUAL_USER)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

NPM_MIRROR="https://registry.npmmirror.com"
# 确保 pnpm 路径
export PATH="$USER_HOME/.local/bin:/usr/local/bin:/usr/bin:$PATH"

echo -e "${GREEN}>>> OpenClaw 加速更新工具${NC}"
echo -e "npm 镜像: ${CYAN}$NPM_MIRROR${NC}"

# --- 1. 检测安装方式 ---
echo -e "\n${CYAN}[1/4] 检测安装方式...${NC}"

# 查找 openclaw 二进制文件位置
OPENCLAW_BIN_PATH=""
for path in "$USER_HOME/.local/bin/openclaw" "/usr/local/bin/openclaw" "/usr/bin/openclaw"; do
    if [ -f "$path" ]; then
        OPENCLAW_BIN_PATH="$path"
        break
    fi
done

# 检测是通过哪种包管理器安装的
INSTALL_TYPE=""
if [ -n "$OPENCLAW_BIN_PATH" ]; then
    # 检查 node_modules 链接确定安装方式
    if [ "$OPENCLAW_BIN_PATH" = "$USER_HOME/.local/bin/openclaw" ]; then
        # pnpm 安装在用户目录
        if command -v pnpm &>/dev/null; then
            INSTALL_TYPE="pnpm"
        fi
    elif [ "$OPENCLAW_BIN_PATH" = "/usr/bin/openclaw" ] || [ "$OPENCLAW_BIN_PATH" = "/usr/local/bin/openclaw" ]; then
        # 可能是 npm 全局安装
        INSTALL_TYPE="npm"
    fi
fi

# 如果无法检测，尝试直接运行 openclaw update
if [ -z "$INSTALL_TYPE" ]; then
    if command -v openclaw &>/dev/null; then
        INSTALL_TYPE="auto"
    fi
fi

echo -e "检测到安装方式: ${YELLOW}$INSTALL_TYPE${NC}"

# --- 2. 设置镜像 ---
echo -e "\n${CYAN}[2/4] 设置 npm/pnpm 镜像...${NC}"

# npm 镜像
npm config set registry "$NPM_MIRROR" 2>/dev/null || true
echo "registry=$NPM_MIRROR" > /root/.npmrc
if [ "$ACTUAL_USER" != "root" ]; then
    echo "registry=$NPM_MIRROR" > "$USER_HOME/.npmrc"
    chown "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME/.npmrc"
fi

# pnpm 镜像
if command -v pnpm &>/dev/null; then
    pnpm config set registry "$NPM_MIRROR" 2>/dev/null || true
    if [ "$ACTUAL_USER" != "root" ]; then
        sudo -u "$ACTUAL_USER" pnpm config set registry "$NPM_MIRROR" 2>/dev/null || true
    fi
fi
echo -e "${GREEN}[✓] 镜像已设置${NC}"

# --- 3. 执行更新 ---
echo -e "\n${CYAN}[3/4] 执行更新...${NC}"

if [ -n "$OPENCLAW_VERSION" ]; then
    # 指定版本模式
    echo -e "${YELLOW}指定版本: $OPENCLAW_VERSION${NC}"

    case "$INSTALL_TYPE" in
        pnpm)
            echo -e "使用 pnpm 升级..."
            sudo -u "$ACTUAL_USER" env PATH="$USER_HOME/.local/bin:$PATH" pnpm add -g "openclaw@$OPENCLAW_VERSION"
            ;;
        npm)
            echo -e "使用 npm 升级..."
            sudo npm install -g "openclaw@$OPENCLAW_VERSION"
            ;;
        *)
            # 尝试检测并升级
            if command -v pnpm &>/dev/null && pnpm list -g openclaw 2>/dev/null | grep -q openclaw; then
                echo -e "使用 pnpm 升级..."
                sudo -u "$ACTUAL_USER" env PATH="$USER_HOME/.local/bin:$PATH" pnpm add -g "openclaw@$OPENCLAW_VERSION"
            else
                echo -e "使用 npm 升级..."
                sudo npm install -g "openclaw@$OPENCLAW_VERSION"
            fi
            ;;
    esac
else
    # 最新版模式：使用 openclaw update
    echo -e "使用 openclaw update 升级到最新版..."

    if command -v openclaw &>/dev/null; then
        # 设置环境变量让 update 也走镜像
        export npm_config_registry="$NPM_MIRROR"
        openclaw update
    else
        echo -e "${RED}openclaw 命令未找到，请先运行 setup.sh 安装。${NC}"
        exit 1
    fi
fi

# --- 4. 完成 ---
echo -e "\n${CYAN}[4/4] 更新完成，检查版本...${NC}"

# 重新查找 openclaw 位置
OPENCLAW_BIN_PATH=""
for path in "$USER_HOME/.local/bin/openclaw" "/usr/local/bin/openclaw" "/usr/bin/openclaw"; do
    if [ -f "$path" ]; then
        OPENCLAW_BIN_PATH="$path"
        break
    fi
done

# 创建软链接
if [ -n "$OPENCLAW_BIN_PATH" ]; then
    ln -sf "$OPENCLAW_BIN_PATH" /usr/local/bin/openclaw 2>/dev/null || true
    echo -e "${GREEN}[✓] 软链接已更新${NC}"
fi

# 验证版本
CURRENT_VERSION=$(openclaw --version 2>/dev/null | grep -oP 'OpenClaw \K[0-9.]+' || echo "")
if [ -n "$CURRENT_VERSION" ]; then
    echo -e "${GREEN}[✓] 当前版本: $CURRENT_VERSION${NC}"
else
    echo -e "${YELLOW}[!] 版本检查失败${NC}"
fi

echo -e "\n${GREEN}完成！${NC}"
echo -e "${YELLOW}提示：${NC}"
echo -e "- 直接运行 ${CYAN}openclaw gateway${NC} 启动"
echo -e "- 使用 ${CYAN}sudo openclaw gateway${NC} 运行"
echo -e "- 如需重启 Gateway：${CYAN}pm2 restart openclaw${NC}"
