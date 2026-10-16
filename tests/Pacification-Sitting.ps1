param([string] $RunId, [string] $RunDirectory, [switch] $Poses, [switch] $Male)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Pacification-Fixture.ps1')
$player='0x00000014'; $actor=$null; $owned=[Collections.Generic.HashSet[string]]::new(); $summary.actorCleaned=$false; $summary.poses=@()
$saveName='YieldSitting_'+($RunId -replace '-',''); $yieldSave='YieldDefeat_'+($RunId -replace '-',''); $saveDir=$null
$configs=@()
if(-not $Poses) {
    foreach($relative in @('Data\SKSE\Acheron\Settings.yaml','Data\SKSE\Acheron\Consequences\Weights.yaml')) {
        $path=Join-Path $GameRoot $relative
        Assert-DesktopWritePath $path
        $configs+=@{path=$path;bytes=if(Test-Path -LiteralPath $path){[IO.File]::ReadAllBytes($path)}else{$null}}
    }
}
$animationLog=Join-Path (Split-Path -Parent $PrefsPath) 'SKSE\OpenAnimationReplacer.log'
if($Male) {$yieldEnemyBase='0x00043BDD'}
function Assert-SittingClip($State, [int] $Start) {
    $priority=5105+$State.selectedSittingVariant
    $deadline=(Get-Date).AddSeconds(6)
    do {$clips=(Get-Content $animationLog -Raw).Substring($Start)} while($clips -notmatch ("AnimationLogEntry:.*_CustomConditions[\\/]"+$priority+'[\\/]idlekneelidle\.hkx') -and (Get-Date) -lt $deadline)
    if($clips -notmatch ("AnimationLogEntry:.*_CustomConditions[\\/]"+$priority+'[\\/]idlekneelidle\.hkx') -or
       (Invoke-NpcPapyrus Actor GetSitState $actor).returned -ne 3) {throw 'Selected sitting clip/native held posture missing'}
    return $clips
}
function New-SittingActor {
    $before=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
    $spawn=(Invoke-NpcPapyrus ObjectReference PlaceAtMe $player @(@{form=$yieldEnemyBase},1,$true,$true)).returned
    $after=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
    $actor=Resolve-NpcSpawn $before $after $yieldEnemyBase $spawn.formId
    $owned.Add($actor) | Out-Null
    Invoke-NpcPapyrus Actor EnableAI $actor @($false) | Out-Null
    Invoke-NpcPapyrus ObjectReference MoveTo $actor @(@{form=$player},0.0,-150.0,0.0,$false) | Out-Null
    Invoke-NpcPapyrus ObjectReference Enable $actor @($false) | Out-Null
    Set-NpcEnemyEquipment $actor -ExpectedSex $(if($Male){0}else{1}) | Out-Null
    foreach($stat in @('HealRate','HealRateMult')) {Invoke-NpcPapyrus Actor SetActorValue $actor @($stat,0.0) | Out-Null}
    Invoke-NpcPapyrus Actor SetActorValue $actor @('Health',100.0) | Out-Null
    Invoke-NpcPapyrus Acheron DefeatActor '' @(@{form=$actor}) | Out-Null
    Invoke-NpcPapyrus Actor EnableAI $actor @($true) | Out-Null
    Invoke-YieldTool menu @{action='open';name='Console'} | Out-Null
    Invoke-YieldTool console @{action='exec';command=('prid '+($actor -replace '^0x',''))} | Out-Null
    Invoke-YieldTool menu @{action='close';name='Console'} | Out-Null
    return $actor
}
try {
    $actor=New-SittingActor
    if($Poses) {
        $catalog=Get-Content (Join-Path $PSScriptRoot '../scripts/sitting-animations.json') -Raw | ConvertFrom-Json
        for($i=0;$i -lt $catalog.Count;$i++) {
            if($Male -and $catalog[$i].femaleOnly) {continue}
            # Asset qualification uses independent actors; chained marker movement is a separate stress scenario.
            if($i -gt 0) {
                Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$actor}) | Out-Null
                Invoke-NpcPapyrus ObjectReference Disable $actor @($false) | Out-Null
                Invoke-NpcPapyrus ObjectReference Delete $actor | Out-Null
                $owned.Remove($actor) | Out-Null
                $actor=New-SittingActor
            }
            $poseHealth=(Invoke-NpcPapyrus Actor GetActorValue $actor @('Health')).returned
            $rootInfo=0x836
            Select-PeacefulDialogueChoice $actor 'Test' $rootInfo $RunId | Out-Null
            if($Male -and $i -eq 0) {
                $deadline=(Get-Date).AddSeconds(5)
                do {$dialogue=Read-PeacefulDialogue $actor} while(-not @($dialogue.choices | Where-Object text -eq 'Sit (Cross-legged)').Count -and (Get-Date) -lt $deadline)
                if(@($dialogue.choices | Where-Object {$_.text -match 'Female Laydown|Take a Seat 7'}).Count) {throw 'Female-only Test pose exposed to male NPC'}
            }
            $start=(Get-Content $animationLog -Raw).Length
            $label=$(if($i -ge 10){'Sit wounded'}else{'Sit'})+' ('+$catalog[$i].name+')'
            Select-PeacefulDialogueChoice $actor $label (0x861+2*$i) $RunId -AlreadyOpen | Out-Null
            $state=Wait-PeacefulPhase $actor $(if($i -ge 10){6}else{5}) 20
            if($state.selectedSittingVariant -ne $i) {throw 'Explicit Test sitting family changed'}
            $clips=Assert-SittingClip $state $start
            if($clips -notmatch ('AnimationLogEntry:.*_CustomConditions[\\/]'+(5005+$i)+'[\\/]idlekneelenter\.hkx')) {throw 'Selected sitting enter replacement missing'}
            $deadline=(Get-Date).AddSeconds([math]::Max(15,$catalog[$i].loopSeconds+3))
            do {
                $loopLog=(Get-Content $animationLog -Raw).Substring($start)
                $looped=$loopLog -match ('AnimationLogEntry: Loop.*_CustomConditions[\\/]'+(5105+$i)+'[\\/]idlekneelidle\.hkx')
                if(-not $looped) {Start-Sleep -Milliseconds 100}
            } while(-not $looped -and (Get-Date) -lt $deadline)
            if(-not $looped) {throw 'Selected sitting idle did not loop'}
            $held=Read-PeacefulState $actor
            if($held.phase -ne $state.phase -or -not $held.ready -or $held.goal -ne $state.goal) {throw 'Sitting did not remain held'}
            if((Invoke-NpcPapyrus Actor GetActorValue $actor @('Health')).returned -ne $poseHealth) {throw 'Test pose changed engine health'}
            $summary.poses+=@{actor=$actor;index=$i;state=$state;clips=$clips;held=$held}
        }
        Invoke-NpcPapyrus Acheron ProbeCommandHold '' @(@{form=$actor},0.0) | Out-Null
        $summary.expired=Wait-PeacefulPhase $actor 2 20
        if($summary.expired.commandHoldRemaining -ne 0 -or (Invoke-NpcPapyrus Actor GetSitState $actor).returned -ne 0) {throw 'Sitting hold expiry did not return to locomotion'}
    } else {
        $saveDir=(Invoke-YieldTool game @{action='list';filter=$saveName}).dir
        Assert-DesktopWritePath $saveDir
        foreach($prefix in @($saveName,$yieldSave)) {if(Get-ChildItem -LiteralPath $saveDir -Filter ($prefix+'*')) {throw 'Owned sitting save already exists'}}
        $save=Invoke-YieldTool scenario @{steps=@(@{tool='game';args=@{action='save';name=$yieldSave}},@{waitFor='saveGame';timeoutMs=10000})}
        if(-not $save.ok) {throw 'Yielding save lifecycle event missing'}
        $listing=Wait-PeacefulSave $yieldSave $saveDir
        Load-PeacefulSave $listing.saves[0].name
        if(-not (Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$actor})).returned) {throw 'Defeated injury baseline ownership lost on load'}
        Invoke-YieldTool menu @{action='open';name='Console'} | Out-Null
        Invoke-YieldTool console @{action='exec';command=('prid '+($actor -replace '^0x',''))} | Out-Null
        Invoke-YieldTool menu @{action='close';name='Console'} | Out-Null
        $start=(Get-Content $animationLog -Raw).Length
        $summary.sit=Select-PeacefulDialogueChoice $actor 'On the ground.' 0x853 $RunId
        $wounded=Wait-PeacefulPhase $actor 6 20
        $summary.wounded=$wounded
        Assert-SittingClip $wounded $start | Out-Null
        if($wounded.injuryHealth -ne 0) {throw 'Defeat clamp counted as positive injury health'}
        Invoke-NpcPapyrus Acheron SitActor '' @(@{form=$actor}) | Out-Null
        $repeat=Read-PeacefulState $actor
        if($repeat.goal -ne $wounded.goal -or $repeat.commandHoldRemaining -gt $wounded.commandHoldRemaining) {throw 'Repeated Sit restarted hold'}
        $save=Invoke-YieldTool scenario @{steps=@(@{tool='game';args=@{action='save';name=$saveName}},@{waitFor='saveGame';timeoutMs=10000})}
        if(-not $save.ok) {throw 'Sitting save lifecycle event missing'}
        $listing=Wait-PeacefulSave $saveName $saveDir
        Load-PeacefulSave $listing.saves[0].name
        $restored=Wait-PeacefulPhase $actor 6 20
        if($restored.selectedSittingVariant -ne $wounded.selectedSittingVariant -or $restored.injuryHealth -ne 0 -or
           $restored.goal -ne $wounded.goal -or $restored.commandHoldRemaining -gt $repeat.commandHoldRemaining+0.1 -or
           $restored.remaining -ne $wounded.remaining) {throw 'Sitting save/load rerolled pose, lost injury or restarted timer'}
        $summary.persistence=$restored
        Invoke-YieldTool menu @{action='open';name='Console'} | Out-Null
        Invoke-YieldTool console @{action='exec';command=('prid '+($actor -replace '^0x',''))} | Out-Null
        Invoke-YieldTool menu @{action='close';name='Console'} | Out-Null
        # Fresh bootstrap supplies potions; remove consumables only inside this unsaved failure fixture.
        foreach($item in @(Get-NpcInventory $player | Where-Object formType -eq 'ALCH')) {
            $removed=Invoke-YieldTool papyrus @{action='call';script='ObjectReference';function='RemoveItem';self=@{form=$player};args=@(@{form=$item.formId},$item.count,$true);fillNeutral=$true}
            if(-not $removed.called) {throw 'Failed-treatment fixture consumable removal did not execute'}
        }
        $available=(Invoke-NpcPapyrus Acheron GetMostEfficientPotion '' @(@{form=$actor},@{form=$player})).returned
        if($available.formId) {throw 'Failed-treatment fixture unexpectedly owns a healing potion'}
        $beforeFailure=Read-PeacefulState $actor
        $summary.failedHealSelection=Select-PeacefulDialogueChoice $actor 'Heal' 0x856 $RunId
        Close-PeacefulDialogue $actor $RunId
        $failedHeal=Read-PeacefulState $actor
        if($failedHeal.phase -ne 6 -or $failedHeal.injuryHealth -ne 0 -or $failedHeal.goal -ne $beforeFailure.goal -or
           $failedHeal.commandHoldRemaining -gt $beforeFailure.commandHoldRemaining) {throw 'Failed Heal changed posture/injury or restarted hold'}
        $summary.failedHeal=$failedHeal
        $potion=(Invoke-NpcPapyrus Game GetFormFromFile '' @(0x3EADD,'Skyrim.esm')).returned.formId
        Invoke-NpcPapyrus ObjectReference AddItem $player @(@{form=$potion},1,$true) | Out-Null
        $count=(Invoke-NpcPapyrus ObjectReference GetItemCount $player @(@{form=$potion})).returned
        $health=(Invoke-NpcPapyrus Actor GetActorValue $actor @('Health')).returned
        $start=(Get-Content $animationLog -Raw).Length
        $summary.healSelection=Select-PeacefulDialogueChoice $actor 'Heal' 0x856 $RunId
        $healed=Wait-PeacefulPhase $actor 5 12
        $clips=Assert-SittingClip $healed $start
        if($healed.goal -ne $wounded.goal -or $healed.remaining -ne $wounded.remaining -or
           $healed.commandHoldRemaining -gt $repeat.commandHoldRemaining -or
           $clips -match 'AnimationLogEntry:.*(?:idlekneelexit|idlekneelenter)\.hkx' -or
           [math]::Abs((Invoke-NpcPapyrus Actor GetActorValue $actor @('Health')).returned-$health-25) -gt 0.01 -or
           (Invoke-NpcPapyrus ObjectReference GetItemCount $player @(@{form=$potion})).returned -ne $count-1) {throw 'Heal failed direct pose, timer, native potion or health contract'}
        $summary.healed=@{state=$healed;clips=$clips}
        Close-PeacefulDialogue $actor $RunId
        Invoke-NpcPapyrus ObjectReference Activate $actor @(@{form=$player},$false) | Out-Null
        $deadline=(Get-Date).AddSeconds(8)
        do {$dialogue=Read-PeacefulDialogue $actor} while((-not $dialogue.menuOpen -or -not @($dialogue.choices | Where-Object text -eq 'On your feet.').Count) -and (Get-Date) -lt $deadline)
        if(@($dialogue.choices | Where-Object text -eq 'Heal').Count) {throw 'Heal exposed after successful healing'}
        Close-PeacefulDialogue $actor $RunId
        $summary.stand=Select-PeacefulDialogueChoice $actor 'On your feet.' 0x833 $RunId
        Wait-PeacefulPhase $actor 2 20 | Out-Null
        $rescuedScope=(Invoke-NpcPapyrus Game GetFormFromFile '' @(0x819,'Acheron.esm')).returned.formId
        if(-not (Invoke-NpcPapyrus Actor IsInFaction $actor @(@{form=$rescuedScope})).returned) {throw 'Successful treatment lost rescued locomotion on resume'}
        $summary.sitHealthy=Select-PeacefulDialogueChoice $actor 'On the ground.' 0x852 $RunId
        Wait-PeacefulPhase $actor 5 20 | Out-Null
        $summary.kneel=Select-PeacefulDialogueChoice $actor 'On your knees.' 0x81C $RunId
        Wait-PeacefulPhase $actor 3 20 | Out-Null
        $summary.sitFromKneeling=Select-PeacefulDialogueChoice $actor 'On the ground.' 0x852 $RunId
        Wait-PeacefulPhase $actor 5 20 | Out-Null
        $summary.bind=Select-PeacefulDialogueChoice $actor 'Bind' 0x820 $RunId
        $bound=Wait-PeacefulPhase $actor 4 20
        if($bound.commandHoldRemaining -lt 1760) {throw 'Sitting Bind failed to restart command hold'}
        Select-PeacefulDialogueChoice $actor 'Test' 0x837 $RunId | Out-Null
        Select-PeacefulDialogueChoice $actor 'Sit wounded (Beggar)' 0x875 $RunId -AlreadyOpen | Out-Null
        $beforeSpell=Wait-PeacefulPhase $actor 6 20
        $health=(Invoke-NpcPapyrus Actor GetActorValue $actor @('Health')).returned
        if($beforeSpell.injuryHealth -ne 0) {throw 'Explicit wounded Test state did not initialize its diagnostic injury baseline'}
        $spell=(Invoke-NpcPapyrus Game GetFormFromFile '' @(0x12FD2,'Skyrim.esm')).returned.formId
        $start=(Get-Content $animationLog -Raw).Length
        Invoke-NpcPapyrus Spell Cast $spell @(@{form=$player},@{form=$actor}) | Out-Null
        $afterSpell=Wait-PeacefulPhase $actor 5 12
        $clips=Assert-SittingClip $afterSpell $start
        $expectedHealing=[math]::Min(75.0,100.0-$health)
        if($afterSpell.goal -ne $beforeSpell.goal -or $afterSpell.commandHoldRemaining -gt $beforeSpell.commandHoldRemaining -or
           $afterSpell.remaining -ne $beforeSpell.remaining -or $clips -match 'AnimationLogEntry:.*(?:idlekneelexit|idlekneelenter)\.hkx' -or
           [math]::Abs((Invoke-NpcPapyrus Actor GetActorValue $actor @('Health')).returned-$health-$expectedHealing) -gt 0.01) {throw 'External spell healing failed direct pose/timer/health contract'}
        $summary.externalHealing=@{before=$beforeSpell;after=$afterSpell;clips=$clips}
    }
    if(-not (Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$actor})).returned -or (Invoke-NpcPapyrus Actor IsDead $actor).returned) {throw 'Sitting lost living pacification'}
    return @{message="PASS: sitting native dialogue/poses; poses=$Poses male=$Male";screenshot=$null}
} finally {
    foreach($id in $owned) {Invoke-NpcPapyrus ObjectReference Disable $id @($false) | Out-Null;Invoke-NpcPapyrus ObjectReference Delete $id | Out-Null}
    if($saveDir) {
        foreach($prefix in @($saveName,$yieldSave)) {
            foreach($file in Get-ChildItem -LiteralPath $saveDir -Filter ($prefix+'*') -File) {
                Assert-DesktopWritePath $file.FullName
                if($file.DirectoryName -ne [IO.Path]::GetFullPath($saveDir).TrimEnd('\') -or $file.BaseName -notlike ($prefix+'*')) {throw 'Owned sitting save escaped directory'}
                Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $RunDirectory $file.Name)
                Remove-Item -LiteralPath $file.FullName
            }
        }
    }
    foreach($config in $configs) {
        Assert-DesktopWritePath $config.path
        if($null -eq $config.bytes) {Remove-Item -LiteralPath $config.path -ErrorAction SilentlyContinue}
        else {[IO.File]::WriteAllBytes($config.path,$config.bytes)}
    }
    $summary.persistenceSettingsRestored=$true
    $summary.actorCleaned=$true
}
