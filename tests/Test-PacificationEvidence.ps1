$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Pacification-Evidence.ps1')
$before = '[YieldAttack] source=FF000111 target=FF000222 state=2 combat=true defeated=false pacified=false dead=false tickMs=500' + "`n" +
    '[YieldHit] target=FF000222 source=FF000111 damage=5 immune=false tickMs=600'
$after = (0..52 | ForEach-Object { '[YieldAttack] source=FF000111 target=00000000 state=0 combat=false defeated=false pacified=false dead=false tickMs=' + (1000 + $_ * 250) }) -join "`n"
$result = Measure-Pacification $before $after '0xFF000111' '0xFF000222'
if ($result.outcome -ne 'stopped-attacking' -or $result.observationWindowMs -lt 10000) { throw 'Quiet teammate misclassified' }
$result = Measure-Pacification $before ($after.Replace('state=0 combat=false defeated=false pacified=false dead=false tickMs=8500','state=2 combat=true defeated=false pacified=false dead=false tickMs=8500')) '0xFF000111' '0xFF000222'
if ($result.outcome -ne 'continued-attacks') { throw 'Attack masked by health immunity' }
$result = Measure-Pacification $before ($after + "`n[YieldHit] target=FF000222 source=FF000111 damage=5 immune=true tickMs=8500") '0xFF000111' '0xFF000222'
if ($result.outcome -ne 'continued-attacks') { throw 'Blocked hit ignored' }
$result = Measure-Pacification $before ($after.Replace("state=0 combat=false defeated=false pacified=false dead=false tickMs=1250`n","state=2 combat=true defeated=false pacified=false dead=false tickMs=1250`n")) '0xFF000111' '0xFF000222'
if ($result.outcome -ne 'stopped-attacking' -or $result.settlingAttackSamples -ne 1) { throw 'Settling attack not separated' }
$result = Measure-Pacification $before ($after + "`n[YieldHit] target=FF000222 source=FF000111 damage=5 immune=true tickMs=1250") '0xFF000111' '0xFF000222'
if ($result.outcome -ne 'stopped-attacking' -or $result.settlingHits -ne 1) { throw 'In-flight hit lost from pacification evidence' }
$result = Measure-Pacification $before ($after.Replace('target=00000000 state=0 combat=false defeated=false pacified=false dead=false tickMs=8500','target=FF000222 state=0 combat=true defeated=false pacified=false dead=false tickMs=8500')) '0xFF000111' '0xFF000222'
if ($result.outcome -ne 'no-attacks-observed-combat-lingers') { throw 'Lingering target incorrectly reported stopped' }
foreach ($bad in @('', $before.Replace('FF000111','FF000333'), $before.Replace('damage=5','damage=0'))) {
    $rejected = $false
    try { Measure-Pacification $bad $after '0xFF000111' '0xFF000222' | Out-Null } catch { $rejected = $true }
    if (-not $rejected) { throw 'Unproven baseline accepted' }
}
$rejected = $false
try { Measure-Pacification $before ($after.Split("`n")[0..3] -join "`n") '0xFF000111' '0xFF000222' | Out-Null } catch { $rejected = $true }
if (-not $rejected) { throw 'Insufficient observation accepted' }
foreach ($flag in @('defeated','pacified','dead')) {
    $rejected=$false
    try { Measure-Pacification $before ($after.Replace("$flag=false","$flag=true")) '0xFF000111' '0xFF000222' | Out-Null } catch { $rejected=$true }
    if (-not $rejected) { throw 'Disabled follower falsely treated as pacification pacification success' }
}
Assert-PacificationStopped (Measure-Pacification $before $after '0xFF000111' '0xFF000222')
foreach ($badLog in @(
    $after.Replace('state=0 combat=false defeated=false pacified=false dead=false tickMs=8500','state=2 combat=true defeated=false pacified=false dead=false tickMs=8500'),
    ($after + "`n[YieldHit] target=FF000222 source=FF000111 damage=5 immune=true tickMs=8500"),
    $after.Replace('target=00000000 state=0 combat=false defeated=false pacified=false dead=false tickMs=8500','target=FF000222 state=0 combat=true defeated=false pacified=false dead=false tickMs=8500')
)) {
    $rejected=$false
    try { Assert-PacificationStopped (Measure-Pacification $before $badLog '0xFF000111' '0xFF000222') } catch { $rejected=$true }
    if (-not $rejected) { throw 'Continued attacks, blocked hits or lingering combat accepted as regression PASS' }
}
'PASS: pacification regressions reject continued attacks, blocked hits, lingering combat and invalid evidence'
