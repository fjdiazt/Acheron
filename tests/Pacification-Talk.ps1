param([string] $RunId, [string] $RunDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Pacification-Fixture.ps1')
$player='0x00000014';$actor=$null;$summary.actorCleaned=$false;$summary.talk=@()
try {
    $package=(Invoke-NpcPapyrus Game GetFormFromFile '' @(0x813,'Acheron.esm')).returned.formId
    if($package -notmatch '813$') {throw 'Unexpected package mapping'}
    $perk=$package -replace '813$','803';$info=$package -replace '813$','817'
    Invoke-NpcPapyrus Actor AddPerk $player @(@{form=$perk}) | Out-Null
    if((Invoke-NpcPapyrus Actor HasPerk $player @(@{form=$perk})).returned -ne $true) {throw 'Interaction perk missing'}
    $capabilities=Invoke-YieldTool input @{action='capabilities'}
    foreach($key in @('e','up','down')) {
        if($key -notin $capabilities.capabilities.keyboard.keys.key) {throw "Required dialogue input unavailable: $key"}
    }
    Invoke-YieldTool camera @{action='freecam';on=$false} | Out-Null
    foreach($fixture in @(@{kind='enemy';base=$yieldEnemyBase},@{kind='civilian';base='0x00013BBF'})) {
        $before=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
        $spawn=(Invoke-NpcPapyrus ObjectReference PlaceAtMe $player @(@{form=$fixture.base},1,$true,$false)).returned
        $after=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
        $actor=Resolve-NpcSpawn $before $after $fixture.base $spawn.formId
        $case=@{kind=$fixture.kind;actor=$actor};$summary.talk+=,$case
        Invoke-NpcPapyrus Actor EnableAI $actor @($false) | Out-Null
        if($fixture.base -eq $yieldEnemyBase) {Set-NpcEnemyEquipment $actor | Out-Null}
        Invoke-NpcPapyrus ObjectReference MoveTo $actor @(@{form=$player},0.0,-85.0,0.0,$false) | Out-Null
        Invoke-NpcPapyrus Actor StopCombat $player | Out-Null
        $case.originalRank=(Invoke-NpcPapyrus Actor GetRelationshipRank $actor @(@{form=$player})).returned
        $case.originalAggression=(Invoke-NpcPapyrus Actor GetActorValue $actor @('Aggression')).returned
        $expectedRank=if($fixture.kind -eq 'enemy') {-3}else{$case.originalRank}
        Invoke-NpcPapyrus Acheron BeginPeacefulState '' @(@{form=$actor},30) | Out-Null
        Invoke-NpcPapyrus Actor EnableAI $actor @($true) | Out-Null
        $case.state=Wait-PeacefulPhase $actor 2
        $case.managedRank=(Invoke-NpcPapyrus Actor GetRelationshipRank $actor @(@{form=$player})).returned
        if($case.managedRank -ne $expectedRank) {throw 'Peaceful relationship policy changed wrong actor or missed enemy'}
        Invoke-NpcPapyrus Actor SetDontMove $actor @($true) | Out-Null
        Invoke-NpcPapyrus ObjectReference MoveTo $actor @(@{form=$player},0.0,-120.0,0.0,$false) | Out-Null
        Invoke-NpcPapyrus ObjectReference SetAngle $player @(0.0,0.0,180.0) | Out-Null
        $deadline=(Get-Date).AddSeconds(3)
        do {$case.beforeInteraction=Read-PeacefulDialogue $actor} while($case.beforeInteraction.crosshair -ne $actor -and (Get-Date) -lt $deadline)
        if($case.beforeInteraction.crosshair -ne $actor) {throw 'Interact crosshair did not acquire expected actor'}
        Invoke-YieldTool input @{action='tap';device='keyboard';key='e';durationMs=50;owner=$RunId} | Out-Null
        $deadline=(Get-Date).AddSeconds(8)
        do {
            $case.dialogue=Read-PeacefulDialogue $actor
            $choice=$null
            try {$choice=Assert-PeacefulDialogueChoice $case.dialogue $actor} catch {}
            if($choice) {break}
            Start-Sleep -Milliseconds 100
        } while((Get-Date) -lt $deadline)
        if(-not $choice) {throw 'Visible selectable dialogue choice unavailable'}
        # Drive the real list input; never invoke the action's Papyrus handler directly.
        $selected=[int]$case.dialogue.selectedIndex
        $delta=[int]$choice.row-$selected
        if([math]::Abs($delta) -gt 256) {throw 'Invalid dialogue selection index'}
        $key=if($delta -lt 0) {'w'} else {'s'}
        for($step=0;$step -lt [math]::Abs($delta);$step++) {
            Invoke-YieldTool input @{action='tap';device='keyboard';key=$key;durationMs=50;owner=$RunId} | Out-Null
        }
        $deadline=(Get-Date).AddSeconds(5)
        do {
            $case.beforeSelection=Read-PeacefulDialogue $actor
            $choice=$null
            try {$choice=Assert-PeacefulDialogueChoice $case.beforeSelection $actor} catch {}
        } while(-not $choice -and (Get-Date) -lt $deadline)
        if(-not $choice) {throw 'Dialogue readiness lost before selection'}
        if($case.beforeSelection.selectedIndex -ne $choice.row) {throw 'Real dialogue input selected wrong row'}
        $start=(Get-Content $logPath -Raw).Length
        Invoke-YieldTool input @{action='tap';device='keyboard';key='e';durationMs=50;owner=$RunId} | Out-Null
        $case.afterSelection=Read-PeacefulDialogue $actor
        $deadline=(Get-Date).AddSeconds(5)
        do {
            $event=$null
            try {$event=Assert-PeacefulTopicSelected ((Get-Content $logPath -Raw).Substring($start)) $actor $info} catch {}
            if($event) {break}
            Start-Sleep -Milliseconds 50
        } while((Get-Date) -lt $deadline)
        if(-not $event) {throw 'Selected Continue. did not execute native INFO'}
        if($case.beforeSelection.selectedInfo -eq $info -or $case.afterSelection.selectedInfo -ne $info -or
           $case.afterSelection.selectedTopic -ne ($package -replace '813$','816')) {throw 'Native selected topic did not change to Continue.'}
        $case.selection=$event
        if((Invoke-NpcPapyrus Actor IsInDialogueWithPlayer $actor).returned -ne $true -or
           (Invoke-NpcPapyrus Acheron IsPeacefulState '' @(@{form=$actor})).returned -ne $true -or
           (Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$actor})).returned -ne $true -or
           (Invoke-NpcPapyrus Actor GetActorValue $actor @('Aggression')).returned -ne $case.originalAggression) {throw 'Continue. damaged peaceful state, speaker or original aggression'}
        $case.stateAfterSelection=Read-PeacefulState $actor
        if($case.stateAfterSelection.generation -ne $case.state.generation -or $case.stateAfterSelection.anchor -ne $case.state.anchor) {throw 'Continue. replaced controller ownership'}
        Invoke-NpcPapyrus Acheron BeginPeacefulState '' @(@{form=$actor},2) | Out-Null
        Start-Sleep -Milliseconds 2500
        if((Invoke-NpcPapyrus Acheron IsPeacefulState '' @(@{form=$actor})).returned -ne $true) {throw 'Expiry interrupted dialogue'}
        Close-PeacefulDialogue $actor $RunId
        $deadline=(Get-Date).AddSeconds(6)
        do {
            $active=(Invoke-NpcPapyrus Acheron IsPeacefulState '' @(@{form=$actor})).returned
            if(-not $active) {break}
            Start-Sleep -Milliseconds 50
        } while((Get-Date) -lt $deadline)
        if($active) {throw 'Closed dialogue did not resume expiry'}
        $case.releasedRank=(Invoke-NpcPapyrus Actor GetRelationshipRank $actor @(@{form=$player})).returned
        if($case.releasedRank -ne $expectedRank) {throw 'Release restored enemy rank or changed civilian disposition'}
        Invoke-NpcPapyrus ObjectReference Disable $actor @($false) | Out-Null
        Invoke-NpcPapyrus ObjectReference Delete $actor | Out-Null
        $actor=$null;$case.cleaned=$true
    }
    return @{message='PASS: Forsworn/civilian visible native choice, real selection, preserved peaceful state and deferred expiry';screenshot=$null}
} finally {
    Invoke-YieldTool input @{action='releaseAll';device='keyboard';owner=$RunId} | Out-Null
    Invoke-YieldTool menu @{action='close';name='Dialogue Menu'} | Out-Null
    if($actor) {
        if((Invoke-NpcPapyrus Acheron IsPeacefulState '' @(@{form=$actor})).returned) {Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$actor}) | Out-Null}
        Invoke-NpcPapyrus ObjectReference Disable $actor @($false) | Out-Null
        Invoke-NpcPapyrus ObjectReference Delete $actor | Out-Null
    }
    $summary.actorCleaned=$true
}
