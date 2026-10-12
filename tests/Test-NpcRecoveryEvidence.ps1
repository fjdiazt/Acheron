$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Npc-Recovery-Evidence.ps1')

function New-RecoveryLog([int] $ElapsedMs) {
    $lines = @(
        '[YieldAttack] source=FF000123 target=00000000 state=0 combat=false defeated=false pacified=false dead=false tickMs=9900',
        '[YieldHit] target=FF000123 source=00000014 damage=7 immune=false tickMs=10000',
        '[YieldTest] target=FF000123 source=00000014 health=1 damage=7 lethal=true defeated=true pacified=true registered=true'
    )
    for ($tick=10250; $tick -lt 10000 + $ElapsedMs; $tick+=250) {
        $lines += "[YieldAttack] source=FF000123 target=00000000 state=0 combat=false defeated=true pacified=true dead=false tickMs=$tick"
    }
    $lines += 'FF000123 (Forsworn) has been rescued'
    $lines += "[YieldAttack] source=FF000123 target=00000000 state=0 combat=false defeated=false pacified=false dead=false tickMs=$(10000 + $ElapsedMs)"
    return $lines -join "`n"
}

foreach ($seconds in @(2,3)) {
    $good = New-RecoveryLog ($seconds * 1000 + 250)
    $result = Measure-YieldRecovery $good '0xFF000123' $seconds
    if ($result.elapsedMs -ne $seconds * 1000 + 250) { throw 'FAIL: wrong native recovery duration' }
    foreach ($bad in @(
        (New-RecoveryLog ($seconds * 1000 - 500)),
        (New-RecoveryLog ($seconds * 1000 + 750)),
        $good.Replace('source=00000014','source=00000015'),
        $good.Replace('target=FF000123 source=00000014','target=FF000124 source=00000014'),
        $good.Replace('registered=true','registered=false'),
        $good.Replace('damage=7','damage=0.5'),
        $good.Replace('has been rescued','still defeated'),
        $good.Replace('defeated=false pacified=false dead=false tickMs=' + (10000 + $seconds * 1000 + 250), 'defeated=false pacified=true dead=false tickMs=' + (10000 + $seconds * 1000 + 250)),
        $good.Replace('dead=false','dead=true'),
        (($good -split "`n" | Where-Object { $_ -notmatch 'tickMs=10(500|750)' }) -join "`n"),
        ''
    )) {
        $rejected = $false
        try { Measure-YieldRecovery $bad '0xFF000123' $seconds | Out-Null } catch { $rejected = $true }
        if (-not $rejected) { throw 'FAIL: early/late/foreign/stalled/incomplete recovery evidence accepted' }
    }
}
Write-Output 'PASS: 2s/3s native recovery timing and negative evidence cases (no game)'
