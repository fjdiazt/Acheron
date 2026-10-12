function Assert-YieldDefeatEvidence([string] $Log, [string] $ActorId, [bool] $Dead, [bool] $Defeated, [bool] $Pacified, [double] $Health, [string] $SourceId = '0x00000014') {
    $id = $ActorId -replace '^0x',''
    $number = '[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?'
    $pattern = '\[YieldTest\] target=' + [regex]::Escape($id) + ' source=' + [regex]::Escape(($SourceId -replace '^0x','')) + ' health=(?<hp>' + $number + ') damage=(?<damage>' + $number + ') lethal=true defeated=true pacified=true registered=true'
    $hits = [regex]::Matches($Log, $pattern)
    if ($hits.Count -ne 1) { throw 'Expected exactly one registered lethal source hit on owned target' }
    $hp = [double]::Parse($hits[0].Groups['hp'].Value, [Globalization.CultureInfo]::InvariantCulture)
    $damage = [double]::Parse($hits[0].Groups['damage'].Value, [Globalization.CultureInfo]::InvariantCulture)
    if ($hp -le 0 -or $damage -lt $hp) { throw 'Native hook damage was not lethal' }
    if ($Dead -or -not $Defeated -or -not $Pacified -or -not [double]::IsFinite($Health) -or $Health -le 0) { throw 'Target did not remain alive, defeated and pacified' }
}
