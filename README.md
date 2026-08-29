# windows-terminal-setup

Reproduce my exact Windows terminal setup on any new machine with a single script.

## What you get

- **[winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/)** — package manager (built into Windows 10/11)
- **[PowerShell 7](https://github.com/PowerShell/PowerShell)** — modern cross-platform shell, set as default
- **[Oh My Posh](https://ohmyposh.dev)** — fast, themeable prompt (Windows equivalent of Powerlevel10k)
- **[PSReadLine](https://github.com/PowerShell/PSReadLine)** — fish-style ghost-text completion (press → to accept) + syntax highlighting
- **[fzf](https://github.com/junegunn/fzf) + [PSFzf](https://github.com/kelleyma49/PSFzf)** — fuzzy finder (`Ctrl+R` history, `Ctrl+T` files)
- **[MesloLGS Nerd Font](https://github.com/ryanoasis/nerd-fonts)** — glyphs/icons for the prompt
- A curated `profile.ps1` wired up to the PS7 `$PROFILE`

## Quick start

### Clone and run

```powershell
git clone https://github.com/<your-username>/windows-terminal-setup.git
cd windows-terminal-setup
.\install.ps1
```

### Or one-liner on a brand-new machine (no clone needed)

```powershell
irm https://raw.githubusercontent.com/<your-username>/windows-terminal-setup/main/install.ps1 | iex
```

> **Note:** The one-liner installs all tools but skips profile linking (no local repo to link from). Clone the repo for the full setup.

The installer is **idempotent** — safe to run multiple times. It skips anything already installed and backs up any existing profile (as `Microsoft.PowerShell_profile.ps1.backup-<timestamp>`) before linking.

## After installing

1. **Restart Windows Terminal and/or VS Code** to pick up the new font. The installer auto-patches both — but if prompt icons look like broken boxes, set the font manually:
   - Windows Terminal → *Settings → Profiles → Defaults → Appearance → Font face*: `MesloLGS NF`
   - VS Code → `"terminal.integrated.fontFamily": "MesloLGS NF"`
2. **Open a new `pwsh` session** — Oh My Posh loads with the configured theme.
3. If `neal.omp.json` isn't in this repo yet, Oh My Posh starts with its built-in default theme. Customize it with:
   ```powershell
   oh-my-posh config export --output "$HOME\.omp.json"
   oh-my-posh config edit   # opens in $EDITOR (VS Code)
   ```

## Saving your prompt style across machines

After you've tuned the prompt and want future installs to get the same look, copy the config back into this repo:

```powershell
Copy-Item "$HOME\.omp.json" ".\neal.omp.json"
git add neal.omp.json
git commit -m "Update Oh My Posh theme config"
```

The installer automatically links `neal.omp.json` → `$HOME\.omp.json` if it's present in the repo.

## Files

| File | Purpose |
|---|---|
| `install.ps1` | One-shot bootstrap: installs everything and links dotfiles |
| `profile.ps1` | Shell config (linked to the PS7 `$PROFILE`) |
| `neal.omp.json` | Oh My Posh theme config (linked to `~\.omp.json`) |
