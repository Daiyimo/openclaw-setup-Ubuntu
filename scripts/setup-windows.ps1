param(
    [string]$Version,
    [switch]$Beta,
    [string]$Registry,
    [switch]$NoOnboard,
    [switch]$NoPrompt,
    [switch]$Help
)

# Set UTF-8 encoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
if ($env:POWERSHELL_TELEMETRY_OPTOUT -ne "1") { chcp 65001 | Out-Null }

# OpenClaw Windows One-Click Installation Script
# For Windows 10/11 (PowerShell)
#
# Usage (local file):
#   .\setup-windows.ps1
#   .\setup-windows.ps1 -Version 2026.3.2
#
# Usage (one-line):
#   iwr -useb https://.../setup-windows.ps1 | iex
#   iwr -useb https://gh-proxy.com/https://raw.githubusercontent.com/Daiyimo/openclaw-setup-Ubuntu/main/scripts/setup-windows.ps1 | iex
#
# Environment variables:
#   OPENCLAW_VERSION    Version (default: latest)
#   OPENCLAW_BETA       Use beta (set to "1")
#   NPM_MIRROR          npm registry (default: https://registry.npmmirror.com)
#   OPENCLAW_NO_ONBOARD Skip onboarding (set to "1")
#   OPENCLAW_NO_PROMPT  Disable prompts (set to "1")

# Use Continue instead of Stop to avoid immediate script exit
$ErrorActionPreference = "Continue"

# Color definitions
$AccentColor = "DarkYellow"
$InfoColor = "Yellow"
$SuccessColor = "Green"
$WarnColor = "DarkYellow"
$ErrorColor = "Red"
$MutedColor = "DarkGray"

# Show help
if ($Help) {
    Write-Host ""
    Write-Host "OpenClaw Windows Installation Script" -ForegroundColor $AccentColor
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor $InfoColor
    Write-Host "  .\setup-windows.ps1 [options]"
    Write-Host "  iwr -useb https://.../setup-windows.ps1 | iex"
    Write-Host ""
    Write-Host "Options:" -ForegroundColor $InfoColor
    Write-Host "  -Version <version>   Specify OpenClaw version (default: latest)"
    Write-Host "  -Beta                Use beta version"
    Write-Host "  -Registry <url>      npm mirror (default: https://registry.npmmirror.com)"
    Write-Host "  -NoOnboard           Skip onboarding"
    Write-Host "  -NoPrompt            Disable prompts"
    Write-Host "  -Help                Show this help"
    Write-Host ""
    Write-Host "Environment variables:" -ForegroundColor $InfoColor
    Write-Host "  OPENCLAW_VERSION, OPENCLAW_BETA, NPM_MIRROR"
    Write-Host "  OPENCLAW_NO_ONBOARD, OPENCLAW_NO_PROMPT"
    Write-Host ""
    exit 0
}

# Config - Command-line args take priority, then environment variables
$script:NoOnboard = $NoOnboard -or ($env:OPENCLAW_NO_ONBOARD -eq "1")
$script:NoPrompt = $NoPrompt -or ($env:OPENCLAW_NO_PROMPT -eq "1")
$OpenclawVersion = if ($Version) { $Version } elseif ($env:OPENCLAW_VERSION) { $env:OPENCLAW_VERSION } else { "latest" }
$NpmRegistry = if ($Registry) { $Registry } elseif ($env:NPM_MIRROR) { $env:NPM_MIRROR } else { "https://registry.npmmirror.com" }
$UseBeta = $Beta -or ($env:OPENCLAW_BETA -eq "1")

# Refresh PATH
function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

# Banner
Write-Host ""
Write-Host "  ======================================" -ForegroundColor $AccentColor
Write-Host "    OpenClaw Windows Installation Script" -ForegroundColor $AccentColor
Write-Host "  ======================================" -ForegroundColor $AccentColor
Write-Host ""
Write-Host "  Version: $OpenclawVersion" -ForegroundColor $MutedColor
Write-Host "  Registry: $NpmRegistry" -ForegroundColor $MutedColor
Write-Host ""

# Detect operating system
Write-Host "[OK] Windows detected" -ForegroundColor $SuccessColor

# Check Node.js
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
            Write-Host "[OK] Node.js $nodeVersion installed" -ForegroundColor $SuccessColor
            return $true
        } else {
            Write-Host "[!] Node.js $nodeVersion installed, but v22+ required" -ForegroundColor $WarnColor
            return $false
        }
    } else {
        Write-Host "[!] Node.js not found" -ForegroundColor $WarnColor
        return $false
    }
}

# Install Node.js
function Install-NodeJS {
    Write-Host "[*] Installing Node.js..." -ForegroundColor $InfoColor

    # winget
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "  Using winget..." -ForegroundColor $MutedColor
        & winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
        Refresh-Path

        if (Test-NodeInstalled) {
            Write-Host "[OK] Node.js installed via winget" -ForegroundColor $SuccessColor
            return $true
        }
    }

    # Chocolatey
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host "  Using Chocolatey..." -ForegroundColor $MutedColor
        & choco install nodejs-lts -y
        Refresh-Path

        if (Test-NodeInstalled) {
            Write-Host "[OK] Node.js installed via Chocolatey" -ForegroundColor $SuccessColor
            return $true
        }
    }

    # Scoop
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Host "  Using Scoop..." -ForegroundColor $MutedColor
        & scoop install nodejs-lts
        Refresh-Path

        if (Test-NodeInstalled) {
            Write-Host "[OK] Node.js installed via Scoop" -ForegroundColor $SuccessColor
            return $true
        }
    }

    Write-Host ""
    Write-Host "Error: Cannot auto-install Node.js" -ForegroundColor $ErrorColor
    Write-Host ""
    Write-Host "Please manually install Node.js 22+:" -ForegroundColor $InfoColor
    Write-Host "  https://nodejs.org/download/" -ForegroundColor $AccentColor
    Write-Host ""
    return $false
}

# Check and install Node.js
if (-not (Test-NodeInstalled)) {
    if ($NoPrompt) {
        if (-not (Install-NodeJS)) {
            exit 1
        }
    } else {
        Write-Host ""
        $response = Read-Host "Install Node.js? [Y/n]"
        if ([string]::IsNullOrEmpty($response) -or $response -match '^[Yy]') {
            if (-not (Install-NodeJS)) {
                exit 1
            }
        } else {
            Write-Host "Node.js 22+ is required to continue" -ForegroundColor $ErrorColor
            exit 1
        }
    }

    if (-not (Test-NodeInstalled)) {
        Write-Host "Node.js installation failed" -ForegroundColor $ErrorColor
        exit 1
    }
}

# Refresh PATH
Refresh-Path

# Set npm registry
Write-Host ""
Write-Host "[*] Setting npm registry..." -ForegroundColor $InfoColor
npm config set registry $NpmRegistry
Write-Host "[OK] npm registry: $NpmRegistry" -ForegroundColor $SuccessColor

# Install pnpm
Write-Host ""
Write-Host "[*] Installing pnpm..." -ForegroundColor $InfoColor
npm install -g pnpm
pnpm config set registry $NpmRegistry 2>$null
Write-Host "[OK] pnpm installed" -ForegroundColor $SuccessColor

# Refresh PATH
Refresh-Path

# Determine package name
if ($UseBeta) {
    $packageSpec = "openclaw@beta"
} elseif ($OpenclawVersion -ne "latest") {
    $packageSpec = "openclaw@$OpenclawVersion"
} else {
    $packageSpec = "openclaw"
}

# Install OpenClaw
Write-Host ""
Write-Host "[*] Installing $packageSpec..." -ForegroundColor $InfoColor
Write-Host "    Registry: $NpmRegistry" -ForegroundColor $MutedColor

$installLog = "$env:TEMP\openclaw_install_$PID.log"

# Install with logging
$npmExitCode = 0
npm --no-fund --no-audit install -g $packageSpec --registry $NpmRegistry 2>&1 | Tee-Object -Variable npmOutput | Out-File -FilePath $installLog -Encoding UTF8
$npmExitCode = $LASTEXITCODE

if ($npmExitCode -ne 0) {
    Write-Host "[!] npm install issues detected, checking log..." -ForegroundColor $WarnColor

    # Common error detection
    if ($npmOutput -match "ENOTEMPTY|directory not empty") {
        Write-Host "[*] Cleaning leftover directory and retrying..." -ForegroundColor $InfoColor
        $globalModules = npm root -g
        $openclawPath = Join-Path $globalModules "openclaw"
        if (Test-Path $openclawPath) {
            Remove-Item -Path $openclawPath -Recurse -Force -ErrorAction SilentlyContinue
            npm install -g $packageSpec --registry $NpmRegistry
        }
    }

    if ($npmOutput -match "git|not found") {
        Write-Host "[!] Git-related error detected" -ForegroundColor $WarnColor
        Write-Host "Please ensure git is installed: winget install Git.Git" -ForegroundColor $InfoColor
    }

    if ($npmOutput -match "EACCES|permission denied") {
        Write-Host "[!] Permission issue (EACCES/permission denied)" -ForegroundColor $WarnColor
        Write-Host "Try running PowerShell as Administrator" -ForegroundColor $InfoColor
    }

    if ($npmOutput -match "node-gyp|gyp ERR|C\+\+") {
        Write-Host "[!] Build dependency missing (node-gyp)" -ForegroundColor $WarnColor
        Write-Host "You may need Visual Studio Build Tools" -ForegroundColor $InfoColor
    }

    # Output log tail
    Write-Host ""
    Write-Host "=== npm output (last 20 lines) ===" -ForegroundColor $MutedColor
    Get-Content $installLog -Tail 20 -ErrorAction SilentlyContinue
    Write-Host ""

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Installation failed" -ForegroundColor $ErrorColor
        exit 1
    }
}

# Clean up log
Remove-Item $installLog -ErrorAction SilentlyContinue

Write-Host "[OK] OpenClaw installed successfully" -ForegroundColor $SuccessColor

# Refresh PATH
Refresh-Path

# Show version
Write-Host ""
$version = $null
try {
    $version = & openclaw --version 2>&1
} catch {}

if ($version -and $version -notmatch 'not recognized') {
    Write-Host "[OK] Version: $version" -ForegroundColor $SuccessColor
} else {
    Write-Host "[!] Cannot verify installation, you may need to restart terminal" -ForegroundColor $WarnColor
}

# Run onboarding
if (-not $NoOnboard) {
    Write-Host ""
    Write-Host "[*] Starting onboarding..." -ForegroundColor $InfoColor

    # Detect interactive environment
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
            & openclaw onboard
        } catch {
            Write-Host "[!] Onboarding failed: $($_.Exception.Message)" -ForegroundColor $WarnColor
            Write-Host "You can run 'openclaw onboard' later to complete setup" -ForegroundColor $InfoColor
        }
    } else {
        Write-Host "Non-interactive environment, please run 'openclaw onboard' in terminal later" -ForegroundColor $WarnColor
    }
} else {
    Write-Host ""
    Write-Host "Tip: Run 'openclaw onboard' to start configuration" -ForegroundColor $InfoColor
}

# Completion message
Write-Host ""
Write-Host "============================================" -ForegroundColor $SuccessColor
Write-Host "Installation complete!" -ForegroundColor $SuccessColor
Write-Host "============================================" -ForegroundColor $SuccessColor
Write-Host ""
Write-Host "Next steps:" -ForegroundColor $InfoColor
Write-Host "  1. Run 'openclaw gateway' to start"
Write-Host "  2. View config: openclaw config file"
Write-Host "  3. Update version: openclaw update"
Write-Host ""
Write-Host "Note:" -ForegroundColor $WarnColor
Write-Host "  - If command not found, please restart PowerShell"
Write-Host "  - Gateway requires administrator privileges"

# Keep window open
Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor $MutedColor
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
