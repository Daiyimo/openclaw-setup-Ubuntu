# OpenClaw Ubuntu 一键安装脚本

> Last updated: 2026-03-03 | Update by Claude-4.6-Sonnet

这是一个为 Linux 服务器（特别是 Ubuntu 24.04+）量身定制的自动化初始化脚本，旨在快速搭建 OpenClaw AI Agent 运行环境。

**不同 OpenClaw 版本对应不同分支**，请根据你的目标版本选择对应分支的脚本。

---

## 🌿 版本分支对照表

| 分支 | 适配 OpenClaw 版本 | 状态 |
|------|-------------------|------|
| [2026.3.2](https://github.com/Daiyimo/openclaw-setup-Ubuntu/tree/2026.3.2) | v2026.3.2 | ✅ 最新 |
| [2026.3.1](https://github.com/Daiyimo/openclaw-setup-Ubuntu/tree/2026.3.1) | v2026.3.1 | 维护中 |
| [2026.2.26](https://github.com/Daiyimo/openclaw-setup-Ubuntu/tree/2026.2.26) | v2026.2.26 | 归档 |
| [2026.2.19](https://github.com/Daiyimo/openclaw-setup-Ubuntu/tree/2026.2.19) | v2026.2.19 | 归档 |
| main | 开发主线（最早期版本） | 参考用 |

> **建议始终使用最新分支**，旧版本分支仅供归档参考。

---

## 🚀 核心功能

* **系统环境优化**：自动设置 `Asia/Shanghai` 时区，更新系统补丁。
* **工具链集成**：预装 `Vim`、`curl`、`git`、`build-essential` 等基础工具。
* **SSH 增强**：自动配置并重启 SSH，允许 Root 登录及密码认证。
* **Node.js 生态**：自动安装 **Node.js 22.x**（需 >= 22.12.0），已安装则自动跳过。
* **OpenClaw 一键安装**：
    * 通过 `npm install -g` 全局安装指定版本 OpenClaw。
    * 自动执行 `openclaw onboard --install-daemon` 完成初始化。
    * **时区对齐**：脚本设置的系统时区将自动被 OpenClaw 识别。

---

## 📦 快速开始（以最新版 2026.3.2 为例）

### 方式 A：一行命令安装
```bash
sudo apt update && sudo apt install -y curl && \
curl -fsSL https://gh-proxy.com/https://raw.githubusercontent.com/Daiyimo/openclaw-setup-Ubuntu/2026.3.2/setup.sh -o setup.sh && \
sudo bash setup.sh
```

### 方式 B：克隆仓库执行
```bash
sudo -i
apt install git
git clone https://gh-proxy.com/https://github.com/Daiyimo/openclaw-setup-Ubuntu.git -b 2026.3.2 setup
cd setup
sudo bash setup.sh
```

> 安装其他版本只需将命令中的 `2026.3.2` 替换为对应分支名即可。

---

## 🔧 脚本执行流程

| 步骤 | 操作 | 说明 |
|------|------|------|
| 1 | 系统环境配置 | 设置时区 `Asia/Shanghai`、更新系统、安装基础工具 |
| 2 | 安装 Node.js 22.x | 通过 NodeSource 官方源安装，已安装则跳过 |
| 3 | 配置 SSH | 允许 Root 登录 + 密码认证，重启 sshd |
| 4 | 全局安装 OpenClaw | `npm install -g openclaw@<version>` |
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

---

## ❓ 常见问题

**Q：网络无法访问 GitHub 怎么办？**
脚本中的克隆地址已通过 `gh-proxy.com` 加速，国内服务器可直接使用。

**Q：如何升级到新版本？**
重新执行对应新版本分支的 `setup.sh` 即可，npm 全局安装会自动覆盖旧版本。

**Q：脚本需要 root 权限吗？**
是的，脚本需要以 root 权限运行（`sudo bash setup.sh`），用于配置系统环境和全局安装。

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

