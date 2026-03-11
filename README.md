# OpenClaw 多平台一键安装脚本

> Last updated: 2026-03-11 | Update by Claude-4.6-Sonnet

这是一个跨平台的 OpenClaw AI Agent 自动化安装脚本，支持 **Ubuntu (Linux)**、**macOS** 和 **Windows**。

**不同 OpenClaw 版本对应不同分支**，请根据你的目标版本选择对应分支的脚本。

---

## 🌿 版本分支对照表

| 分支 | 适配 OpenClaw 版本 | 状态 |
|------|-------------------|------|
| [2026.3.8](https://github.com/Daiyimo/openclaw-setup-Ubuntu/tree/2026.3.8) | v2026.3.8 | ✅ 最新 |
| [2026.3.7](https://github.com/Daiyimo/openclaw-setup-Ubuntu/tree/2026.3.7) | v2026.3.7 | 维护中 |
| [2026.3.2](https://github.com/Daiyimo/openclaw-setup-Ubuntu/tree/2026.3.2) | v2026.3.2 | 归档 |
| [2026.3.1](https://github.com/Daiyimo/openclaw-setup-Ubuntu/tree/2026.3.1) | v2026.3.1 | 归档 |
| [2026.2.26](https://github.com/Daiyimo/openclaw-setup-Ubuntu/tree/2026.2.26) | v2026.2.26 | 归档 |
| [2026.2.19](https://github.com/Daiyimo/openclaw-setup-Ubuntu/tree/2026.2.19) | v2026.2.19 | 归档 |
| main | 通用安装脚本（兼容最新版本） | ✅ 推荐 |

> **推荐使用 main 分支**，会自动安装/更新到最新版本。旧版本分支仅供归档参考。

---

## 🚀 核心功能

* **系统环境优化**：自动设置 `Asia/Shanghai` 时区，更新系统补丁。
* **工具链集成**：预装 `Vim`、`curl`、`git`、`build-essential` 等基础工具。
* **SSH 增强**：自动配置并重启 SSH，允许 Root 登录及密码认证。
* **Node.js 生态**：自动安装 **Node.js 22.x**（需 >= 22.12.0），已安装则自动跳过。
* **国内全程加速**：
    * NodeSource 安装脚本通过 `gh-proxy.com` 代理拉取。
    * npm 全局镜像自动切换为 `npmmirror.com`（阿里云，实时同步官方）。
    * 镜像写入 `~/.npmrc`，`openclaw update` 后续升级**同样走加速**，无需额外配置。
* **OpenClaw 一键安装**：
    * 通过 `npm install -g` 全局安装指定版本 OpenClaw。
    * 自动执行 `openclaw onboard --install-daemon` 完成初始化。
    * **时区对齐**：脚本设置的系统时区将自动被 OpenClaw 识别。

---

## 📦 快速开始

### 🐧 Linux (Ubuntu)

**一行命令安装：**
```bash
curl -fsSL https://gh-proxy.com/https://raw.githubusercontent.com/Daiyimo/openclaw-setup-Ubuntu/main/scripts/setup.sh | bash
```

**或指定版本：**
```bash
OPENCLAW_VERSION=2026.3.8 curl -fsSL https://gh-proxy.com/https://raw.githubusercontent.com/Daiyimo/openclaw-setup-Ubuntu/main/scripts/setup.sh | bash
```

### 🍎 macOS

```bash
curl -fsSL https://gh-proxy.com/https://raw.githubusercontent.com/Daiyimo/openclaw-setup-Ubuntu/main/scripts/setup-macos.sh | bash
```

### 🪟 Windows (PowerShell)

```powershell
irm https://gh-proxy.com/https://raw.githubusercontent.com/Daiyimo/openclaw-setup-Ubuntu/main/scripts/setup-windows.ps1 | iex
```

---

## 🔧 脚本执行流程

| 步骤 | 操作 | 说明 |
|------|------|------|
| 1 | 系统环境配置 | 设置时区 `Asia/Shanghai`、更新系统、安装基础工具 |
| 2 | 安装 Node.js 22.x | 通过 gh-proxy 代理 NodeSource 脚本安装 |
| 2.5 | **设置 npm 镜像** | 写入 `~/.npmrc`，切换为 `npmmirror.com`，全程加速 |
| 3 | 配置 SSH | 允许 Root 登录 + 密码认证，重启 sshd |
| 4 | 全局安装 OpenClaw | `npm install -g openclaw@<version>`（走镜像） |
| 5 | 初始化 | `openclaw onboard --install-daemon` |

---

## 🚀 安装完成后

启动 Gateway：
```bash
openclaw gateway --port 18789 --verbose
```

查看配置文件路径：
```bash
openclaw config file
```

升级到最新版（已自动走 npmmirror 加速）：
```bash
openclaw update
```

---

## ⚡ 已安装服务器：加速升级

对于**已通过旧版 setup.sh 安装**、但 `~/.npmrc` 未配置镜像的服务器，可使用 `scripts/update.sh` 一键完成镜像配置 + 升级：

```bash
# 升级到最新版
sudo bash scripts/update.sh

# 升级到指定版本
# 不指定版本则自动更新到最新
sudo bash scripts/update.sh

# 或指定版本
OPENCLAW_VERSION=2026.3.8 sudo bash scripts/update.sh
```

`update.sh` 会自动：
1. 将 npm/pnpm 镜像持久化写入 `~/.npmrc`（后续 `openclaw update` 自动走镜像）
2. 执行 `openclaw update` 或指定版本安装
3. 输出当前版本确认

---

## ❓ 常见问题

**Q：网络无法访问 GitHub 怎么办？**
脚本中的克隆地址已通过 `gh-proxy.com` 加速，国内服务器可直接使用。

**Q：npm 安装慢 / openclaw update 下载缓慢怎么办？**
`scripts/setup.sh` 会自动将 npm 镜像切换为 `npmmirror.com`，并写入 `~/.npmrc`。
对于已安装的服务器，运行 `scripts/update.sh` 可一次性完成镜像配置与升级。

**Q：如何升级到新版本？**
- 推荐：直接运行 `openclaw update`（镜像已配置，速度快）
- 或：`OPENCLAW_VERSION=x.x.x sudo bash scripts/update.sh` 升级到指定版本

**Q：脚本需要 root 权限吗？**
是的，脚本需要以 root 权限运行（`sudo bash scripts/setup.sh`），用于配置系统环境和全局安装。

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

