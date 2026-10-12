param([string] $RunId, [string] $RunDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Pacification-Fixture.ps1')
. (Join-Path $PSScriptRoot 'Injured-Animation-Evidence.ps1')
$player='0x00000014'; $owned=[Collections.Generic.List[string]]::new(); $summary.actorCleaned=$false
$animationLog=Join-Path (Split-Path -Parent $PrefsPath) 'SKSE\OpenAnimationReplacer.log'
$summary.animationPhases=@()
$worldLogStart=(Get-Content $logPath -Raw).Length
function Test-RescueWorldChanged {
    return (Get-Content $logPath -Raw).Substring($worldLogStart) -match 'Finished loading data from cosave'
}
function New-RescueAnimationActor([string] $Base, [double] $X, [double] $Health=10000) {
    $before=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
    $spawn=(Invoke-NpcPapyrus ObjectReference PlaceAtMe $player @(@{form=$Base},1,$true,$true)).returned
    $after=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
    $id=Resolve-NpcSpawn $before $after $Base $spawn.formId
    $owned.Add($id)
    Invoke-NpcPapyrus Actor EnableAI $id @($false) | Out-Null
    Invoke-NpcPapyrus ObjectReference MoveTo $id @(@{form=$player},$X,-85.0,0.0,$false) | Out-Null
    Invoke-NpcPapyrus ObjectReference Enable $id @($false) | Out-Null
    $deadline=(Get-Date).AddSeconds(5)
    do {
        $loaded=(Invoke-NpcPapyrus ObjectReference Is3DLoaded $id).returned
        if($loaded) {break}; Start-Sleep -Milliseconds 100
    } while((Get-Date) -lt $deadline)
    if(-not $loaded) {throw 'Rescue animation actor did not load'}
    if($Base -eq $yieldEnemyBase) {Set-NpcEnemyEquipment $id | Out-Null}
    Invoke-NpcPapyrus Actor SetActorValue $id @('Health',$Health) | Out-Null
    Invoke-NpcPapyrus Actor SetActorValue $id @('HealRate',0.0) | Out-Null
    Invoke-NpcPapyrus Actor SetActorValue $id @('Confidence',4.0) | Out-Null
    if((Invoke-NpcPapyrus Actor GetActorValue $id @('Health')).returned -lt $Health-0.1) {throw 'Fixture health was not applied after actor initialization'}
    return $id
}
function Select-RescueAnimationActor([string] $ActorId) {
    Invoke-YieldTool menu @{action='open';name='Console'} | Out-Null
    Invoke-YieldTool console @{action='exec';capture=$true;command=('prid '+($ActorId -replace '^0x',''))} | Out-Null
    Invoke-YieldTool menu @{action='close';name='Console'} | Out-Null
    $selected=Invoke-YieldTool papyrus @{action='call';script='Form';function='GetFormID';self='selected';args=@()}
    if([uint32]([long]$selected.returned -band 0xFFFFFFFFL) -ne [Convert]::ToUInt32(($ActorId -replace '^0x',''),16)) {throw 'OAR actor selection mismatch'}
}
function Assert-RescueLocomotion([string] $ActorId, [int] $Phase, [bool] $Rescued, [scriptblock] $EnterPhase) {
    Select-RescueAnimationActor $ActorId
    & $EnterPhase
    Wait-PeacefulPhase $ActorId $Phase | Out-Null
    # Restart from the tested floor position; teleporting during travel can cancel the logged clip.
    Invoke-NpcPapyrus Actor EnableAI $ActorId @($false) | Out-Null
    Invoke-NpcPapyrus ObjectReference MoveTo $ActorId @(@{form=$player},-60.0,-85.0,0.0,$false) | Out-Null
    $initial=(Invoke-YieldTool inspect @{kind='refs';formId=$ActorId}).refs[0].position
    # Phase transitions can leave old clips in the log; require a fresh settled-phase selection.
    $start=(Get-Content $animationLog -Raw).Length
    Invoke-NpcPapyrus Actor EnableAI $ActorId @($true) | Out-Null
    $walk=$null; $pathPending=$false
    try {
        $walk=Invoke-YieldTool papyrus @{action='call';script='Actor';function='PathToReference';self=@{form=$ActorId};args=@(@{form=$player},0.0);timeoutMs=1000}
    } catch {
        # A dispatched latent request can outlive transport; the real movement/clip checks below remain mandatory.
        $errorBody=$_.ErrorDetails.Message | ConvertFrom-Json
        if([int]$_.Exception.Response.StatusCode -ne 504 -or $errorBody.error -notlike "papyrus call 'Actor.PathToReference' was dispatched but did not complete*") {throw}
        $pathPending=$true
    }
    if($walk -and -not $walk.called) {throw 'Native walking request not executed'}
    $deadline=(Get-Date).AddSeconds(20); $clip=$null; $moved=$false
    do {
        Start-Sleep -Milliseconds 200
        if(Test-RescueWorldChanged) {throw 'Test world replaced by save load; owned references are stale'}
        $clip=Find-InjuredLocomotion ((Get-Content $animationLog -Raw).Substring($start)) $Rescued 5001
        $position=(Invoke-YieldTool inspect @{kind='refs';formId=$ActorId}).refs[0].position
        $moved=[math]::Abs($position[0]-$initial[0])+[math]::Abs($position[1]-$initial[1]) -gt 5
        if($clip -and $moved) {break}
    } while((Get-Date) -lt $deadline)
    if(-not $clip -or -not $moved) {throw "No selected locomotion with movement: phase=$Phase rescued=$Rescued"}
    $state=Read-PeacefulState $ActorId
    if(-not $state.ready -or $state.phase -ne $Phase) {throw 'Actor left required phase during animation evidence'}
    $package=(Invoke-NpcPapyrus Actor GetCurrentPackage $ActorId).returned.formId
    if($package -notmatch $(if($Phase -eq 1) {'813$'} else {'814$'})) {throw 'Walking request replaced managed package'}
    $health=(Invoke-NpcPapyrus Actor GetActorValuePercentage $ActorId @('Health')).returned
    if($health -lt 0.99 -or (Invoke-NpcPapyrus Actor IsDead $ActorId).returned -or (Invoke-NpcPapyrus Actor IsInCombat $ActorId).returned) {throw 'Expected healthy living non-combat animation subject'}
    if((Invoke-NpcPapyrus Actor IsInFaction $ActorId @(@{form=$marker})).returned -ne $Rescued) {throw 'Rescue marker scope mismatch'}
    $selected=Invoke-YieldTool papyrus @{action='call';script='Form';function='GetFormID';self='selected';args=@()}
    if([uint32]([long]$selected.returned -band 0xFFFFFFFFL) -ne [Convert]::ToUInt32(($ActorId -replace '^0x',''),16)) {throw 'OAR actor selection changed during observation'}
    $summary.animationPhases+=@{actor=$ActorId;phase=$Phase;rescued=$Rescued;health=$health;package=$package;stimulus='Actor.PathToReference';pathCompleted=$walk.returned;pathCompletionPending=$pathPending;selectedClip=$clip;initial=$initial;position=$position}
}
try {
    # shortcut: toggle once in this fresh session; use a state-aware setter if the runner reuses worlds.
    Invoke-YieldTool console @{action='exec';command='tgm'} | Out-Null
    $summary.godModeRequested=$true
    $marker=(Invoke-NpcPapyrus Game GetFormFromFile '' @(0x819,'Acheron.esm')).returned.formId
    if($marker -notmatch '819$') {throw 'Rescued wounded faction missing'}
    foreach($relative in @('Data\Acheron.esm','Data\SKSE\Plugins\Acheron.dll','Data\meshes\actors\character\animations\DynamicAnimationReplacer\_CustomConditions\5001\_conditions.txt')) {
        $summary.build[$relative]=(Get-FileHash -LiteralPath (Join-Path $GameRoot $relative)).Hash
    }
    $subject=New-RescueAnimationActor $yieldEnemyBase -60 100
    Invoke-NpcPapyrus Acheron DefeatActor '' @(@{form=$subject}) | Out-Null
    if(-not (Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$subject})).returned -or (Invoke-NpcPapyrus Actor IsInFaction $subject @(@{form=$marker})).returned) {throw 'Bleeding fixture or initial marker incorrect'}
    $summary.bleedingHealth=(Invoke-NpcPapyrus Actor GetActorValue $subject @('Health')).returned
    $enemy=New-RescueAnimationActor $yieldEnemyBase 0
    $guard=New-RescueAnimationActor '0x000D3154' 80
    foreach($id in @($guard,$enemy)) {Invoke-NpcPapyrus Actor EnableAI $id @($true) | Out-Null}
    Invoke-NpcPapyrus Actor StartCombat $guard @(@{form=$enemy}) | Out-Null
    Invoke-NpcPapyrus Actor StartCombat $enemy @(@{form=$guard}) | Out-Null
    if(-not (Invoke-NpcPapyrus Actor IsInCombat $guard).returned) {throw 'Nearby combat did not start'}
    $potion=(Invoke-NpcPapyrus Game GetFormFromFile '' @(0x39BE5,'Skyrim.esm')).returned.formId
    if($potion -ne '0x00039BE5' -or (Invoke-NpcPapyrus Potion GetNthEffectMagnitude $potion @(0)).returned -lt 100) {throw 'Full-healing potion fixture mismatch'}
    Invoke-NpcPapyrus ObjectReference AddItem $subject @(@{form=$potion},1,$true) | Out-Null
    Assert-RescueLocomotion $subject 1 $true {
        Invoke-NpcPapyrus Actor EquipItem $subject @(@{form=$potion},$false,$true) | Out-Null
        Invoke-NpcPapyrus Actor EnableAI $subject @($true) | Out-Null
    }
    if((Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$subject})).returned -or (Invoke-NpcPapyrus ObjectReference GetItemCount $subject @(@{form=$potion})).returned -ne 0) {throw 'Rescue did not end bleeding and consume one potion'}
    if((Invoke-NpcPapyrus Actor IsDead $player).returned) {throw 'Animation fixture player died'}
    Assert-RescueLocomotion $subject 2 $true {
        foreach($id in @($guard,$enemy)) {
            Invoke-NpcPapyrus Actor EnableAI $id @($false) | Out-Null
            Invoke-NpcPapyrus Actor StopCombat $id | Out-Null
        }
        Invoke-NpcPapyrus Actor StopCombat $player | Out-Null
    }
    foreach($id in @($guard,$enemy)) {Invoke-NpcPapyrus ObjectReference Disable $id @($false) | Out-Null}
    # Refresh the existing owner: keep the rescue marker but shorten only this wandering test.
    Invoke-NpcPapyrus Acheron BeginPeacefulState '' @(@{form=$subject},3) | Out-Null
    $deadline=(Get-Date).AddSeconds(8)
    do {
        $active=(Invoke-NpcPapyrus Acheron IsPeacefulState '' @(@{form=$subject})).returned
        if(-not $active) {break}; Start-Sleep -Milliseconds 100
    } while((Get-Date) -lt $deadline)
    if($active -or (Invoke-NpcPapyrus Actor IsInFaction $subject @(@{form=$marker})).returned) {throw 'Wandering expiry retained rescued animation marker'}
    $summary.markerClearedOnExpiry=$true
    Invoke-NpcPapyrus Actor EnableAI $subject @($false) | Out-Null
    Invoke-NpcPapyrus Actor StopCombat $subject | Out-Null
    Invoke-NpcPapyrus Actor StopCombat $player | Out-Null
    Assert-RescueLocomotion $subject 2 $false {
        Invoke-NpcPapyrus Acheron BeginPeacefulState '' @(@{form=$subject},60) | Out-Null
        Invoke-NpcPapyrus Actor EnableAI $subject @($true) | Out-Null
    }
    $summary.normalLocomotionAfterExpiry=$true
    Invoke-NpcPapyrus Actor EnableAI $subject @($false) | Out-Null
    Invoke-NpcPapyrus ObjectReference Disable $subject @($false) | Out-Null
    $control=New-RescueAnimationActor $yieldEnemyBase -60 100
    Assert-RescueLocomotion $control 2 $false {
        Invoke-NpcPapyrus Acheron BeginPeacefulState '' @(@{form=$control},60) | Out-Null
        Invoke-NpcPapyrus Actor EnableAI $control @($true) | Out-Null
    }
    if(Test-RescueWorldChanged) {throw 'Test world replaced by save load; owned references are stale'}
    return @{message='PASS: bleeding rescue selects wounded locomotion at full health in avoidance and wandering; marker expires; non-rescued control stays normal';screenshot=$null}
} finally {
    if(Test-RescueWorldChanged) {
        $summary.actorCleanupSkipped='World replaced by save load; preserve references in user-loaded world'
    } else {
        foreach($id in $owned) {
            Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$id}) | Out-Null
            if((Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$id})).returned) {Invoke-NpcPapyrus Acheron RescueActor '' @(@{form=$id},$true) | Out-Null}
            Invoke-NpcPapyrus ObjectReference Disable $id @($false) | Out-Null
            Invoke-NpcPapyrus ObjectReference Delete $id | Out-Null
        }
        $summary.actorCleaned=$true
    }
}
