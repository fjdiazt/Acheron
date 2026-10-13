param([string] $RunId, [string] $RunDirectory, [switch] $Silent)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Pacification-Fixture.ps1')
$player='0x00000014'; $actor=$null; $control=$null; $summary.greetings=@(); $summary.actorCleaned=$false
try {
    Invoke-YieldTool console @{action='exec';command='setini "bDialogueSubtitles:Interface" 1'} | Out-Null
    Invoke-YieldTool console @{action='exec';command='setini "bGeneralSubtitles:Interface" 1'} | Out-Null
    $before=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
    $spawn=(Invoke-NpcPapyrus ObjectReference PlaceAtMe $player @(@{form=$yieldEnemyBase},1,$true,$true)).returned
    $after=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
    $actor=Resolve-NpcSpawn $before $after $yieldEnemyBase $spawn.formId
    Invoke-NpcPapyrus Actor EnableAI $actor @($false) | Out-Null
    Invoke-NpcPapyrus ObjectReference MoveTo $actor @(@{form=$player},0.0,-150.0,0.0,$false) | Out-Null
    Invoke-NpcPapyrus ObjectReference Enable $actor @($false) | Out-Null
    Set-NpcEnemyEquipment $actor | Out-Null
    Invoke-NpcPapyrus Actor SetActorValue $actor @('HealRate',0.0) | Out-Null
    Invoke-NpcPapyrus Actor SetActorValue $actor @('HealRateMult',0.0) | Out-Null
    $aggression=(Invoke-NpcPapyrus Actor GetActorValue $actor @('Aggression')).returned
    Invoke-NpcPapyrus Acheron DefeatActor '' @(@{form=$actor}) | Out-Null
    Invoke-NpcPapyrus Actor EnableAI $actor @($true) | Out-Null
    Invoke-NpcPapyrus Acheron KneelActor '' @(@{form=$actor}) | Out-Null
    $state=Wait-PeacefulPhase $actor 3 20
    if($Silent) {
        Select-PeacefulDialogueChoice $actor 'Test' 0x837 $RunId | Out-Null
        Select-PeacefulDialogueChoice $actor 'Kneel (Regular)' 0x843 $RunId -AlreadyOpen | Out-Null
        $state=Wait-PeacefulPhase $actor 3 20
        if($state.selectedKneelingVariant -ne 0) {throw 'Silent regular-pose control failed'}
    }
    if((Invoke-NpcPapyrus Actor GetSitState $actor).returned -ne 3) {throw 'Greeting fixture not actually kneeling'}
    $health=(Invoke-NpcPapyrus Actor GetActorValue $actor @('Health')).returned
    $summary.actor=$actor; $summary.kneeling=$state; $summary.originalAggression=$aggression
    $ranks=if($Silent) {@(0)}else{@(-3,0)}
    foreach($rank in $ranks) {
        Invoke-NpcPapyrus Actor SetRelationshipRank $actor @(@{form=$player},$rank) | Out-Null
        if((Invoke-NpcPapyrus Actor GetRelationshipRank $actor @(@{form=$player})).returned -ne $rank) {throw 'Disposable relationship control failed'}
        for($attempt=1;$attempt -le 8;$attempt++) {
            Close-PeacefulDialogue $actor $RunId
            $deadline=(Get-Date).AddSeconds(10)
            do {$sit=(Invoke-NpcPapyrus Actor GetSitState $actor).returned; if($sit -eq 3) {break}; Start-Sleep -Milliseconds 100} while((Get-Date) -lt $deadline)
            if($sit -ne 3) {throw 'NPC did not return to kneeling before next interaction'}
            $start=(Get-Content $logPath -Raw).Length
            Invoke-NpcPapyrus ObjectReference Activate $actor @(@{form=$player},$false) | Out-Null
            $deadline=(Get-Date).AddSeconds(8); $snapshots=@(); $choice=$null
            do {
                $snapshot=Read-PeacefulDialogue $actor
                $snapshots+=,$snapshot
                try {$choice=Assert-PeacefulDialogueChoice $snapshot $actor 'On your feet.'} catch {}
                if($choice) {break}
                Start-Sleep -Milliseconds 50
            } while((Get-Date) -lt $deadline)
            if(-not $choice) {throw 'Greeting interaction failed to reach native choices'}
            $speech=@((Get-Content $logPath -Raw).Substring($start) -split "`n" | Where-Object {$_ -match '\[ManagedSpeech\].*begin=true'})
            $summary.greetings+=@{rank=$rank;attempt=$attempt;speech=$speech;snapshots=$snapshots;sitDuringDialogue=(Invoke-NpcPapyrus Actor GetSitState $actor).returned}
            if($Silent) {
                foreach($observed in $snapshots) {
                    if($null -eq $observed.subtitleText) {throw 'Dialogue caption field not observed'}
                    if(@($observed.spoken | Where-Object {-not [string]::IsNullOrWhiteSpace($_.text)}).Count -or
                       -not [string]::IsNullOrWhiteSpace($observed.subtitleText) -or
                       @($observed.subtitles | Where-Object {-not [string]::IsNullOrWhiteSpace($_)}).Count) {throw 'Opening voice text or caption escaped suppression'}
                }
                if((Invoke-NpcPapyrus Actor GetSitState $actor).returned -ne 3 -or
                   (Invoke-NpcPapyrus Actor GetRelationshipRank $actor @(@{form=$player})).returned -ne 0) {throw 'Silent greeting changed pose or relationship rank'}
            }
            if((Invoke-NpcPapyrus Actor GetActorValue $actor @('Aggression')).returned -ne $aggression -or
               (Invoke-NpcPapyrus Actor GetActorValue $actor @('Health')).returned -ne $health -or
               (Invoke-NpcPapyrus Actor IsInCombat $actor).returned -or
               -not (Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$actor})).returned) {throw 'Greeting changed health/aggression/pacification'}
        }
    }
    $summary.standSelection=Select-PeacefulDialogueChoice $actor 'On your feet.' 0x833 $RunId -AlreadyOpen
    Wait-PeacefulPhase $actor 2 20 | Out-Null
    Invoke-NpcPapyrus Acheron KneelActor '' @(@{form=$actor}) | Out-Null
    Wait-PeacefulPhase $actor 3 20 | Out-Null
    $summary.bindSelection=Select-PeacefulDialogueChoice $actor 'Bind' 0x820 $RunId
    $summary.bound=Wait-PeacefulPhase $actor 4 20
    $summary.boundSelection=Select-PeacefulDialogueChoice $actor 'Continue.' 0x817 $RunId
    if($Silent) {
        Close-PeacefulDialogue $actor $RunId
        $before=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
        $spawn=(Invoke-NpcPapyrus ObjectReference PlaceAtMe $player @(@{form='0x00013BBF'},1,$true,$false)).returned
        $after=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
        $control=Resolve-NpcSpawn $before $after '0x00013BBF' $spawn.formId
        Invoke-NpcPapyrus Actor EnableAI $control @($false) | Out-Null
        Invoke-NpcPapyrus Actor AllowPCDialogue $control @($true) | Out-Null
        Invoke-NpcPapyrus ObjectReference MoveTo $control @(@{form=$player},150.0,-150.0,0.0,$false) | Out-Null
        Invoke-NpcPapyrus Actor EnableAI $control @($true) | Out-Null
        $deadline=(Get-Date).AddSeconds(5)
        do {$loaded=(Invoke-NpcPapyrus ObjectReference Is3DLoaded $control).returned} while(-not $loaded -and (Get-Date) -lt $deadline)
        if(-not $loaded) {throw 'Unmanaged civilian did not load'}
        $start=(Get-Content $logPath -Raw).Length
        Invoke-NpcPapyrus ObjectReference Activate $control @(@{form=$player},$false) | Out-Null
        $deadline=(Get-Date).AddSeconds(8)
        do {
            $snapshot=Read-PeacefulDialogue $control
            if(@($snapshot.subtitles|Where-Object {-not [string]::IsNullOrWhiteSpace($_)}).Count) {break}
        } while((Get-Date) -lt $deadline)
        $summary.unmanagedCivilian=$snapshot
        $summary.unmanagedSpeech=@((Get-Content $logPath -Raw) -split "`n"|Where-Object {$_ -match ('\[UnmanagedSpeech\] actor='+($control -replace '^0x','')+'.*begin=true')})
        if(-not @($snapshot.subtitles|Where-Object {-not [string]::IsNullOrWhiteSpace($_)}).Count -or -not $summary.unmanagedSpeech.Count -or
           (Get-Content $logPath -Raw).Substring($start) -match '\[NativeTalk\]|\[SilentGreetingProbe\]' -or
           (Invoke-NpcPapyrus Acheron IsPeacefulState '' @(@{form=$control})).returned) {throw 'Unmanaged civilian speech/caption control missing or intercepted'}
        Close-PeacefulDialogue $control $RunId
    }
    return @{message='PASS: repeated kneeling greeting observations; native choices/actions preserved';screenshot=$null}
} finally {
    if($control) {
        Close-PeacefulDialogue $control $RunId
        Invoke-NpcPapyrus ObjectReference Disable $control @($false) | Out-Null
        Invoke-NpcPapyrus ObjectReference Delete $control | Out-Null
    }
    if($actor) {
        Close-PeacefulDialogue $actor $RunId
        Invoke-NpcPapyrus Actor EnableAI $actor @($false) | Out-Null
        Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$actor}) | Out-Null
        Invoke-NpcPapyrus ObjectReference Disable $actor @($false) | Out-Null
        Invoke-NpcPapyrus ObjectReference Delete $actor | Out-Null
    }
    $summary.actorCleaned=$true
}
