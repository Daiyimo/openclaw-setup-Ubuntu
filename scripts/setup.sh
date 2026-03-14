#!/bin/bash

# --- 权限与用户信息获取 ---
ACTUAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo ~$ACTUAL_USER)
# 预设锁定版本
export OPENCLAW_VERSION="2026.3.13"

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
# GitHub 资源：使用 gh-proxy 代理加速
# ============================================================
NPM_MIRROR="https://registry.npmmirror.com"
GHPROXY="https://gh-proxy.com"

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
    # 使用 su 而不是 sudo，确保完整的用户环境
    su - "$ACTUAL_USER" -c "pnpm setup"
    su - "$ACTUAL_USER" -c "pnpm config set global-bin-dir '$USER_HOME/.local/bin'"
    su - "$ACTUAL_USER" -c "pnpm config set registry '$NPM_MIRROR'"
    export PATH="$USER_HOME/.local/bin:$PATH"
    grep -qF ".local/bin" "$USER_HOME/.bashrc" || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$USER_HOME/.bashrc"
fi

echo -e "\n${YELLOW}>>> 3. 处理 OpenClaw 安装脚本...${NC}"
# 尝试下载 OpenClaw 安装脚本（可能已失效，不影响选项 2/3）
curl -fsSL https://openclaw.ai/install.sh -o openclaw_install.sh 2>/dev/null || true
if [ -f openclaw_install.sh ]; then
    chown "$ACTUAL_USER:$ACTUAL_USER" openclaw_install.sh
    # 【关键优化】强制修改官方脚本中的版本逻辑
    sed -i "s/VERSION=\"latest\"/VERSION=\"$OPENCLAW_VERSION\"/g" openclaw_install.sh 2>/dev/null
    sed -i "s/version=\"latest\"/version=\"$OPENCLAW_VERSION\"/g" openclaw_install.sh 2>/dev/null
    # 尝试替换 gum 下载链接（使用 gh-proxy）
    sed -i 's|https://github.com/charmbracelet/gum|https://gh-proxy.com/https://github.com/charmbracelet/gum|g' openclaw_install.sh 2>/dev/null
fi

echo -e "\n${GREEN}-------------------------------------------${NC}"
echo -e "设备 IP: ${CYAN}$(ip addr | grep -E "inet 19(2|8)" | head -n 1 | awk '{print $2}' | cut -d/ -f1)${NC}"
echo -e "执行用户: ${YELLOW}$ACTUAL_USER${NC}"
echo -e "锁定版本: ${CYAN}$OPENCLAW_VERSION${NC}"
echo -e "npm 镜像: ${CYAN}$NPM_MIRROR${NC}"
echo -e "-------------------------------------------${NC}"

echo -e "${YELLOW}请选择安装方式：${NC}"
echo "1) 官方脚本安装 (需要访问 GitHub，国内服务器易失败)"
echo "2) pnpm 锁定版本安装 (推荐，走 npmmirror 镜像)"
echo "3) npm 锁定版本安装 (最稳，走 npmmirror 镜像)"
echo "n) 暂不安装"

# 强制用户输入有效选项
while true; do
    printf "选项 [1/2/3/n]: "
    read choice
    # 去除前后空格
    choice=$(echo "$choice" | xargs)

    if [ -z "$choice" ]; then
        echo -e "${RED}输入不能为空，请输入 1、2、3 或 n${NC}"
        continue
    fi

    case "$choice" in
        1|2|3|n|N)
            break
            ;;
        *)
            echo -e "${RED}无效输入！请输入 1、2、3 或 n${NC}"
            ;;
    esac
done

case $choice in
    1)
        echo -e "${YELLOW}提示：官方脚本需要访问 GitHub，国内服务器可能超时${NC}"
        echo -e "${CYAN}如果超时，请按 Ctrl+C 中断，选择选项 2 或 3${NC}"
        sleep 2
        # 设置 npm 镜像环境变量，让官方脚本的 npm install 走加速
        export npm_config_registry="$NPM_MIRROR"
        su - "$ACTUAL_USER" -c "env npm_config_registry='$NPM_MIRROR' bash openclaw_install.sh"
        ;;
    2)
        echo -e "${CYAN}使用 pnpm 安装 (已配置镜像)...${NC}"
        # 确保 pnpm 使用镜像，并修复 PATH 问题
        su - "$ACTUAL_USER" -c "env PATH='$USER_HOME/.local/bin:$PATH' pnpm config set registry '$NPM_MIRROR'"
        su - "$ACTUAL_USER" -c "env PATH='$USER_HOME/.local/bin:$PATH' pnpm add -g 'openclaw@$OPENCLAW_VERSION'"
        ;;
    3)
        echo -e "${CYAN}使用 npm 安装 (已配置镜像)...${NC}"
        # npm 全局安装需要 root 权限，使用 sudo
        sudo npm config set registry "$NPM_MIRROR"
        sudo npm install -g "openclaw@$OPENCLAW_VERSION"
        ;;
    *)
        echo -e "${RED}跳过安装。${NC}"
        exit 0
        ;;
esac

# --- 4. 善后处理 ---
echo -e "\n${GREEN}>>> 4. 最后的检查与配置...${NC}"

# 确保 pnpm 环境变量
export PATH="$USER_HOME/.local/bin:/usr/local/bin:/usr/bin:$PATH"

# 尝试找到 openclaw 二进制文件位置
OPENCLAW_BIN=""
for path in "$USER_HOME/.local/bin/openclaw" "/usr/local/bin/openclaw" "/usr/bin/openclaw"; do
    if [ -f "$path" ]; then
        OPENCLAW_BIN="$path"
        break
    fi
done

# 创建软链接，让 sudo 也能使用新版本
if [ -n "$OPENCLAW_BIN" ]; then
    ln -sf "$OPENCLAW_BIN" /usr/local/bin/openclaw 2>/dev/null || true
    echo -e "${GREEN}[✓] 已创建软链接 /usr/local/bin/openclaw (sudo 可用)${NC}"
fi

# 验证安装
INSTALLED_VERSION=$(openclaw --version 2>/dev/null | grep -oP 'OpenClaw \K[0-9.]+' || echo "")
if [ -n "$INSTALLED_VERSION" ]; then
    echo -e "${GREEN}[✓] OpenClaw $INSTALLED_VERSION 安装成功${NC}"

    # 自动运行新手引导
    echo -e "\n${CYAN}正在运行新手引导...${NC}"
    openclaw onboard --install-daemon
else
    echo -e "${RED}[✗] 安装验证失败${NC}"
fi

echo -e "${GREEN}安装完成！${NC}"
echo -e "${YELLOW}重要提示：${NC}"
echo -e "1. 请执行 ${CYAN}source ~/.bashrc${NC} 来激活命令。"
echo -e "2. 直接运行 ${CYAN}openclaw gateway${NC} 即可启动。"
echo -e "3. 使用 ${CYAN}sudo openclaw gateway${NC} 也能运行新版本。"
echo -e "4. 升级 OpenClaw：${CYAN}openclaw update${NC}（已自动走 npmmirror 加速）。"
