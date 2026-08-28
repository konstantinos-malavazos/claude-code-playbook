<#
.SYNOPSIS
    Windows entry point for the claude-code-playbook installer.

.DESCRIPTION
    This is a preflight-and-delegate wrapper around install.sh. It is deliberately
    NOT a PowerShell port of the installer.

    The reason is the hooks. All seven guardrail hooks are bash scripts, and six of
    them parse their JSON payload with python. A PowerShell installer could copy
    them into place and wire them into settings.json, and they would still be unable
    to run: a hook that cannot execute exits non-zero, and the blocking hooks fail
    CLOSED — so a "successful" native-Windows install would jam every Bash tool call
    rather than guard it.

    So this script targets Git Bash or WSL, checks that bash and python are both
    really there, and hands off. It fails loudly and early rather than leaving you
    with hooks that cannot run.

.PARAMETER Mode
    install (default), update, remove, or list. Passed straight through to install.sh.

.EXAMPLE
    .\install.ps1
    .\install.ps1 update
    .\install.ps1 remove

.NOTES
    To see what this would do without doing it, just run it: install.sh lists every
    file it is about to write and every settings.json key it would add, and asks
    before writing anything. Answering no writes nothing at all.

    Set $env:CLAUDE_HOME to install somewhere other than ~/.claude — a second,
    heavier option, useful when you want a throwaway install you can poke at rather
    than a preview. The value is handed to bash untranslated, so write it the way
    THAT bash sees the world:

      Git Bash   /c/Users/you/claude-test
      WSL        /home/you/claude-test, or /mnt/c/Users/you/claude-test

    Not C:\Users\you\claude-test either way. Giving WSL a /c/... path does not
    fail — it creates that directory inside the distro, and the install lands
    somewhere you are not looking.
#>

[CmdletBinding()]
param(
    [ValidateSet('install', 'update', 'remove', 'list')]
    [string]$Mode = 'install'
)

$ErrorActionPreference = 'Stop'

function Write-Fail {
    param([string]$Message, [string[]]$Fix)
    Write-Host ''
    Write-Host "  x $Message" -ForegroundColor Red
    if ($Fix) {
        Write-Host ''
        foreach ($line in $Fix) { Write-Host "    $line" -ForegroundColor Yellow }
    }
    Write-Host ''
    exit 1
}

function Write-Ok {
    param([string]$Message)
    Write-Host "  + $Message" -ForegroundColor Green
}

$here = $PSScriptRoot
if (-not $here) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
$installSh = Join-Path $here 'install.sh'

Write-Host ''
Write-Host '  claude-code-playbook - Windows preflight' -ForegroundColor Cyan
Write-Host ''

if (-not (Test-Path $installSh)) {
    Write-Fail 'install.sh not found beside this script.' @(
        'Run this from a clone of the repository, not from a copied-out file.'
    )
}

# ---------------------------------------------------------------------------
# 1. bash — Git Bash or WSL
# ---------------------------------------------------------------------------
$bash = $null
$useWsl = $false

# The known Git for Windows locations come FIRST and the PATH lookup comes LAST.
# On a stock Windows install `Get-Command bash.exe` answers C:\Windows\System32\bash.exe,
# which is not Git Bash at all — it is the launcher for the default WSL distro, and
# System32 sits ahead of Git on PATH. Searching PATH first therefore hid a perfectly
# good Git Bash behind a WSL shim.
$candidates = @(
    "$env:ProgramFiles\Git\bin\bash.exe",
    "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
    "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
)

$onPath = Get-Command bash.exe -ErrorAction SilentlyContinue
if ($onPath) { $candidates += $onPath.Source }

# Present is not the same as working, and WHICH bash it is decides the handoff below.
# `uname -s` answers both in one call: MINGW/MSYS is Git Bash and takes /c/... paths
# as they are, Linux means we reached WSL through the System32 shim and must go back
# out through wsl.exe with a translated path. A candidate that cannot run `uname` at
# all — that shim with no usable distro behind it — is skipped rather than reported
# as the bash we found and then blamed for having no python.
foreach ($candidate in $candidates) {
    if (-not $candidate -or -not (Test-Path $candidate)) { continue }
    $kernel = $null
    try { $kernel = & $candidate -c 'uname -s' 2>$null } catch { continue }
    if ($LASTEXITCODE -ne 0 -or -not $kernel) { continue }
    if ($kernel -match 'Linux') { $bash = 'wsl.exe'; $useWsl = $true }
    else                        { $bash = $candidate }
    break
}

if (-not $bash) {
    $wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
    if ($wsl) {
        # `wsl -l -q` succeeding with output means at least one distro is installed;
        # wsl.exe exists even when none is, and then every call fails.
        $distros = & wsl.exe -l -q 2>$null
        if ($LASTEXITCODE -eq 0 -and $distros) {
            $useWsl = $true
            $bash = 'wsl.exe'
        }
    }
}

if (-not $bash) {
    Write-Fail 'No bash found. The playbook hooks are bash scripts and cannot run without one.' @(
        'Install one of:',
        '  Git for Windows (includes Git Bash)  https://git-scm.com/download/win',
        '  WSL                                  wsl --install',
        '',
        'Then run this script again.'
    )
}
Write-Ok "bash: $bash$(if ($useWsl) { ' (WSL)' })"

# ---------------------------------------------------------------------------
# 2. python — inside that same bash, not on the PowerShell PATH
# ---------------------------------------------------------------------------
# Checking PowerShell's PATH would prove nothing: the hooks and install-lib.py run
# inside bash, and a python visible to PowerShell is not necessarily visible there.
# The Microsoft Store python stub is the classic case — it resolves in PowerShell
# and is missing or non-functional in Git Bash.
$pythonProbe = 'for c in python3 python; do command -v "$c" >/dev/null 2>&1 && "$c" -c "import sys; sys.exit(0 if sys.version_info>=(3,7) else 1)" 2>/dev/null && { echo "$c"; exit 0; }; done; exit 1'

if ($useWsl) {
    $pythonFound = & wsl.exe bash -lc $pythonProbe 2>$null
} else {
    $pythonFound = & $bash -lc $pythonProbe 2>$null
}

if ($LASTEXITCODE -ne 0 -or -not $pythonFound) {
    Write-Fail 'No python 3.7+ inside bash. install-lib.py needs it, and so do six of the seven hooks.' @(
        'A python that works in PowerShell is not enough — the hooks run inside bash.',
        '',
        'Git Bash:  install python from https://www.python.org/downloads/ and tick',
        '           "Add python.exe to PATH", then confirm in Git Bash:',
        '             python3 --version',
        'WSL:       sudo apt install python3',
        '',
        'Then run this script again.'
    )
}
# A login shell runs the user's bash profile, and a profile that clears the screen
# puts the escape codes into what we just captured. Keep the interpreter name only.
$pythonName = ($pythonFound | Out-String) -replace '\[[0-9;?]*[A-Za-z]', '' -replace '[^ -~]', ''
Write-Ok "python in bash: $($pythonName.Trim())"

# ---------------------------------------------------------------------------
# 3. hand off
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '  Handing off to install.sh - it does the actual work.' -ForegroundColor DarkGray
Write-Host ''

# CLAUDE_HOME lets you install somewhere other than ~/.claude. It has to be passed
# INTO the command: PowerShell environment variables do not cross the WSL
# boundary, so setting $env:CLAUDE_HOME alone would be silently ignored there.
#
# The value goes through verbatim — nothing below translates it — so it must be
# written for the bash that receives it. Under Git Bash that is /c/Users/you/...;
# under WSL it is /home/you/... or /mnt/c/Users/you/..., because there /c/Users
# is not the C: drive, it is a path at the root of the distro. A Windows-shaped
# C:\Users\you\... is wrong for both. None of these fail loudly: the wrong shape
# installs successfully, somewhere you will not think to look.
$envPrefix = ''
if ($env:CLAUDE_HOME) {
    $envPrefix = "CLAUDE_HOME='$($env:CLAUDE_HOME -replace "'", "'\''")' "
    Write-Host "  CLAUDE_HOME=$($env:CLAUDE_HOME)" -ForegroundColor DarkGray
    Write-Host ''
}

if ($useWsl) {
    # Translate the Windows path so the Linux side can find the clone.
    $wslPath = & wsl.exe wslpath -a ($here -replace '\\', '/') 2>$null
    if (-not $wslPath) {
        Write-Fail 'Could not translate this directory into a WSL path.' @(
            'Run install.sh directly from inside WSL instead:',
            '  cd /mnt/c/path/to/claude-code-playbook && ./install.sh'
        )
    }
    & wsl.exe bash -c "cd '$($wslPath.Trim())' && ${envPrefix}./install.sh $Mode"
} else {
    & $bash -lc "cd '$($here -replace '\\', '/')' && ${envPrefix}./install.sh $Mode"
}

exit $LASTEXITCODE
