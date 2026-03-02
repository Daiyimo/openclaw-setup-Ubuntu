# Server Auto-Setup Script (Optimized for OpenClaw)

> Last updated: 2026-03-02 | Update by Claude-4.6-Sonnet

这是一个为 Linux 服务器（特别是 Ubuntu 24.04+）量身定制的自动化初始化脚本，旨在快速搭建 AI Agent 开发环境。

适配openclaw此更新：https://github.com/openclaw/openclaw/releases/tag/v2026.3.1

## 🚀 核心功能
* **系统环境优化**：自动设置 `Asia/Shanghai` 时区，更新系统补丁。
* **工具链集成**：预装 `Vim`、`curl`、`git`、`build-essential` 等基础工具。
* **SSH 增强**：自动配置并重启 SSH，允许 Root 登录及密码认证。
* **Node.js 生态**：自动安装 **Node.js 22.x**（需 >= 22.12.0）并升级 `npm`。
* **OpenClaw 一键安装**：
    * 通过 `npm install -g` 全局安装指定版本 OpenClaw。
    * 自动执行 `openclaw onboard --install-daemon` 完成初始化。
    * **时区对齐**：脚本设置的系统时区将自动被 OpenClaw 识别。

## 📦 快速开始

### 方式 A：一行命令安装
```bash
# 2026.3.1 版本
sudo apt update && sudo apt install -y curl && \
curl -fsSL https://gh-proxy.com/https://raw.githubusercontent.com/Daiyimo/openclaw-setup-Ubuntu/2026.3.1/setup.sh -o setup.sh && \
sudo bash setup.sh
```

### 方式 B：克隆仓库执行
```bash
sudo -i
apt install git
git clone https://gh-proxy.com/https://github.com/Daiyimo/openclaw-setup-Ubuntu.git -b 2026.3.1 setup
cd setup
sudo bash setup.sh
```

## 🔧 脚本执行流程

| 步骤 | 操作 | 说明 |
|------|------|------|
| 1 | 系统环境配置 | 设置时区 `Asia/Shanghai`、更新系统、安装基础工具 |
| 2 | 安装 Node.js 22.x | 通过 NodeSource 官方源安装（需 >= 22.12.0），已安装则跳过 |
| 3 | 配置 SSH | 允许 Root 登录 + 密码认证，重启 sshd |
| 4 | 全局安装 OpenClaw | `npm install -g openclaw@2026.3.1` |
| 5 | 初始化 | `openclaw onboard --install-daemon` |

## 🚀 安装完成后

启动 Gateway：
```bash
openclaw gateway
```

查看当前配置文件路径（v2026.3.1 新增）：
```bash
openclaw config file
```

Docker/K8s 健康检查探针（v2026.3.1 新增，Gateway 启动后可用）：
```
GET http://<host>:<port>/health
GET http://<host>:<port>/ready
```

---

## 🤖 接入 QQ（NapCat）

OpenClaw 环境搭建完成后，如果你想让 AI Agent 接入 QQ 与好友或群组对话，可以使用以下插件：

> **[openclaw-napcat](https://github.com/Daiyimo/openclaw-napcat)** — 基于 OneBot v11 协议的 QQ 频道插件，已适配最新版 OpenClaw。

**支持的能力包括：**
- 群聊 / 私聊 / QQ 频道消息收发
- 图片、语音、文件等多媒体消息
- 管理员指令、群管、黑白名单
- 戳一戳、表情回应、AI 语音回复
- 连接自愈与生产级风控

前往项目查看完整安装与配置说明 →  https://github.com/Daiyimo/openclaw-napcat
