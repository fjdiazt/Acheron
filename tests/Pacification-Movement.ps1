param([string] $RunId, [string] $RunDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Pacification-Fixture.ps1')
. (Join-Path $PSScriptRoot 'Native-Peaceful-Evidence.ps1')
$player='0x00000014'; $owned=@(); $summary.actorCleaned=$false
$logPath=Join-Path (Split-Path -Parent $PrefsPath) 'SKSE\Acheron.log'
function Read-PeacefulActor([string] $ActorId) {
    return @{ref=(Invoke-YieldTool inspect @{kind='refs';formId=$ActorId}).refs[0];package=(Invoke-NpcPapyrus Actor GetCurrentPackage $ActorId).returned}
}
try {
    Invoke-NpcPapyrus Actor SetActorValue $player @('Health',10000.0) | Out-Null
    foreach($role in @('subject','enemy','guard')) {
        $base=if($role -eq 'guard') {'0x000D3154'} else {$yieldEnemyBase}
        $before=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
        $spawn=(Invoke-NpcPapyrus ObjectReference PlaceAtMe $player @(@{form=$base},1,$true,$false)).returned
        $after=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
        $id=Resolve-NpcSpawn $before $after $base $spawn.formId
        $owned+=$id; Set-Variable $role $id
        Invoke-NpcPapyrus Actor EnableAI $id @($false) | Out-Null
        if($base -eq $yieldEnemyBase) {Set-NpcEnemyEquipment $id | Out-Null}
        $x=if($role -eq 'subject') {-120.0} elseif($role -eq 'guard') {80.0} else {0.0}
        Invoke-NpcPapyrus ObjectReference MoveTo $id @(@{form=$player},$x,-85.0,0.0,$false) | Out-Null
        Invoke-NpcPapyrus Actor SetActorValue $id @('Health',10000.0) | Out-Null
        Invoke-NpcPapyrus Actor SetActorValue $id @('Confidence',4.0) | Out-Null
    }
    foreach($id in @($enemy,$guard)) {Invoke-NpcPapyrus Actor EnableAI $id @($true) | Out-Null}
    $start=(Get-Content $logPath -Raw).Length
    Invoke-NpcPapyrus Actor StartCombat $guard @(@{form=$enemy}) | Out-Null
    $pattern='\[YieldHit\] target='+($enemy -replace '^0x','')+' source='+($guard -replace '^0x','')+' damage=(?<damage>[0-9.eE+-]+) immune=false'
    $deadline=(Get-Date).AddSeconds(20)
    do {
        $log=(Get-Content $logPath -Raw).Substring($start)
        $hit=[regex]::Match($log,$pattern)
        if($hit.Success -and [double]$hit.Groups['damage'].Value -gt 0) {break}
        Start-Sleep -Milliseconds 100
    } while((Get-Date) -lt $deadline)
    if(-not $hit.Success -or [double]$hit.Groups['damage'].Value -le 0) {throw 'No real guard hit before pacification'}
    Invoke-NpcPapyrus Actor EnableAI $subject @($true) | Out-Null
    $initial=(Invoke-YieldTool inspect @{kind='refs';formId=$subject}).refs[0].position
    if((Invoke-NpcPapyrus Acheron BeginPeacefulState '' @(@{form=$subject},60)).returned -ne $true) {throw 'Movement entry rejected'}
    $anchorKey=(Invoke-NpcPapyrus Game GetFormFromFile '' @(0x811,'Acheron.esm')).returned.formId
    $anchorId=(Invoke-NpcPapyrus ObjectReference GetLinkedRef $subject @(@{form=$anchorKey})).returned.formId
    if(-not $anchorId) {throw 'Controller anchor missing'}
    $anchor=(Invoke-YieldTool inspect @{kind='refs';formId=$anchorId}).refs[0]
    $avoid=(Invoke-NpcPapyrus Game GetFormFromFile '' @(0x813,'Acheron.esm')).returned.formId
    $wander=(Invoke-NpcPapyrus Game GetFormFromFile '' @(0x814,'Acheron.esm')).returned.formId
    $samples=@(); foreach($i in 1..10) {$samples+=Read-PeacefulActor $subject;Start-Sleep -Milliseconds 300}
    $summary.avoidance=$samples
    Assert-NativePeacefulMovement $samples $subject $avoid $anchor $initial
    foreach($id in @($guard,$enemy)) {
        Invoke-NpcPapyrus Actor EnableAI $id @($false) | Out-Null
        Invoke-NpcPapyrus Actor StopCombat $id | Out-Null
    }
    Invoke-NpcPapyrus Actor StopCombat $player | Out-Null
    $initial=(Invoke-YieldTool inspect @{kind='refs';formId=$subject}).refs[0].position
    $deadline=(Get-Date).AddSeconds(5)
    do {
        $package=(Invoke-NpcPapyrus Actor GetCurrentPackage $subject).returned.formId
        if($package -eq $wander) {break};Start-Sleep -Milliseconds 100
    } while((Get-Date) -lt $deadline)
    if($package -ne $wander) {throw 'Combat end did not enter wandering'}
    $samples=@(); foreach($i in 1..12) {$samples+=Read-PeacefulActor $subject;Start-Sleep -Milliseconds 300}
    $summary.wandering=$samples
    Assert-NativePeacefulMovement $samples $subject $wander $anchor $initial
    $beforeRestart=Read-PeacefulState $subject
    foreach($id in @($guard,$enemy)) {Invoke-NpcPapyrus Actor EnableAI $id @($true) | Out-Null}
    Invoke-NpcPapyrus Actor StartCombat $guard @(@{form=$enemy}) | Out-Null
    $avoiding=Wait-PeacefulPhase $subject 1
    Start-Sleep -Milliseconds 1500
    $held=Read-PeacefulState $subject
    if([math]::Abs($held.remaining-$avoiding.remaining) -gt 0.05 -or $held.remaining -gt $beforeRestart.remaining) {throw 'Combat restarted/reset the wandering timer'}
    foreach($id in @($guard,$enemy)) {
        Invoke-NpcPapyrus Actor EnableAI $id @($false) | Out-Null
        Invoke-NpcPapyrus Actor StopCombat $id | Out-Null
    }
    Invoke-NpcPapyrus Actor StopCombat $player | Out-Null
    $resumed=Wait-PeacefulPhase $subject 2
    if($resumed.remaining -gt $held.remaining+0.1) {throw 'Combat end restarted a full timer'}
    $summary.combatRestart=@{before=$beforeRestart;avoiding=$avoiding;held=$held;resumed=$resumed}
    # DevBench returns the attached perk script without formId; use the verified plugin mapping.
    if($avoid -notmatch '813$') {throw 'Unexpected peaceful package mapping'}
    $perk=$avoid -replace '813$','803'
    Invoke-NpcPapyrus Actor AddPerk $player @(@{form=$perk}) | Out-Null
    if((Invoke-NpcPapyrus Actor HasPerk $player @(@{form=$perk})).returned -ne $true) {throw 'Interaction perk not active'}
    Invoke-NpcPapyrus Acheron BeginPeacefulState '' @(@{form=$subject},30) | Out-Null
    Invoke-NpcPapyrus ObjectReference Activate $subject @(@{form=$player},$false) | Out-Null
    $deadline=(Get-Date).AddSeconds(3)
    do {
        $summary.dialogue=Invoke-YieldTool menu @{action='list'}
        if($summary.dialogue.openMenus -contains 'Dialogue Menu') {break}
        Start-Sleep -Milliseconds 100
    } while((Get-Date) -lt $deadline)
    if($summary.dialogue.openMenus -notcontains 'Dialogue Menu') {throw 'Standing managed opponent not talkable with interaction perk'}
    if((Invoke-NpcPapyrus Acheron IsPeacefulState '' @(@{form=$subject})).returned -ne $true) {throw 'Talk released peaceful state'}
    Invoke-NpcPapyrus Acheron BeginPeacefulState '' @(@{form=$subject},3) | Out-Null
    Start-Sleep -Milliseconds 3500
    if((Invoke-NpcPapyrus Acheron IsPeacefulState '' @(@{form=$subject})).returned -ne $true) {throw 'Timer expired inside player dialogue'}
    Invoke-YieldTool menu @{action='close';name='Dialogue Menu'} | Out-Null
    $deadline=(Get-Date).AddSeconds(6)
    do {
        $active=(Invoke-NpcPapyrus Acheron IsPeacefulState '' @(@{form=$subject})).returned
        if(-not $active) {break}
    } while((Get-Date) -lt $deadline)
    if($active) {throw 'Dialogue closed but automatic expiry did not resume'}
    $summary.nativeLog=(Get-Content $logPath -Raw).Substring($start)
    return @{message='PASS: controller avoidance, wandering, Talk and standing activation exemption';screenshot=$null}
} finally {
    foreach($id in $owned) {
        if((Invoke-NpcPapyrus Acheron IsPeacefulState '' @(@{form=$id})).returned) {Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$id}) | Out-Null}
        Invoke-NpcPapyrus ObjectReference Disable $id @($false) | Out-Null
        Invoke-NpcPapyrus ObjectReference Delete $id | Out-Null
    }
    $summary.actorCleaned=$true
}
