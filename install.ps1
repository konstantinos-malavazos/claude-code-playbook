<#
.SYNOPSIS
    Windows entry point for the claude-code-playbook installer.

.DESCRIPTION
    This is a preflight-and-delegate wrapper around install.sh. It is deliberately
    NOT a PowerShell port of the installer.

    The reason is the hooks. All six guardrail hooks are bash scripts, and every one
    of them parses its JSON payload with python. A PowerShell installer could copy
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
    Windows PowerShell is set to Restricted out of the box, which blocks every .ps1
    file. Launching it this way lifts that for the one command, and changes nothing
    on the machine:

    powershell -ExecutionPolicy Bypass -File .\install.ps1
    powershell -ExecutionPolicy Bypass -File .\install.ps1 update
    powershell -ExecutionPolicy Bypass -File .\install.ps1 remove

    After a one-time `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` the short
    form works too:

    .\install.ps1

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

# Windows PowerShell 5.1 - `powershell.exe`, and what a right-click Run with
# PowerShell gives you - turns ANY stderr from a native exe into a TERMINATING
# NativeCommandError while $ErrorActionPreference is 'Stop'. Neither `2>$null` nor
# `2>&1` suppresses it; only lowering the preference around the call does. Every
# probe below is a command that is ALLOWED to fail, so without this the script dies
# on a raw PowerShell error dump instead of printing the failure message written for
# exactly that case. pwsh 7 does not behave this way, so nothing here misbehaves for
# whoever wrote it - only for whoever runs it on a stock Windows box.
function Invoke-Probe {
    param([string]$Exe, [string[]]$Arguments)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $global:LASTEXITCODE = 0
        $out = & $Exe @Arguments 2>$null
        [pscustomobject]@{ Output = $out; Code = $LASTEXITCODE }
    } catch {
        # The exe could not be launched at all. Nothing to report from here: every
        # caller treats that the same as a probe that answered no.
        [pscustomobject]@{ Output = $null; Code = 1 }
    } finally {
        $ErrorActionPreference = $prev
    }
}

# WSL being installed is not the same as WSL being usable. Docker Desktop registers
# `docker-desktop` as a distribution - and it can be the DEFAULT one - but it is
# Docker's own utility VM: bash is not executable inside it, and Docker rebuilds it
# whenever it likes. `wsl -l -q` lists it exactly like a real distro, so a name check
# is guesswork and the honest test is to run bash and see.
function Test-WslBash {
    (Invoke-Probe 'wsl.exe' @('bash', '-c', 'exit 0')).Code -eq 0
}

# Everything handed to bash below travels inside single quotes, and one apostrophe
# in the value ends that quoting early - bash then dies on an unterminated string
# rather than on anything to do with the playbook. Windows paths carry apostrophes
# routinely (C:\Users\O'Brien), so quote every interpolated value through here:
# close the quote, escape the apostrophe, reopen. A double quote needs no handling -
# Windows paths cannot contain one.
function ConvertTo-BashQuoted {
    param([string]$Value)
    "'" + ($Value -replace "'", "'\''") + "'"
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
$wslSeen = $false

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
    $probe = Invoke-Probe $candidate @('-c', 'uname -s')
    if ($probe.Code -ne 0 -or -not $probe.Output) { continue }
    if ("$($probe.Output)" -match 'Linux') {
        # We reached WSL through the System32 shim. Take it only if bash actually
        # runs over there; otherwise keep looking rather than adopt a dead end.
        if (-not (Test-WslBash)) { $wslSeen = $true; continue }
        $bash = 'wsl.exe'; $useWsl = $true
    }
    else { $bash = $candidate }
    break
}

if (-not $bash) {
    $wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
    if ($wsl) {
        # `wsl -l -q` succeeding with output means at least one distro is registered;
        # wsl.exe exists even when none is, and then every call fails. Registered is
        # not the same as usable, so Test-WslBash has the last word.
        $distros = Invoke-Probe 'wsl.exe' @('-l', '-q')
        if ($distros.Code -eq 0 -and $distros.Output) {
            $wslSeen = $true
            if (Test-WslBash) {
                $useWsl = $true
                $bash = 'wsl.exe'
            }
        }
    }
}

if (-not $bash) {
    # Two different dead ends, and telling them apart is the whole value of the
    # message: "install WSL" is useless to someone who already has wsl.exe and a
    # docker-desktop entry, and sends them round the same loop a second time.
    if ($wslSeen) {
        Write-Fail 'No usable bash found. WSL answers, but bash does not run in its default distribution.' @(
            'Docker Desktop registers docker-desktop as a WSL distribution. It is not one',
            'you can install into - bash is not executable there and Docker rebuilds it at',
            'will - so if that is the only entry, WSL is not really set up on this machine.',
            '',
            'Install one of:',
            '  Git for Windows (includes Git Bash)  https://git-scm.com/download/win',
            '  A real WSL distribution              wsl --install -d Ubuntu',
            '                                       wsl --set-default Ubuntu',
            '',
            'Then run this script again.'
        )
    }
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
# Not one double quote in this probe, deliberately. Windows PowerShell 5.1 - still
# what `powershell.exe` and a right-click Run with PowerShell give you - does not
# escape embedded double quotes when it builds the command line for a native exe,
# so a probe containing them arrives at bash chopped into fragments and dies with
# `syntax error: unexpected end of file`, which reads like a broken bash rather
# than a broken caller. Single quotes cross intact, and PowerShell adds the outer
# double quotes itself. pwsh 7 escapes correctly and works either way, so this is
# not a difference the author of a change here would notice locally.
$pythonProbe = 'for c in python3 python; do command -v $c >/dev/null 2>&1 && $c -c ''import sys; sys.exit(0 if sys.version_info>=(3,7) else 1)'' 2>/dev/null && { echo $c; exit 0; }; done; exit 1'

if ($useWsl) {
    $python = Invoke-Probe 'wsl.exe' @('bash', '-lc', $pythonProbe)
} else {
    $python = Invoke-Probe $bash @('-lc', $pythonProbe)
}
$pythonFound = $python.Output

if ($python.Code -ne 0 -or -not $pythonFound) {
    Write-Fail 'No python 3.7+ inside bash. install-lib.py needs it, and so do all six hooks.' @(
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
    $envPrefix = "CLAUDE_HOME=$(ConvertTo-BashQuoted $env:CLAUDE_HOME) "
    Write-Host "  CLAUDE_HOME=$($env:CLAUDE_HOME)" -ForegroundColor DarkGray
    Write-Host ''
}

# From here on the child's stderr is output for the user to read, not an error for
# PowerShell to raise. Under 'Stop', one line on stderr from install.sh aborts this
# script with a NativeCommandError - after the install has already run, and instead
# of the exit code we mean to hand back. (5.1 only; see Invoke-Probe above.)
$ErrorActionPreference = 'Continue'

if ($useWsl) {
    # Translate the Windows path so the Linux side can find the clone.
    $translated = Invoke-Probe 'wsl.exe' @('wslpath', '-a', ($here -replace '\\', '/'))
    $wslPath = [string]($translated.Output | Select-Object -First 1)
    if ($translated.Code -ne 0 -or -not $wslPath) {
        Write-Fail 'Could not translate this directory into a WSL path.' @(
            'Run install.sh directly from inside WSL instead:',
            '  cd /mnt/c/path/to/claude-code-playbook && ./install.sh'
        )
    }
    & wsl.exe bash -c "cd $(ConvertTo-BashQuoted ($wslPath.Trim())) && ${envPrefix}./install.sh $Mode"
} else {
    & $bash -lc "cd $(ConvertTo-BashQuoted ($here -replace '\\', '/')) && ${envPrefix}./install.sh $Mode"
}

exit $LASTEXITCODE
