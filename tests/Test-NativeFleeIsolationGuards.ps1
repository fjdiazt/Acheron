$ErrorActionPreference='Stop'
$root=Join-Path ([IO.Path]::GetTempPath()) ('flee-boundary-'+[guid]::NewGuid())
$cases=@(
    @{Test='native-flee-enemy-probe';KeepInstalled=$true},
    @{Test='native-flee-yield-probe';KeepInstalled=$true},
    @{Test='native-flee-yield-probe';DisableAcheronHooks=$true},
    @{Test='peaceful-state';DisableAcheronHooks=$true},
    @{Test='peaceful-state';ExcludeFleePlugins=@('OpenAnimationReplacer.dll')},
    @{Test='native-flee-probe';ExcludeFleePlugins=@('unrelated.dll')}
)
foreach($case in $cases) {
    $rejected=$false
    try {& (Join-Path $PSScriptRoot 'Invoke-PacificationTests.ps1') -GameRoot $root @case}
    catch {
        if($_.Exception.Message -notmatch 'Native flee probes always restore|Isolation requires restoring|ValidateSet|does not belong to the set') {throw}
        $rejected=$true
    }
    if(-not $rejected -or (Test-Path -LiteralPath $root)) {throw 'Isolation guard allowed deployment outside probe scope'}
}
'PASS: flee probes cannot persist candidates, isolate other suites or omit arbitrary DLLs'
