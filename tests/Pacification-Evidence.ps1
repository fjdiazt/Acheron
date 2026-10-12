function Assert-PacificationStopped($Result) {
    if ($Result.outcome -ne 'stopped-attacking') { throw "Pacification regression: $($Result.outcome)" }
}

function Measure-Pacification([string] $BeforeLog, [string] $AfterLog, [string] $AttackerId, [string] $EnemyId) {
    $source = [regex]::Escape(($AttackerId -replace '^0x',''))
    $target = [regex]::Escape(($EnemyId -replace '^0x',''))
    $attackPattern = '\[YieldAttack\] source=' + $source + ' target=(?<target>[0-9A-F]{8}) state=(?<state>\d+) combat=(?<combat>true|false) defeated=(?<defeated>true|false) pacified=(?<pacified>true|false) dead=(?<dead>true|false) tickMs=(?<tick>\d+)'
    $hitPattern = '\[YieldHit\] target=' + $target + ' source=' + $source + ' damage=(?<damage>[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?) immune=(?<immune>true|false) tickMs=(?<tick>\d+)'
    $beforeHits = @([regex]::Matches($BeforeLog,$hitPattern) | Where-Object {
        $_.Groups['immune'].Value -eq 'false' -and [double]::Parse($_.Groups['damage'].Value,[Globalization.CultureInfo]::InvariantCulture) -gt 0
    })
    $beforeAttacks = @([regex]::Matches($BeforeLog,$attackPattern) | Where-Object {
        $_.Groups['target'].Value -eq $target -and [int]$_.Groups['state'].Value -gt 0 -and $_.Groups['combat'].Value -eq 'true'
    })
    if (-not $beforeHits.Count -or -not $beforeAttacks.Count) { throw 'Attacker attack activity and damaging hit not proven before pacification' }
    $samples = @([regex]::Matches($AfterLog,$attackPattern))
    if (-not $samples.Count) { throw 'No live attacker attack observations after pacification' }
    if (@($samples | Where-Object { $_.Groups['defeated'].Value -eq 'true' -or $_.Groups['pacified'].Value -eq 'true' -or $_.Groups['dead'].Value -eq 'true' }).Count) {
        throw 'Attacker defeated, pacified or dead; stopping cannot be attributed to enemy pacification'
    }
    $settledAt = [long]$samples[0].Groups['tick'].Value + 2000
    $quiet = @($samples | Where-Object { [long]$_.Groups['tick'].Value -ge $settledAt })
    if ($quiet.Count -lt 20) { throw 'Insufficient post-pacification observations' }
    $windowMs = [long]$quiet[-1].Groups['tick'].Value - [long]$quiet[0].Groups['tick'].Value
    if ($windowMs -lt 10000) { throw 'Post-settling observation window shorter than ten seconds' }
    $active = @($quiet | Where-Object { [int]$_.Groups['state'].Value -gt 0 })
    $settling = @($samples | Where-Object { [long]$_.Groups['tick'].Value -lt $settledAt -and [int]$_.Groups['state'].Value -gt 0 })
    $afterHits = @([regex]::Matches($AfterLog,$hitPattern))
    $hits = @($afterHits | Where-Object { [long]$_.Groups['tick'].Value -ge $settledAt })
    $settlingHits = @($afterHits | Where-Object { [long]$_.Groups['tick'].Value -lt $settledAt })
    $combat = @($quiet | Where-Object { $_.Groups['combat'].Value -eq 'true' -or $_.Groups['target'].Value -ne '00000000' })
    $outcome = if ($active.Count -or $hits.Count) { 'continued-attacks' } elseif ($combat.Count) { 'no-attacks-observed-combat-lingers' } else { 'stopped-attacking' }
    [pscustomobject]@{ outcome=$outcome; baselineHits=$beforeHits.Count; baselineAttackSamples=$beforeAttacks.Count;
        settlingAttackSamples=$settling.Count; settlingHits=$settlingHits.Count; postSettlingAttackSamples=$active.Count; postSettlingHits=$hits.Count;
        lingeringCombatSamples=$combat.Count; observedSamples=$quiet.Count; observationWindowMs=$windowMs }
}
