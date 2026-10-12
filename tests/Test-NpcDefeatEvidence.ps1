$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Npc-Defeat-Evidence.ps1')
$line = '[02:00:00] [info] [YieldTest] target=FF000123 source=00000014 health=1 damage=7 lethal=true defeated=true pacified=true registered=true'
Assert-YieldDefeatEvidence $line '0xFF000123' $false $true $true 0.05
$followerLine = $line.Replace('00000014','FF000456')
Assert-YieldDefeatEvidence $followerLine '0xFF000123' $false $true $true 0.05 '0xFF000456'
$rejected = $false
try { Assert-YieldDefeatEvidence $followerLine '0xFF000123' $false $true $true 0.05 '0xFF000457' } catch { $rejected = $true }
if (-not $rejected) { throw 'FAIL: wrong follower source accepted' }
foreach ($bad in @($line.Replace('00000014','00000015'), $line.Replace('FF000123','FF000124'), $line.Replace('damage=7','damage=0.5'), $line.Replace('registered=true','registered=false'), '')) {
    $rejected = $false
    try { Assert-YieldDefeatEvidence $bad '0xFF000123' $false $true $true 0.05 } catch { $rejected = $true }
    if (-not $rejected) { throw 'FAIL: missing/nonlethal/foreign evidence accepted' }
}
foreach ($state in @(@($true,$true,$true,0.05), @($false,$false,$true,0.05), @($false,$true,$false,0.05), @($false,$true,$true,0))) {
    $rejected = $false
    try { Assert-YieldDefeatEvidence $line '0xFF000123' $state[0] $state[1] $state[2] $state[3] } catch { $rejected = $true }
    if (-not $rejected) { throw 'FAIL: invalid live state accepted' }
}
Write-Output 'PASS: real lethal player-hit evidence and live defeat assertions'
