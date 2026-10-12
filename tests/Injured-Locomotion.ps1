param([string] $RunId, [string] $RunDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Pacification-Fixture.ps1')
. (Join-Path $PSScriptRoot 'Injured-Animation-Evidence.ps1')
$actor=$null; $owned=@(); $summary.actorCleaned=$false
$animationLog=Join-Path (Split-Path -Parent $PrefsPath) 'SKSE\OpenAnimationReplacer.log'
try {
    foreach($relative in @('Data\SKSE\Plugins\OpenAnimationReplacer.dll','Data\SKSE\Plugins\AnimationQueueFix.dll','Data\meshes\actors\character\animations\DynamicAnimationReplacer\_CustomConditions\5000\_conditions.txt','Data\meshes\actors\character\animations\DynamicAnimationReplacer\_CustomConditions\5000\female\mt_walkforward.hkx')) {
        $summary.build[$relative]=(Get-FileHash -LiteralPath (Join-Path $GameRoot $relative)).Hash
    }
    $summary.animationPhases=@()
    foreach($phase in @('healthy','injured')) {
    $injured=$phase -eq 'injured'
    $before=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
    $spawn=(Invoke-NpcPapyrus ObjectReference PlaceAtMe '0x00000014' @(@{form=$yieldEnemyBase},1,$true,$true)).returned
    $after=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
    $actor=Resolve-NpcSpawn $before $after $yieldEnemyBase $spawn.formId
    $owned+=$actor
    Invoke-NpcPapyrus Actor EnableAI $actor @($false) | Out-Null
    Invoke-NpcPapyrus ObjectReference MoveTo $actor @(@{form='0x00000014'},-60.0,-85.0,0.0,$false) | Out-Null
    Invoke-NpcPapyrus ObjectReference Enable $actor @($false) | Out-Null
    $deadline=(Get-Date).AddSeconds(5)
    do {
        $loaded=(Invoke-NpcPapyrus ObjectReference Is3DLoaded $actor).returned
        if($loaded) {break}
        Start-Sleep -Milliseconds 100
    } while((Get-Date) -lt $deadline)
    if(-not $loaded) {throw 'Animation subject not loaded'}
    Set-NpcEnemyEquipment $actor | Out-Null
    Invoke-NpcPapyrus Actor SetActorValue $actor @('Health',100.0) | Out-Null
    Invoke-NpcPapyrus Actor SetActorValue $actor @('HealRate',0.0) | Out-Null
    if($injured) {Invoke-NpcPapyrus Actor DamageActorValue $actor @('Health',90.0) | Out-Null}
    $health=(Invoke-NpcPapyrus Actor GetActorValuePercentage $actor @('Health')).returned
    if(($injured -and ($health -lt 0.09 -or $health -gt 0.11)) -or (-not $injured -and $health -lt 0.99)) {throw 'Animation phase health mismatch'}
    Invoke-YieldTool menu @{action='open';name='Console'} | Out-Null
    Invoke-YieldTool console @{action='exec';capture=$true;command=('prid '+($actor -replace '^0x',''))} | Out-Null
    Invoke-YieldTool menu @{action='close';name='Console'} | Out-Null
    $selected=Invoke-YieldTool papyrus @{action='call';script='Form';function='GetFormID';self='selected';args=@()}
    if([uint32]([long]$selected.returned -band 0xFFFFFFFFL) -ne [Convert]::ToUInt32(($actor -replace '^0x',''),16)) {throw 'OAR console actor selection mismatch'}
    $start=(Get-Content $animationLog -Raw).Length
    $initial=(Invoke-YieldTool inspect @{kind='refs';formId=$actor}).refs[0].position
    Invoke-NpcPapyrus Actor EnableAI $actor @($true) | Out-Null
    if((Invoke-NpcPapyrus Acheron BeginPeacefulState '' @(@{form=$actor},120)).returned -ne $true) {throw 'Peaceful animation subject rejected'}
    Wait-PeacefulPhase $actor 2 | Out-Null
        $deadline=(Get-Date).AddSeconds(20);$evidence=$null;$moved=$false
        do {
            Start-Sleep -Milliseconds 300
            $log=(Get-Content $animationLog -Raw).Substring($start)
            $evidence=Find-InjuredLocomotion $log $injured
            $position=(Invoke-YieldTool inspect @{kind='refs';formId=$actor}).refs[0].position
            $moved=[Math]::Abs($position[0]-$initial[0])+[Math]::Abs($position[1]-$initial[1]) -gt 5
            if($evidence -and $moved) {break}
        } while((Get-Date) -lt $deadline)
        if(-not $evidence -or -not $moved) {throw "No selected moving locomotion evidence: $phase"}
        $selected=Invoke-YieldTool papyrus @{action='call';script='Form';function='GetFormID';self='selected';args=@()}
        if([uint32]([long]$selected.returned -band 0xFFFFFFFFL) -ne [Convert]::ToUInt32(($actor -replace '^0x',''),16)) {throw 'OAR actor selection changed during phase'}
        if((Invoke-NpcPapyrus Actor IsDead $actor).returned -or -not (Invoke-NpcPapyrus Acheron IsPeacefulState '' @(@{form=$actor})).returned) {throw 'Animation subject lost living peaceful state'}
        $summary.animationPhases+=@{actor=$actor;phase=$phase;health=$health;selectedClip=$evidence;initial=$initial;position=$position}
        Invoke-NpcPapyrus Actor EnableAI $actor @($false) | Out-Null
        Invoke-NpcPapyrus ObjectReference Disable $actor @($false) | Out-Null
    }
    return @{message='PASS: peaceful enemy selects wounded locomotion at 10%, normal at 100%; health set before movement';screenshot=$null}
} finally {
    foreach($actor in $owned) {
        Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$actor}) | Out-Null
        Invoke-NpcPapyrus ObjectReference Disable $actor @($false) | Out-Null
        Invoke-NpcPapyrus ObjectReference Delete $actor | Out-Null
    }
    $summary.actorCleaned=$true
}
