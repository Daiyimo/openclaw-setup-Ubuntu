# OpenClaw Windows 一键安装脚本
# 适用于 Windows 10/11
#
# 使用方法（PowerShell）：
#   .\setup-windows.ps1
#   $env:OPENCLAW_VERSION="2026.3.2"; .\setup-windows.ps1
#
# 需要管理员权限运行

param(
    [string]$OpenclawVersion = "2026.3.2"
)

$ErrorActionPreference = "Stop"

# 颜色定义
function Write-Green { param($msg) Write-Host $msg -ForegroundColor Green }
function Write-Yellow { param($msg) Write-Host $msg -ForegroundColor Yellow }
function Write-Cyan { param($msg) Write-Host $msg -ForegroundColor Cyan }
function Write-Red { param($msg) Write-Host $msg -ForegroundColor Red }

# 加速配置
$NPM_MIRROR = "https://registry.npmmirror.com"

Write-Green "============================================"
Write-Green "  OpenClaw Windows 安装脚本"
Write-Green "  目标版本: $OpenclawVersion"
Write-Green "============================================"

# --- 1. 检查管理员权限 ---
Write-Host ""
Write-Green ">>> 1. 检查权限..."
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Red "[错误] 请以管理员身份运行此脚本！"
    Write-Host "右键点击 PowerShell -> '以管理员身份运行'"
    exit 1
}
Write-Green "[OK] 管理员权限确认"

# --- 2. 安装 Node.js ---
Write-Host ""
Write-Green ">>> 2. 安装 Node.js 22..."

# 检查 winget
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "使用 winget 安装 Node.js 22..."
    winget install OpenJS.NodeJS.22 --accept-source-agreements --accept-package-agreements -h
}
# 检查 chocolatey
elseif (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Host "使用 chocolatey 安装 Node.js 22..."
    choco install nodejs-lts -y
}
# 检查是否已安装
elseif (Get-Command node -ErrorAction SilentlyContinue) {
    $nodeVersion = node --version
    Write-Yellow "[跳过] Node.js 已安装: $nodeVersion"
}
else {
    Write-Red "[错误] 未找到 winget 或 chocolatey，请手动安装 Node.js 22"
    Write-Host "下载链接: https://nodejs.org/"
    exit 1
}

# 刷新环境变量
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# 验证 Node.js
$nodeVersion = node --version
Write-Green "[OK] Node.js 版本: $nodeVersion"

# --- 3. 设置 npm 镜像 ---
Write-Host ""
Write-Green ">>> 3. 设置 npm 镜像..."
npm config set registry $NPM_MIRROR
Write-Green "[OK] npm 镜像已设置为 $NPM_MIRROR"

# --- 4. 安装 pnpm ---
Write-Host ""
Write-Green ">>> 4. 安装 pnpm..."
npm install -g pnpm
Write-Green "[OK] pnpm 安装完成"

# pnpm 也设置镜像
pnpm config set registry $NPM_MIRROR 2>$null

# --- 5. 安装 OpenClaw ---
Write-Host ""
Write-Green ">>> 5. 安装 OpenClaw..."
Write-Host ""

Write-Cyan "请选择安装方式："
Write-Host "1) npm 安装 (推荐，最稳定)"
Write-Host "2) pnpm 安装"
Write-Host "n) 暂不安装"
$choice = Read-Host "选项 [1/2/n]"

switch ($choice) {
    "1" {
        Write-Cyan "使用 npm 安装..."
        npm install -g "openclaw@$OpenclawVersion"
    }
    "2" {
        Write-Cyan "使用 pnpm 安装..."
        pnpm add -g "openclaw@$OpenclawVersion"
    }
    default {
        Write-Red "跳过安装。"
        exit 0
    }
}

# --- 6. 验证安装 ---
Write-Host ""
Write-Green ">>> 6. 验证安装..."

# 刷新 PATH 并查找 openclaw
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

Start-Sleep -Seconds 2

try {
    $openclawVersion = openclaw --version 2>$null | Select-String -Pattern "OpenClaw" -Raw
    if ($openclawVersion) {
        Write-Green "[OK] $openclawVersion"
    } else {
        Write-Yellow "[!] 版本检测失败，尝试直接运行 openclaw"
    }
} catch {
    Write-Yellow "[!] openclaw 命令未找到，尝试查找安装位置..."
}

# 查找 openclaw 安装位置
$globalModules = npm root -g
$openclawPath = Join-Path $globalModules "openclaw"
if (Test-Path $openclawPath) {
    Write-Green "[OK] OpenClaw 安装路径: $openclawPath"
} else {
    Write-Yellow "[!] 未找到安装目录"
}

# --- 7. 运行新手引导 ---
Write-Host ""
Write-Cyan "是否运行新手引导？(y/n)"
$runOnboard = Read-Host "(建议首次运行) [y/n]"
if ($runOnboard -eq "y" -or $runOnboard -eq "") {
    Write-Cyan "正在运行新手引导..."
    openclaw onboard --install-daemon 2>$null
}

# --- 8. 完成提示 ---
Write-Host ""
Write-Green "============================================"
Write-Green "安装完成！"
Write-Green "============================================"
Write-Yellow "后续操作："
Write-Host "1. 运行 ${Cyan}openclaw gateway${NC} 启动"
Write-Host "2. 查看配置: ${Cyan}openclaw config file${NC}"
Write-Host "3. 升级版本: ${Cyan}openclaw update${NC}"
Write-Host ""
Write-Yellow "注意："
Write-Host "- 如果命令找不到，请重启终端或手动刷新环境变量"
Write-Host "- Windows 环境下 Gateway 运行在 PowerShell 中"
