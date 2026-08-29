#
# windows-terminal-setup — one-shot terminal bootstrap for Windows.
#
# Reproduces the exact terminal setup:
#   - PowerShell 7 (pwsh)      installed and set as the default shell
#   - Oh My Posh               prompt engine (Windows equivalent of Powerlevel10k)
#   - MesloLGS Nerd Font       glyphs/icons for the prompt
#   - PSReadLine               inline auto-suggestions, arrow-right acceptance,
#                              syntax highlighting (built into PS7, just configured)
#   - fzf + PSFzf              fuzzy finder (Ctrl+T files, Ctrl+R history)
#   - profile.ps1 from repo    linked to the PS7 $PROFILE
#
# Usage (from a clone of this repo):
#   .\install.ps1
#
# Or one-liner on a brand-new machine (no clone; profile linking is skipped):
#   irm https://raw.githubusercontent.com/<you>/windows-terminal-setup/main/install.ps1 | iex

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─────────────────────────────────────────────────────────────────────────────
#  Helpers
# ─────────────────────────────────────────────────────────────────────────────
function Info([string]$Msg) { Write-Host "==> $Msg" -ForegroundColor Blue }
function Ok([string]$Msg)   { Write-Host "  v $Msg" -ForegroundColor Green }
function Warn([string]$Msg) { Write-Host "  ! $Msg" -ForegroundColor Yellow }

# Falls back to $PWD when run via  irm ... | iex  (no file context).
$SCRIPT_DIR = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }

# ─────────────────────────────────────────────────────────────────────────────
#  0. Sanity — Windows only; elevate to admin if needed
# ─────────────────────────────────────────────────────────────────────────────
if ($env:OS -ne 'Windows_NT') {
    Write-Error 'This script is for Windows only.'; exit 1
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Warn 'Not running as Administrator — winget package installs (MSI) may hang waiting for a hidden UAC prompt.'
    Warn 'Re-run this script from an elevated (Run as Administrator) terminal for a fully silent install.'
    Warn 'Continuing anyway — installer UI and UAC prompts will appear as needed.'
}

# ─────────────────────────────────────────────────────────────────────────────
#  1. Execution policy
# ─────────────────────────────────────────────────────────────────────────────
Info 'Setting execution policy to RemoteSigned for current user...'
try {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
} catch {
    # A process-scope or Group Policy override raises a terminating error; harmless to ignore.
}
Ok 'Execution policy set.'

# ─────────────────────────────────────────────────────────────────────────────
#  2. winget
# ─────────────────────────────────────────────────────────────────────────────
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Error "winget not found. Install 'App Installer' from the Microsoft Store, then re-run."
    exit 1
}
Ok 'winget is available.'

# Reload PATH in the current session after winget installs a tool.
function Update-EnvPath {
    $machine     = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
    $user        = [Environment]::GetEnvironmentVariable('PATH', 'User')
    # MSIX app execution aliases (oh-my-posh, pwsh, etc.) live here and aren't in registry PATH.
    $windowsApps = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
    $env:PATH = "$machine;$user;$windowsApps"
}

# Install a winget package, guarded by a command-existence check.
function Install-WingetPackage([string]$Id, [string]$TestCommand, [string]$DisplayName) {
    if (Get-Command $TestCommand -ErrorAction SilentlyContinue) {
        Ok "$DisplayName already installed."; return
    }
    Info "Installing $DisplayName..."
    # Omit --silent so the MSI installer's UI and any UAC prompt are visible;
    # --silent causes winget to hang when elevation is required but not pre-granted.
    winget install --id $Id --source winget `
        --accept-package-agreements --accept-source-agreements
    Update-EnvPath
    Ok "$DisplayName installed."
}

# Strip JSONC comments so ConvertFrom-Json can parse Windows Terminal's settings file.
function Remove-JsonComments([string]$Json) {
    $re = [System.Text.RegularExpressions.Regex]::new('("(?:[^"\\]|\\.)*")|//[^\n]*|/\*[\s\S]*?\*/')
    $evaluator = [System.Text.RegularExpressions.MatchEvaluator]{
        param([System.Text.RegularExpressions.Match]$m)
        if ($m.Groups[1].Success) { $m.Value } else { [string]::Empty }
    }
    $stripped = $re.Replace($Json, $evaluator)
    # Remove trailing commas before ] or } (valid JSONC, invalid JSON).
    $stripped -replace ',(?=\s*[}\]])', ''
}

# ─────────────────────────────────────────────────────────────────────────────
#  3. PowerShell 7
# ─────────────────────────────────────────────────────────────────────────────
Install-WingetPackage 'Microsoft.PowerShell' 'pwsh' 'PowerShell 7'

# ─────────────────────────────────────────────────────────────────────────────
#  4. Oh My Posh  (direct binary — avoids MSIX/AppX staging which hangs on
#                  some machines; winget's OhMyPosh package is an MSIX)
# ─────────────────────────────────────────────────────────────────────────────
$ompDir = "$env:LOCALAPPDATA\Programs\oh-my-posh\bin"
$ompExe = "$ompDir\oh-my-posh.exe"

if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    Ok 'Oh My Posh already installed.'
    $ompExe = (Get-Command oh-my-posh).Source
} elseif (Test-Path $ompExe) {
    Ok 'Oh My Posh already installed (binary).'
} else {
    Info 'Installing Oh My Posh (direct binary download)...'
    New-Item -ItemType Directory -Force -Path $ompDir | Out-Null
    Invoke-WebRequest 'https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-windows-amd64.exe' `
        -OutFile $ompExe -UseBasicParsing
    # Add to user PATH so new sessions find it.
    $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    if ($userPath -notlike "*$ompDir*") {
        [Environment]::SetEnvironmentVariable('PATH', "$userPath;$ompDir", 'User')
    }
    $env:PATH = "$env:PATH;$ompDir"
    Ok 'Oh My Posh installed.'
}

# ─────────────────────────────────────────────────────────────────────────────
#  5. MesloLGS Nerd Font  (oh-my-posh ships its own font installer)
# ─────────────────────────────────────────────────────────────────────────────
Info 'Installing MesloLGS Nerd Font...'
& $ompExe font install meslo
Ok 'MesloLGS Nerd Font installed.'

# ─────────────────────────────────────────────────────────────────────────────
#  6. fzf
# ─────────────────────────────────────────────────────────────────────────────
Install-WingetPackage 'junegunn.fzf' 'fzf' 'fzf'

# ─────────────────────────────────────────────────────────────────────────────
#  7. PSFzf  (PowerShell wrapper module for fzf)
# ─────────────────────────────────────────────────────────────────────────────
if (Get-Module PSFzf -ListAvailable) {
    Ok 'PSFzf already installed.'
} else {
    Info 'Installing PSFzf module...'
    if ((Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue).InstallationPolicy -ne 'Trusted') {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }
    Install-Module PSFzf -Scope CurrentUser -Force -AllowClobber
    Ok 'PSFzf installed.'
}

# ─────────────────────────────────────────────────────────────────────────────
#  8. PowerShell 7 profile
# ─────────────────────────────────────────────────────────────────────────────
$profileSrc = Join-Path $SCRIPT_DIR 'profile.ps1'
# Ask pwsh itself for its profile path — handles OneDrive/redirected Documents folders.
$ps7Profile    = pwsh -NoProfile -Command '$PROFILE.CurrentUserCurrentHost'
$ps7ProfileDir = Split-Path $ps7Profile -Parent
$timestamp     = Get-Date -Format 'yyyyMMdd-HHmmss'

if (-not (Test-Path $ps7ProfileDir)) {
    New-Item -ItemType Directory -Path $ps7ProfileDir -Force | Out-Null
}

if (Test-Path $ps7Profile) {
    $backup = "$ps7Profile.backup-$timestamp"
    Warn "Backing up existing profile -> $backup"
    Move-Item $ps7Profile $backup
}

if (Test-Path $profileSrc) {
    Info 'Linking PowerShell profile...'
    try {
        New-Item -ItemType SymbolicLink -Path $ps7Profile -Target $profileSrc -Force | Out-Null
        Ok "Symlinked profile -> $profileSrc"
    } catch {
        # Symlinks require Developer Mode or admin; copy as fallback.
        Copy-Item $profileSrc $ps7Profile
        Warn 'Copied profile (symlink requires Developer Mode or admin — re-run to upgrade to a live symlink).'
    }
} else {
    Warn "profile.ps1 not found in $SCRIPT_DIR - skipped (run from a repo clone to link it)."
}

# ─────────────────────────────────────────────────────────────────────────────
#  9. Oh My Posh theme  (only if .omp.json is present in the repo)
# ─────────────────────────────────────────────────────────────────────────────
$ompSrc  = Join-Path $SCRIPT_DIR 'neal.omp.json'
$ompDest = Join-Path $HOME '.omp.json'

if (Test-Path $ompSrc) {
    if (Test-Path $ompDest) {
        Warn "Backing up existing .omp.json -> $ompDest.backup-$timestamp"
        Move-Item $ompDest "$ompDest.backup-$timestamp"
    }
    Info 'Linking Oh My Posh theme...'
    try {
        New-Item -ItemType SymbolicLink -Path $ompDest -Target $ompSrc -Force | Out-Null
        Ok "Symlinked .omp.json -> $ompSrc"
    } catch {
        Copy-Item $ompSrc $ompDest
        Warn 'Copied .omp.json (symlink requires Developer Mode or admin).'
    }
} else {
    Info '.omp.json not in repo — Oh My Posh will use its built-in default theme.'
}

# ─────────────────────────────────────────────────────────────────────────────
#  10. Patch Windows Terminal settings
# ─────────────────────────────────────────────────────────────────────────────
$wtCandidates = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
)
$wtSettings = $wtCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($wtSettings) {
    Info "Patching Windows Terminal: $wtSettings"
    try {
        $raw      = Get-Content $wtSettings -Raw
        $stripped = Remove-JsonComments $raw
        $json     = $stripped | ConvertFrom-Json

        # Stable GUID Windows Terminal auto-assigns to the PowerShell Core (pwsh) profile.
        $json | Add-Member -MemberType NoteProperty -Name 'defaultProfile' `
            -Value '{574e775e-4f2a-5b96-ac1e-a2962a402336}' -Force

        # Ensure profiles.defaults exists before setting the font.
        if (-not $json.PSObject.Properties['profiles']) {
            $json | Add-Member -MemberType NoteProperty -Name 'profiles' `
                -Value ([PSCustomObject]@{ defaults = [PSCustomObject]@{} }) -Force
        }
        if (-not $json.profiles.PSObject.Properties['defaults']) {
            $json.profiles | Add-Member -MemberType NoteProperty -Name 'defaults' `
                -Value ([PSCustomObject]@{}) -Force
        }

        # Set font in profiles.defaults so it applies to every profile.
        $json.profiles.defaults | Add-Member -MemberType NoteProperty -Name 'font' `
            -Value ([PSCustomObject]@{ face = 'MesloLGS Nerd Font Mono' }) -Force

        Copy-Item $wtSettings "$wtSettings.backup-$timestamp"
        $json | ConvertTo-Json -Depth 20 | Set-Content $wtSettings -Encoding UTF8
        Ok 'Windows Terminal settings patched.'
    } catch {
        Warn "Could not auto-patch Windows Terminal settings: $_"
        Warn 'Set manually: Settings -> Defaults -> Appearance -> Font face: MesloLGS Nerd Font Mono'
        Warn 'And set defaultProfile to {574e775e-4f2a-5b96-ac1e-a2962a402336}'
    }
} else {
    Warn 'Windows Terminal settings.json not found — install Windows Terminal, then re-run.'
}

# ─────────────────────────────────────────────────────────────────────────────
#  11. Patch VS Code terminal font
# ─────────────────────────────────────────────────────────────────────────────
$vsCodePaths = @(
    "$env:APPDATA\Code\User\settings.json",
    "$env:APPDATA\Code - Insiders\User\settings.json"
)

foreach ($vsPath in $vsCodePaths) {
    if (-not (Test-Path $vsPath)) { continue }
    Info "Patching VS Code settings: $vsPath"
    try {
        $json = (Remove-JsonComments (Get-Content $vsPath -Raw)) | ConvertFrom-Json
        $json | Add-Member -MemberType NoteProperty `
            -Name 'terminal.integrated.fontFamily' -Value 'MesloLGS Nerd Font Mono' -Force
        Copy-Item $vsPath "$vsPath.backup-$timestamp"
        $json | ConvertTo-Json -Depth 20 | Set-Content $vsPath -Encoding UTF8
        Ok 'VS Code settings patched.'
    } catch {
        Warn "Could not patch VS Code settings at ${vsPath}: $_"
    }
}

# ─────────────────────────────────────────────────────────────────────────────
#  Done
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ''
Ok 'Terminal setup complete!'
Write-Host ''
Write-Host 'Next steps:'
Write-Host '  1. Restart Windows Terminal and/or VS Code to pick up the new font.'
Write-Host '  2. Open a new pwsh session — Oh My Posh loads with its default theme.'
if (-not (Test-Path (Join-Path $SCRIPT_DIR '.omp.json'))) {
    Write-Host '  3. Customize your prompt:'
    Write-Host '       oh-my-posh config edit'
    Write-Host '     Then save it back to this repo:'
    Write-Host "       Copy-Item `"`$HOME\.omp.json`" `"$(Join-Path $SCRIPT_DIR '.omp.json')`""
    Write-Host "       git -C `"$SCRIPT_DIR`" add .omp.json"
    Write-Host "       git -C `"$SCRIPT_DIR`" commit -m `"Add Oh My Posh theme config`""
}
