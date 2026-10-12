param([string] $RunId, [string] $RunDirectory, [switch] $BindOnly)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Pacification-Fixture.ps1')
. (Join-Path $PSScriptRoot 'Npc-Defeat-Evidence.ps1')
$player='0x00000014'; $owned=[Collections.Generic.List[string]]::new()
$summary.actorCleaned=$false; $summary.kneeling=@()
$worldStart=(Get-Content $logPath -Raw).Length
function New-KneelingActor([string] $Base, [double] $X) {
    $before=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
    $spawn=(Invoke-NpcPapyrus ObjectReference PlaceAtMe $player @(@{form=$Base},1,$true,$true)).returned
    $after=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
    $id=Resolve-NpcSpawn $before $after $Base $spawn.formId
    $owned.Add($id)
    Invoke-NpcPapyrus Actor EnableAI $id @($false) | Out-Null
    Invoke-NpcPapyrus ObjectReference MoveTo $id @(@{form=$player},$X,-120.0,0.0,$false) | Out-Null
    Invoke-NpcPapyrus ObjectReference Enable $id @($false) | Out-Null
    $deadline=(Get-Date).AddSeconds(5)
    do {$loaded=(Invoke-NpcPapyrus ObjectReference Is3DLoaded $id).returned} while(-not $loaded -and (Get-Date) -lt $deadline)
    if(-not $loaded) {throw 'Kneeling fixture did not load'}
    if($Base -eq $yieldEnemyBase) {Set-NpcEnemyEquipment $id | Out-Null}
    Invoke-NpcPapyrus Actor SetActorValue $id @('Health',10000.0) | Out-Null
    Invoke-NpcPapyrus Actor SetActorValue $id @('HealRate',0.0) | Out-Null
    Invoke-NpcPapyrus Actor SetActorValue $id @('HealRateMult',0.0) | Out-Null
    Invoke-NpcPapyrus Actor SetActorValue $id @('Confidence',4.0) | Out-Null
    return $id
}
function Assert-Kneeling([string] $Actor, [string] $Entry, [double] $Health, [int] $LogStart) {
    # Capture travel before readiness now requires settled furniture occupancy.
    $deadline=(Get-Date).AddSeconds(5)
    do {$state=Read-PeacefulState $Actor} while($state.phase -ne 3 -and (Get-Date) -lt $deadline)
    if($state.phase -ne 3) {throw "Kneeling owner missing: $Entry"}
    $case=@{entry=$Entry;actor=$Actor;state=$state}
    $id=[regex]::Escape(($Actor -replace '^0x',''))
    $requests=[regex]::Matches((Get-Content $logPath -Raw).Substring($LogStart), "\[PeacefulPackage\] actor=$id generation=\d+ stage=request phase=(\d+)", 'IgnoreCase')
    $case.packageRequests=@($requests | ForEach-Object {[int]$_.Groups[1].Value})
    if($requests.Count -ne 1 -or $case.packageRequests[0] -ne 3) {throw "Kneeling must request only its target package: $Entry; phases=$($case.packageRequests -join ',')"}
    $entryPoint=[regex]::Match((Get-Content $logPath -Raw).Substring($LogStart), "\[PeacefulKneelEntry\] actor=$id bind=false x=(?<x>[-+0-9.eE]+) y=(?<y>[-+0-9.eE]+) z=(?<z>[-+0-9.eE]+)", 'IgnoreCase')
    if(-not $entryPoint.Success) {throw 'Command-time kneeling origin missing'}
    $Origin=@([double]$entryPoint.Groups['x'].Value,[double]$entryPoint.Groups['y'].Value,[double]$entryPoint.Groups['z'].Value)
    $case.origin=$Origin
    $marker=(Invoke-YieldTool inspect @{kind='refs';formId=$case.state.goal}).refs[0]
    if($Origin.Count -ne 3 -or $marker.position.Count -ne 3) {throw 'Kneeling position evidence missing'}
    $case.markerDistance=[math]::Sqrt([math]::Pow($marker.position[0]-$Origin[0],2)+[math]::Pow($marker.position[1]-$Origin[1],2)+[math]::Pow($marker.position[2]-$Origin[2],2))
    $case.markerRotation=$marker.rotation
    $summary.lastKneelingCheck=$case
    if($case.markerDistance -gt 1 -or [math]::Abs($marker.rotation[0]) -gt 0.001 -or [math]::Abs($marker.rotation[1]) -gt 0.001) {throw "Kneeling marker displaced/tilted: $Entry; distance=$($case.markerDistance); rotation=$($marker.rotation -join ',')"}
    $case.maximumTravel=0.0
    $deadline=(Get-Date).AddSeconds(12)
    do {
        $position=(Invoke-YieldTool inspect @{kind='refs';formId=$Actor}).refs[0].position
        if($position.Count -ne 3) {throw 'Kneeling movement evidence missing'}
        $distance=[math]::Sqrt([math]::Pow($position[0]-$Origin[0],2)+[math]::Pow($position[1]-$Origin[1],2)+[math]::Pow($position[2]-$Origin[2],2))
        $case.maximumTravel=[math]::Max($case.maximumTravel,$distance)
        $case.sitState=(Invoke-NpcPapyrus Actor GetSitState $Actor).returned
        $case.furniture=(Invoke-NpcPapyrus Actor GetFurnitureReference $Actor).returned.formId
        if($case.sitState -eq 3 -and $case.furniture -eq $case.state.goal) {break}
        Start-Sleep -Milliseconds 100
    } while((Get-Date) -lt $deadline)
    if($case.sitState -ne 3 -or $case.furniture -ne $case.state.goal) {throw "Native kneeling pose not acquired: $Entry"}
    if($case.maximumTravel -gt 10) {throw "Kneeling walked away before pose: $Entry; maximumTravel=$($case.maximumTravel)"}
    $case.base=(Invoke-NpcPapyrus ObjectReference GetBaseObject $case.furniture).returned.formId
    $expectedBase=if($case.state.selectedKneelingVariant -eq 1) {'0x000F11F1'}else{'0x000E8E4E'}
    if($case.base -ne $expectedBase) {throw 'Actor using wrong furniture pose'}
    $case.state=Wait-PeacefulPhase $Actor 3
    if($case.state.commandHoldRemaining -lt 1750 -or $case.state.commandHoldRemaining -gt 1800) {throw 'Separate 30-minute command hold timer missing'}
    $case.health=(Invoke-NpcPapyrus Actor GetActorValue $Actor @('Health')).returned
    $summary.lastKneelingCheck=$case
    if([math]::Abs($case.health-$Health) -gt 0.1 -or (Invoke-NpcPapyrus Actor IsDead $Actor).returned -or
       (Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$Actor})).returned -or
       -not (Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$Actor})).returned) {throw 'Kneeling healed, killed, or lost pacification'}
    Start-Sleep -Milliseconds 1500
    if((Invoke-NpcPapyrus Actor GetSitState $Actor).returned -ne 3 -or (Read-PeacefulState $Actor).phase -ne 3) {throw 'Kneeling was not held'}
    $summary.kneeling+=,$case
    return $case
}
function Read-KneelingChoice([string] $Actor, [string] $Text) {
    $deadline=(Get-Date).AddSeconds(8)
    do {
        $snapshot=Read-PeacefulDialogue $Actor
        try {$choice=Assert-PeacefulDialogueChoice $snapshot $Actor $Text; return @{snapshot=$snapshot;choice=$choice}} catch {}
        Start-Sleep -Milliseconds 100
    } while((Get-Date) -lt $deadline)
    throw "Talk choice unavailable: $Text"
}
function Wait-KneelingExit([string] $Actor) {
    $deadline=(Get-Date).AddSeconds(8)
    do {$sit=(Invoke-NpcPapyrus Actor GetSitState $Actor).returned} while($sit -ne 0 -and (Get-Date) -lt $deadline)
    if($sit -ne 0) {throw 'Actor remained stuck in kneeling furniture after release'}
}
function Select-DownedChoice([string] $Actor, [string] $Text, [int] $InfoOffset, [switch] $Interact) {
    if($Interact) {
        foreach($pitch in @(0,10,20,30,40,50,60,70)) {
            Invoke-NpcPapyrus ObjectReference SetAngle $player @([double]$pitch,0.0,180.0) | Out-Null
            $deadline=(Get-Date).AddMilliseconds(250)
            do {$pick=Read-PeacefulDialogue $Actor} while($pick.crosshair -ne $Actor -and (Get-Date) -lt $deadline)
            if($pick.crosshair -eq $Actor) {break}
        }
        if($pick.crosshair -ne $Actor) {throw 'Downed Interact crosshair did not acquire expected actor'}
        $summary.downedCrosshair=$pick
        Invoke-YieldTool input @{action='tap';device='keyboard';key='e';durationMs=50;owner=$RunId} | Out-Null
    } else {Invoke-NpcPapyrus ObjectReference Activate $Actor @(@{form=$player},$false) | Out-Null}
    $talk=Read-KneelingChoice $Actor $Text
    $summary.downedDialogue=$talk.snapshot
    $delta=[int]$talk.choice.row-[int]$talk.snapshot.selectedIndex
    $key=if($delta -lt 0) {'w'}else{'s'}
    for($i=0;$i -lt [math]::Abs($delta);$i++) {Invoke-YieldTool input @{action='tap';device='keyboard';key=$key;durationMs=50;owner=$RunId} | Out-Null}
    $selected=Read-KneelingChoice $Actor $Text
    if($selected.snapshot.selectedIndex -ne $selected.choice.row) {throw 'Wrong downed dialogue row selected'}
    if(-not (Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$Actor})).returned) {throw 'Talking released defeat before action selection'}
    $start=(Get-Content $logPath -Raw).Length
    Invoke-YieldTool input @{action='tap';device='keyboard';key='e';durationMs=50;owner=$RunId} | Out-Null
    $info=(Invoke-NpcPapyrus Game GetFormFromFile '' @($InfoOffset,'Acheron.esm')).returned.formId
    $deadline=(Get-Date).AddSeconds(5)
    do {
        try {return Assert-PeacefulTopicSelected ((Get-Content $logPath -Raw).Substring($start)) $Actor $info} catch {}
    } while((Get-Date) -lt $deadline)
    throw 'Downed dialogue action did not execute'
}
try {
    Invoke-YieldTool console @{action='exec';command='tgm'} | Out-Null
    Invoke-YieldTool camera @{action='freecam';on=$false} | Out-Null
    Draw-YieldPlayerWeapon
    $actor=New-KneelingActor $yieldEnemyBase -30
    $originalAggression=(Invoke-NpcPapyrus Actor GetActorValue $actor @('Aggression')).returned
    Invoke-YieldTool menu @{action='open';name='Console'} | Out-Null
    Invoke-YieldTool console @{action='exec';capture=$true;command=('prid '+($actor -replace '^0x',''))} | Out-Null
    Invoke-YieldTool menu @{action='close';name='Console'} | Out-Null
    $ability=(Invoke-NpcPapyrus Game GetFormFromFile '' @(0x807,'Acheron.esm')).returned.formId
    $perk=$ability -replace '807$','803'
    Invoke-NpcPapyrus Actor AddPerk $player @(@{form=$perk}) | Out-Null
    if(-not (Invoke-NpcPapyrus Actor HasPerk $player @(@{form=$perk})).returned) {throw 'Talk-label perk missing'}
    Invoke-NpcPapyrus Actor AddSpell $player @(@{form=$ability},$false) | Out-Null
    Invoke-NpcPapyrus ObjectReference SetAngle $player @(0.0,0.0,180.0) | Out-Null
    Invoke-NpcPapyrus ObjectReference MoveTo $actor @(@{form=$player},0.0,-85.0,0.0,$false) | Out-Null
    Invoke-NpcPapyrus Actor SetActorValue $actor @('Health',1.0) | Out-Null
    Invoke-NpcPapyrus Actor SetDontMove $actor @($true) | Out-Null
    Invoke-NpcPapyrus Actor EnableAI $actor @($true) | Out-Null
    $deadline=(Get-Date).AddSeconds(5)
    do {$drawn=(Invoke-NpcPapyrus Actor IsWeaponDrawn $player).returned} while(-not $drawn -and (Get-Date) -lt $deadline)
    if(-not $drawn) {throw 'Player weapon not drawn'}
    for($attempt=0;$attempt -lt 3;$attempt++) {
        Invoke-YieldTool input @{action='tap';device='keyboard';key='mouseLeft';durationMs=100;owner=$RunId} | Out-Null
        $deadline=(Get-Date).AddSeconds(3)
        do {$defeated=(Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$actor})).returned} while(-not $defeated -and (Get-Date) -lt $deadline)
        if($defeated) {break}
    }
    if(-not $defeated) {throw 'Yielding precondition missing'}
    $health=(Invoke-NpcPapyrus Actor GetActorValue $actor @('Health')).returned
    Assert-YieldDefeatEvidence (Get-Content $logPath -Raw) $actor (Invoke-NpcPapyrus Actor IsDead $actor).returned $defeated (Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$actor})).returned $health
    Invoke-NpcPapyrus Actor SheatheWeapon $player | Out-Null
    $start=(Get-Content $logPath -Raw).Length
    $summary.yieldDialogueSelection=Select-DownedChoice $actor 'On your knees.' 0x830 -Interact
    Invoke-NpcPapyrus Actor SetDontMove $actor @($false) | Out-Null
    $summary.fromYield=Assert-Kneeling $actor 'Yielding/native dialogue' $health $start
    if(-not $BindOnly) {
    Invoke-NpcPapyrus Acheron ResumePeacefulState '' @(@{form=$actor}) | Out-Null
    Wait-PeacefulPhase $actor 2 | Out-Null
    Wait-KneelingExit $actor
    Invoke-NpcPapyrus Actor EnableAI $actor @($false) | Out-Null
    Invoke-NpcPapyrus ObjectReference MoveTo $actor @(@{form=$player},0.0,-120.0,0.0,$false) | Out-Null
    Invoke-NpcPapyrus Actor EnableAI $actor @($true) | Out-Null
    Invoke-NpcPapyrus Actor SetDontMove $actor @($true) | Out-Null
    Invoke-NpcPapyrus ObjectReference Activate $actor @(@{form=$player},$false) | Out-Null
    $talk=Read-KneelingChoice $actor 'On your knees.'
    $delta=[int]$talk.choice.row-[int]$talk.snapshot.selectedIndex
    $key=if($delta -lt 0) {'w'}else{'s'}
    for($i=0;$i -lt [math]::Abs($delta);$i++) {Invoke-YieldTool input @{action='tap';device='keyboard';key=$key;durationMs=50;owner=$RunId} | Out-Null}
    $selected=Read-KneelingChoice $actor 'On your knees.'
    if($selected.snapshot.selectedIndex -ne $selected.choice.row) {throw 'Wrong kneeling dialogue row selected'}
    $start=(Get-Content $logPath -Raw).Length
    Invoke-YieldTool input @{action='tap';device='keyboard';key='e';durationMs=50;owner=$RunId} | Out-Null
    Invoke-NpcPapyrus Actor SetDontMove $actor @($false) | Out-Null
    $summary.fromWander=Assert-Kneeling $actor 'Wandering/dialogue' $health $start
    $info=(Invoke-NpcPapyrus Game GetFormFromFile '' @(0x81C,'Acheron.esm')).returned.formId
    $summary.dialogueSelection=Assert-PeacefulTopicSelected ((Get-Content $logPath -Raw).Substring($start)) $actor $info
    Invoke-NpcPapyrus ObjectReference Activate $actor @(@{form=$player},$false) | Out-Null
    $summary.kneelingDialogue=(Read-KneelingChoice $actor 'Continue.').snapshot
    $summary.bindAvailable=Assert-PeacefulDialogueChoice $summary.kneelingDialogue $actor 'Bind'
    Close-PeacefulDialogue $actor $RunId
    if((Invoke-NpcPapyrus Actor GetSitState $actor).returned -ne 3) {throw 'Dialogue broke kneeling pose'}
    Invoke-NpcPapyrus Acheron ResumePeacefulState '' @(@{form=$actor}) | Out-Null
    Wait-PeacefulPhase $actor 2 | Out-Null
    Wait-KneelingExit $actor
    $enemy=New-KneelingActor $yieldEnemyBase 30
    $guard=New-KneelingActor '0x000D3154' 80
    foreach($id in @($enemy,$guard)) {Invoke-NpcPapyrus Actor EnableAI $id @($true) | Out-Null}
    Invoke-NpcPapyrus Actor StartCombat $guard @(@{form=$enemy}) | Out-Null
    Invoke-NpcPapyrus Actor StartCombat $enemy @(@{form=$guard}) | Out-Null
    Wait-PeacefulPhase $actor 1 | Out-Null
    $start=(Get-Content $logPath -Raw).Length
    Invoke-NpcPapyrus Acheron KneelActor '' @(@{form=$actor}) | Out-Null
    $summary.fromAvoid=Assert-Kneeling $actor 'AvoidingCombat' $health $start
    foreach($id in @($enemy,$guard)) {
        Invoke-NpcPapyrus Actor EnableAI $id @($false) | Out-Null
        Invoke-NpcPapyrus Actor StopCombat $id | Out-Null
        Invoke-NpcPapyrus ObjectReference Disable $id @($false) | Out-Null
    }
    Invoke-NpcPapyrus Actor StopCombat $player | Out-Null
    Invoke-NpcPapyrus Acheron BeginPeacefulState '' @(@{form=$actor},2) | Out-Null
    $deadline=(Get-Date).AddSeconds(8)
    do {$active=(Invoke-NpcPapyrus Acheron IsPeacefulState '' @(@{form=$actor})).returned} while($active -and (Get-Date) -lt $deadline)
    if(-not $active -or (Read-PeacefulState $actor).phase -ne 3) {throw 'Wandering timer released kneeling owner'}
    }
    $summary.beforeBind=Read-PeacefulState $actor
    Invoke-NpcPapyrus ObjectReference Activate $actor @(@{form=$player},$false) | Out-Null
    $talk=Read-KneelingChoice $actor 'Bind'
    $delta=[int]$talk.choice.row-[int]$talk.snapshot.selectedIndex
    $key=if($delta -lt 0) {'w'}else{'s'}
    for($i=0;$i -lt [math]::Abs($delta);$i++) {Invoke-YieldTool input @{action='tap';device='keyboard';key=$key;durationMs=50;owner=$RunId} | Out-Null}
    $selected=Read-KneelingChoice $actor 'Bind'
    if($selected.snapshot.selectedIndex -ne $selected.choice.row) {throw 'Wrong Bind dialogue row selected'}
    $start=(Get-Content $logPath -Raw).Length
    $animationLog=Join-Path (Split-Path -Parent $PrefsPath) 'SKSE\OpenAnimationReplacer.log'
    $animationStart=(Get-Content $animationLog -Raw).Length
    $bindClock=[Diagnostics.Stopwatch]::StartNew()
    Invoke-YieldTool input @{action='tap';device='keyboard';key='e';durationMs=50;owner=$RunId} | Out-Null
    # Bind must finish furniture exit and re-entry; the controller permits 15 seconds for entry.
    $summary.bound=Wait-PeacefulPhase $actor 4 20
    $summary.bindElapsedSeconds=$bindClock.Elapsed.TotalSeconds
    $deadline=(Get-Date).AddSeconds(12)
    do {
        $sit=(Invoke-NpcPapyrus Actor GetSitState $actor).returned
        $furniture=(Invoke-NpcPapyrus Actor GetFurnitureReference $actor).returned.formId
        if($sit -eq 3 -and $furniture -eq $summary.bound.goal) {break}
    } while((Get-Date) -lt $deadline)
    $boundBase=(Invoke-NpcPapyrus Game GetFormFromFile '' @(0x822,'Acheron.esm')).returned.formId
    if($sit -ne 3 -or $furniture -ne $summary.bound.goal -or
       (Invoke-NpcPapyrus ObjectReference GetBaseObject $furniture).returned.formId -ne $boundBase) {throw 'Native bound kneeling pose not acquired'}
    $summary.boundClip=@((Get-Content $animationLog -Raw).Substring($animationStart) -split "`n" | Where-Object {$_ -match 'AnimationLogEntry:.*AOBoundKneesIdle\.hkx'}) | Select-Object -Last 1
    if(-not $summary.boundClip) {throw 'Bound kneeling animation clip missing'}
    $resetBudget=$summary.bound.commandHoldRemaining+$summary.bindElapsedSeconds
    if($resetBudget -lt 1798 -or $resetBudget -gt 1805 -or
       $summary.bound.remaining -ne $summary.beforeBind.remaining) {throw 'Bind did not restart only the command hold timer'}
    $info=(Invoke-NpcPapyrus Game GetFormFromFile '' @(0x820,'Acheron.esm')).returned.formId
    $summary.bindSelection=Assert-PeacefulTopicSelected ((Get-Content $logPath -Raw).Substring($start)) $actor $info
    Start-Sleep -Milliseconds 1500
    if((Invoke-NpcPapyrus Actor GetActorValue $actor @('Health')).returned -ne $health -or
       -not (Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$actor})).returned -or
       (Invoke-NpcPapyrus Actor GetSitState $actor).returned -ne 3) {throw 'Bound kneeling did not retain pose, health or pacification'}
    Invoke-NpcPapyrus ObjectReference Activate $actor @(@{form=$player},$false) | Out-Null
    $summary.boundDialogue=(Read-KneelingChoice $actor 'Continue.').snapshot
    if(@($summary.boundDialogue.choices | Where-Object {$_.text -in @('Bind','On your knees.')}).Count) {throw 'Bound dialogue offers binding or silent unbinding again'}
    Close-PeacefulDialogue $actor $RunId
    if((Invoke-NpcPapyrus Actor GetSitState $actor).returned -ne 3) {throw 'Dialogue broke bound kneeling pose'}
    Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$actor}) | Out-Null
    Wait-KneelingExit $actor
    if((Invoke-NpcPapyrus Actor GetActorValue $actor @('Aggression')).returned -ne $originalAggression) {throw 'Defeat/dialogue changed original aggression permanently'}
    Invoke-NpcPapyrus Actor EnableAI $actor @($false) | Out-Null
    Invoke-NpcPapyrus Actor StopCombat $actor | Out-Null
    Invoke-NpcPapyrus Actor StopCombat $player | Out-Null
    $summary.released=$true
    $rescued=New-KneelingActor $yieldEnemyBase 0
    Invoke-NpcPapyrus Actor SetActorValue $rescued @('Health',100.0) | Out-Null
    Invoke-NpcPapyrus Acheron DefeatActor '' @(@{form=$rescued}) | Out-Null
    Invoke-NpcPapyrus Actor EnableAI $rescued @($true) | Out-Null
    $potion='0x0003EADD'
    Invoke-NpcPapyrus ObjectReference AddItem $player @(@{form=$potion},1,$true) | Out-Null
    $count=(Invoke-NpcPapyrus ObjectReference GetItemCount $player @(@{form=$potion})).returned
    $summary.rescueSelection=Select-DownedChoice $rescued 'Rescue' 0x826
    $summary.rescueState=Wait-PeacefulPhase $rescued 2
    $healed=(Invoke-NpcPapyrus Actor GetActorValue $rescued @('Health')).returned
    if([math]::Abs($healed-25.05) -gt 0.1 -or
       (Invoke-NpcPapyrus ObjectReference GetItemCount $player @(@{form=$potion})).returned -ne $count-1 -or
       (Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$rescued})).returned -or
       (Invoke-NpcPapyrus Actor IsDead $rescued).returned -or
       -not (Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$rescued})).returned) {throw 'Native Rescue failed potion healing or peaceful ownership'}
    return @{message='PASS: real player defeat, downed Interact/dialogue Kneel and Rescue, native Bind, held poses, restarted hold timer, health and aggression restoration';screenshot=$null}
} finally {
    Invoke-YieldTool input @{action='releaseAll';device='keyboard';owner=$RunId} | Out-Null
    Invoke-YieldTool menu @{action='close';name='Dialogue Menu'} | Out-Null
    if((Get-Content $logPath -Raw).Substring($worldStart) -match 'Finished loading data from cosave') {throw 'Unexpected world load; stale actor cleanup skipped'}
    foreach($id in $owned) {
        if((Invoke-NpcPapyrus Acheron IsPeacefulState '' @(@{form=$id})).returned) {Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$id}) | Out-Null}
        if((Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$id})).returned) {Invoke-NpcPapyrus Acheron RescueActor '' @(@{form=$id},$true) | Out-Null}
        Invoke-NpcPapyrus ObjectReference Disable $id @($false) | Out-Null
        Invoke-NpcPapyrus ObjectReference Delete $id | Out-Null
    }
    $summary.actorCleaned=$true
}
