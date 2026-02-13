# Server Auto-Setup Script (Optimized for OpenClaw)

这是一个为 Linux 服务器（特别是 Ubuntu 24.04+）量身定制的自动化初始化脚本，旨在快速搭建 AI Agent 开发环境。

适配openclaw此更新：https://github.com/openclaw/openclaw/releases/tag/v2026.2.12

## 🚀 核心功能
* **系统环境优化**：自动设置 `Asia/Shanghai` 时区，更新系统补丁。
* **工具链集成**：预装 `Vim`、`curl`、`git`。
* **SSH 增强**：自动配置并重启 SSH，允许 Root 登录及密码认证。
* **Node.js 生态**：自动安装 **Node.js 22.x**，并升级 `npm` 和 `pnpm` 至最新版本。
* **OpenClaw 适配**：
    * 自动下载安装脚本。
    * **时区对齐**：脚本设置的系统时区将自动被 OpenClaw (v2026.2.12+) 识别。
    * **交互安装**：支持通过官方脚本、pnpm 或 npm 多种方式安装。

## 📦 快速开始

### 方式 A：克隆仓库执行（推荐）
```bash
# 需要先进入特权模式install git
sudo -i
# 输入密码
apt install git
git clone https://gh-proxy.com/https://github.com/Daiyimo/openclaw-setup-Ubuntu.git setup
cd setup
sudo bash setup.sh
