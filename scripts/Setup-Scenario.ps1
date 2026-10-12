param([string] $RunId, [string] $RunDirectory, [switch] $WithFollower)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../tests/Npc-Papyrus.ps1')
$player='0x00000014';$owned=@();$summary.actors=@();$summary.actorCleaned=$false;$summary.scenarioReady=$false
try {
    # shortcut: toggle once in a fresh session; use a state-aware setter if setups reuse a running world.
    Invoke-YieldTool console @{action='exec';command='tgm'} | Out-Null
    $summary.godModeRequested=$true
    $hunter=(Invoke-NpcPapyrus Game GetFormFromFile '' @(0x807,'Acheron.esm')).returned.formId
    $effect=(Invoke-NpcPapyrus Game GetFormFromFile '' @(0x806,'Acheron.esm')).returned.formId
    if($hunter -notmatch '807$' -or $effect -notmatch '806$') {throw 'Hunter Pride forms missing'}
    # Script-attached perks omit IDs in DevBench returns; use the verified spell mapping.
    $perk=$hunter -replace '807$','803'
    Invoke-NpcPapyrus Actor AddPerk $player @(@{form=$perk}) | Out-Null
    if((Invoke-NpcPapyrus Actor HasPerk $player @(@{form=$perk})).returned -ne $true) {throw 'Interaction perk missing'}
    Invoke-NpcPapyrus Actor AddSpell $player @(@{form=$hunter},$false) | Out-Null
    $deadline=(Get-Date).AddSeconds(5)
    do {$active=(Invoke-NpcPapyrus Actor HasMagicEffect $player @(@{form=$effect})).returned} while($active -ne $true -and (Get-Date) -lt $deadline)
    if($active -ne $true) {throw 'Hunter Pride inactive'}
    Invoke-YieldTool camera @{action='freecam';on=$false} | Out-Null
    Invoke-NpcPapyrus ObjectReference SetAngle $player @(0.0,0.0,180.0) | Out-Null
    # Local draws only: same spawn/check calls, no in-game search or leveled-list expansion.
    $selectionWatch=[Diagnostics.Stopwatch]::StartNew()
    $yieldEnemyBase=Get-Random -InputObject @('0x00043BE1','0x00043BE0','0x00043BE2')
    $roles=@(@{role='enemy';base=$yieldEnemyBase;label='Test Enemy (Female Forsworn copy)';x=0.0;y=-220.0})
    if($WithFollower) {
        $follower=Get-Random -InputObject @(
            @{base='0x000A2C8E';name='Lydia'},
            @{base='0x000A2C8F';name='Jordis'},
            @{base='0x000A2C91';name='Iona'},
            @{base='0x000A2C90';name='Calder'},
            @{base='0x000A2C8C';name='Argis'}
        )
        $roles+=@{role='follower';base=$follower.base;label="Test Follower ($($follower.name) copy)";x=120.0;y=-100.0}
    }
    $selectionWatch.Stop()
    $summary.actorSelectionMilliseconds=$selectionWatch.Elapsed.TotalMilliseconds
    foreach($role in $roles) {
        $before=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
        $spawn=(Invoke-NpcPapyrus ObjectReference PlaceAtMe $player @(@{form=$role.base},1,$true,$true)).returned
        $after=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
        $actor=Resolve-NpcSpawn $before $after $role.base $spawn.formId
        $owned+=$actor
        Invoke-NpcPapyrus Actor SetGhost $actor @($true) | Out-Null
        Invoke-NpcPapyrus Actor EnableAI $actor @($false) | Out-Null
        Invoke-NpcPapyrus ObjectReference MoveTo $actor @(@{form=$player},$role.x,$role.y,0.0,$false) | Out-Null
        if((Invoke-NpcPapyrus ObjectReference SetDisplayName $actor @($role.label,$true)).returned -ne $true) {throw 'Scenario label did not apply'}
        if($role.role -eq 'follower') {
            Invoke-NpcPapyrus Actor SetFactionRank $actor @(@{form='0x00000DB1'},0) | Out-Null
            Invoke-NpcPapyrus Actor SetPlayerTeammate $actor @($true,$false) | Out-Null
            Invoke-NpcPapyrus Actor SetActorValue $actor @('Aggression',1.0) | Out-Null
        }
        Invoke-NpcPapyrus ObjectReference Enable $actor @($false) | Out-Null
        $deadline=(Get-Date).AddSeconds(5)
        do {$loaded=(Invoke-NpcPapyrus ObjectReference Is3DLoaded $actor).returned} while($loaded -ne $true -and (Get-Date) -lt $deadline)
        if($loaded -ne $true) {throw 'Scenario actor did not load'}
        $equipment=@{}
        if($role.role -eq 'enemy') {
            $equipment=Set-NpcEnemyEquipment $actor
        }
        $teammate=(Invoke-NpcPapyrus Actor IsPlayerTeammate $actor).returned
        $hostile=(Invoke-NpcPapyrus Actor IsHostileToActor $actor @(@{form=$player})).returned
        if($teammate -ne ($role.role -eq 'follower') -or $hostile -ne ($role.role -eq 'enemy') -or
           (Invoke-NpcPapyrus Actor IsDead $actor).returned -ne $false -or
           (Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$actor})).returned -ne $false) {throw 'Scenario actor role or starting state incorrect'}
        $summary.actors+=@{role=$role.role;formId=$actor;base=$role.base;label=$role.label;teammate=$teammate;hostileToPlayer=$hostile;equipment=$equipment}
    }
    foreach($actor in $owned) {
        Invoke-NpcPapyrus Actor EnableAI $actor @($true) | Out-Null
        Invoke-NpcPapyrus Actor SetGhost $actor @($false) | Out-Null
    }
    $summary.scenarioReady=$true
    return @{message='READY: disposable actors spawned; normal combat AI enabled; game left open';screenshot=$null}
} finally {
    if(-not $summary.scenarioReady) {
        foreach($actor in $owned) {
            Invoke-NpcPapyrus ObjectReference Disable $actor @($false) | Out-Null
            Invoke-NpcPapyrus ObjectReference Delete $actor | Out-Null
        }
        $summary.actorCleaned=$true
    }
}
