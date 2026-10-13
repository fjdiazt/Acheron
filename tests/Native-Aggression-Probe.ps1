param([string] $RunId, [string] $RunDirectory, [switch] $Bypass, [switch] $RequireOriginalTalk)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Pacification-Fixture.ps1')
$player='0x00000014'; $actor=$null
$summary.actorCleaned=$false; $summary.aggressionProbe=@()
function Interact-UnmanagedActor {
    Invoke-NpcPapyrus ObjectReference MoveTo $actor @(@{form=$player},0.0,-120.0,0.0,$false) | Out-Null
    Invoke-NpcPapyrus ObjectReference SetAngle $player @(0.0,0.0,180.0) | Out-Null
    $deadline=(Get-Date).AddSeconds(3)
    do {$pick=Read-PeacefulDialogue $actor} while($pick.crosshair -ne $actor -and (Get-Date) -lt $deadline)
    if($pick.crosshair -ne $actor) {throw 'Unmanaged crosshair missed expected actor'}
    Invoke-YieldTool input @{action='tap';device='keyboard';key='e';durationMs=50;owner=$RunId} | Out-Null
}
try {
    $perk=(Invoke-NpcPapyrus Game GetFormFromFile '' @(0x803,'Acheron.esm')).returned.formId
    Invoke-NpcPapyrus Actor AddPerk $player @(@{form=$perk}) | Out-Null
    if(-not (Invoke-NpcPapyrus Actor HasPerk $player @(@{form=$perk})).returned) {throw 'Talk perk missing'}
    Invoke-YieldTool camera @{action='freecam';on=$false} | Out-Null
    Invoke-YieldTool camera @{action='setPov';pov='third'} | Out-Null
    $before=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
    $spawn=(Invoke-NpcPapyrus ObjectReference PlaceAtMe $player @(@{form=$yieldEnemyBase},1,$true,$true)).returned
    $after=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
    $actor=Resolve-NpcSpawn $before $after $yieldEnemyBase $spawn.formId
    Invoke-NpcPapyrus Actor EnableAI $actor @($false) | Out-Null
    Invoke-NpcPapyrus ObjectReference MoveTo $actor @(@{form=$player},0.0,-120.0,0.0,$false) | Out-Null
    Invoke-NpcPapyrus ObjectReference Enable $actor @($false) | Out-Null
    $deadline=(Get-Date).AddSeconds(5)
    do {$loaded=(Invoke-NpcPapyrus ObjectReference Is3DLoaded $actor).returned} while(-not $loaded -and (Get-Date) -lt $deadline)
    if(-not $loaded) {throw 'Probe actor did not load'}
    Set-NpcEnemyEquipment $actor | Out-Null
    $original=(Invoke-NpcPapyrus Actor GetActorValue $actor @('Aggression')).returned
    if($original -le 0) {throw 'Probe needs originally aggressive enemy'}
    $summary.originalAggression=$original
    if($Bypass -or $RequireOriginalTalk) {
        $summary.unmanagedBypassRejected=(Invoke-NpcPapyrus Acheron ProbeNativeDialogue '' @(@{form=$actor})).returned -eq $false
        if(-not $summary.unmanagedBypassRejected -or (Read-PeacefulDialogue $actor).menuOpen) {throw 'Bypass accepted unmanaged enemy'}
        if($RequireOriginalTalk) {
            $start=(Get-Content $logPath -Raw).Length
            Interact-UnmanagedActor
            Start-Sleep -Milliseconds 500
            $summary.unmanagedActivation=Read-PeacefulDialogue $actor
            if($summary.unmanagedActivation.menuOpen -or (Get-Content $logPath -Raw).Substring($start) -match '\[NativeTalk\]') {throw 'Scoped activation intercepted unmanaged enemy'}
        }
        Invoke-NpcPapyrus Actor AllowPCDialogue $actor @($true) | Out-Null
        Invoke-NpcPapyrus Acheron PacifyActor '' @(@{form=$actor}) | Out-Null
        if(-not (Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$actor})).returned) {throw 'Unmanaged pacified control missing'}
        $summary.unmanagedPacifiedBypassRejected=(Invoke-NpcPapyrus Acheron ProbeNativeDialogue '' @(@{form=$actor})).returned -eq $false
        if(-not $summary.unmanagedPacifiedBypassRejected -or (Read-PeacefulDialogue $actor).menuOpen) {throw 'Bypass accepted pacified NPC without defeat/controller ownership'}
        if($RequireOriginalTalk) {
            $start=(Get-Content $logPath -Raw).Length
            Interact-UnmanagedActor
            Start-Sleep -Milliseconds 500
            $summary.unmanagedPacifiedActivation=Read-PeacefulDialogue $actor
            if($summary.unmanagedPacifiedActivation.menuOpen -or (Get-Content $logPath -Raw).Substring($start) -match '\[NativeTalk\]') {throw 'Scoped activation intercepted unowned pacified enemy'}
        }
        Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$actor}) | Out-Null
        $deadline=(Get-Date).AddSeconds(3)
        do {$pacified=(Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$actor})).returned} while($pacified -and (Get-Date) -lt $deadline)
        if($pacified) {throw 'Unmanaged control did not release'}
    }
    Invoke-NpcPapyrus Acheron DefeatActor '' @(@{form=$actor}) | Out-Null
    Invoke-NpcPapyrus Actor SetDontMove $actor @($true) | Out-Null
    Invoke-NpcPapyrus Actor EnableAI $actor @($true) | Out-Null
    foreach($phase in @('yielding','wandering')) {
        if($phase -eq 'wandering') {
            Close-PeacefulDialogue $actor $RunId
            Invoke-NpcPapyrus Actor EnableAI $actor @($false) | Out-Null
            Invoke-NpcPapyrus Acheron RescueActor '' @(@{form=$actor},$true) | Out-Null
            $deadline=(Get-Date).AddSeconds(3)
            do {$pacified=(Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$actor})).returned} while($pacified -and (Get-Date) -lt $deadline)
            if($pacified) {throw 'Rescue did not release previous pacification ownership'}
            if(-not (Invoke-NpcPapyrus Acheron BeginPeacefulState '' @(@{form=$actor},120)).returned) {throw 'Peaceful probe entry rejected'}
            Invoke-NpcPapyrus Actor EnableAI $actor @($true) | Out-Null
            Wait-PeacefulPhase $actor 2 | Out-Null
        }
        $choiceText=if($phase -eq 'yielding') {'On your knees.'}else{'Continue.'}
        foreach($attempt in @(1,2)) {
            Close-PeacefulDialogue $actor $RunId
            $actual=(Invoke-NpcPapyrus Actor GetActorValue $actor @('Aggression')).returned
            if($actual -notin @(0.0,1.0,$original)) {throw 'Unexpected probe aggression'}
            if($RequireOriginalTalk -and $actual -ne $original) {throw 'Native Talk changed original aggression'}
            if($Bypass -and $actual -ne $original) {throw 'Bypass probe requires unsuppressed original aggression'}
            Invoke-NpcPapyrus ObjectReference MoveTo $actor @(@{form=$player},0.0,-85.0,0.0,$false) | Out-Null
            $summary.probePosition=Invoke-YieldTool inspect @{kind='refs';formId=$actor}
            foreach($pitch in @(0,15,30,45,60,75)) {
                Invoke-NpcPapyrus ObjectReference SetAngle $player @([double]$pitch,0.0,180.0) | Out-Null
                Start-Sleep -Milliseconds 100
                $pick=Read-PeacefulDialogue $actor
                if($pick.crosshair -eq $actor) {break}
            }
            if($pick.crosshair -ne $actor) {throw 'Probe crosshair missed expected actor'}
            $entry=$null
            if($Bypass) {
                $start=(Get-Content $logPath -Raw).Length
                if(-not (Invoke-NpcPapyrus Acheron ProbeNativeDialogue '' @(@{form=$actor})).returned) {throw 'Managed bypass rejected'}
                $deadline=(Get-Date).AddSeconds(3)
                do {
                    $entry=[regex]::Match((Get-Content $logPath -Raw).Substring($start),'\[NativeDialogueProbe\] actor='+($actor -replace '^0x','')+' aggression=(?<aggression>[0-9.]+) nativeResult=(?<result>true|false)')
                    if($entry.Success) {break}
                    Start-Sleep -Milliseconds 25
                } while((Get-Date) -lt $deadline)
                if(-not $entry.Success -or $entry.Groups['result'].Value -ne 'true' -or [double]$entry.Groups['aggression'].Value -ne $original) {throw 'Scoped native entry execution missing, rejected, or aggression changed'}
            } else {Invoke-YieldTool input @{action='tap';device='keyboard';key='e';durationMs=50;owner=$RunId} | Out-Null}
            $deadline=(Get-Date).AddSeconds(8); $choice=$null
            do {
                $dialogue=Read-PeacefulDialogue $actor
                try {$choice=Assert-PeacefulDialogueChoice $dialogue $actor $choiceText} catch {}
                if($choice) {break}
                Start-Sleep -Milliseconds 100
            } while((Get-Date) -lt $deadline)
            $case=@{phase=$phase;aggression=$actual;choicesReady=[bool]$choice;dialogue=$dialogue;
                aggressionAfter=(Invoke-NpcPapyrus Actor GetActorValue $actor @('Aggression')).returned;
                defeated=(Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$actor})).returned;
                pacified=(Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$actor})).returned;
                combat=(Invoke-NpcPapyrus Actor IsInCombat $actor).returned}
            if($Bypass) {$case.nativeEntry=$entry.Value}
            $summary.aggressionProbe+=,$case
            if($case.aggressionAfter -ne $actual -or -not $case.pacified -or $case.combat -or
               $case.defeated -ne ($phase -eq 'yielding')) {throw 'Probe changed aggression or pacification during Talk'}
            if($actual -eq 0 -and -not $choice) {throw 'Zero-aggression control failed; comparison invalid'}
            if($RequireOriginalTalk -and -not $choice) {throw 'Native E activation failed with original aggression'}
            if($Bypass -and -not $choice) {throw 'Native bypass failed to open usable dialogue'}
        }
    }
    $originalCases=@($summary.aggressionProbe | Where-Object {$_.aggression -eq $original})
    $summary.originalAggressionAttempts=$originalCases.Count
    $summary.originalAggressionTalkPassed=if($originalCases.Count -eq 4) {@($originalCases | Where-Object {-not $_.choicesReady}).Count -eq 0}else{$null}
    $oneCases=@($summary.aggressionProbe | Where-Object {$_.aggression -eq 1})
    $summary.aggressionOneAttempts=$oneCases.Count
    $summary.aggressionOneTalkPassed=if($oneCases.Count -eq 4) {@($oneCases | Where-Object {-not $_.choicesReady}).Count -eq 0}else{$null}
    if($Bypass) {
        $summary.bypassTalkPassed=$summary.originalAggressionTalkPassed
        if($summary.bypassTalkPassed) {
            $summary.bypassSelection=Select-PeacefulDialogueChoice $actor 'On your knees.' 0x81C $RunId -AlreadyOpen
            Invoke-NpcPapyrus Actor SetDontMove $actor @($false) | Out-Null
            $summary.bypassKneeling=Wait-PeacefulPhase $actor 3
            if((Invoke-NpcPapyrus Actor GetActorValue $actor @('Aggression')).returned -ne $original -or
               -not (Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$actor})).returned -or
               (Invoke-NpcPapyrus Actor IsInCombat $actor).returned) {throw 'Bypass action changed aggression or pacification'}
        }
    }
    return @{message="PASS: native Talk observations; bypass=$Bypass; original-aggression attempts=$($originalCases.Count), all opened=$($summary.originalAggressionTalkPassed); aggression-1 attempts=$($oneCases.Count), all opened=$($summary.aggressionOneTalkPassed)";screenshot=$null}
} finally {
    Invoke-YieldTool input @{action='releaseAll';device='keyboard';owner=$RunId} | Out-Null
    if($actor) {
        Close-PeacefulDialogue $actor $RunId
        Invoke-NpcPapyrus Actor EnableAI $actor @($false) | Out-Null
        Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$actor}) | Out-Null
        Invoke-NpcPapyrus ObjectReference Disable $actor @($false) | Out-Null
        Invoke-NpcPapyrus ObjectReference Delete $actor | Out-Null
    }
    $summary.actorCleaned=$true
}
