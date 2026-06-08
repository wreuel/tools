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
# 2b. NODE.JS (required by the Claude statusline.js)
# =========================
Ensure-Command -Name "node" -WingetId "OpenJS.NodeJS"

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

    # 6a. Deploy the custom statusline.js from the repo into ~/.claude
    $statusLineSource = Join-Path $toolsPath "claude\statusline.js"
    $statusLineDest   = Join-Path $claudeDir "statusline.js"

    if (Test-Path $statusLineSource) {
        Copy-Item -Path $statusLineSource -Destination $statusLineDest -Force
        Write-Host "Deployed statusline.js to $statusLineDest" -ForegroundColor Green
    }
    else {
        Write-Host "statusline.js not found at $statusLineSource — skipping copy." -ForegroundColor DarkYellow
    }

    # 6b. Merge the statusLine setting into existing settings.json (don't clobber other keys)
    $claudeConfig = @{}
    if (Test-Path $claudeSettings) {
        try {
            $existing = Get-Content $claudeSettings -Raw -ErrorAction Stop | ConvertFrom-Json
            if ($existing) {
                $existing.PSObject.Properties | ForEach-Object { $claudeConfig[$_.Name] = $_.Value }
            }
        }
        catch {
            Write-Host "Could not parse existing settings.json — recreating it." -ForegroundColor DarkYellow
        }
    }

    # On Windows the .js file won't self-execute, so invoke node explicitly with an absolute path.
    $claudeConfig["statusLine"] = @{
        type    = "command"
        command = "node `"$statusLineDest`""
        padding = 2
    }

    $claudeConfig | ConvertTo-Json -Depth 10 | Set-Content $claudeSettings -Encoding UTF8

    Write-Host "Claude config updated." -ForegroundColor Green

    # 6c. Sanity check — feed sample JSON to the status line and show what it renders
    if ((Get-Command node -ErrorAction SilentlyContinue) -and (Test-Path $statusLineDest)) {
        Write-Host "Testing status line output (sample data):" -ForegroundColor Cyan

        $sample = @{
            model          = @{ display_name = "Claude Opus 4.8" }
            cost           = @{ total_cost_usd = 1.23; total_duration_ms = 95000 }
            context_window = @{ used_percentage = 42 }
            cwd            = $toolsPath
        } | ConvertTo-Json -Compress

        try {
            $sample | node $statusLineDest
            Write-Host "Status line is working." -ForegroundColor Green
        }
        catch {
            Write-Host "Status line test failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Open a NEW terminal so 'node' is on PATH, then re-run." -ForegroundColor DarkYellow
        }
    }
    else {
        Write-Host "Skipping status line test (node not on PATH yet — restart terminal)." -ForegroundColor DarkYellow
    }
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