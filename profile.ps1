# ─────────────────────────────────────────────────────────────────────────────
#  Editor
# ─────────────────────────────────────────────────────────────────────────────
$env:EDITOR = 'code --wait'

# ─────────────────────────────────────────────────────────────────────────────
#  Oh My Posh — prompt
#  Uses $HOME\.omp.json if present (copied back from this repo after configuring),
#  otherwise falls back to oh-my-posh's built-in default theme.
# ─────────────────────────────────────────────────────────────────────────────
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    $ompConfig = Join-Path $HOME '.omp.json'
    if (Test-Path $ompConfig) {
        oh-my-posh init pwsh --config $ompConfig | Invoke-Expression
    } else {
        oh-my-posh init pwsh | Invoke-Expression
    }
}

# ─────────────────────────────────────────────────────────────────────────────
#  PSReadLine — inline auto-suggestions, arrow-right acceptance, syntax highlighting
#  Syntax highlighting is on by default; only prediction needs explicit config.
# ─────────────────────────────────────────────────────────────────────────────
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle InlineView

# At end-of-line: accept the full inline suggestion. Mid-line: move cursor right.
Set-PSReadLineKeyHandler -Key RightArrow -ScriptBlock {
    param($key, $arg)
    $line = $null; $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    if ($cursor -lt $line.Length) {
        [Microsoft.PowerShell.PSConsoleReadLine]::ForwardChar($key, $arg)
    } else {
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptSuggestion($key, $arg)
    }
}

# ─────────────────────────────────────────────────────────────────────────────
#  PSFzf — fuzzy finder  (Ctrl+T: files  |  Ctrl+R: history search)
# ─────────────────────────────────────────────────────────────────────────────
if (Get-Module -Name PSFzf -ListAvailable) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t'
    Set-PsFzfOption -PSReadlineChordReverseHistory 'Ctrl+r'
}
