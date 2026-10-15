param([string] $RunId, [string] $RunDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Pacification-Fixture.ps1')
$player='0x00000014';$owned=[Collections.Generic.List[string]]::new()
$summary.actorCleaned=$false;$summary.variants=@();$summary.stand=@()
$seen=[Collections.Generic.HashSet[int]]::new()
$saveName='YieldKneeling_'+($RunId -replace '-','')
$saveDir=(Invoke-YieldTool game @{action='list';filter=$saveName}).dir
Assert-DesktopWritePath $saveDir
if(Get-ChildItem -LiteralPath $saveDir -Filter ($saveName+'*')) {throw 'Owned kneeling save already exists'}
$configs=@()
foreach($relative in @('Data\SKSE\Acheron\Settings.yaml','Data\SKSE\Acheron\Consequences\Weights.yaml')) {
    $path=Join-Path $GameRoot $relative
    Assert-DesktopWritePath $path
    $configs+=@{path=$path;bytes=if(Test-Path -LiteralPath $path){[IO.File]::ReadAllBytes($path)}else{$null}}
}
function New-VariantActor([string] $Base, [double] $X) {
    $before=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
    $spawn=(Invoke-NpcPapyrus ObjectReference PlaceAtMe $player @(@{form=$Base},1,$true,$true)).returned
    $after=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
    $id=Resolve-NpcSpawn $before $after $Base $spawn.formId
    $owned.Add($id)
    Invoke-NpcPapyrus Actor EnableAI $id @($false) | Out-Null
    Invoke-NpcPapyrus ObjectReference MoveTo $id @(@{form=$player},$X,-150.0,0.0,$false) | Out-Null
    Invoke-NpcPapyrus ObjectReference Enable $id @($false) | Out-Null
    $deadline=(Get-Date).AddSeconds(5)
    do {$loaded=(Invoke-NpcPapyrus ObjectReference Is3DLoaded $id).returned} while(-not $loaded -and (Get-Date) -lt $deadline)
    if(-not $loaded) {throw 'Kneeling variant fixture did not load'}
    if($Base -eq $yieldEnemyBase) {Set-NpcEnemyEquipment $id | Out-Null}
    Invoke-NpcPapyrus Actor SetActorValue $id @('Health',10000.0) | Out-Null
    Invoke-NpcPapyrus Actor SetActorValue $id @('HealRate',0.0) | Out-Null
    Invoke-NpcPapyrus Actor SetActorValue $id @('HealRateMult',0.0) | Out-Null
    return $id
}
function Assert-Variant([string] $Actor, [int] $Start) {
    $state=Wait-PeacefulPhase $Actor 3 20
    if($null -eq $state.selectedKneelingVariant -or $state.selectedKneelingVariant -notin @(0,1,2)) {throw 'Saved kneeling variant missing/invalid'}
    $expected='0x000E8E4E'
    if((Invoke-NpcPapyrus Actor GetFurnitureReference $Actor).returned.formId -ne $state.goal -or
       (Invoke-NpcPapyrus ObjectReference GetBaseObject $state.goal).returned.formId -ne $expected -or
       (Invoke-NpcPapyrus Actor GetSitState $Actor).returned -ne 3) {throw 'Kneeling variant not occupying matching native furniture'}
    $clip='IdleKneelIdle'
    $priority=5002+$state.selectedKneelingVariant
    $deadline=(Get-Date).AddSeconds(3)
    do {
        $evidence=@((Get-Content $animationLog -Raw).Substring($Start) -split "`n" | Where-Object {$_ -match ('AnimationLogEntry:.*_CustomConditions[\\/]'+$priority+'[\\/]'+$clip+'\.hkx')})
        if($evidence) {break}
        Start-Sleep -Milliseconds 50
    } while((Get-Date) -lt $deadline)
    if(-not $evidence) {throw "Matching kneeling loop missing: $clip"}
    $summary.variants+=@{actor=$Actor;state=$state;clip=$evidence[-1]}
    $seen.Add($state.selectedKneelingVariant) | Out-Null
    return $state
}
try {
    Invoke-YieldTool console @{action='exec';command='tgm'} | Out-Null
    Invoke-YieldTool camera @{action='freecam';on=$false} | Out-Null
    $perk=(Invoke-NpcPapyrus Game GetFormFromFile '' @(0x803,'Acheron.esm')).returned.formId
    Invoke-NpcPapyrus Actor AddPerk $player @(@{form=$perk}) | Out-Null
    $actor=New-VariantActor $yieldEnemyBase 0
    $originalAggression=(Invoke-NpcPapyrus Actor GetActorValue $actor @('Aggression')).returned
    Invoke-YieldTool menu @{action='open';name='Console'} | Out-Null
    Invoke-YieldTool console @{action='exec';capture=$true;command=('prid '+($actor -replace '^0x',''))} | Out-Null
    Invoke-YieldTool menu @{action='close';name='Console'} | Out-Null
    Invoke-NpcPapyrus Acheron DefeatActor '' @(@{form=$actor}) | Out-Null
    $health=(Invoke-NpcPapyrus Actor GetActorValue $actor @('Health')).returned
    Invoke-NpcPapyrus Actor EnableAI $actor @($true) | Out-Null
    $animationLog=Join-Path (Split-Path -Parent $PrefsPath) 'SKSE\OpenAnimationReplacer.log'
    for($attempt=0;$attempt -lt 18;$attempt++) {
        $start=(Get-Content $animationLog -Raw).Length
        Invoke-NpcPapyrus Acheron KneelActor '' @(@{form=$actor}) | Out-Null
        $state=Assert-Variant $actor $start
        Invoke-NpcPapyrus Acheron KneelActor '' @(@{form=$actor}) | Out-Null
        Invoke-NpcPapyrus Acheron BeginPeacefulState '' @(@{form=$actor},120) | Out-Null
        $unchanged=Read-PeacefulState $actor
        if($unchanged.selectedKneelingVariant -ne $state.selectedKneelingVariant -or $unchanged.goal -ne $state.goal -or
           $unchanged.commandHoldRemaining -gt $state.commandHoldRemaining+0.1) {throw 'Refresh/ignored Kneel rerolled pose or reset hold'}
        $selection=Select-PeacefulDialogueChoice $actor 'On your feet.' 0x833 $RunId
        if((Invoke-NpcPapyrus Actor GetActorValue $actor @('Aggression')).returned -ne $originalAggression) {throw 'Kneeling Talk changed original aggression'}
        $standing=Wait-PeacefulPhase $actor 2 20
        if($standing.commandHoldRemaining -ne 0 -or [math]::Abs($standing.remaining-120) -gt 5 -or
           (Invoke-NpcPapyrus Actor GetSitState $actor).returned -ne 0 -or
           (Invoke-NpcPapyrus Actor GetActorValue $actor @('Health')).returned -ne $health -or
           -not (Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$actor})).returned) {throw 'On your feet lost health/pacification/time or failed to stand'}
        $exit='IdleKneelExit'
        $exitLog=(Get-Content $animationLog -Raw).Substring($start)
        if($exitLog -notmatch ('AnimationLogEntry:.*'+$exit+'\.hkx')) {throw "Matching variant exit missing: $exit"}
        $summary.stand+=@{selection=$selection;before=$state;after=$standing;exit=$exit}
        Close-PeacefulDialogue $actor $RunId
        if($seen.Count -eq 3) {break}
    }
    if($seen.Count -ne 3) {throw 'INCONCLUSIVE: random draw did not cover all three kneeling families in 18 entries'}
    Select-PeacefulDialogueChoice $actor 'Test' 0x837 $RunId | Out-Null
    $start=(Get-Content $animationLog -Raw).Length
    Select-PeacefulDialogueChoice $actor 'Kneel (Child sit/kneel)' 0x84F $RunId -AlreadyOpen | Out-Null
    $beforeSave=Assert-Variant $actor $start
    if($beforeSave.selectedKneelingVariant -ne 2) {throw 'Explicit child pose did not select child for persistence test'}
    $save=Invoke-YieldTool scenario @{steps=@(@{tool='game';args=@{action='save';name=$saveName}},@{waitFor='saveGame';timeoutMs=10000})}
    if(-not $save.ok) {throw 'Kneeling save lifecycle event missing'}
    $listing=Wait-PeacefulSave $saveName $saveDir
    Load-PeacefulSave $listing.saves[0].name
    $restored=Wait-PeacefulPhase $actor 3 20
    if($restored.selectedKneelingVariant -ne $beforeSave.selectedKneelingVariant -or $restored.goal -ne $beforeSave.goal -or
       $restored.commandHoldRemaining -gt $beforeSave.commandHoldRemaining+0.1) {throw 'Save/load rerolled kneeling or reset hold'}
    $summary.persistence=@{before=$beforeSave;after=$restored}
    $enemy=New-VariantActor $yieldEnemyBase 250
    $guard=New-VariantActor '0x000D3154' 350
    foreach($id in @($enemy,$guard)) {Invoke-NpcPapyrus Actor EnableAI $id @($true) | Out-Null}
    Invoke-NpcPapyrus Actor StartCombat $guard @(@{form=$enemy}) | Out-Null
    Invoke-NpcPapyrus Actor StartCombat $enemy @(@{form=$guard}) | Out-Null
    if(-not (Invoke-NpcPapyrus Actor IsInCombat $guard).returned) {throw 'Nearby combat precondition missing'}
    $selection=Select-PeacefulDialogueChoice $actor 'On your feet.' 0x833 $RunId
    $summary.combatStand=@{selection=$selection;state=Wait-PeacefulPhase $actor 1 20}
    foreach($id in @($enemy,$guard)) {
        Invoke-NpcPapyrus Actor EnableAI $id @($false) | Out-Null
        Invoke-NpcPapyrus Actor StopCombat $id | Out-Null
        Invoke-NpcPapyrus ObjectReference Disable $id @($false) | Out-Null
    }
    Invoke-NpcPapyrus Actor StopCombat $player | Out-Null
    Wait-PeacefulPhase $actor 2 10 | Out-Null
    $start=(Get-Content $animationLog -Raw).Length
    Invoke-NpcPapyrus Acheron KneelActor '' @(@{form=$actor}) | Out-Null
    $beforeBind=Assert-Variant $actor $start
    Invoke-YieldTool menu @{action='open';name='Console'} | Out-Null
    try {
        Invoke-NpcPapyrus Acheron BindActor '' @(@{form=$actor}) | Out-Null
        Invoke-NpcPapyrus Acheron ResumePeacefulState '' @(@{form=$actor}) | Out-Null
        $paused=Read-PeacefulState $actor
        if($paused.phase -ne 3 -or $paused.goal -ne $beforeBind.goal -or
           $paused.commandHoldRemaining -gt $beforeBind.commandHoldRemaining+0.1) {throw 'Paused command changed pose or restarted hold'}
    } finally {Invoke-YieldTool menu @{action='close';name='Console'} | Out-Null}
    $summary.bindSelection=Select-PeacefulDialogueChoice $actor 'Bind' 0x820 $RunId
    $summary.bound=Wait-PeacefulPhase $actor 4 20
    Invoke-NpcPapyrus ObjectReference Activate $actor @(@{form=$player},$false) | Out-Null
    $deadline=(Get-Date).AddSeconds(8)
    do {
        $snapshot=Read-PeacefulDialogue $actor
        $choice=$null
        try {$choice=Assert-PeacefulDialogueChoice $snapshot $actor 'Continue.'} catch {}
    } while(-not $choice -and (Get-Date) -lt $deadline)
    if(-not $choice -or (Invoke-NpcPapyrus Actor GetActorValue $actor @('Aggression')).returned -ne $originalAggression) {throw 'Bound native activation failed or changed aggression'}
    $summary.boundDialogue=$snapshot
    $summary.originalAggression=$originalAggression
    Close-PeacefulDialogue $actor $RunId
    $bindAnimations=(Get-Content $animationLog -Raw).Substring($start)
    $exit='IdleKneelExit'
    $oldExit=[regex]::Match($bindAnimations,'AnimationLogEntry:.*'+$exit+'\.hkx','IgnoreCase')
    $boundIdle=[regex]::Match($bindAnimations,'AnimationLogEntry:.*AOBoundKneesIdle\.hkx','IgnoreCase')
    if(-not $oldExit.Success -or -not $boundIdle.Success -or $oldExit.Index -ge $boundIdle.Index) {throw 'Bind did not play selected family exit before bound pose'}
    if($summary.bound.commandHoldRemaining -lt 1770 -or $summary.bound.remaining -ne $beforeBind.remaining -or
       (Get-Content $animationLog -Raw).Substring($start) -notmatch 'AnimationLogEntry:.*AOBoundKneesIdle\.hkx') {throw 'Bind lost native pose or failed to restart hold'}
    $id=[regex]::Escape(($actor -replace '^0x',''))
    $bindLog=Get-Content $logPath -Raw
    $accepted=[regex]::Matches($bindLog,"\[PeacefulPoseExit\] actor=$id phase=3 event=3 hold=(?<hold>[0-9.eE+-]+)")
    $completed=[regex]::Matches($bindLog,"\[PeacefulPoseExitComplete\] actor=$id event=3 hold=(?<hold>[0-9.eE+-]+)")
    if(-not $accepted.Count -or -not $completed.Count -or [double]$accepted[-1].Groups['hold'].Value -ne 1800 -or
       [double]$completed[-1].Groups['hold'].Value -ge 1800 -or
       $summary.bound.commandHoldRemaining -gt [double]$completed[-1].Groups['hold'].Value+0.1) {throw 'Bind did not start hold at acceptance or restarted it after exit'}
    $summary.bindTiming=@{accepted=[double]$accepted[-1].Groups['hold'].Value;exitComplete=[double]$completed[-1].Groups['hold'].Value;ready=$summary.bound.commandHoldRemaining;pausedCommandsRejected=$true}
    Invoke-NpcPapyrus ObjectReference Activate $actor @(@{form=$player},$false) | Out-Null
    $deadline=(Get-Date).AddSeconds(8)
    do {
        $dialogue=Read-PeacefulDialogue $actor
        try {Assert-PeacefulDialogueChoice $dialogue $actor 'Continue.' | Out-Null;break} catch {}
    } while((Get-Date) -lt $deadline)
    if(@($dialogue.choices | Where-Object text -eq 'On your feet.').Count) {throw 'Unbound On your feet exposed while bound'}
    Invoke-NpcPapyrus Acheron ProbeCommandHold '' @(@{form=$actor},0.0) | Out-Null
    Invoke-NpcPapyrus Acheron BeginPeacefulState '' @(@{form=$actor},120) | Out-Null
    $heldDialogue=Read-PeacefulState $actor
    if($heldDialogue.phase -ne 4 -or $heldDialogue.commandHoldRemaining -ne 0 -or $heldDialogue.remaining -ne 120) {throw 'Refresh/expired hold interrupted live dialogue'}
    $exitStart=(Get-Content $logPath -Raw).Length
    $animationStart=(Get-Content $animationLog -Raw).Length
    Close-PeacefulDialogue $actor $RunId
    $afterExpiry=Wait-PeacefulPhase $actor 2 20
    $expiryLog=(Get-Content $logPath -Raw).Substring($exitStart)
    $exitDone=[regex]::Match($expiryLog,"\[PeacefulPoseExitComplete\] actor=$id event=0 hold=0")
    $movement=[regex]::Match($expiryLog,"\[PeacefulPackage\] actor=$id generation=\d+ stage=request phase=2")
    if(-not $exitDone.Success -or -not $movement.Success -or $exitDone.Index -ge $movement.Index -or
       (Invoke-NpcPapyrus Actor GetSitState $actor).returned -ne 0 -or
       (Get-Content $animationLog -Raw).Substring($animationStart) -notmatch 'AnimationLogEntry:.*AOBoundKneesExit\.hkx') {throw 'Automatic hold expiry applied movement before native bound exit'}
    if((Invoke-NpcPapyrus Actor GetActorValue $actor @('Health')).returned -ne $health -or
       -not (Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$actor})).returned) {throw 'Automatic hold expiry lost health or pacification'}
    $summary.holdExpiry=@{duringDialogue=$heldDialogue;after=$afterExpiry;exitBeforeMovement=$true}
    return @{message='PASS: kneeling variants, save/load, command guards, acceptance-time Bind and ordered hold expiry';screenshot=$null}
} finally {
    Invoke-YieldTool input @{action='releaseAll';device='keyboard';owner=$RunId} | Out-Null
    Invoke-YieldTool menu @{action='close';name='Dialogue Menu'} | Out-Null
    foreach($id in $owned) {
        Invoke-NpcPapyrus Actor EnableAI $id @($false) | Out-Null
        if((Invoke-NpcPapyrus Acheron IsPeacefulState '' @(@{form=$id})).returned) {Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$id}) | Out-Null}
        if((Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$id})).returned) {Invoke-NpcPapyrus Acheron RescueActor '' @(@{form=$id},$true) | Out-Null}
        Invoke-NpcPapyrus ObjectReference Disable $id @($false) | Out-Null
        Invoke-NpcPapyrus ObjectReference Delete $id | Out-Null
    }
    foreach($file in Get-ChildItem -LiteralPath $saveDir -Filter ($saveName+'*') -File) {
        Assert-DesktopWritePath $file.FullName
        if($file.DirectoryName -ne [IO.Path]::GetFullPath($saveDir).TrimEnd('\') -or $file.BaseName -notlike ($saveName+'*')) {throw 'Owned save path escaped its directory'}
        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $RunDirectory $file.Name)
        Remove-Item -LiteralPath $file.FullName
    }
    foreach($config in $configs) {
        Assert-DesktopWritePath $config.path
        if($null -eq $config.bytes) {Remove-Item -LiteralPath $config.path -ErrorAction SilentlyContinue}
        else {[IO.File]::WriteAllBytes($config.path,$config.bytes)}
    }
    $summary.actorCleaned=$true
    $summary.persistenceSettingsRestored=$true
}
