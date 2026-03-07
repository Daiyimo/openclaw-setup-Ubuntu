# OpenClaw Windows 一键安装脚本
# 适用于 Windows 10/11 (PowerShell)
#
# 使用方法：
#   .\setup-windows.ps1
#   .\setup-windows.ps1 -Version 2026.3.2
#
# 命令行参数：
#   -Version <版本>    指定 OpenClaw 版本 (默认: latest)
#   -Registry <url>   npm 镜像源 (默认: https://registry.npmmirror.com)
#   -Beta             使用 beta 版本
#   -NoOnboard        跳过新手引导
#   -NoPrompt         禁用提示 (CI/自动化)
#   -Verbose          显示详细输出
#   -Help             显示帮助
#
# 环境变量：
#   OPENCLAW_VERSION  OpenClaw 版本
#   NPM_MIRROR       npm 镜像源

param(
    [string]$Version,
    [switch]$Beta,
    [string]$Registry,
    [switch]$NoOnboard,
    [switch]$NoPrompt,
    [switch]$Verbose,
    [switch]$Help
)

# 使用 Continue 而不是 Stop，避免脚本立即退出
$ErrorActionPreference = "Continue"

# 设置 UTF-8 编码
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
    chcp 65001 | Out-Null
} catch {}

# 颜色定义
$AccentColor = "DarkYellow"
$InfoColor = "Yellow"
$SuccessColor = "Green"
$WarnColor = "DarkYellow"
$ErrorColor = "Red"
$MutedColor = "DarkGray"

# 显示帮助
if ($Help) {
    Write-Host ""
    Write-Host "OpenClaw Windows 安装脚本" -ForegroundColor $AccentColor
    Write-Host ""
    Write-Host "用法:" -ForegroundColor $InfoColor
    Write-Host "  .\scripts\setup-windows.ps1 [选项]"
    Write-Host ""
    Write-Host "选项:" -ForegroundColor $InfoColor
    Write-Host "  -Version <版本>    指定 OpenClaw 版本 (默认: latest)"
    Write-Host "  -Beta             使用 beta 版本"
    Write-Host "  -Registry <url>   npm 镜像源 (默认: https://registry.npmmirror.com)"
    Write-Host "  -NoOnboard        跳过新手引导"
    Write-Host "  -NoPrompt         禁用提示 (CI/自动化)"
    Write-Host "  -Verbose          显示详细输出"
    Write-Host "  -Help             显示此帮助"
    Write-Host ""
    Write-Host "环境变量:" -ForegroundColor $InfoColor
    Write-Host "  OPENCLAW_VERSION  OpenClaw 版本"
    Write-Host "  NPM_MIRROR       npm 镜像源"
    Write-Host ""
    exit 0
}

# 配置 - 命令行参数优先，环境变量次之
$script:NoOnboard = $NoOnboard -or ($env:OPENCLAW_NO_ONBOARD -eq "1")
$script:NoPrompt = $NoPrompt -or ($env:OPENCLAW_NO_PROMPT -eq "1")
$OpenclawVersion = if ($Version) { $Version } elseif ($env:OPENCLAW_VERSION) { $env:OPENCLAW_VERSION } else { "latest" }
$NpmRegistry = if ($Registry) { $Registry } elseif ($env:NPM_MIRROR) { $env:NPM_MIRROR } else { "https://registry.npmmirror.com" }
$UseBeta = $Beta -or ($env:OPENCLAW_BETA -eq "1")

# 刷新 PATH
function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

# Banner
Write-Host ""
Write-Host "  ======================================" -ForegroundColor $AccentColor
Write-Host "       OpenClaw Windows 安装脚本" -ForegroundColor $AccentColor
Write-Host "  ======================================" -ForegroundColor $AccentColor
Write-Host ""
Write-Host "  版本: $OpenclawVersion" -ForegroundColor $MutedColor
Write-Host "  镜像: $NpmRegistry" -ForegroundColor $MutedColor
Write-Host ""

# 检测操作系统
Write-Host "[OK] Windows detected" -ForegroundColor $SuccessColor

# 检查 Node.js
function Test-NodeInstalled {
    $nodeVersion = $null
    try {
        $nodeVersion = & node -v 2>&1
    } catch {}

    if ($nodeVersion -and $nodeVersion -match '^v\d+') {
        $majorVersion = 0
        if ($nodeVersion -match 'v(\d+)') {
            $majorVersion = [int]$Matches[1]
        }
        if ($majorVersion -ge 22) {
            Write-Host "[OK] Node.js $nodeVersion 已安装" -ForegroundColor $SuccessColor
            return $true
        } else {
            Write-Host "[!] Node.js $nodeVersion 已安装，但需要 v22+" -ForegroundColor $WarnColor
            return $false
        }
    } else {
        Write-Host "[!] 未找到 Node.js" -ForegroundColor $WarnColor
        return $false
    }
}

# 安装 Node.js
function Install-NodeJS {
    Write-Host "[*] 正在安装 Node.js..." -ForegroundColor $InfoColor

    # winget
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "  使用 winget..." -ForegroundColor $MutedColor
        & winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
        Refresh-Path

        if (Test-NodeInstalled) {
            Write-Host "[OK] Node.js 已通过 winget 安装" -ForegroundColor $SuccessColor
            return $true
        }
    }

    # Chocolatey
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host "  使用 Chocolatey..." -ForegroundColor $MutedColor
        & choco install nodejs-lts -y
        Refresh-Path

        if (Test-NodeInstalled) {
            Write-Host "[OK] Node.js 已通过 Chocolatey 安装" -ForegroundColor $SuccessColor
            return $true
        }
    }

    # Scoop
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Host "  使用 Scoop..." -ForegroundColor $MutedColor
        & scoop install nodejs-lts
        Refresh-Path

        if (Test-NodeInstalled) {
            Write-Host "[OK] Node.js 已通过 Scoop 安装" -ForegroundColor $SuccessColor
            return $true
        }
    }

    Write-Host ""
    Write-Host "错误: 无法自动安装 Node.js" -ForegroundColor $ErrorColor
    Write-Host ""
    Write-Host "请手动安装 Node.js 22+:" -ForegroundColor $InfoColor
    Write-Host "  https://nodejs.org/zh-cn/download/" -ForegroundColor $AccentColor
    Write-Host ""
    return $false
}

# 检查并安装 Node.js
if (-not (Test-NodeInstalled)) {
    if ($NoPrompt) {
        if (-not (Install-NodeJS)) {
            exit 1
        }
    } else {
        Write-Host ""
        $response = Read-Host "是否安装 Node.js? [Y/n]"
        if ([string]::IsNullOrEmpty($response) -or $response -match '^[Yy]') {
            if (-not (Install-NodeJS)) {
                exit 1
            }
        } else {
            Write-Host "需要 Node.js 22+ 才能继续" -ForegroundColor $ErrorColor
            exit 1
        }
    }

    if (-not (Test-NodeInstalled)) {
        Write-Host "Node.js 安装失败" -ForegroundColor $ErrorColor
        exit 1
    }
}

# 刷新 PATH
Refresh-Path

# 设置 npm 镜像
Write-Host ""
Write-Host "[*] 设置 npm 镜像..." -ForegroundColor $InfoColor
npm config set registry $NpmRegistry
Write-Host "[OK] npm 镜像: $NpmRegistry" -ForegroundColor $SuccessColor

# 安装 pnpm
Write-Host ""
Write-Host "[*] 安装 pnpm..." -ForegroundColor $InfoColor
npm install -g pnpm
pnpm config set registry $NpmRegistry 2>$null
Write-Host "[OK] pnpm 已安装" -ForegroundColor $SuccessColor

# 刷新 PATH
Refresh-Path

# 确定安装包名
if ($UseBeta) {
    $packageSpec = "openclaw-cn@beta"
} elseif ($OpenclawVersion -ne "latest") {
    $packageSpec = "openclaw-cn@$OpenclawVersion"
} else {
    $packageSpec = "openclaw-cn"
}

# 安装 OpenClaw
Write-Host ""
Write-Host "[*] 安装 $packageSpec..." -ForegroundColor $InfoColor
Write-Host "    镜像: $NpmRegistry" -ForegroundColor $MutedColor

$installLog = "$env:TEMP\openclaw_install_$PID.log"

# 使用 tee 记录日志
$npmExitCode = 0
npm --no-fund --no-audit install -g $packageSpec --registry $NpmRegistry 2>&1 | Tee-Object -Variable npmOutput | Out-File -FilePath $installLog -Encoding UTF8
$npmExitCode = $LASTEXITCODE

if ($npmExitCode -ne 0) {
    Write-Host "[!] npm 安装出现问题，查看日志..." -ForegroundColor $WarnColor

    # 常见错误检测
    if ($npmOutput -match "ENOTEMPTY|directory not empty") {
        Write-Host "[*] 清理残留目录并重试..." -ForegroundColor $InfoColor
        $globalModules = npm root -g
        $openclawPath = Join-Path $globalModules "openclaw-cn"
        if (Test-Path $openclawPath) {
            Remove-Item -Path $openclawPath -Recurse -Force -ErrorAction SilentlyContinue
            npm install -g $packageSpec --registry $NpmRegistry
        }
    }

    if ($npmOutput -match "git|not found") {
        Write-Host "[!] 检测到 git 相关错误" -ForegroundColor $WarnColor
        Write-Host "请确保已安装 git: winget install Git.Git" -ForegroundColor $InfoColor
    }

    if ($npmOutput -match "EACCES|permission denied") {
        Write-Host "[!] 权限问题 (EACCES/permission denied)" -ForegroundColor $WarnColor
        Write-Host "建议使用管理员权限运行 PowerShell" -ForegroundColor $InfoColor
    }

    if ($npmOutput -match "node-gyp|gyp ERR|C\+\+") {
        Write-Host "[!] 编译依赖缺失 (node-gyp)" -ForegroundColor $WarnColor
        Write-Host "可能需要安装 Visual Studio Build Tools" -ForegroundColor $InfoColor
    }

    # 输出日志末尾
    Write-Host ""
    Write-Host "=== npm 输出 (最后 20 行) ===" -ForegroundColor $MutedColor
    Get-Content $installLog -Tail 20 -ErrorAction SilentlyContinue
    Write-Host ""

    if ($LASTEXITCODE -ne 0) {
        Write-Host "安装失败" -ForegroundColor $ErrorColor
        exit 1
    }
}

# 清理日志
Remove-Item $installLog -ErrorAction SilentlyContinue

Write-Host "[OK] OpenClaw 安装成功" -ForegroundColor $SuccessColor

# 刷新 PATH
Refresh-Path

# 显示版本
Write-Host ""
$version = $null
try {
    $version = & openclaw-cn --version 2>&1
} catch {}

if ($version -and $version -notmatch 'not recognized') {
    Write-Host "[OK] 版本: $version" -ForegroundColor $SuccessColor
} else {
    Write-Host "[!] 无法验证安装，可能需要重启终端" -ForegroundColor $WarnColor
}

# 运行新手引导
if (-not $NoOnboard) {
    Write-Host ""
    Write-Host "[*] 启动新手引导..." -ForegroundColor $InfoColor

    # 检测交互环境
    $isInteractive = $true
    try {
        if ($Host.Name -eq "ServerRemoteHost") {
            $isInteractive = $false
        } elseif ($Host.UI.RawUI -eq $null) {
            $isInteractive = $false
        }
    } catch {
        $isInteractive = $false
    }

    if ($isInteractive) {
        try {
            & openclaw-cn onboard
        } catch {
            Write-Host "[!] 新手引导失败: $($_.Exception.Message)" -ForegroundColor $WarnColor
            Write-Host "可以稍后运行 'openclaw-cn onboard' 完成配置" -ForegroundColor $InfoColor
        }
    } else {
        Write-Host "非交互环境，请稍后在终端中运行 'openclaw-cn onboard'" -ForegroundColor $WarnColor
    }
} else {
    Write-Host ""
    Write-Host "提示: 运行 'openclaw-cn onboard' 开始配置" -ForegroundColor $InfoColor
}

# 完成提示
Write-Host ""
Write-Host "============================================" -ForegroundColor $SuccessColor
Write-Host "安装完成!" -ForegroundColor $SuccessColor
Write-Host "============================================" -ForegroundColor $SuccessColor
Write-Host ""
Write-Host "后续操作:" -ForegroundColor $InfoColor
Write-Host "  1. 运行 openclaw gateway 启动"
Write-Host "  2. 查看配置: openclaw config file"
Write-Host "  3. 升级版本: openclaw update"
Write-Host ""
Write-Host "注意:" -ForegroundColor $WarnColor
Write-Host "  - 如果命令找不到，请重启 PowerShell"
Write-Host "  - 需要管理员权限运行 Gateway"

# 保持窗口打开
Write-Host ""
Write-Host "按任意键退出..." -ForegroundColor $MutedColor
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
