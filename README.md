# Server Auto-Setup Script

这是一个用于 Linux 服务器快速初始化环境的自动化脚本。

## 包含的功能
1.  **系统优化**：自动更新软件包、设置 `Asia/Shanghai` 时区。
2.  **时间同步**：安装并配置 `chrony` 强制校验时间。
3.  **SSH 增强**：自动配置并重启 SSH，允许 Root 登录及密码认证。
4.  **开发环境**：自动安装 **Node.js 22.x**。
5.  **OpenClaw**：自动下载安装脚本，并提供交互式选项供用户选择安装方式。
6.  **信息反馈**：脚本结束时自动显示设备内网 IP。

## 使用方法

### 方式 A：克隆仓库执行 (推荐)
```bash
git clone https://ghproxy.com/https://github.com/Daiyimo/openclaw-setup-Ubuntu.git setup
cd setup
sudo bash setup.sh
