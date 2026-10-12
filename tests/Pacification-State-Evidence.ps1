function Measure-PeacefulExpiry([string] $Log, [string] $ActorId, [int] $Seconds) {
    $id = $ActorId -replace '^0x',''
    $pattern = '\[PeacefulState\] actor=' + [regex]::Escape($id) + ' phase=(?<phase>\d+) remaining=(?<remaining>[0-9.eE+-]+) generation=(?<generation>\d+) tickMs=(?<tick>\d+)'
    $events = @([regex]::Matches($Log,$pattern))
    if ($events.Count -ne 2 -or $events[0].Groups['phase'].Value -ne '2' -or $events[1].Groups['phase'].Value -ne '0') { throw 'Expected one native wandering entry and expiry' }
    if ($events[0].Groups['generation'].Value -ne $events[1].Groups['generation'].Value) { throw 'Peaceful generation changed before expiry' }
    if ([double]$events[0].Groups['remaining'].Value -ne $Seconds -or [double]$events[1].Groups['remaining'].Value -ne 0) { throw 'Peaceful expiry was not timer driven' }
    $elapsed = [long]$events[1].Groups['tick'].Value - [long]$events[0].Groups['tick'].Value
    if ([math]::Abs($elapsed - $Seconds*1000) -gt 500) { throw "Peaceful expiry outside 500ms tolerance: ${elapsed}ms" }
    return @{ actor=$ActorId; seconds=$Seconds; elapsedMs=$elapsed }
}
