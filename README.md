# tools

Personal dev-environment bootstrap for Windows. One PowerShell script installs the
prerequisites (Git, Oh My Posh, Node.js, the Meslo Nerd Font), clones/updates this repo
to `C:\tools`, and wires up custom prompts/status lines for **PowerShell**, **Claude Code**,
and **GitHub Copilot CLI**.

---

## Repo layout

| Path | What it is |
|------|------------|
| `scripts/InstallOhMyPosh.ps1` | The bootstrap installer. Run this once on a new machine. |
| `claude/statusline.js`        | Custom Node-based status line for Claude Code (model, cwd, git branch, context-usage bar, cost, elapsed time). |
| `ohmyposh/*.omp.json`         | Oh My Posh prompt themes. |
| `Cmder/`                      | Cmder console config (git-ignored). |

---

## Prerequisites

- **Windows 10/11** with **PowerShell** (Windows PowerShell 5.1 or PowerShell 7+).
- **winget** (App Installer) available on `PATH` — used to install missing tools.
- An internet connection (the script downloads tools and clones the repo).

Everything else (Git, Oh My Posh, Node.js, the font) is installed automatically if missing.

---

## Quick start

```powershell
# Allow the script to run for this session only (no permanent policy change)
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Run the installer
C:\tools\scripts\InstallOhMyPosh.ps1
```

> If you haven't cloned the repo yet, grab the script first:
> ```powershell
> irm https://raw.githubusercontent.com/wreuel/tools/main/scripts/InstallOhMyPosh.ps1 -OutFile "$env:TEMP\InstallOhMyPosh.ps1"
> & "$env:TEMP\InstallOhMyPosh.ps1"
> ```
> The script clones the full repo to `C:\tools` as part of its run.

**Restart your terminal after the script finishes** so PATH changes (Node.js) and the new
prompt/status lines take effect.

---

## What the installer does

| Step | Action |
|------|--------|
| 1 | Ensures **Git** is installed (`Git.Git`). |
| 2 | Ensures **Oh My Posh** is installed (`JanDeDobbeleer.OhMyPosh`). |
| 2b | Ensures **Node.js** is installed (`OpenJS.NodeJS`) — required by the Claude status line. |
| 3 | Installs the **Meslo Nerd Font** via Oh My Posh (needed for prompt glyphs/icons). |
| 4 | Clones the repo to `C:\tools`, or `git pull`s if it already exists. |
| 5 | Adds the Oh My Posh init line to your **PowerShell `$PROFILE`** (idempotent). |
| 6 | Configures **Claude Code** (see below). |
| 7 | Configures **GitHub Copilot CLI** status line (`oh-my-posh copilot`). |

The script is **idempotent** — safe to re-run. It checks before installing and merges
config rather than blindly overwriting.

---

## The Claude Code status line

Step 6 of the installer:

1. **Deploys** `claude/statusline.js` → `%USERPROFILE%\.claude\statusline.js`.
2. **Merges** a `statusLine` entry into `%USERPROFILE%\.claude\settings.json` (existing keys
   are preserved):

   ```json
   "statusLine": {
     "type": "command",
     "command": "node \"C:\\Users\\<you>\\.claude\\statusline.js\"",
     "padding": 2
   }
   ```
3. **Sanity-checks** it by piping sample JSON through the script and printing the result.

### Why `node "<abs path>"` and not `~/.claude/statusline.js`?

On Windows a bare `.js` path does **not** self-execute — the `#!/usr/bin/env node` shebang
is ignored, and `.js` file association is unreliable (it may open an editor or Windows Script
Host instead of running). Invoking `node` explicitly with the resolved absolute path is the
robust approach.

### What it shows

```
[Claude Opus 4.8] | 📂 tools | 🌿 main
████░░░░░░ 42% | $1.23 | ⏱️ 1m 35s
```

- **Model** display name
- **Current folder** and **git branch** (if in a repo)
- **Context-window usage** bar — green `<70%`, yellow `70–89%`, red `≥90%`
- **Session cost** in USD
- **Elapsed time**

Claude Code feeds the script a JSON object on **stdin** every refresh; the script parses it
and prints (up to) two lines. Customize the look by editing `claude/statusline.js` and
re-running the installer (or copying it to `~/.claude` yourself).

### Test it manually

```powershell
$sample = @{
    model          = @{ display_name = "Claude Opus 4.8" }
    cost           = @{ total_cost_usd = 1.23; total_duration_ms = 95000 }
    context_window = @{ used_percentage = 42 }
    cwd            = "C:\tools"
} | ConvertTo-Json -Compress

$sample | node "$env:USERPROFILE\.claude\statusline.js"
```

---

## Oh My Posh prompt

Step 5 appends this to your PowerShell profile:

```powershell
oh-my-posh --init --shell pwsh --config 'C:/tools/ohmyposh/myposhttheme.omp.json' | Invoke-Expression
```

To switch themes, point `--config` at a different file in `ohmyposh/` and reload
(`. $PROFILE`).

---

## GitHub Copilot CLI status line

Step 7 (only if `%USERPROFILE%\.copilot` exists) writes a `statusline.cmd` that runs
`oh-my-posh copilot`, then enables it in `%USERPROFILE%\.copilot\settings.json` via the
`STATUS_LINE` feature flag.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Status line is blank / shows an error in Claude | Open a **new** terminal so `node` is on PATH, confirm `node --version` works, then re-run the installer. |
| Prompt shows boxes/`?` instead of icons | Set your terminal font to **MesloLGM Nerd Font** (installed in step 3). |
| `script cannot be loaded ... execution policy` | Run `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force` first. |
| Claude config got wiped before | Fixed — step 6 now **merges** into `settings.json` instead of overwriting it. |
| Status line test prints raw `\x1b[...]` codes | That's just ANSI escapes shown in a non-rendering host; they display as colors in a real terminal. |

---

## Re-running / updating

```powershell
git -C C:\tools pull          # get latest scripts/themes/status line
C:\tools\scripts\InstallOhMyPosh.ps1   # re-apply config (idempotent)
```
