param([string] $RunId, [string] $RunDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Pacification-Fixture.ps1')
$player='0x00000014'; $actor=$null
$summary.actorCleaned=$false; $summary.aggressionProbe=@()
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
            if($actual -ne 0 -and $actual -ne $original) {throw 'Unexpected probe aggression'}
            Invoke-NpcPapyrus ObjectReference MoveTo $actor @(@{form=$player},0.0,-85.0,0.0,$false) | Out-Null
            $summary.probePosition=Invoke-YieldTool inspect @{kind='refs';formId=$actor}
            foreach($pitch in @(0,15,30,45,60,75)) {
                Invoke-NpcPapyrus ObjectReference SetAngle $player @([double]$pitch,0.0,180.0) | Out-Null
                Start-Sleep -Milliseconds 100
                $pick=Read-PeacefulDialogue $actor
                if($pick.crosshair -eq $actor) {break}
            }
            if($pick.crosshair -ne $actor) {throw 'Probe crosshair missed expected actor'}
            Invoke-YieldTool input @{action='tap';device='keyboard';key='e';durationMs=50;owner=$RunId} | Out-Null
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
            $summary.aggressionProbe+=,$case
            if($case.aggressionAfter -ne $actual -or -not $case.pacified -or $case.combat -or
               $case.defeated -ne ($phase -eq 'yielding')) {throw 'Probe changed aggression or pacification during Talk'}
            if($actual -eq 0 -and -not $choice) {throw 'Zero-aggression control failed; comparison invalid'}
        }
    }
    $originalCases=@($summary.aggressionProbe | Where-Object {$_.aggression -eq $original})
    $summary.originalAggressionAttempts=$originalCases.Count
    $summary.originalAggressionTalkPassed=if($originalCases.Count -eq 4) {@($originalCases | Where-Object {-not $_.choicesReady}).Count -eq 0}else{$null}
    return @{message="PASS: native Talk observations; original-aggression attempts=$($originalCases.Count), all opened=$($summary.originalAggressionTalkPassed)";screenshot=$null}
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
