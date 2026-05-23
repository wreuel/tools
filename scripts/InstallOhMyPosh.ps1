# =========================
# CONFIG
# =========================
$toolsPath = "C:\tools"
$repoUrl = "https://github.com/wreuel/tools"
$profilePath = $PROFILE

$claudeSettings = "$env:USERPROFILE\.claude\settings.json"
$copilotSettings = "$env:USERPROFILE\.copilot\settings.json"
$copilotStatusLine = "$env:USERPROFILE\.copilot\statusline.cmd"

# =========================
# HELPERS
# =========================
function Ensure-Command {
    param(
        [string]$Name,
        [string]$WingetId
    )

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Write-Host "$Name not found. Installing..." -ForegroundColor Yellow
        winget install --id $WingetId -e --silent --accept-source-agreements --accept-package-agreements
    }
    else {
        Write-Host "$Name already installed." -ForegroundColor Green
    }
}

function Ensure-Folder {
    param([string]$Path)

    if (!(Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

# =========================
# 1. GIT
# =========================
Ensure-Command -Name "git" -WingetId "Git.Git"

# =========================
# 2. OH MY POSH
# =========================
Ensure-Command -Name "oh-my-posh" -WingetId "JanDeDobbeleer.OhMyPosh"

# =========================
# 3. MESLO FONT (via OMP)
# =========================
Write-Host "Checking Meslo Nerd Font..." -ForegroundColor Cyan

function Ensure-MesloFont {

    if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
        Write-Host "Oh My Posh not installed yet — skipping font install." -ForegroundColor Red
        return
    }

    $fonts = (New-Object -ComObject Shell.Application).Namespace(0x14).Items()
    $exists = $fonts | Where-Object { $_.Name -like "*Meslo*" }

    if ($exists) {
        Write-Host "Meslo font already installed." -ForegroundColor Green
        return
    }

    Write-Host "Installing Meslo Nerd Font via Oh My Posh..." -ForegroundColor Yellow
    oh-my-posh font install meslo

    Write-Host "Meslo font installed." -ForegroundColor Green
}

Ensure-MesloFont

# =========================
# 4. CLONE / UPDATE TOOLS
# =========================
Write-Host "Setting up tools repo..." -ForegroundColor Cyan

if (!(Test-Path $toolsPath)) {
    git clone $repoUrl $toolsPath
}
else {
    git -C $toolsPath pull
}

# =========================
# 5. POWERSHELL PROFILE
# =========================
Write-Host "Configuring PowerShell profile..." -ForegroundColor Cyan

Ensure-Folder (Split-Path $profilePath)

if (!(Test-Path $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
}

$profileLine = "oh-my-posh --init --shell pwsh --config 'C:/tools/ohmyposh/myposhttheme.omp.json' | Invoke-Expression"
$profileContent = Get-Content $profilePath -ErrorAction SilentlyContinue

if ($profileContent -notcontains $profileLine) {
    Add-Content -Path $profilePath -Value "`n$profileLine"
    Write-Host "PowerShell profile updated." -ForegroundColor Green
}
else {
    Write-Host "PowerShell profile already configured." -ForegroundColor Green
}

# =========================
# 6. CLAUDE
# =========================
Write-Host "Configuring Claude..." -ForegroundColor Cyan

$claudeDir = Split-Path $claudeSettings

if (Test-Path $claudeDir) {

    Ensure-Folder $claudeDir

    $claudeJson = @{
        statusLine = @{
            type    = "command"
            command = "oh-my-posh claude"
            padding = 0
        }
    }

    $claudeJson | ConvertTo-Json -Depth 10 | Set-Content $claudeSettings -Encoding UTF8

    Write-Host "Claude config updated." -ForegroundColor Green
}
else {
    Write-Host "Claude not installed — skipping." -ForegroundColor DarkYellow
}

# =========================
# 7. COPILOT
# =========================
Write-Host "Configuring Copilot..." -ForegroundColor Cyan

$copilotDir = Split-Path $copilotSettings

if (Test-Path $copilotDir) {

    Ensure-Folder $copilotDir

@"
@echo off
oh-my-posh copilot
"@ | Set-Content $copilotStatusLine -Encoding ASCII

    $copilotJson = @{
        statusLine = @{
            type    = "command"
            command = $copilotStatusLine
        }
        feature_flags = @{
            enabled = @("STATUS_LINE")
        }
        experimental = $true
    }

    $copilotJson | ConvertTo-Json -Depth 10 | Set-Content $copilotSettings -Encoding UTF8

    Write-Host "Copilot config updated." -ForegroundColor Green
}
else {
    Write-Host "Copilot not installed — skipping." -ForegroundColor DarkYellow
}

# =========================
# DONE
# =========================
Write-Host "`nSetup complete. Restart terminal." -ForegroundColor Green