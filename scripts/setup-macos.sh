#!/bin/bash

# OpenClaw macOS 一键安装脚本
# 适用于 macOS 12+ (Monterey 及以上)
#
# 使用方法：
#   bash scripts/setup-macos.sh
#   OPENCLAW_VERSION=2026.3.2 bash scripts/setup-macos.sh  # 安装指定版本
#
# 命令行参数：
#   --version <版本>    指定 OpenClaw 版本
#   --no-onboard       跳过新手引导
#   --verbose          显示详细输出
#   --help            显示帮助

set -euo pipefail

# --- 兼容性检测 ---
# 检测 grep 是否支持 -P (macOS 默认 grep 不支持)
if echo "test" | grep -P "test" &>/dev/null; then
    GREP_OPT="-P"
else
    GREP_OPT="-E"
fi

# 获取用户目录（处理 sudo 场景）
get_user_home() {
    if [[ -n "${SUDO_USER:-}" ]]; then
        eval echo "~${SUDO_USER}"
    else
        echo "$HOME"
    fi
}
USER_HOME="$(get_user_home)"

# 颜色定义
BOLD='\033[1m'
ACCENT='\033[38;2;255;90;45m'
INFO='\033[38;2;255;138;91m'
SUCCESS='\033[38;2;47;191;113m'
WARN='\033[38;2;255;176;32m'
ERROR='\033[38;2;226;61;45m'
MUTED='\033[38;2;139;127;119m'
NC='\033[0m'

# 默认配置
OPENCLAW_VERSION="${OPENCLAW_VERSION:-2026.3.2}"
NPM_MIRROR="${NPM_MIRROR:-https://registry.npmmirror.com}"
GHPROXY="https://gh-proxy.com"
NO_ONBOARD=0
VERBOSE=0

# 命令行参数解析
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            OPENCLAW_VERSION="$2"
            shift 2
            ;;
        --no-onboard)
            NO_ONBOARD=1
            shift
            ;;
        --verbose)
            VERBOSE=1
            shift
            ;;
        --help|-h)
            echo "OpenClaw macOS 安装脚本"
            echo ""
            echo "用法: bash scripts/setup-macos.sh [选项]"
            echo ""
            echo "选项:"
            echo "  --version <版本>   指定 OpenClaw 版本 (默认: 2026.3.2)"
            echo "  --no-onboard      跳过新手引导"
            echo "  --verbose         显示详细输出"
            echo "  --help, -h        显示此帮助"
            echo ""
            echo "环境变量:"
            echo "  OPENCLAW_VERSION  OpenClaw 版本"
            echo "  NPM_MIRROR       npm 镜像源"
            exit 0
            ;;
        *)
            echo -e "${ERROR}未知选项: $1${NC}"
            exit 1
            ;;
    esac
done

if [[ "$VERBOSE" -eq 1 ]]; then
    set -x
fi

# 加速配置
NPM_MIRROR="${NPM_MIRROR:-https://registry.npmmirror.com}"
GHPROXY="https://gh-proxy.com"

ACTUAL_USER=$(whoami)

# --- Homebrew 环境变量 ---
# 加载 Homebrew 环境变量（如果存在）
if [[ -f "${HOMEBREW_PREFIX}/bin/brew" ]]; then
    eval "$(${HOMEBREW_PREFIX}/bin/brew shellenv)" 2>/dev/null || true
fi

# 检测芯片架构
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    HOMEBREW_PREFIX="/opt/homebrew"
else
    HOMEBREW_PREFIX="/usr/local"
fi

echo -e "${SUCCESS}============================================${NC}"
echo -e "${SUCCESS}  OpenClaw macOS 安装脚本${NC}"
echo -e "${SUCCESS}  目标版本: $OPENCLAW_VERSION${NC}"
echo -e "${SUCCESS}  npm 镜像: $NPM_MIRROR${NC}"
echo -e "${SUCCESS}  芯片架构: $ARCH${NC}"
echo -e "${SUCCESS}============================================${NC}"

# --- 1. 检查 Homebrew ---
echo -e "\n${INFO}>>> 1. 检查 Homebrew...${NC}"

if ! command -v brew &> /dev/null; then
    echo -e "${WARN}未检测到 Homebrew，正在安装...${NC}"
    # 使用 gh-proxy 加速 Homebrew 安装
    /bin/bash -c "$(curl -fsSL ${GHPROXY}/https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo -e "${SUCCESS}[✓] Homebrew 已安装${NC}"
    brew update
fi

# --- 2. 检查 Git ---
echo -e "\n${INFO}>>> 2. 检查 Git...${NC}"
if ! command -v git &> /dev/null; then
    echo -e "${WARN}未检测到 Git，正在安装...${NC}"
    brew install git
fi
echo -e "${SUCCESS}[✓] Git $(git --version 2>/dev/null || echo "已安装")${NC}"

# --- 3. 安装 Node.js 22 ---
echo -e "\n${INFO}>>> 3. 安装 Node.js...${NC}"

# 尝试安装 Node.js 22
if ! brew list node@22 &>/dev/null; then
    echo -e "${INFO}[*] 安装 Node.js 22...${NC}"
    brew install node@22 2>/dev/null || {
        echo -e "${WARN}[*] 尝试直接安装 Node.js...${NC}"
        brew install node 2>/dev/null || true
    }
fi

# 确保 Node.js 已安装并获取版本
if command -v node &>/dev/null; then
    NODE_VERSION=$(node --version)
    echo -e "${SUCCESS}[✓] Node.js: $NODE_VERSION${NC}"
else
    echo -e "${ERROR}[✗] Node.js 安装失败，请手动安装${NC}"
    exit 1
fi

# 安装 pnpm (优先使用 corepack，回退到 brew)
COREBOOK_FAILED=false
if command -v node &>/dev/null && [[ "$NODE_VERSION" =~ ^v22 ]]; then
    echo -e "${INFO}[*] 尝试使用 corepack 启用 pnpm...${NC}"
    if corepack enable 2>/dev/null; then
        echo -e "${SUCCESS}[✓] pnpm (via corepack)${NC}"
    else
        COREBOOK_FAILED=true
        echo -e "${WARN}[!] corepack 启用失败，尝试使用 brew 安装...${NC}"
    fi
fi

# 如果 corepack 失败或不可用，使用 brew 安装
if [[ "$COREBOOK_FAILED" == "true" ]] || ! command -v pnpm &>/dev/null; then
    brew install pnpm 2>/dev/null || {
        # 最后尝试：使用 npm 全局安装
        echo -e "${WARN}[!] brew 安装失败，尝试 npm 全局安装...${NC}"
        npm install -g pnpm 2>/dev/null || true
    }
fi

# 检查 pnpm 是否可用
if command -v pnpm &>/dev/null; then
    echo -e "${SUCCESS}[✓] pnpm: $(pnpm --version)${NC}"
fi

# --- 智能 PATH 刷新函数 ---
refresh_node_path() {
    # 尝试找到 Node.js 和全局模块路径
    local node_path=""
    local npm_global=""

    # 从 node 命令获取路径
    if command -v node &>/dev/null; then
        node_path="$(dirname "$(command -v node)")"
        npm_global="$(npm config get prefix 2>/dev/null || echo "")/bin"
    fi

    # Homebrew 路径
    local brew_paths="${HOMEBREW_PREFIX}/opt/node@22/bin:${HOMEBREW_PREFIX}/bin"

    # 合并路径（去重）
    local new_path="$node_path:$npm_global:$brew_paths:/usr/local/bin:$PATH"

    # 去除空值和重复
    export PATH=$(echo "$new_path" | tr ':' '\n' | awk '!seen[$0]++' | tr '\n' ':' | sed 's/:$//')
}

# 刷新 PATH
refresh_node_path

# --- 4. 设置 npm 镜像 ---
echo -e "\n${INFO}>>> 4. 设置 npm 镜像...${NC}"
npm config set registry "$NPM_MIRROR"
echo "registry=$NPM_MIRROR" > "$USER_HOME/.npmrc"
echo -e "${SUCCESS}[✓] npm 镜像已设置为 $NPM_MIRROR${NC}"

# --- 5. 设置 pnpm 镜像 ---
if command -v pnpm &> /dev/null; then
    pnpm config set registry "$NPM_MIRROR"
    echo -e "${SUCCESS}[✓] pnpm 镜像已设置${NC}"
fi

# --- 6. 检测并处理 GitHub SSH 配置问题 ---
echo -e "\n${INFO}>>> 5. 检测 GitHub 配置...${NC}"
GIT_CONFIG_BACKUP=""
if git config --global --get url."git@github.com:".insteadOf &>/dev/null; then
    GIT_CONFIG_BACKUP="$(git config --global --get url."git@github.com:".insteadOf 2>/dev/null || true)"
    if [[ -n "$GIT_CONFIG_BACKUP" ]]; then
        echo -e "${WARN}[!] 检测到 Git 全局 GitHub SSH 配置: ${ACCENT}$GIT_CONFIG_BACKUP${NC}"
        echo -e "${INFO}[*] 临时禁用 SSH 配置以避免安装失败...${NC}"
        git config --global --unset url."git@github.com:".insteadOf 2>/dev/null || true
    fi
fi

# --- 7. 安装 OpenClaw ---
echo -e "\n${INFO}>>> 6. 安装 OpenClaw...${NC}"
echo -e "${ACCENT}请选择安装方式：${NC}"
echo "1) npm 安装 (推荐，最稳定)"
echo "2) pnpm 安装"
echo "n) 暂不安装"

# 支持非交互模式（通过环境变量或命令行参数）
if [ -n "$INSTALL_METHOD" ]; then
    choice="$INSTALL_METHOD"
elif [ -z "$CI" ]; then
    read -p "选项 [1/2/n] (默认1): " choice
    choice="${choice:-1}"
else
    choice="1"
fi

# 恢复 GitHub SSH 配置的函数
restore_git_config() {
    if [[ -n "$GIT_CONFIG_BACKUP" ]]; then
        git config --global url."git@github.com:".insteadOf "$GIT_CONFIG_BACKUP" 2>/dev/null || true
        echo -e "${SUCCESS}[✓] GitHub SSH 配置已恢复${NC}"
    fi
}
trap restore_git_config EXIT

case $choice in
    1)
        echo -e "${INFO}使用 npm 安装...${NC}"
        npm install -g "openclaw@$OPENCLAW_VERSION"
        ;;
    2)
        echo -e "${INFO}使用 pnpm 安装...${NC}"
        pnpm add -g "openclaw@$OPENCLAW_VERSION"
        ;;
    *)
        echo -e "${ERROR}跳过安装。${NC}"
        exit 0
        ;;
esac

# --- 8. 验证安装 ---
echo -e "\n${INFO}>>> 7. 验证安装...${NC}"

# 刷新 PATH 并查找 openclaw
refresh_node_path
OPENCLAW_PATH=$(command -v openclaw 2>/dev/null || echo "")

if [ -n "$OPENCLAW_PATH" ]; then
    INSTALLED_VERSION=$(openclaw --version 2>/dev/null | grep $GREP_OPT 'OpenClaw \K[0-9.]+' || echo "")
    echo -e "${SUCCESS}[✓] OpenClaw $INSTALLED_VERSION 安装成功${NC}"
    echo -e "${SUCCESS}[✓] 安装路径: $OPENCLAW_PATH${NC}"

    # 运行新手引导（除非指定跳过）
    if [ "$NO_ONBOARD" -eq 0 ]; then
        echo -e "\n${INFO}正在运行新手引导...${NC}"
        openclaw onboard --install-daemon || true
    else
        echo -e "${INFO}跳过新手引导 (--no-onboard)${NC}"
    fi
else
    echo -e "${ERROR}[✗] 安装验证失败${NC}"
    echo -e "${YELLOW}请尝试手动运行: openclaw --version${NC}"
fi

# --- 9. 完成提示 ---
echo -e "\n${SUCCESS}============================================${NC}"
echo -e "${SUCCESS}安装完成！${NC}"
echo -e "${SUCCESS}============================================${NC}"
echo -e "${INFO}后续操作：${NC}"
echo -e "1. 运行 ${ACCENT}openclaw gateway${NC} 启动"
echo -e "2. 查看配置: ${ACCENT}openclaw config file${NC}"
echo -e "3. 升级版本: ${ACCENT}openclaw update${NC}"
echo -e "\n${WARN}注意：${NC}"
echo -e "- 首次使用可能需要重启终端或运行: source ~/.zshrc"
echo -e "- 如果命令找不到，添加以下到 ~/.zshrc:"
echo -e "  export PATH=\"\$(npm root -g)/../bin:\$PATH\""
echo -e "- Apple Silicon (M系列) 芯片: ${HOMEBREW_PREFIX}"
