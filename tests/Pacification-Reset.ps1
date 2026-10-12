param([string] $RunId, [string] $RunDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Pacification-Fixture.ps1')
$player='0x00000014';$actor='0x000E66FB';$homeMarker=$null;$available=$false;$summary.actorCleaned=$false
try {
    # Verified persistent Riften guard; its NPC base has Respawn. Nazeem lacks that flag.
    $deadline=(Get-Date).AddSeconds(15)
    do {
        $original=(Invoke-YieldTool inspect @{kind='refs';formId=$actor}).refs | Select-Object -First 1
        if($original) {break};Start-Sleep -Milliseconds 100
    } while((Get-Date) -lt $deadline)
    if(-not $original -or $original.base.formId -ne '0x000E66F6' -or $original.actor.alive -ne $true) {throw 'Vanilla reset actor fixture mismatch'}
    $available=$true
    $aggression=(Invoke-NpcPapyrus Actor GetActorValue $actor @('Aggression')).returned
    $homeMarker=(Invoke-NpcPapyrus ObjectReference PlaceAtMe $actor @(@{form='0x0000003B'},1,$true,$false)).returned.formId
    if($homeMarker -notmatch '^0xFF[0-9A-Fa-f]{6}$') {throw 'Owned home marker missing'}
    Invoke-NpcPapyrus Actor EnableAI $actor @($false) | Out-Null
    Invoke-NpcPapyrus ObjectReference MoveTo $actor @(@{form=$player},-120.0,-85.0,0.0,$false) | Out-Null
    $deadline=(Get-Date).AddSeconds(5)
    do {
        if((Invoke-NpcPapyrus ObjectReference Is3DLoaded $actor).returned) {break}
    } while((Get-Date) -lt $deadline)
    Invoke-NpcPapyrus Actor StopCombat $player | Out-Null
    Invoke-NpcPapyrus Acheron BeginPeacefulState '' @(@{form=$actor},30) | Out-Null
    Invoke-NpcPapyrus Actor EnableAI $actor @($true) | Out-Null
    $state=Wait-PeacefulPhase $actor 2
    $start=(Get-Content $logPath -Raw).Length
    $reset=Invoke-YieldTool papyrus @{action='call';script='ObjectReference';function='Reset';self=@{form=$actor};args=@();fillNeutral=$true}
    if($reset.called -ne $true) {throw 'Reset not executed'}
    $deadline=(Get-Date).AddSeconds(5)
    do {
        $active=(Invoke-NpcPapyrus Acheron IsPeacefulState '' @(@{form=$actor})).returned
        if(-not $active) {break}
    } while((Get-Date) -lt $deadline)
    if($active) {
        $summary.failedReset=@{state=(Read-PeacefulState $actor);actor=(Invoke-YieldTool inspect @{kind='refs';formId=$actor}).refs[0];reset=$reset}
        throw 'Vanilla actor reset did not release controller'
    }
    Invoke-NpcPapyrus Actor EnableAI $actor @($false) | Out-Null
    Assert-PeacefulReleased $actor $aggression
    $summary.reset=@{original=$original;state=$state;log=(Get-Content $logPath -Raw).Substring($start)}
    return @{message='PASS: vanilla actor reset releases owned state';screenshot=$null}
} finally {
    if($available -and (Invoke-NpcPapyrus Acheron IsPeacefulState '' @(@{form=$actor})).returned) {Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$actor}) | Out-Null}
    if($homeMarker) {
        Invoke-NpcPapyrus ObjectReference MoveTo $actor @(@{form=$homeMarker},0.0,0.0,0.0,$false) | Out-Null
        Invoke-NpcPapyrus Actor EnableAI $actor @($true) | Out-Null
        Invoke-NpcPapyrus ObjectReference Disable $homeMarker @($false) | Out-Null
        Invoke-NpcPapyrus ObjectReference Delete $homeMarker | Out-Null
    }
    $summary.actorCleaned=$true
}
