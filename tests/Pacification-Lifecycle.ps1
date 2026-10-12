param([string] $RunId, [string] $RunDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Pacification-Fixture.ps1')
$player='0x00000014';$owned=@();$summary.actorCleaned=$false
try {
    foreach($role in @('subject','other')) {
        $id=(Invoke-NpcPapyrus ObjectReference PlaceAtMe $player @(@{form=$yieldEnemyBase},1,$true,$false)).returned.formId
        if($id -notmatch '^0xFF[0-9a-fA-F]{6}$') {throw 'Disposable lifecycle actor missing'}
        $owned+=$id;Set-Variable $role $id
        Invoke-NpcPapyrus Actor EnableAI $id @($false) | Out-Null
        Set-NpcEnemyEquipment $id | Out-Null
        Invoke-NpcPapyrus ObjectReference MoveTo $id @(@{form=$player},-120.0,-85.0,0.0,$false) | Out-Null
        Invoke-NpcPapyrus Actor StopCombat $id | Out-Null
    }
    Invoke-NpcPapyrus Actor StopCombat $player | Out-Null
    $ability=(Invoke-NpcPapyrus Game GetFormFromFile '' @(0x807,'Acheron.esm')).returned.formId
    if($ability -notmatch '807$') {throw 'Unexpected MCM quest mapping'}
    $mcm=$ability -replace '807$','800'
    $duration=(Invoke-NpcPapyrus AcheronMCM GetSettingInt $mcm @('iPeacefulWanderDuration')).returned
    try {
        foreach($case in @(@(0,1),@(999,600),@(60,60))) {
            Invoke-NpcPapyrus AcheronMCM SetSettingInt $mcm @('iPeacefulWanderDuration',$case[0]) | Out-Null
            if((Invoke-NpcPapyrus AcheronMCM GetSettingInt $mcm @('iPeacefulWanderDuration')).returned -ne $case[1]) {throw 'MCM duration clamp failed'}
        }
    } finally {Invoke-NpcPapyrus AcheronMCM SetSettingInt $mcm @('iPeacefulWanderDuration',$duration) | Out-Null}
    $aggression=(Invoke-NpcPapyrus Actor GetActorValue $subject @('Aggression')).returned
    $otherAggression=(Invoke-NpcPapyrus Actor GetActorValue $other @('Aggression')).returned
    foreach($invalid in @(0,601)) {
        if((Invoke-NpcPapyrus Acheron BeginPeacefulState '' @(@{form=$subject},$invalid)).returned -ne $false) {throw 'Invalid duration accepted'}
    }
    if((Invoke-NpcPapyrus Acheron BeginPeacefulState '' @(@{form=$player},30)).returned -ne $false) {throw 'Player accepted'}
    Invoke-NpcPapyrus Actor SetPlayerTeammate $subject @($true,$false) | Out-Null
    if((Invoke-NpcPapyrus Acheron BeginPeacefulState '' @(@{form=$subject},30)).returned -ne $false) {throw 'Follower accepted'}
    Invoke-NpcPapyrus Actor SetPlayerTeammate $subject @($false,$false) | Out-Null
    Invoke-NpcPapyrus Acheron PacifyActor '' @(@{form=$subject}) | Out-Null
    Invoke-NpcPapyrus Acheron BeginPeacefulState '' @(@{form=$subject},30) | Out-Null
    if((Invoke-NpcPapyrus Acheron IsPeacefulState '' @(@{form=$subject})).returned -or
       (Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$subject})).returned -ne $true) {throw 'Foreign pacification acquired/released'}
    Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$subject}) | Out-Null
    foreach($id in $owned) {
        Invoke-NpcPapyrus Acheron BeginPeacefulState '' @(@{form=$id},30) | Out-Null
        Invoke-NpcPapyrus Actor EnableAI $id @($true) | Out-Null
    }
    $initial=Wait-PeacefulPhase $subject 2;$second=Wait-PeacefulPhase $other 2
    if($initial.anchor -eq $second.anchor -or $initial.goal -eq $second.goal) {throw 'Same-base actors share markers'}
    Invoke-NpcPapyrus Acheron BeginPeacefulState '' @(@{form=$subject},40) | Out-Null
    $refreshed=Read-PeacefulState $subject
    if($refreshed.anchor -ne $initial.anchor -or $refreshed.goal -ne $initial.goal -or
       $refreshed.generation -le $initial.generation -or $refreshed.remaining -lt 38) {throw 'Refresh stacked effects or failed to refresh timer'}
    $summary.refresh=@{before=$initial;after=$refreshed;other=$second}
    Invoke-NpcPapyrus Acheron DefeatActor '' @(@{form=$subject}) | Out-Null
    Invoke-NpcPapyrus Actor EnableAI $subject @($false) | Out-Null
    Assert-PeacefulReleased $subject $aggression $true
    if((Invoke-NpcPapyrus Acheron IsPeacefulState '' @(@{form=$other})).returned -ne $true) {throw 'One actor exit removed another owner'}
    Invoke-NpcPapyrus Acheron RescueActor '' @(@{form=$subject},$true) | Out-Null
    Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$other}) | Out-Null
    Invoke-NpcPapyrus Actor EnableAI $other @($false) | Out-Null
    Assert-PeacefulReleased $other $otherAggression
    Invoke-NpcPapyrus Acheron BeginPeacefulState '' @(@{form=$other},30) | Out-Null
    Invoke-NpcPapyrus Actor EnableAI $other @($true) | Out-Null
    Wait-PeacefulPhase $other 2 | Out-Null
    Invoke-NpcPapyrus Actor Kill $other @(@{form=$player}) | Out-Null
    if((Invoke-NpcPapyrus Actor IsDead $other).returned -ne $true) {throw 'Death fixture did not die'}
    Assert-PeacefulReleased $other $otherAggression
    return @{message='PASS: eligibility, foreign ownership, refresh, actor isolation, re-defeat and death';screenshot=$null}
} finally {
    foreach($id in $owned) {
        if((Invoke-NpcPapyrus Acheron IsPeacefulState '' @(@{form=$id})).returned) {Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$id}) | Out-Null}
        if((Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$id})).returned) {Invoke-NpcPapyrus Acheron RescueActor '' @(@{form=$id},$true) | Out-Null}
        Invoke-NpcPapyrus ObjectReference Disable $id @($false) | Out-Null
        Invoke-NpcPapyrus ObjectReference Delete $id | Out-Null
    }
    $summary.actorCleaned=$true
}
