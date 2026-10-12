$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Pacification-State-Evidence.ps1')
$start='[PeacefulState] actor=FF000123 phase=2 remaining=2 generation=10 tickMs=1000'
$end='[PeacefulState] actor=FF000123 phase=0 remaining=0 generation=10 tickMs=3000'
Measure-PeacefulExpiry "$start`n$end" '0xFF000123' 2 | Out-Null
foreach($log in @($start, "$start`n$($end.Replace('3000','1200'))", "$start`n$($end.Replace('3000','9000'))", "$start`n$($end.Replace('generation=10','generation=11'))", "$start`n$($end.Replace('remaining=0','remaining=1'))", "$start`n$($end.Replace('FF000123','FF000124'))")) {
    $rejected=$false
    try { Measure-PeacefulExpiry $log '0xFF000123' 2 | Out-Null } catch { $rejected=$true }
    if(-not $rejected) { throw 'Invalid peaceful evidence accepted' }
}
'PASS: peaceful expiry evidence rejects missing, early, late, wrong actor, refresh and manual exit'
