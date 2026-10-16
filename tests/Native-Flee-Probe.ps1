param([string] $RunId, [string] $RunDirectory, [switch] $EnemyControl, [switch] $YieldControl,
    [ValidateSet('From','To')] [string] $PackageMode)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Npc-Papyrus.ps1')
. (Join-Path $PSScriptRoot 'Yield-StartupPrompts.ps1')
. (Join-Path $PSScriptRoot 'Native-Flee-Evidence.ps1')
$player='0x00000014'; $actor=$null; $goal=$null; $travel=$null; $fleePackage=$null; $summary.actorCleaned=$false
$logPath=Join-Path (Split-Path -Parent $PrefsPath) 'SKSE\Acheron.log'
function Read-FleeProbe([string] $ActorId, [int] $Action=2, [switch] $AfterPrompt) {
    if($Action -ne 0) {Resolve-YieldStartupPrompts}
    $start=(Get-Content $logPath -Raw).Length
    if(-not (Invoke-NpcPapyrus Acheron ProbeNativeFlee '' @(@{form=$ActorId},$Action)).returned) {throw 'Native flee diagnostic rejected actor/action'}
    $deadline=(Get-Date).AddSeconds(3)
    do {
        $log=Get-Content $logPath -Raw
        if($log.Length -ge $start) {
            foreach($match in [regex]::Matches($log.Substring($start),'\[NativeFleeProbe\] (?<json>\{[^\r\n]*\})')) {
                $sample=$match.Groups['json'].Value|ConvertFrom-Json
                if($sample.actor -eq $ActorId -and $sample.action -eq $Action) {
                    if($sample.paused -and $Action -ne 0) {
                        $declines=[int]$summary.survivalPromptDeclines
                        Resolve-YieldStartupPrompts
                        if($AfterPrompt -or [int]$summary.survivalPromptDeclines -le $declines) {throw 'Native flee snapshot paused without a newly handled Survival prompt'}
                        $summary.promptPausedSnapshots+=,$sample
                        # Resnapshot only; never repeat a flight mutation after dismissing a late modal.
                        return Read-FleeProbe $ActorId 2 -AfterPrompt
                    }
                    return $sample
                }
            }
        }
        Start-Sleep -Milliseconds 25
    } while((Get-Date) -lt $deadline)
    throw 'Native flee task did not produce snapshot'
}
try {
    Invoke-YieldTool console @{action='exec';command='coc WhiterunExterior16'} | Out-Null
    $deadline=(Get-Date).AddSeconds(45); $cell=$null
    do {
        try {$cell=(Invoke-YieldTool inspect @{kind='refs';formId=$player}).refs[0].cell.editorId}
        catch {if($_.ErrorDetails.Message -notmatch 'queued task abandoned') {throw}; $cell=$null}
        Start-Sleep -Milliseconds 100
    } while($cell -ne 'WhiterunExterior16' -and (Get-Date) -lt $deadline)
    if($cell -ne 'WhiterunExterior16') {throw 'Outdoor test cell did not load'}
    Resolve-YieldStartupPrompts
    $playerStart=(Invoke-YieldTool inspect @{kind='refs';formId=$player}).refs[0].position
    $summary.probe=if($YieldControl){'Actual Yielding entry; no Travel warm-up or player relocation'}else{'Acheron hook isolation with native Travel path control'}
    $summary.nativeCall='InitiateFlee(player,true,true,false,nullptr,nullptr,4096.0f,50.0f)'
    if($PackageMode) {
        if(-not $YieldControl -or -not $EnemyControl) {throw 'Package flight requires actual enemy Yielding entry'}
        $summary.nativeCall="ActorUtil package Flee$PackageMode"
        $key=if($PackageMode -eq 'From'){0x880}else{0x881}
        $form=(Invoke-NpcPapyrus Game GetFormFromFile '' @($key,'Acheron.esm')).returned
        # Package EditorIDs are unavailable here; compiled readback and deployment hashes establish fixture identity.
        if($form.formType -ne '79' -or $form.formId -notmatch ('{0:X3}$' -f $key)) {throw 'Compile FleeFrom/FleeTo fixtures before package probe'}
        $fleePackage=$form.formId
    }
    $summary.hooksExpected=$env:ACHERON_NATIVE_FLEE_NO_HOOKS -ne '1'
    if(-not $YieldControl) {
        $travel=(Invoke-NpcPapyrus Game GetFormFromFile '' @(0x880,'Acheron.esm')).returned.formId
        if(-not $travel) {throw 'Compile native-flee Travel fixture before isolation probe'}
    }
    $summary.controls=@()
    $pacificationControls=if($EnemyControl){@($true)}else{@($false,$true)}
    foreach($pacify in $pacificationControls) {
        $base=if($EnemyControl){$yieldEnemyBase}else{'0x000D3154'}
        $before=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
        $spawn=(Invoke-NpcPapyrus ObjectReference PlaceAtMe $player @(@{form=$base},1,$true,$true)).returned
        $after=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
        $actor=Resolve-NpcSpawn $before $after $base $spawn.formId
        Invoke-NpcPapyrus Actor EnableAI $actor @($false) | Out-Null
        Invoke-NpcPapyrus ObjectReference MoveTo $actor @(@{form=$player},150.0,0.0,0.0,$false) | Out-Null
        Invoke-NpcPapyrus ObjectReference Enable $actor @($false) | Out-Null
        $deadline=(Get-Date).AddSeconds(5)
        do {$loaded=(Invoke-NpcPapyrus ObjectReference Is3DLoaded $actor).returned} while(-not $loaded -and (Get-Date) -lt $deadline)
        if(-not $loaded) {throw 'Guard control did not load'}
        if($YieldControl) {
            Set-NpcEnemyEquipment $actor | Out-Null
            Invoke-NpcPapyrus Actor SetActorValue $actor @('HealRate',0.0) | Out-Null
            Invoke-NpcPapyrus Actor SetActorValue $actor @('HealRateMult',0.0) | Out-Null
            Invoke-NpcPapyrus Acheron DefeatActor '' @(@{form=$actor}) | Out-Null
            Invoke-NpcPapyrus Actor EnableAI $actor @($true) | Out-Null
            $deadline=(Get-Date).AddSeconds(5)
            do {$down=Read-FleeProbe $actor; if($down.defeated -and $down.bleedoutLocked -and $down.defeatPackage) {break}; Start-Sleep -Milliseconds 100} while((Get-Date) -lt $deadline)
            if(-not $down.defeated -or -not $down.bleedoutLocked -or -not $down.defeatPackage -or -not $down.pacified) {throw 'Actual Yielding entry did not acquire defeat ownership/immobilization'}
        } elseif($pacify) {Invoke-NpcPapyrus Acheron PacifyActor '' @(@{form=$actor}) | Out-Null}
        $initial=Read-FleeProbe $actor
        if($initial.hooksEnabled -ne $summary.hooksExpected -or $initial.combat -or $initial.pacified -ne $pacify) {throw 'Isolation control was not peaceful or hook mode mismatched'}
        $startRef=(Invoke-YieldTool inspect @{kind='refs';formId=$actor}).refs[0]
        $control=@{pacifiedRequested=$pacify;initial=$initial;actor=$startRef;pathSamples=@();samples=@()}
        if($YieldControl) {$control.requirePlanar=$true}
        $summary.controls+=,$control
        if($YieldControl) {
            $control.yielding=$down
            Invoke-NpcPapyrus Actor EnableAI $actor @($true) | Out-Null
            Invoke-NpcPapyrus Acheron RescueActor '' @(@{form=$actor},$false) | Out-Null
            $deadline=(Get-Date).AddSeconds(5)
            do {$sample=Read-FleeProbe $actor; if(-not $sample.defeated -and -not $sample.bleedoutLocked -and -not $sample.defeatPackage) {break}; Start-Sleep -Milliseconds 100} while((Get-Date) -lt $deadline)
            if($sample.defeated -or $sample.bleedoutLocked -or $sample.defeatPackage) {throw 'No-heal bleedout exit did not complete'}
            $control.bleedoutExit=$sample
        } else {
            $goal=(Invoke-NpcPapyrus ObjectReference PlaceAtMe $player @(@{form='0x0000003B'},1,$true,$false)).returned.formId
            Invoke-NpcPapyrus ObjectReference MoveTo $goal @(@{form=$player},0.0,-900.0,0.0,$false) | Out-Null
            Invoke-NpcPapyrus Acheron ProbePeacefulLinks '' @(@{form=$actor},@{form=$goal},@{form=$goal}) | Out-Null
            $control.goal=(Invoke-YieldTool inspect @{kind='refs';formId=$goal}).refs[0]
            Invoke-NpcPapyrus ActorUtil AddPackageOverride '' @(@{form=$actor},@{form=$travel},100,1) | Out-Null
            Invoke-NpcPapyrus Actor EnableAI $actor @($true) | Out-Null
            Invoke-NpcPapyrus Actor EvaluatePackage $actor | Out-Null
            $deadline=(Get-Date).AddSeconds(12)
            do {
                $sample=Read-FleeProbe $actor
                $goalDistance=(Invoke-NpcPapyrus ObjectReference GetDistance $actor @(@{form=$goal})).returned
                $control.pathSamples+=@{native=$sample;goalDistance=$goalDistance}
                if($goalDistance -lt 128) {break}
                Start-Sleep -Milliseconds 100
            } while((Get-Date) -lt $deadline)
            $control.pathQualified=$goalDistance -lt 128 -and -not $sample.paused -and @($control.pathSamples|Where-Object {$_.native.combat -or $_.native.health -ne $initial.health}).Count -eq 0
            if(-not $control.pathQualified) {throw 'Native Travel path control failed; no fleeing conclusion allowed'}
            Invoke-NpcPapyrus Actor EnableAI $actor @($false) | Out-Null
            if($EnemyControl) {Set-NpcEnemyEquipment $actor | Out-Null}
            Invoke-NpcPapyrus ActorUtil RemovePackageOverride '' @(@{form=$actor},@{form=$travel}) | Out-Null
            Invoke-NpcPapyrus Actor EvaluatePackage $actor | Out-Null
            # Flee back along the proven path; teleporting the actor back can invalidate its pathing context.
            $arrived=(Invoke-YieldTool inspect @{kind='refs';formId=$actor}).refs[0].position
            $dx=$arrived[0]-$startRef.position[0];$dy=$arrived[1]-$startRef.position[1]
            $length=[math]::Sqrt($dx*$dx+$dy*$dy)
            if($length -lt 350) {throw 'Travel control did not establish a useful escape route'}
            Invoke-NpcPapyrus ObjectReference SetPosition $player @([float]($arrived[0]+$dx/$length*200),[float]($arrived[1]+$dy/$length*200),[float]$arrived[2]) | Out-Null
            $control.fleeActorPosition=$arrived
            $control.fleePlayer=(Invoke-YieldTool inspect @{kind='refs';formId=$player}).refs[0]
        }
        $control.fleeInitial=Read-FleeProbe $actor
        Invoke-NpcPapyrus Actor EnableAI $actor @($true) | Out-Null
        if($fleePackage) {
            if($PackageMode -eq 'To') {
                $goal=(Invoke-NpcPapyrus ObjectReference PlaceAtMe $player @(@{form='0x0000003B'},1,$true,$false)).returned.formId
                if($goal -notmatch '^0xFF[0-9A-Fa-f]{6}$') {throw 'Escape marker ownership missing'}
                # Same short outdoor corridor previously traversed by the independent Travel control.
                Invoke-NpcPapyrus ObjectReference MoveTo $goal @(@{form=$player},0.0,-900.0,0.0,$false) | Out-Null
                Invoke-NpcPapyrus Acheron ProbePeacefulLinks '' @(@{form=$actor},@{form=$goal},@{form=$goal}) | Out-Null
                $keyword=(Invoke-NpcPapyrus Game GetFormFromFile '' @(0x812,'Acheron.esm')).returned.formId
                if((Invoke-NpcPapyrus ObjectReference GetLinkedRef $actor @(@{form=$keyword})).returned.formId -ne $goal) {throw 'Escape goal link not applied'}
                $control.goal=(Invoke-YieldTool inspect @{kind='refs';formId=$goal}).refs[0]
            }
            $control.expectedPackage=$fleePackage
            Invoke-NpcPapyrus ActorUtil AddPackageOverride '' @(@{form=$actor},@{form=$fleePackage},100,1) | Out-Null
            Invoke-NpcPapyrus Actor EvaluatePackage $actor | Out-Null
            $control.start=Read-FleeProbe $actor
        } else {$control.start=Read-FleeProbe $actor 3}
        $deadline=(Get-Date).AddSeconds(8)
        do {
            $sample=Read-FleeProbe $actor
            $control.samples+=,$sample
            if($goal) {$control.pathSamples+=@{native=$sample;goalDistance=(Invoke-NpcPapyrus ObjectReference GetDistance $actor @(@{form=$goal})).returned}}
            Start-Sleep -Milliseconds 150
        } while((Get-Date) -lt $deadline)
        $outcome=Get-NativeFleeOutcome $control $summary.hooksExpected
        foreach($key in $outcome.Keys) {$control[$key]=$outcome[$key]}
        if($fleePackage) {
            Invoke-NpcPapyrus ActorUtil RemovePackageOverride '' @(@{form=$actor},@{form=$fleePackage}) | Out-Null
            Invoke-NpcPapyrus Actor EvaluatePackage $actor | Out-Null
        }
        $control.stop=Read-FleeProbe $actor 0
        $deadline=(Get-Date).AddSeconds(3)
        do {$sample=Read-FleeProbe $actor; if(-not $sample.fleeing -and $sample.packageType -notin @(10,22) -and $sample.package -ne $fleePackage) {break}; Start-Sleep -Milliseconds 100} while((Get-Date) -lt $deadline)
        $control.stopped=-not $sample.fleeing -and $sample.packageType -notin @(10,22) -and $sample.package -ne $fleePackage
        $control.afterStop=$sample
        if(-not $control.invariantsPreserved -or -not $control.stopped) {throw 'Isolation actor invariants or native stop failed'}
        if($YieldControl) {
            $position=(Invoke-YieldTool inspect @{kind='refs';formId=$player}).refs[0].position
            $control.playerStationary=([math]::Abs($position[0]-$playerStart[0]) -lt 1 -and [math]::Abs($position[1]-$playerStart[1]) -lt 1)
            if(-not $control.playerStationary -or -not $control.fleeQualified) {throw 'Actual Yielding flight failed without prepared route; see observations'}
        }
        Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$actor}) | Out-Null
        Invoke-NpcPapyrus ObjectReference Disable $actor @($false) | Out-Null
        Invoke-NpcPapyrus ObjectReference Delete $actor | Out-Null
        $actor=$null
        if($goal) {
            Invoke-NpcPapyrus ObjectReference Disable $goal @($false) | Out-Null
            Invoke-NpcPapyrus ObjectReference Delete $goal | Out-Null
            $goal=$null
        }
        if(-not $YieldControl) {Invoke-NpcPapyrus ObjectReference SetPosition $player @($playerStart[0],$playerStart[1],$playerStart[2]) | Out-Null}
    }
    return @{message='PASS: isolation observations collected; fleeQualified contains behavior result';screenshot=$null}
} finally {
    if($actor) {
        if($travel) {Invoke-NpcPapyrus ActorUtil RemovePackageOverride '' @(@{form=$actor},@{form=$travel}) | Out-Null}
        if($fleePackage) {Invoke-NpcPapyrus ActorUtil RemovePackageOverride '' @(@{form=$actor},@{form=$fleePackage}) | Out-Null}
        if((Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$actor})).returned) {Invoke-NpcPapyrus Acheron RescueActor '' @(@{form=$actor},$false) | Out-Null}
        Read-FleeProbe $actor 0 | Out-Null
        Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$actor}) | Out-Null
        Invoke-NpcPapyrus ObjectReference Disable $actor @($false) | Out-Null
        Invoke-NpcPapyrus ObjectReference Delete $actor | Out-Null
    }
    if($goal) {Invoke-NpcPapyrus ObjectReference Disable $goal @($false)|Out-Null; Invoke-NpcPapyrus ObjectReference Delete $goal|Out-Null}
    $summary.actorCleaned=$true
}
