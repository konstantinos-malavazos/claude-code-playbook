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
    because most sections run the real installer end to end. Sections 4, 7, 9, 10, 11
    and 12 reach install.sh, and 13 reads what 10 and 11 left behind, so a break in
    EITHER half lands here.

.NOTES
    Nothing here writes to the real ~/.claude: every run that gets as far as install.sh
    is `list`, which changes nothing, except section 10's install and section 11's
    updates, which run with HOME and CLAUDE_HOME both redirected into the temp dir. Set PLAYBOOK_TEST_DIR to move that
    temp dir, as the bash suites do.
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

# C:\Users\x -> /c/Users/x.
# Sections 4 and 7 hand install.ps1 an already bash-shaped value, which must pass through unchanged.
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
        [hashtable]$WithEnv = @{},
        [string]$StdinFile = '',
        [string[]]$Extra = @()
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
        $hostArgs += @('-File', (Join-Path $Dir 'install.ps1'), $Mode) + $Extra
        if ($StdinFile) {
            # Keystrokes for an install: the child inherits this stdin, and so does the
            # bash it hands off to. Start-Process joins its arguments with spaces and
            # quotes none of them, so a path with a space is quoted here.
            $errFile = Join-Path $Logs "$Log.err.txt"
            $quoted = $hostArgs | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }
            $p = Start-Process -FilePath $HostExe -ArgumentList $quoted -NoNewWindow -Wait -PassThru `
                    -RedirectStandardInput $StdinFile -RedirectStandardOutput $outFile -RedirectStandardError $errFile
            $text = [string](Get-Content $outFile -Raw) + [string](Get-Content $errFile -Raw)
            [pscustomobject]@{ Code = $p.ExitCode; Text = $text; Log = $outFile }
        } else {
            & $HostExe @hostArgs *> $outFile
            $code = $LASTEXITCODE
            [pscustomobject]@{ Code = $code; Text = (Get-Content $outFile -Raw); Log = $outFile }
        }
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
inlog $r4 'this clone can install' 'reaches install.sh discovery'
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
inlog $r7 'this clone can install' 'reaches discovery'
notinlog $r7 'discovery failed' 'discovery does not fail'
notinlog $r7 'unexpected EOF' 'bash got a terminated command'
notinlog $r7 "can't open file" 'python opened every path it was handed'
notcrashed $r7 'no raw PowerShell error'

# ---------------------------------------------------------------- 8 wsl shell flags
banner '8 · the WSL hand-off runs the shell its python probe ran'
$matchA = [regex]::Matches($src, '(?m)Invoke-Probe ''wsl\.exe'' @\(''-e'', ''bash'', ''([^'']*)'', \$pythonProbe\)')
$matchB = [regex]::Matches($src, '(?m)& wsl\.exe -e bash ([^\s]+) "cd')
# Without -e, wsl.exe hands the rest of its command line to the distro's default shell,
# which expands a $ or backtick in a path before bash or wslpath ever sees it. -l lists
# distros and runs nothing.
$noE = [regex]::Matches($src, '(?m)(Invoke-Probe ''wsl\.exe'' @\((?!''-e'',|''-l'',)|^\s*& wsl\.exe (?!-e ))[^\r\n]*')
chk ($noE.Count -eq 0) 'every wsl.exe call that runs a program passes -e' `
    "found $($noE.Count): $(($noE | ForEach-Object { $_.Value.Trim() }) -join ' | ')"
chk ($matchA.Count -eq 1) 'WSL probe line matched exactly once' "matched $($matchA.Count) times, expected 1"
chk ($matchB.Count -eq 1) 'WSL hand-off line matched exactly once' "matched $($matchB.Count) times, expected 1"
if ($matchA.Count -eq 1 -and $matchB.Count -eq 1) {
    $flagA = $matchA[0].Groups[1].Value
    $flagB = $matchB[0].Groups[1].Value
    chk ($flagA -eq $flagB) 'the WSL hand-off uses the same bash flag as the WSL probe' `
        "probe used '$flagA' but hand-off used '$flagB'"
}

# ---------------------------------------------------------------- 9 claude_home translation
banner '9 · a Windows-shaped CLAUDE_HOME is translated or refused'
$h9 = (Join-Path $Work 'home9\.claude') -replace '/', '\'
New-Item -ItemType Directory -Force -Path $h9 | Out-Null
$r9a = Invoke-Installer -Dir $Repo -Log 'winhome' -Mode 'list' -WithEnv @{ CLAUDE_HOME = $h9 }
chk ($r9a.Code -eq 0) 'exits 0' "rc=$($r9a.Code) — see $($r9a.Log)"
$expectedPattern = 'currently installed in:\r?\n\s+' + [regex]::Escape((ConvertTo-BashPath $h9))
chk ($r9a.Text -match $expectedPattern) 'install.sh gets the bash form of a Windows CLAUDE_HOME' `
    "expected match for $expectedPattern"
notinlog $r9a $h9 'the raw Windows path reaches nobody'
notcrashed $r9a 'no raw PowerShell error'

$r9b = Invoke-Installer -Dir $Repo -Log 'relhome' -Mode 'list' -WithEnv @{ CLAUDE_HOME = 'relative\.claude' }
chk ($r9b.Code -ne 0) 'exits non-zero' "rc=$($r9b.Code)"
inlog $r9b 'CLAUDE_HOME cannot be translated for this bash' 'CLAUDE_HOME cannot be translated for this bash'
notinlog $r9b 'this clone can install' 'install.sh was never reached'
notcrashed $r9b 'no raw PowerShell error'

# ---------------------------------------------------------------- 10 the hook library
# Every hook sources hooks/_lib/common.sh and refuses every call without it, so an
# install through this door has to land it. A real install: keystrokes on stdin, and a
# scratch HOME holding the two MCP servers the install gates on.
banner '10 · an install through install.ps1 lands hooks/_lib/common.sh'
$home10 = Join-Path $Work 'home10'
$ch10   = Join-Path $home10 '.claude'
$ws10   = Join-Path $Work 'ws10'
New-Item -ItemType Directory -Force -Path $ch10, $ws10 | Out-Null
[IO.File]::WriteAllText((Join-Path $home10 '.claude.json'),
    '{ "mcpServers": { "serena": { "command": "uvx", "args": ["serena"] }, "forgetful": { "command": "forgetful-mcp" } } }')
# The same answers as tests/test-installer.sh's FULL list, LF-terminated for bash's read.
$keys10 = Join-Path $Work 'keys10.in'
$answers10 = @('', '', '5', '4', '', 'i', '', '', '', '', '', '', '', '', 'y', (ConvertTo-BashPath $ws10), '')
[IO.File]::WriteAllText($keys10, (($answers10 -join "`n") + "`n"))
$r10 = Invoke-Installer -Dir $Repo -Log 'install-hook-lib' -Mode 'install' -StdinFile $keys10 `
        -WithEnv @{ HOME = (ConvertTo-BashPath $home10); CLAUDE_HOME = (ConvertTo-BashPath $ch10); PLAYBOOK_SCRIPTED_INPUT = '1' }
chk ($r10.Code -eq 0) 'exits 0' "rc=$($r10.Code) — see $($r10.Log)"
$lib10 = Join-Path $ch10 'hooks\_lib\common.sh'
chk (Test-Path $lib10) 'wrote hooks/_lib/common.sh' "see $($r10.Log)"
if (Test-Path $lib10) {
    chk (-not ([IO.File]::ReadAllBytes($lib10) -contains 13)) 'hooks/_lib/common.sh has no CR bytes' 'a CRLF library breaks every hook'
}
notcrashed $r10 'no raw PowerShell error'

# ---------------------------------------------------------------- 11 a retired hook
# cleanup-handoffs.sh deleted handoff folders at every session end. An update through this
# door must delete the recorded copy and its SessionEnd entry, keep a SessionEnd hook of
# the user's own, and leave every other hook wired. Builds on section 10's install.
banner '11 · update through install.ps1 retires cleanup-handoffs'
$man11 = Join-Path $ch10 '.playbook-install.json'
$set11 = Join-Path $ch10 'settings.json'
$hook11 = Join-Path $ch10 'hooks\cleanup-handoffs.sh'
$seeded11 = $false
if ((Test-Path $man11) -and (Test-Path $set11)) {
    [IO.File]::WriteAllText($hook11, "#!/usr/bin/env bash`n# section 11 as installed`nexit 0`n")
    $hash11 = (Get-FileHash -Algorithm SHA256 $hook11).Hash.ToLower()
    $mtext = [IO.File]::ReadAllText($man11)
    $dm = [regex]::Match($mtext, '"hook:block-dangerous-git": \{[^}]*?"dest": "([^"]*)block-dangerous-git\.sh"')
    $stext = [IO.File]::ReadAllText($set11)
    $nUnits = ([regex]'"units": \{').Matches($mtext).Count
    $nHooks = ([regex]'"hooks": \{').Matches($stext).Count
    if ($dm.Success -and $nUnits -eq 1 -and $nHooks -eq 1) {
        $rec = '"units": {' + "`n" + '    "hook:cleanup-handoffs": {"kind": "hook", "dest": "' + $dm.Groups[1].Value +
               'cleanup-handoffs.sh", "hash": "' + $hash11 + '", "source_hash": "' + ('0' * 64) + '"},'
        [IO.File]::WriteAllText($man11, $mtext.Replace('"units": {', $rec))
        $ours = '{"type": "command", "command": "~/.claude/hooks/cleanup-handoffs.sh"}'
        $end = '"hooks": {' + "`n" + '    "SessionEnd": [{"hooks": [' + $ours + ']}, {"hooks": [' +
               '{"type": "command", "command": "~/bin/my-session-end.sh"}, ' + $ours + ']}],'
        [IO.File]::WriteAllText($set11, $stext.Replace('"hooks": {', $end))
        $seeded11 = $true
    }
}
chk $seeded11 'seeded a recorded, wired cleanup-handoffs beside a SessionEnd hook of the user''s own' `
    "section 10's install did not leave a manifest and settings.json shaped as expected — see $($r10.Log)"
if ($seeded11) {
    $empty11 = Join-Path $Work 'keys11.in'
    [IO.File]::WriteAllText($empty11, '')
    $env11 = @{ HOME = (ConvertTo-BashPath $home10); CLAUDE_HOME = (ConvertTo-BashPath $ch10); PLAYBOOK_SCRIPTED_INPUT = '1' }
    $r11 = Invoke-Installer -Dir $Repo -Log 'update-retire' -Mode 'update' -StdinFile $empty11 -WithEnv $env11
    chk ($r11.Code -eq 0) 'update exits 0' "rc=$($r11.Code) — see $($r11.Log)"
    chk (-not (Test-Path $hook11)) 'update deleted hooks/cleanup-handoffs.sh' "see $($r11.Log)"
    $after11 = [IO.File]::ReadAllText($set11)
    chk (-not $after11.Contains('cleanup-handoffs')) 'settings.json no longer names cleanup-handoffs' $set11
    chk $after11.Contains('~/bin/my-session-end.sh') 'the user''s own SessionEnd hook is still wired' $set11
    chk $after11.Contains('~/.claude/hooks/block-dangerous-git.sh') 'the PreToolUse hooks are still wired' $set11
    chk (-not [IO.File]::ReadAllText($man11).Contains('hook:cleanup-handoffs')) `
        'the manifest no longer records hook:cleanup-handoffs' $man11
    notcrashed $r11 'no raw PowerShell error'
    $r11b = Invoke-Installer -Dir $Repo -Log 'update-retire-again' -Mode 'update' -StdinFile $empty11 -WithEnv $env11
    chk ($r11b.Code -eq 0) 'a second update exits 0' "rc=$($r11b.Code) — see $($r11b.Log)"
    chk ([IO.File]::ReadAllText($set11) -ceq $after11) 'a second update leaves settings.json unchanged' $set11
}


# ---------------------------------------------------------------- 12 serena-wire
# The route C rewire mode, and the folder arguments it takes after the mode, have to
# reach install.sh whole: -Mode must accept the name, and every extra argument must
# be passed on.
banner '12 · serena-wire is a mode, and its folder argument reaches install.sh'
$h12 = Join-Path $Work 'h12/.claude'
New-Item -ItemType Directory -Force -Path $h12 | Out-Null
$d12 = Join-Path $Work "no such folder o'k"
# install.sh refuses on stderr. Through Start-Process (the -StdinFile path) that stays
# text; through the call operator a 5.1 host would wrap it in an error record of its own.
$empty12 = Join-Path $Work 'empty12.txt'
[IO.File]::WriteAllText($empty12, '')
$r12 = Invoke-Installer -Dir $Repo -Log 'serena-wire' -Mode 'serena-wire' -Extra @($d12) `
        -StdinFile $empty12 -WithEnv @{ CLAUDE_HOME = (ConvertTo-BashPath $h12) }
notinlog $r12 'Cannot validate argument' '-Mode accepts serena-wire'
inlog $r12 'is not a folder' 'install.sh ran serena-wire and checked the folder it was given'
inlog $r12 "no such folder o'k" 'the folder argument arrives whole, spaces and apostrophe included'
chk ($r12.Code -ne 0) 'exits non-zero for a folder that is not there' "rc=$($r12.Code)"
notcrashed $r12 'no raw PowerShell error'

# ---------------------------------------------------------------- 13 modelSettings
# The per-model effort defaults land through this door too. Section 10's install wrote
# settings.json and section 11's updates replayed it: each recorded model id must carry
# its effortLevel there, keyed by the full id.
banner '13 · an install through install.ps1 merges the per-model effort defaults'
$man13 = Join-Path $ch10 '.playbook-install.json'
$set13 = Join-Path $ch10 'settings.json'
$values13 = $null
$models13 = $null
if ((Test-Path $man13) -and (Test-Path $set13)) {
    try {
        $values13 = ([IO.File]::ReadAllText($man13) | ConvertFrom-Json).config.placeholders.values
        $models13 = ([IO.File]::ReadAllText($set13) | ConvertFrom-Json).modelSettings
    } catch {
        $values13 = $null
    }
}
chk ($null -ne $values13) 'read the manifest and settings.json section 10 left' "see $($r10.Log)"
if ($null -ne $values13) {
    $want13 = @{ '<strong-model-id>' = 'medium'; '<fast-model-id>' = 'high' }
    foreach ($tok13 in '<strong-model-id>', '<fast-model-id>') {
        $id13 = [string]$values13.$tok13
        $got13 = $null
        if ($id13 -and $null -ne $models13 -and $models13.PSObject.Properties[$id13]) {
            $got13 = $models13.$id13.effortLevel
        }
        chk ($got13 -eq $want13[$tok13]) "modelSettings[$id13].effortLevel is $($want13[$tok13])" "got '$got13' in $set13"
    }
    $keys13 = @()
    if ($null -ne $models13) { $keys13 = @($models13.PSObject.Properties | ForEach-Object { $_.Name }) }
    chk (($keys13.Count -gt 0) -and -not ($keys13 | Where-Object { $_ -notlike '*claude-*' })) `
        'every modelSettings key is a full model id' "keys: $($keys13 -join ', ')"
}

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
