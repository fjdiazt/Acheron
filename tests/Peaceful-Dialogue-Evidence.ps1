function Assert-PeacefulDialogueChoice($Snapshot, [string] $ActorId, [string] $Text = 'Continue.') {
    if($Snapshot.actor -ne $ActorId -or $Snapshot.speaker -ne $ActorId -or
       $Snapshot.menuOpen -ne $true -or $Snapshot.questStopped -ne $false -or
       $Snapshot.canTalk -ne $true -or $Snapshot.goodbye -ne $false -or
       $Snapshot.greeting -ne $false -or $Snapshot.speaking -ne $false -or $Snapshot.fadedIn -ne $true -or
       $Snapshot.visible -ne $true -or $Snapshot.menuState -ne 1 -or $Snapshot.allowProgress -ne $true) {
        throw 'Native dialogue choices not ready for expected speaker'
    }
    $choices=@($Snapshot.choices | Where-Object {$_.text -ceq $Text})
    if($choices.Count -ne 1) {throw "Expected exactly one selectable $Text choice"}
    foreach($value in @($Snapshot.selectedIndex,$choices[0].row,$choices[0].topicIndex)) {
        if($null -eq $value -or $value -isnot [ValueType] -or $value -is [bool] -or
           -not [double]::IsFinite([double]$value) -or [math]::Truncate([double]$value) -ne $value -or $value -lt 0 -or $value -gt 255) {
            throw 'Invalid native dialogue index'
        }
    }
    if($choices[0].row -ge @($Snapshot.choices).Count -or $Snapshot.selectedIndex -ge @($Snapshot.choices).Count) {throw 'Dialogue index outside visible choices'}
    return $choices[0]
}
function Assert-PeacefulTopicSelected([string] $Log, [string] $ActorId, [string] $InfoId) {
    $pattern='\[PeacefulTopic\] actor='+[regex]::Escape(($ActorId -replace '^0x',''))+' info='+[regex]::Escape(($InfoId -replace '^0x',''))+' begin=true'
    $match=[regex]::Match($Log,$pattern,[Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if(-not $match.Success) {throw 'Expected dialogue INFO did not execute for expected speaker'}
    return $match.Value
}
