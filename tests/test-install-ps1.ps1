<#
.SYNOPSIS
    Regression suite for install.ps1 — the Windows entry point.

.DESCRIPTION
    Every bug this file covers was invisible to the other three suites, because they
    run bash on Linux and install.ps1 is PowerShell on Windows. Three of the four were
    also invisible under pwsh 7 and only appeared under Windows PowerShell 5.1 — which
    is what `powershell.exe` and a right-click "Run with PowerShell" still give you,
    and therefore what most people who run this file will be using.

    So CI runs this suite TWICE, once under each host. It tests whichever PowerShell
    is running it: there is nothing to configure, and a difference between the two
    shells shows up as one job green and the other red.

    Run it by hand the same way:

      powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/test-install-ps1.ps1
      pwsh.exe       -NoProfile -File tests/test-install-ps1.ps1

    It needs the same things install.ps1 needs — Git Bash and a python inside it —
    because four of the seven sections run the real installer end to end. Sections 4
    and 7 reach install.sh, so a break in EITHER half lands here.

.NOTES
    Nothing here writes to the real ~/.claude: every run that gets as far as install.sh
    is `list`, which changes nothing, and CLAUDE_HOME is redirected into a temp dir
    anyway. Set PLAYBOOK_TEST_DIR to move that temp dir, as the bash suites do.
#>

# Deliberate, and the subject of section 5: this suite runs commands that are MEANT to
# fail. Under 'Stop', the first one would take the suite down instead of being an
# observation about install.ps1.
$ErrorActionPreference = 'Continue'

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Repo = Split-Path -Parent $Here
$Ps1  = Join-Path $Repo 'install.ps1'

$Scratch = if ($env:PLAYBOOK_TEST_DIR) { $env:PLAYBOOK_TEST_DIR }
           else { Join-Path ([IO.Path]::GetTempPath()) 'playbook-ps1-tests' }
$Logs = Join-Path $Scratch 'logs'
$Work = Join-Path $Scratch 'work'
Remove-Item -Recurse -Force $Work -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $Logs, $Work | Out-Null

# The host running this suite is the host under test. 5.1 reports itself as
# powershell.exe, 7 as pwsh.exe, and the version line makes the two jobs tellable
# apart in a CI log.
$HostExe = (Get-Process -Id $PID).Path

$script:Pass = 0
$script:Fail = 0
$script:Failed = @()

function banner($t) { Write-Host ''; Write-Host "=== $t" }
function pass($n)   { $script:Pass++; Write-Host "    PASS  $n" }
function fail($n, $why) {
    $script:Fail++; $script:Failed += $n
    Write-Host "    FAIL  $n"
    if ($why) { Write-Host "          $why" }
}
function chk([bool]$ok, $n, $why) { if ($ok) { pass $n } else { fail $n $why } }

function has($result, $text)    { $result.Text -and $result.Text.Contains($text) }
function inlog($result, $text, $n)    { chk (has $result $text) $n "not in the output" }
function notinlog($result, $text, $n) { chk (-not (has $result $text)) $n "found `"$text`" in the output" }

# A raw PowerShell error record where a written message belongs. This is the whole
# point of section 5, and every live section asserts it: a failure the script HANDLES
# must never surface as one of these.
function notcrashed($result, $n) {
    chk (-not (($result.Text -match 'NativeCommandError') -or
               ($result.Text -match 'FullyQualifiedErrorId'))) $n `
        'the script died on a PowerShell error record instead of printing its own message'
}

# C:\Users\x -> /c/Users/x. install.ps1 hands CLAUDE_HOME to bash verbatim by design,
# so a Windows-shaped value would install somewhere nobody is looking.
function ConvertTo-BashPath([string]$p) {
    $s = $p -replace '\\', '/'
    if ($s -match '^([A-Za-z]):(.*)$') { '/' + $matches[1].ToLower() + $matches[2] } else { $s }
}

# Invoke-Installer DIR LOG [-Mode] [-WithEnv @{}] — runs install.ps1 from DIR in a
# child of this same host, captures every stream, and puts the environment back.
function Invoke-Installer {
    param(
        [string]$Dir,
        [string]$Log,
        [string]$Mode = 'list',
        [hashtable]$WithEnv = @{}
    )
    $saved = @{}
    foreach ($k in $WithEnv.Keys) {
        $saved[$k] = [Environment]::GetEnvironmentVariable($k)
        [Environment]::SetEnvironmentVariable($k, $WithEnv[$k])
    }
    try {
        $outFile = Join-Path $Logs "$Log.txt"
        $hostArgs = @('-NoProfile')
        if ($HostExe -match 'powershell\.exe$') { $hostArgs += @('-ExecutionPolicy', 'Bypass') }
        $hostArgs += @('-File', (Join-Path $Dir 'install.ps1'), $Mode)
        & $HostExe @hostArgs *> $outFile
        $code = $LASTEXITCODE
        [pscustomobject]@{ Code = $code; Text = (Get-Content $outFile -Raw); Log = $outFile }
    } finally {
        foreach ($k in $saved.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
    }
}

# A clone is install.ps1 plus the three things install.sh needs beside it. Copy-Item
# is enough — NTFS has no exec bit, and msys reads a copied .sh as executable.
function New-Clone([string]$Dest) {
    New-Item -ItemType Directory -Force -Path $Dest | Out-Null
    foreach ($f in 'install.ps1', 'install.sh', 'install-lib.py') {
        Copy-Item (Join-Path $Repo $f) $Dest -Force
    }
    Copy-Item (Join-Path $Repo 'templates') $Dest -Recurse -Force
    $Dest
}

# Rewrite one line of a clone's install.ps1, keeping the BOM section 1 asserts on.
# Returns how many lines matched, so a section can fail loudly when the line it meant
# to patch has been renamed — a patch that silently matched nothing is a test that
# silently stopped testing.
function Edit-Clone([string]$Dir, [string]$Pattern, [string]$Replacement) {
    $p = Join-Path $Dir 'install.ps1'
    $text = [IO.File]::ReadAllText($p)
    $n = ([regex]$Pattern).Matches($text).Count
    if ($n -eq 1) {
        $text = [regex]::Replace($text, $Pattern, { param($m) $Replacement })
        [IO.File]::WriteAllText($p, $text, (New-Object Text.UTF8Encoding($true)))
    }
    $n
}

Write-Host ''
Write-Host "  install.ps1 suite — host $($HostExe | Split-Path -Leaf) $($PSVersionTable.PSVersion)"

# ---------------------------------------------------------------- 1 encoding
# 5.1 reads a BOM-less file as ANSI. Every em dash in install.ps1 then arrives as
# three mojibake characters, the last of which is a smart quote — and a smart quote
# inside a double-quoted string TERMINATES it. So this is not a cosmetic check: it is
# the difference between the file parsing and not.
banner '1 · install.ps1 is UTF-8 with a BOM'
$bytes = [IO.File]::ReadAllBytes($Ps1)[0..2]
chk (($bytes[0] -eq 0xEF) -and ($bytes[1] -eq 0xBB) -and ($bytes[2] -eq 0xBF)) `
    'starts with a UTF-8 BOM' "first bytes were $($bytes -join ',')"

# ---------------------------------------------------------------- 2 probe quoting
# 5.1 does not escape embedded double quotes when it builds a native exe's command
# line, so a bash script containing them reaches bash in fragments. The failure reads
# as `syntax error: unexpected end of file` — a broken bash, apparently, rather than a
# broken caller. Single quotes cross intact.
banner '2 · the python probe carries no double quotes'
$probeLine = Select-String -Path $Ps1 -Pattern '^\$pythonProbe = ' | Select-Object -First 1
chk ($null -ne $probeLine) 'the probe line is still called $pythonProbe' 'not found — sections 2 and 5 no longer test anything'
if ($probeLine) {
    chk (-not $probeLine.Line.Contains('"')) 'no double quote in the probe' $probeLine.Line
}

# ---------------------------------------------------------------- 3 hand-off quoting
# Every value interpolated into the bash command goes inside single quotes, so an
# apostrophe in the path ends that quoting early and bash dies on an unterminated
# string. C:\Users\O'Brien is an ordinary Windows home directory.
banner '3 · every path handed to bash is escaped, not just quoted'
$src = [IO.File]::ReadAllText($Ps1)
chk (-not ($src -match "cd '\`$\(")) 'no raw single-quoted path in a hand-off' 'found cd ''$( ... — use ConvertTo-BashQuoted'
chk ($src -match 'ConvertTo-BashQuoted') 'the escaping helper is still there' 'ConvertTo-BashQuoted is gone'

# ---------------------------------------------------------------- 4 the real thing
# `list` is the whole chain — powershell -> install.ps1 -> bash -> install.sh -> python
# — and it changes nothing on disk.
banner '4 · list runs the whole chain'
$ch = Join-Path $Work 'home/.claude'
New-Item -ItemType Directory -Force -Path $ch | Out-Null
$r4 = Invoke-Installer -Dir $Repo -Log 'list' -Mode 'list' `
        -WithEnv @{ CLAUDE_HOME = (ConvertTo-BashPath $ch) }
chk ($r4.Code -eq 0) 'exits 0' "rc=$($r4.Code) — see $($r4.Log)"
inlog $r4 'python in bash' 'the python probe answers'
inlog $r4 'Discover' 'reaches install.sh discovery'
notinlog $r4 'discovery failed' 'discovery does not fail'
notcrashed $r4 'no raw PowerShell error'

# ---------------------------------------------------------------- 5 a handled failure
# Under $ErrorActionPreference = 'Stop', 5.1 turns ANY stderr from a native exe into a
# TERMINATING error — `2>$null` does not stop it and neither does `2>&1`. Every probe
# in install.ps1 is allowed to fail, so before this was handled the script died on a
# red error dump and the message written for this exact case never printed.
banner '5 · a failing probe prints its own message'
$c5 = New-Clone (Join-Path $Work 'nopython')
$n5 = Edit-Clone $c5 '(?m)^\$pythonProbe = .*$' "`$pythonProbe = 'echo no-python-here >&2; exit 1'"
chk ($n5 -eq 1) 'patched the probe line' "matched $n5 lines, expected 1"
if ($n5 -eq 1) {
    $r5 = Invoke-Installer -Dir $c5 -Log 'nopython'
    chk ($r5.Code -ne 0) 'exits non-zero' "rc=$($r5.Code)"
    inlog $r5 'No python 3.7+ inside bash' 'prints the written failure message'
    notcrashed $r5 'no raw PowerShell error'
}

# ---------------------------------------------------------------- 6 no bash anywhere
# Two halves, because Windows will not let one do it: blanking $env:ProgramFiles does
# not reach a child process (the OS re-derives that one, unlike PATH), so the three
# known Git for Windows locations are emptied by patching the clone, and the PATH
# lookup and the WSL fallback — both of which go through PATH — are emptied by handing
# the child a PATH with nothing on it but PowerShell itself.
banner '6 · no bash at all is a written message, not a crash'
$c6 = New-Clone (Join-Path $Work 'nobash')
$n6 = Edit-Clone $c6 '(?ms)^\$candidates = @\(.*?^\)\r?$' '$candidates = @()'
chk ($n6 -eq 1) 'emptied the candidate list' "matched $n6 blocks, expected 1"
$r6 = Invoke-Installer -Dir $c6 -Log 'nobash' -WithEnv @{ PATH = $PSHOME }
chk ($r6.Code -ne 0) 'exits non-zero' "rc=$($r6.Code)"
# Either wording is correct here: a machine with a WSL that cannot run bash — Docker
# Desktop registers docker-desktop as a distribution — gets the longer message.
chk (($r6.Text -match 'No bash found') -or ($r6.Text -match 'No usable bash found')) `
    'says no bash was found' "see $($r6.Log)"
inlog $r6 'git-scm.com' 'says where to get one'
notcrashed $r6 'no raw PowerShell error'

# ---------------------------------------------------------------- 7 apostrophe path
# Both halves at once. install.ps1 must escape the apostrophe on its way into the bash
# command; install.sh must convert /c/... into C:/... itself for the arguments msys
# refuses to touch. Before either fix this died — first at `cd`, then at discovery.
banner "7 · a clone at a path with an apostrophe"
$c7 = New-Clone (Join-Path $Work "o'brien clone")
$h7 = Join-Path $Work "o'brien home/.claude"
New-Item -ItemType Directory -Force -Path $h7 | Out-Null
$r7 = Invoke-Installer -Dir $c7 -Log 'apostrophe' -Mode 'list' `
        -WithEnv @{ CLAUDE_HOME = (ConvertTo-BashPath $h7) }
chk ($r7.Code -eq 0) 'exits 0' "rc=$($r7.Code) — see $($r7.Log)"
inlog $r7 'Discover' 'reaches discovery'
notinlog $r7 'discovery failed' 'discovery does not fail'
notinlog $r7 'unexpected EOF' 'bash got a terminated command'
notinlog $r7 "can't open file" 'python opened every path it was handed'
notcrashed $r7 'no raw PowerShell error'

Write-Host ''
Write-Host '================================'
Write-Host "  passed $script:Pass   failed $script:Fail"
if ($script:Fail -gt 0) {
    Write-Host '  failures:'
    foreach ($f in $script:Failed) { Write-Host "    - $f" }
    Write-Host "  logs in $Logs"
    exit 1
}
exit 0
