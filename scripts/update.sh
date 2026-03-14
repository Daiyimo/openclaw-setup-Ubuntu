#!/bin/bash

# OpenClaw 加速更新脚本
# 适用于：已通过 setup.sh 安装好的服务器，执行 openclaw update 时走国内镜像加速
#
# 用法：
#   sudo bash update.sh              # 升级到最新版
#   OPENCLAW_VERSION=2026.3.13 sudo bash update.sh  # 升级到指定版本
#   sudo bash update.sh --reinstall # 强制重新安装

ACTUAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo ~$ACTUAL_USER)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

NPM_MIRROR="https://registry.npmmirror.com"
export PATH="$USER_HOME/.local/bin:/usr/local/bin:/usr/bin:$PATH"

# 检查是否为强制重装模式
FORCE_REINSTALL=false
if [[ "$1" == "--reinstall" ]]; then
    FORCE_REINSTALL=true
fi

echo -e "${GREEN}>>> OpenClaw 加速更新工具${NC}"
echo -e "npm 镜像: ${CYAN}$NPM_MIRROR${NC}"

# --- 0. 清理旧版本（避免混合安装问题）---
if [ "$FORCE_REINSTALL" = true ]; then
    echo -e "\n${YELLOW}[*] 强制重装模式，清理旧版本...${NC}"
    # 停止 pm2
    pm2 stop openclaw 2>/dev/null || true
    pm2 delete openclaw 2>/dev/null || true

    # 卸载所有安装方式的 openclaw
    npm uninstall -g openclaw 2>/dev/null || true
    pnpm remove -g openclaw 2>/dev/null || true

    # 清理旧文件和链接
    rm -rf "$USER_HOME/.local/share/pnpm" 2>/dev/null || true
    rm -f "$USER_HOME/.local/bin/openclaw" 2>/dev/null || true
    rm -f /usr/local/bin/openclaw 2>/dev/null || true
    rm -f /usr/bin/openclaw 2>/dev/null || true
    rm -rf /usr/lib/node_modules/openclaw 2>/dev/null || true

    echo -e "${GREEN}[✓] 旧版本已清理${NC}"
fi

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

# 查找 openclaw 模块目录
OPENCLAW_MODULE_PATH=""
for path in "$USER_HOME/.local/lib/node_modules/openclaw" "/usr/lib/node_modules/openclaw" "/usr/local/lib/node_modules/openclaw"; do
    if [ -d "$path" ]; then
        OPENCLAW_MODULE_PATH="$path"
        break
    fi
done

# 检测安装类型
INSTALL_TYPE="unknown"
if [ -n "$OPENCLAW_BIN_PATH" ]; then
    if [[ "$OPENCLAW_BIN_PATH" == *".local/bin"* ]]; then
        INSTALL_TYPE="pnpm"
    elif [[ "$OPENCLAW_BIN_PATH" == "/usr/bin/openclaw" ]] || [[ "$OPENCLAW_BIN_PATH" == "/usr/local/bin/openclaw" ]]; then
        INSTALL_TYPE="npm"
    fi
fi

# 如果模块存在但bin不存在，尝试修复
if [ -z "$OPENCLAW_BIN_PATH" ] && [ -n "$OPENCLAW_MODULE_PATH" ]; then
    echo -e "${YELLOW}[!] 发现模块目录但 bin 链接丢失，尝试修复...${NC}"
    if [ -f "$OPENCLAW_MODULE_PATH/openclaw.mjs" ]; then
        ln -sf "$OPENCLAW_MODULE_PATH/openclaw.mjs" /usr/local/bin/openclaw 2>/dev/null || true
        OPENCLAW_BIN_PATH="/usr/local/bin/openclaw"
        INSTALL_TYPE="npm"
    fi
fi

echo -e "检测到安装方式: ${YELLOW}$INSTALL_TYPE${NC}"
if [ -n "$OPENCLAW_BIN_PATH" ]; then
    echo -e "bin 路径: $OPENCLAW_BIN_PATH"
fi

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
        sudo -H -u "$ACTUAL_USER" pnpm config set registry "$NPM_MIRROR" 2>/dev/null || true
    fi
fi
echo -e "${GREEN}[✓] 镜像已设置${NC}"

# --- 3. 执行更新 ---
echo -e "\n${CYAN}[3/4] 执行更新...${NC}"

if [ -n "$OPENCLAW_VERSION" ]; then
    # 指定版本模式
    TARGET_VERSION="$OPENCLAW_VERSION"
else
    # 获取最新版本
    TARGET_VERSION="latest"
fi

echo -e "目标版本: ${YELLOW}$TARGET_VERSION${NC}"

# 执行安装/更新
case "$INSTALL_TYPE" in
    pnpm)
        echo -e "使用 pnpm 升级..."
        # 清理旧的 pnpm 全局模块
        rm -rf "$USER_HOME/.local/share/pnpm" 2>/dev/null || true
        sudo -H -u "$ACTUAL_USER" env PATH="$USER_HOME/.local/bin:$PATH" pnpm add -g "openclaw@$TARGET_VERSION"
        ;;
    npm)
        echo -e "使用 npm 升级..."
        # 清理旧的 npm 全局模块
        rm -rf /usr/lib/node_modules/openclaw 2>/dev/null || true
        sudo npm install -g "openclaw@$TARGET_VERSION"
        ;;
    *)
        # 默认尝试 npm（更可靠）
        echo -e "未检测到安装方式，使用 npm 安装..."
        sudo npm install -g "openclaw@$TARGET_VERSION"
        ;;
esac

# --- 4. 修复软链接 ---
echo -e "\n${CYAN}[4/4] 修复软链接...${NC}"

# 重新查找 openclaw 位置
OPENCLAW_BIN_PATH=""
for path in "$USER_HOME/.local/bin/openclaw" "/usr/local/bin/openclaw" "/usr/bin/openclaw"; do
    if [ -f "$path" ]; then
        OPENCLAW_BIN_PATH="$path"
        break
    fi
done

# 如果 bin 存在但模块目录不存在，尝试修复
if [ -n "$OPENCLAW_BIN_PATH" ]; then
    # 检查主文件是否存在
    if [[ "$OPENCLAW_BIN_PATH" == *".local/bin"* ]]; then
        # pnpm 模式，检查模块
        if [ ! -d "$USER_HOME/.local/share/pnpm" ]; then
            echo -e "${YELLOW}[!] pnpm 模块可能损坏，尝试修复...${NC}"
        fi
    fi

    # 确保 /usr/local/bin 有链接
    if [ "$OPENCLAW_BIN_PATH" != "/usr/local/bin/openclaw" ]; then
        ln -sf "$OPENCLAW_BIN_PATH" /usr/local/bin/openclaw 2>/dev/null || true
    fi
    echo -e "${GREEN}[✓] 软链接已更新: /usr/local/bin/openclaw -> $OPENCLAW_BIN_PATH${NC}"
else
    echo -e "${RED}[✗] 无法找到 openclaw 二进制文件${NC}"
    echo -e "${YELLOW}请尝试: sudo bash update.sh --reinstall${NC}"
fi

# 验证版本
echo -e "\n${CYAN}验证安装...${NC}"
CURRENT_VERSION=$(openclaw --version 2>/dev/null | grep -oP 'OpenClaw \K[0-9.]+' || echo "")
if [ -n "$CURRENT_VERSION" ]; then
    echo -e "${GREEN}[✓] 当前版本: $CURRENT_VERSION${NC}"
else
    echo -e "${YELLOW}[!] 版本检查失败，尝试手动修复...${NC}"
    # 最后尝试：直接链接到可能的模块
    for mjs in /usr/lib/node_modules/openclaw/openclaw.mjs "$USER_HOME/.local/lib/node_modules/openclaw/openclaw.mjs"; do
        if [ -f "$mjs" ]; then
            ln -sf "$mjs" /usr/local/bin/openclaw 2>/dev/null || true
            CURRENT_VERSION=$(openclaw --version 2>/dev/null | grep -oP 'OpenClaw \K[0-9.]+' || echo "")
            if [ -n "$CURRENT_VERSION" ]; then
                echo -e "${GREEN}[✓] 修复成功，当前版本: $CURRENT_VERSION${NC}"
                break
            fi
        fi
    done
fi

echo -e "\n${GREEN}完成！${NC}"
echo -e "${YELLOW}提示：${NC}"
echo -e "- 直接运行 ${CYAN}openclaw gateway${NC} 启动"
echo -e "- 使用 ${CYAN}sudo openclaw gateway${NC} 运行"
echo -e "- 如需重启 Gateway：${CYAN}pm2 restart openclaw${NC}"
echo -e "- 如遇问题，尝试：${CYAN}sudo bash update.sh --reinstall${NC}"
