param([string] $RunId, [string] $RunDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Pacification-Fixture.ps1')
$player='0x00000014'; $owned=[Collections.Generic.List[string]]::new()
$summary.testCommands=@(); $summary.actorCleaned=$false
$animationLog=Join-Path (Split-Path -Parent $PrefsPath) 'SKSE\OpenAnimationReplacer.log'
function New-TestActor([string] $Base, [double] $X) {
    $before=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
    $spawn=(Invoke-NpcPapyrus ObjectReference PlaceAtMe $player @(@{form=$Base},1,$true,$true)).returned
    $after=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
    $id=Resolve-NpcSpawn $before $after $Base $spawn.formId; $owned.Add($id)
    Invoke-NpcPapyrus Actor EnableAI $id @($false) | Out-Null
    Invoke-NpcPapyrus ObjectReference MoveTo $id @(@{form=$player},$X,-150.0,0.0,$false) | Out-Null
    Invoke-NpcPapyrus ObjectReference Enable $id @($false) | Out-Null
    $deadline=(Get-Date).AddSeconds(5)
    do {$loaded=(Invoke-NpcPapyrus ObjectReference Is3DLoaded $id).returned} while(-not $loaded -and (Get-Date) -lt $deadline)
    if(-not $loaded) {throw 'Test dialogue fixture did not load'}
    if($Base -eq $yieldEnemyBase) {Set-NpcEnemyEquipment $id | Out-Null}
    Invoke-NpcPapyrus Actor SetActorValue $id @('Health',10000.0) | Out-Null
    Invoke-NpcPapyrus Actor SetActorValue $id @('HealRate',0.0) | Out-Null
    Invoke-NpcPapyrus Actor SetActorValue $id @('HealRateMult',0.0) | Out-Null
    return $id
}
function Choose-Test([int] $Command, [string] $Label) {
    $root=if((Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$actor})).returned) {0x836}else{0x837}
    if($root -eq 0x836) {
        $blank=(Invoke-NpcPapyrus Game GetFormFromFile '' @(0x804,'Acheron.esm')).returned.formId
        $deadline=(Get-Date).AddSeconds(8)
        do {
            $bleeding=(Get-Content $animationLog -Raw).Substring($script:yieldLogStart) -match 'AnimationLogEntry:.*BleedOut_Idle\.hkx'
            $package=(Invoke-NpcPapyrus Actor GetCurrentPackage $actor).returned.formId
        } while(((-not $bleeding) -or $package -ne $blank) -and (Get-Date) -lt $deadline)
        if(-not $bleeding -or $package -ne $blank) {throw 'Yielding native animation/package did not settle before dialogue'}
    }
    $deadline=(Get-Date).AddSeconds(5)
    do {$open=(Read-PeacefulDialogue $actor).menuOpen} while($open -and (Get-Date) -lt $deadline)
    if($open) {throw 'Previous Test dialogue did not finish closing'}
    if($Command -eq 2) {$script:yieldLogStart=(Get-Content $animationLog -Raw).Length}
    Select-PeacefulDialogueChoice $actor 'Test' $root $RunId | Out-Null
    $script:commandLogStart=(Get-Content $animationLog -Raw).Length
    $selection=Select-PeacefulDialogueChoice $actor $Label (0x839+2*$Command) $RunId -AlreadyOpen
    $summary.testCommands+=@{actor=$actor;command=$Command;label=$Label;selection=$selection}
}
function Wait-TestMovement {
    $deadline=(Get-Date).AddSeconds(8)
    do {$log=(Get-Content $animationLog -Raw).Substring($script:commandLogStart)} while($log -notmatch 'AnimationLogEntry:.*MT_(Idle|Walk|Run)' -and (Get-Date) -lt $deadline)
    if($log -notmatch 'AnimationLogEntry:.*MT_(Idle|Walk|Run)') {throw 'Native transition did not return to locomotion before next dialogue'}
}
function Assert-TestPose([int] $Phase, [int] $Variant, [string] $Clip, [int] $Start) {
    $state=Wait-PeacefulPhase $actor $Phase 20
    if($state.commandHoldRemaining -lt 1770 -or ($Phase -eq 3 -and $state.selectedKneelingVariant -ne $Variant)) {throw 'Explicit Test pose/timer incorrect'}
    $deadline=(Get-Date).AddSeconds(3)
    do {$log=(Get-Content $animationLog -Raw).Substring($Start)} while($log -notmatch ('AnimationLogEntry:.*'+$Clip+'\.hkx') -and (Get-Date) -lt $deadline)
    if($log -notmatch ('AnimationLogEntry:.*'+$Clip+'\.hkx')) {throw "Explicit Test animation missing: $Clip"}
    if(-not (Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$actor})).returned -or
       (Invoke-NpcPapyrus Actor GetActorValue $actor @('Health')).returned -ne $health) {throw 'Test pose lost pacification or changed health'}
    $summary.testCommands[-1].state=$state
}
try {
    Invoke-YieldTool camera @{action='freecam';on=$false} | Out-Null
    Invoke-NpcPapyrus Actor SetActorValue $player @('Health',100000.0) | Out-Null
    $perk=(Invoke-NpcPapyrus Game GetFormFromFile '' @(0x803,'Acheron.esm')).returned.formId
    Invoke-NpcPapyrus Actor AddPerk $player @(@{form=$perk}) | Out-Null
    $actor=New-TestActor $yieldEnemyBase 0
    Invoke-NpcPapyrus Actor EnableAI $actor @($true) | Out-Null
    Invoke-YieldTool menu @{action='open';name='Console'} | Out-Null
    Invoke-YieldTool console @{action='exec';command=('prid '+($actor -replace '^0x',''));capture=$true} | Out-Null
    Invoke-YieldTool menu @{action='close';name='Console'} | Out-Null
    $script:yieldLogStart=(Get-Content $animationLog -Raw).Length
    Invoke-NpcPapyrus Acheron DefeatActor '' @(@{form=$actor}) | Out-Null
    $health=(Invoke-NpcPapyrus Actor GetActorValue $actor @('Health')).returned
    foreach($pose in @(@{command=5;label='Kneel (Regular)';variant=0;clip='IdleKneelIdle'},@{command=6;label='Kneel (Blessing)';variant=1;clip='IdleBlessingKneel_Loop'},@{command=7;label='Kneeling bound';variant=0;clip='AOBoundKneesIdle'})) {
        $start=(Get-Content $animationLog -Raw).Length
        Choose-Test $pose.command $pose.label
        Assert-TestPose $(if($pose.command -eq 7){4}else{3}) $pose.variant $pose.clip $start
    }
    # Bound -> exact regular bypasses the ordinary Bind/Resume restrictions.
    $start=(Get-Content $animationLog -Raw).Length
    Choose-Test 5 'Kneel (Regular)'; Assert-TestPose 3 0 'IdleKneelIdle' $start
    Choose-Test 2 'Yielding'
    $deadline=(Get-Date).AddSeconds(15)
    do {$defeated=(Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$actor})).returned} while(-not $defeated -and (Get-Date) -lt $deadline)
    if(-not $defeated) {throw 'Test Yielding failed'}
    Choose-Test 4 'Wandering'; $summary.testWander=Wait-PeacefulPhase $actor 2 15
    Wait-TestMovement
    Choose-Test 0 'Normal'
    $deadline=(Get-Date).AddSeconds(5)
    do {$active=(Invoke-NpcPapyrus Acheron IsPeacefulState '' @(@{form=$actor})).returned} while($active -and (Get-Date) -lt $deadline)
    if($active -or (Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$actor})).returned) {throw 'Test Normal retained ownership'}
    $script:yieldLogStart=(Get-Content $animationLog -Raw).Length
    Invoke-NpcPapyrus Acheron DefeatActor '' @(@{form=$actor}) | Out-Null
    Choose-Test 1 'Combat'
    Wait-TestMovement
    $deadline=(Get-Date).AddSeconds(5)
    do {$combat=(Invoke-NpcPapyrus Actor IsInCombat $actor).returned} while(-not $combat -and (Get-Date) -lt $deadline)
    if(-not $combat) {throw 'Test Combat did not start combat'}
    # Combat is not a talkable source. Use a fresh fixture for the next source,
    # rather than adding an unrelated synthetic-combat -> DefeatActor prerequisite.
    Invoke-NpcPapyrus Actor StopCombat $actor | Out-Null
    Invoke-NpcPapyrus ObjectReference Disable $actor @($false) | Out-Null
    Invoke-NpcPapyrus Actor StopCombat $player | Out-Null
    $actor=New-TestActor $yieldEnemyBase 0
    Invoke-NpcPapyrus Actor EnableAI $actor @($true) | Out-Null
    Invoke-YieldTool menu @{action='open';name='Console'} | Out-Null
    Invoke-YieldTool console @{action='exec';command=('prid '+($actor -replace '^0x',''));capture=$true} | Out-Null
    Invoke-YieldTool menu @{action='close';name='Console'} | Out-Null
    $script:yieldLogStart=(Get-Content $animationLog -Raw).Length
    Invoke-NpcPapyrus Acheron DefeatActor '' @(@{form=$actor}) | Out-Null
    $enemy=New-TestActor $yieldEnemyBase 350; $guard=New-TestActor '0x000D3154' 450
    foreach($id in @($enemy,$guard)) {Invoke-NpcPapyrus Actor EnableAI $id @($true) | Out-Null}
    Invoke-NpcPapyrus Actor StartCombat $guard @(@{form=$enemy}) | Out-Null
    Invoke-NpcPapyrus Actor StartCombat $enemy @(@{form=$guard}) | Out-Null
    Choose-Test 3 'Avoiding combat'; $summary.testAvoid=Wait-PeacefulPhase $actor 1 15
    Wait-TestMovement
    Choose-Test 3 'Avoiding combat'; $summary.testAvoidRepeat=Wait-PeacefulPhase $actor 1 15
    foreach($id in @($enemy,$guard)) {Invoke-NpcPapyrus Actor StopCombat $id | Out-Null; Invoke-NpcPapyrus ObjectReference Disable $id @($false) | Out-Null}
    Invoke-NpcPapyrus Actor StopCombat $player | Out-Null
    $summary.combatEnded=Wait-PeacefulPhase $actor 2 15
    Choose-Test 8 'Dead (kill NPC)'
    $deadline=(Get-Date).AddSeconds(5)
    do {$dead=(Invoke-NpcPapyrus Actor IsDead $actor).returned} while(-not $dead -and (Get-Date) -lt $deadline)
    if(-not $dead) {throw 'Test Dead did not kill disposable NPC'}
    $summary.testDead=$dead
    @{message='PASS: native Test tree, deterministic poses and engine/peaceful destinations';screenshot=$null}
} finally {
    foreach($id in $owned) {
        Invoke-NpcPapyrus ObjectReference Disable $id @($false) | Out-Null
        Invoke-NpcPapyrus ObjectReference Delete $id | Out-Null
    }
    $summary.actorCleaned=$true
}
