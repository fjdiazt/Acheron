function Measure-YieldRecovery([string] $Log, [string] $ActorId, [ValidateSet(2,3)] [int] $Seconds) {
    $id = [regex]::Escape(($ActorId -replace '^0x',''))
    $number = '[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?'
    $hit = [regex]::Matches($Log, ('\[YieldHit\] target=' + $id + ' source=00000014 damage=(?<damage>' + $number + ') immune=false tickMs=(?<tick>\d+)'))
    $entry = [regex]::Matches($Log, ('\[YieldTest\] target=' + $id + ' source=00000014 health=(?<hp>' + $number + ') damage=(?<damage>' + $number + ') lethal=true defeated=true pacified=true registered=true'))
    if ($hit.Count -ne 1 -or $entry.Count -ne 1 -or $hit[0].Index -ge $entry[0].Index) { throw 'Recovery requires one real player lethal hit and defeat registration' }
    $hp = [double]::Parse($entry[0].Groups['hp'].Value, [Globalization.CultureInfo]::InvariantCulture)
    $damage = [double]::Parse($entry[0].Groups['damage'].Value, [Globalization.CultureInfo]::InvariantCulture)
    if (-not [double]::IsFinite($hp) -or -not [double]::IsFinite($damage) -or $hp -le 0 -or $damage -lt $hp) { throw 'Recovery fixture hit was not lethal' }
    $start = [long]$hit[0].Groups['tick'].Value
    $samples = @([regex]::Matches($Log, ('\[YieldAttack\] source=' + $id + ' target=[0-9A-F]{8} state=\d+ combat=(?:true|false) defeated=(?<defeated>true|false) pacified=(?<pacified>true|false) dead=(?<dead>true|false) tickMs=(?<tick>\d+)')) | Where-Object { $_.Index -gt $entry[0].Index })
    $previous = $start
    $lastDefeated = $null
    $recovered = $null
    foreach ($sample in $samples) {
        $tick = [long]$sample.Groups['tick'].Value
        if ($tick -lt $previous -or $tick - $previous -gt 500) { throw 'Recovery observations missing or stalled (maximum gap 500ms)' }
        if ($sample.Groups['dead'].Value -ne 'false') { throw 'Recovery fixture died' }
        if ($sample.Groups['defeated'].Value -eq 'true' -and $sample.Groups['pacified'].Value -eq 'true') {
            $lastDefeated = $tick
        } elseif ($sample.Groups['defeated'].Value -eq 'false' -and $sample.Groups['pacified'].Value -eq 'false' -and $null -ne $lastDefeated) {
            $recovered = $tick
            break
        } else { throw 'Recovery state inconsistent or yield never observed' }
        $previous = $tick
    }
    if ($null -eq $recovered) { throw 'No native automatic recovery transition' }
    $rescues = [regex]::Matches($Log, ($id + ' \([^\r\n]*\) has been rescued'))
    if ($rescues.Count -ne 1 -or $rescues[0].Index -le $entry[0].Index -or $rescues[0].Index -ge $sample.Index) { throw 'Expected one rescue completion between defeat and cleared flags' }
    $elapsed = $recovered - $start
    if ($lastDefeated - $start -lt $Seconds * 1000 - 500 -or $elapsed -gt $Seconds * 1000 + 500) { throw "Automatic recovery outside ${Seconds}s +/- 500ms" }
    [pscustomobject]@{ requestedSeconds=$Seconds; toleranceMs=500; hitTickMs=$start; lastDefeatedTickMs=$lastDefeated; recoveredTickMs=$recovered; elapsedMs=$elapsed }
}
