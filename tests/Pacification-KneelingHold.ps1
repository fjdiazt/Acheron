param([string] $RunId, [string] $RunDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Pacification-Fixture.ps1')
$actor=$null; $summary.actorCleaned=$false; $summary.holdSamples=@()
$animationLog=Join-Path (Split-Path -Parent $PrefsPath) 'SKSE\OpenAnimationReplacer.log'
try {
    $player='0x00000014'
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
    Invoke-YieldTool menu @{action='open';name='Console'} | Out-Null
    Invoke-YieldTool console @{action='exec';command=('prid '+($actor -replace '^0x',''))} | Out-Null
    Invoke-YieldTool menu @{action='close';name='Console'} | Out-Null
    Invoke-NpcPapyrus Acheron DefeatActor '' @(@{form=$actor}) | Out-Null
    Invoke-NpcPapyrus Actor EnableAI $actor @($true) | Out-Null
    Select-PeacefulDialogueChoice $actor 'Test' 0x836 $RunId | Out-Null
    $start=(Get-Content $animationLog -Raw).Length
    Select-PeacefulDialogueChoice $actor 'Kneel (Blessing)' 0x845 $RunId -AlreadyOpen | Out-Null
    $initial=Wait-PeacefulPhase $actor 3 20
    if($initial.selectedKneelingVariant -ne 1) {throw 'Blessing variant not selected'}
    $poseFaction=(Invoke-NpcPapyrus Game GetFormFromFile '' @(0x84D,'Acheron.esm')).returned.formId
    if((Invoke-NpcPapyrus Actor GetFactionRank $actor @(@{form=$poseFaction})).returned -ne 1) {throw 'Scoped blessing marker missing'}
    $health=(Invoke-NpcPapyrus Actor GetActorValue $actor @('Health')).returned
    $aggression=(Invoke-NpcPapyrus Actor GetActorValue $actor @('Aggression')).returned
    $clock=[Diagnostics.Stopwatch]::StartNew()
    do {
        $state=Read-PeacefulState $actor
        $sit=(Invoke-NpcPapyrus Actor GetSitState $actor).returned
        $log=(Get-Content $animationLog -Raw).Substring($start)
        $summary.holdSamples+=@{seconds=$clock.Elapsed.TotalSeconds;state=$state;sit=$sit}
        if($state.phase -ne 3 -or -not $state.ready -or $sit -ne 3 -or $state.goal -ne $initial.goal -or
           $state.commandHoldRemaining -lt 1750 -or $log -match 'AnimationLogEntry:.*(?:IdleKneelExit|IdleBlessingKneel_Exit)\.hkx') {
            throw 'Kneeling exited before command/hold expiry'
        }
        Start-Sleep -Milliseconds 100
    } while($clock.Elapsed.TotalSeconds -lt 12)
    $held=(Get-Content $animationLog -Raw).Substring($start)
    foreach($clip in @('idlekneelenter','idlekneelidle')) {
        if($held -notmatch ('AnimationLogEntry:.*_CustomConditions[\\/]5003[\\/]'+$clip+'\.hkx')) {throw "Scoped blessing replacement missing: $clip"}
    }
    if([regex]::Matches($held,'AnimationLogEntry: Loop animation.*_CustomConditions[\\/]5003[\\/]idlekneelidle\.hkx','IgnoreCase').Count -lt 2) {throw 'Blessing clip did not repeat during hold'}
    for($i=0;$i -lt 3;$i++) {
        Invoke-NpcPapyrus ObjectReference Activate $actor @(@{form=$player},$false) | Out-Null
        $deadline=(Get-Date).AddSeconds(8)
        do {$dialogue=Read-PeacefulDialogue $actor; $choice=$null; try {$choice=Assert-PeacefulDialogueChoice $dialogue $actor 'On your feet.'} catch {}} while(-not $choice -and (Get-Date) -lt $deadline)
        if(-not $choice -or (Invoke-NpcPapyrus Actor GetSitState $actor).returned -ne 3) {throw 'Talk interrupted held kneeling'}
        Close-PeacefulDialogue $actor $RunId
        if((Get-Content $animationLog -Raw).Substring($start) -match 'AnimationLogEntry:.*(?:IdleKneelExit|IdleBlessingKneel_Exit)\.hkx') {throw 'Talk played premature kneeling exit'}
    }
    $summary.stand=Select-PeacefulDialogueChoice $actor 'On your feet.' 0x833 $RunId
    $summary.after=Wait-PeacefulPhase $actor 2 20
    $summary.animationEvidence=(Get-Content $animationLog -Raw).Substring($start)
    if($summary.animationEvidence -notmatch 'AnimationLogEntry:.*_CustomConditions[\\/]5003[\\/]idlekneelexit\.hkx' -or
       (Invoke-NpcPapyrus Actor IsInFaction $actor @(@{form=$poseFaction})).returned) {throw 'Exit override or animation marker cleanup failed'}
    if((Invoke-NpcPapyrus Actor GetActorValue $actor @('Health')).returned -ne $health -or
       (Invoke-NpcPapyrus Actor GetActorValue $actor @('Aggression')).returned -ne $aggression -or
       -not (Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$actor})).returned) {throw 'Pose transition changed actor invariants'}
    # Same animation graph outside commanded Kneeling must retain vanilla clips.
    Invoke-NpcPapyrus Actor EnableAI $actor @($false) | Out-Null
    $controlStart=(Get-Content $animationLog -Raw).Length
    Invoke-NpcPapyrus Debug SendAnimationEvent '' @(@{form=$actor},'IdleKneelingEnterInstant') | Out-Null
    $deadline=(Get-Date).AddSeconds(5)
    do {$control=(Get-Content $animationLog -Raw).Substring($controlStart)} while($control -notmatch 'AnimationLogEntry:.*IdleKneelIdle\.hkx' -and (Get-Date) -lt $deadline)
    if($control -notmatch 'AnimationLogEntry:.*IdleKneelIdle\.hkx.* - original ' -or
       $control -match '_CustomConditions[\\/]500[23][\\/]') {throw 'Kneeling replacement leaked outside owned pose'}
    $summary.unownedPoseControl=$control
    Invoke-NpcPapyrus Debug SendAnimationEvent '' @(@{form=$actor},'IdleChairExitStart') | Out-Null
    @{message='PASS: blessing sustained hold, native Talk/stand and scoped animation control';screenshot=$null}
} finally {
    if($actor) {Invoke-NpcPapyrus ObjectReference Disable $actor @($false) | Out-Null; Invoke-NpcPapyrus ObjectReference Delete $actor | Out-Null}
    $summary.actorCleaned=$true
}
