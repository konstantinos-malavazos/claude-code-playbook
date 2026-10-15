# serena-down.ps1 [repo-key...] — stop route C Serena servers (no key: all of them) and
# check by process listing that none is left. serena_route.py beside this file does
# the work; this finds a python.
$found = @()
foreach ($name in 'python3', 'python') {
    # On Windows, `&` hands anything but a program or a batch file to the shell, which opens
    # it without waiting (an extensionless python3 script brings up the Open-with handler)
    # and never sets $LASTEXITCODE: such a file is not a candidate.
    $found += @(Get-Command $name -CommandType Application -All -ErrorAction SilentlyContinue |
        Where-Object { $env:OS -ne 'Windows_NT' -or $_.Extension -in '.exe', '.bat', '.cmd' } |
        ForEach-Object { $_.Source })
}
# The WindowsApps python is the Store's alias, which may print an advert instead of
# running python: it is tried last, never dropped.
$ordered = @($found | Where-Object { $_ -notmatch '\\WindowsApps\\' }) +
    @($found | Where-Object { $_ -match '\\WindowsApps\\' })
$py = $null
foreach ($c in $ordered) {
    & $c -c "pass" *> $null
    if ($LASTEXITCODE -eq 0) { $py = $c; break }
}
if (-not $py) {
    [Console]::Error.WriteLine("serena-down: no working python found (tried: " + ($ordered -join ', ') + ")")
    exit 1
}
& $py (Join-Path $PSScriptRoot 'serena_route.py') down @args
exit $LASTEXITCODE
