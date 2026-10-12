$ErrorActionPreference='Stop'
function Assert([bool] $Condition, [string] $Reason) {
    if(-not $Condition) {throw "FAIL: $Reason"}
}
# Force every catalog choice through the real setup; only randomness is controlled.
function Get-Random([object[]] $InputObject) {
    if($InputObject[0] -is [string]) {return $InputObject[[int]$scenarioTestState.enemyIndex]}
    return $InputObject[[int]$scenarioTestState.followerIndex]
}
# Exercise the real fixture with only the DevBench boundary replaced.
function Invoke-YieldTool([string] $Name, [hashtable] $Arguments) {
    $scenarioTestState.calls.Add(@{tool=$Name;args=$Arguments})
    if($Name -eq 'console') {
        Assert ($Arguments.action -eq 'exec' -and $Arguments.command -eq 'tgm') 'unexpected setup console command'
        $scenarioTestState.godModeRequested=$true
        return @{queued=$true}
    }
    if($Name -eq 'camera') {return @{freeCam=$false}}
    if($Name -eq 'inspect') {
        if($Arguments.kind -eq 'inventory') {
            $items=@(foreach($id in $scenarioTestState.actors[$Arguments.formId].items) {
                $type=switch($id){'0x00000001'{'WEAP'};'0x00000002'{'AMMO'};'0x00012EB7'{'WEAP'};default{'ARMO'}}
                [pscustomobject]@{formId=$id;formType=$type;count=1}
            })
            return [pscustomobject]@{owner=@{formId=$Arguments.formId;formType='ACHR'};count=$items.Count;returned=$items.Count;truncated=$false;items=$items}
        }
        return @{refs=@($scenarioTestState.actors.Values | ForEach-Object {$_.ref});truncated=$false}
    }
    if($Name -ne 'papyrus') {throw "Unexpected tool: $Name"}
    $id=$Arguments.self.form;$a=$Arguments.args;$value=$null
    switch($Arguments.function) {
        'GetFormFromFile' {
            $value=if($a[0] -eq 0x803){@{scriptType='PRKF_AcheronInteraction_05000805'}}else{@{formId=('0xFE003{0:X3}' -f $a[0])}}
        }
        'HasMagicEffect' {$value=$true}
        'AddPerk' {
            Assert ($a[0].form -eq '0xFE003803') 'interaction perk mapped to wrong load-order ID'
            $scenarioTestState.perkAdded=$true
        }
        'HasPerk' {$value=$scenarioTestState.perkAdded -and -not $scenarioTestState.failPerk}
        'PlaceAtMe' {
            Assert ($scenarioTestState.perkAdded) 'actors spawned before interaction initialized'
            Assert ($scenarioTestState.godModeRequested) 'actors spawned before God mode requested'
            $id='0xFF{0:X6}' -f (1+$scenarioTestState.actors.Count)
            $scenarioTestState.actors[$id]=@{ref=@{formId=$id;formType='ACHR';base=@{formId=$a[0].form}};teammate=$false;ai=$false;enabled=$false;deleted=$false;items=@('0x00000001','0x00000002','0x00000003','0x00000004');right='0x00000001';left='0x00000001';shield='0x00000003'}
            $value=@{formId=$id}
        }
        'GetBaseObject' {$value=$scenarioTestState.actors[$id].ref.base}
        'GetSex' {$value=if($scenarioTestState.failSex){0}else{1}}
        'GetSlotMask' {$value=if($id -eq '0x00000003'){512}else{4}}
        'GetItemCount' {$value=@($scenarioTestState.actors[$id].items | Where-Object {$_ -eq $a[0].form}).Count}
        'RemoveItem' {
            Assert (-not $scenarioTestState.actors[$id].ai) 'inventory changed with combat AI enabled'
            Assert ($a[2] -eq $true -and $a.Count -eq 3 -and $Arguments.fillNeutral -eq $true) 'removed equipment transferred to another actor or not silent'
            $scenarioTestState.actors[$id].items=@($scenarioTestState.actors[$id].items | Where-Object {$_ -ne $a[0].form})
            foreach($slot in @('right','left','shield')) {if($scenarioTestState.actors[$id][$slot] -eq $a[0].form){$scenarioTestState.actors[$id][$slot]=$null}}
        }
        'AddItem' {$scenarioTestState.actors[$id].items+=@($a[0].form)}
        'EquipItem' {if(-not $scenarioTestState.failEquipment){$scenarioTestState.actors[$id].right=$a[0].form}}
        'GetEquippedWeapon' {$slot=if($a[0]){'left'}else{'right'};if($scenarioTestState.actors[$id][$slot]){$value=@{formId=$scenarioTestState.actors[$id][$slot]}}}
        'GetEquippedShield' {if($scenarioTestState.actors[$id].shield){$value=@{formId=$scenarioTestState.actors[$id].shield}}}
        'EnableAI' {$scenarioTestState.actors[$id].ai=$a[0]}
        'SetGhost' {$scenarioTestState.actors[$id].ghost=$a[0]}
        'SetPlayerTeammate' {$scenarioTestState.actors[$id].teammate=$a[0]}
        'SetDisplayName' {$value=-not ($scenarioTestState.failLabel -and $scenarioTestState.actors.Count -eq 2)}
        'Enable' {
            Assert ($scenarioTestState.actors[$id].ghost) 'actor exposed to early player hits during setup'
            $scenarioTestState.actors[$id].enabled=$true
        }
        'Disable' {$scenarioTestState.actors[$id].enabled=$false}
        'Delete' {$scenarioTestState.actors[$id].deleted=$true}
        'Is3DLoaded' {$value=$scenarioTestState.actors[$id].enabled}
        'IsPlayerTeammate' {$value=$scenarioTestState.actors[$id].teammate}
        'IsHostileToActor' {$value=$scenarioTestState.actors[$id].ref.base.formId -in @('0x00043BE1','0x00043BE0','0x00043BE2')}
        'IsDead' {$value=$false}
        'IsDefeated' {
            $actor=$scenarioTestState.actors[$a[0].form]
            Assert ($actor.ghost) 'starting state checked after removing setup protection'
            $value=-not $actor.ghost
        }
        {$_ -in @('AddSpell','SetAngle','MoveTo','SetFactionRank','SetActorValue')} {}
        default {throw "Unexpected Papyrus call: $($Arguments.function)"}
    }
    return @{called=$true;returned=$value}
}
$cases=@(foreach($enemyIndex in 0..2) {
    @{withFollower=$false;enemyIndex=$enemyIndex;followerIndex=0}
    foreach($followerIndex in 0..4) {@{withFollower=$true;enemyIndex=$enemyIndex;followerIndex=$followerIndex}}
})
$callCounts=@{}
foreach($case in $cases) {
    $withFollower=$case.withFollower
    $scenarioTestState=@{actors=@{};calls=[Collections.Generic.List[object]]::new();failLabel=$false;enemyIndex=$case.enemyIndex;followerIndex=$case.followerIndex};$summary=[ordered]@{}
    $result=& (Join-Path $PSScriptRoot '../scripts/Setup-Scenario.ps1') -RunId 'self-check' -RunDirectory $PSScriptRoot -WithFollower:$withFollower
    $count=if($withFollower){2}else{1}
    Assert ($summary.scenarioReady -and $summary.actors.Count -eq $count -and $scenarioTestState.actors.Count -eq $count) 'wrong scenario actors or no handoff'
    Assert (-not $summary.actorCleaned -and $result.message -like 'READY:*') 'successful scenario cleaned up or claimed test PASS'
    Assert ($scenarioTestState.perkAdded) 'interaction perk never added'
    Assert ($summary.godModeRequested -and @($scenarioTestState.calls | Where-Object {$_.tool -eq 'console' -and $_.args.command -eq 'tgm'}).Count -eq 1) 'God mode toggle missing or repeated'
    foreach($actor in $scenarioTestState.actors.Values) {Assert ($actor.enabled -and $actor.ai -and -not $actor.deleted -and -not $actor.ghost) 'successful actor not left running or setup protection leaked'}
    Assert (@($summary.actors | Where-Object {$_.role -eq 'enemy' -and $_.hostileToPlayer -and -not $_.teammate}).Count -eq 1) 'enemy role wrong'
    $enemy=$summary.actors | Where-Object {$_.role -eq 'enemy'}
    Assert ($enemy.base -eq @('0x00043BE1','0x00043BE0','0x00043BE2')[$case.enemyIndex] -and $enemy.equipment.sex -eq 1 -and $enemy.equipment.weapon -eq '0x00012EB7' -and $enemy.equipment.shield -eq $false) 'female Forsworn equipment summary wrong'
    if($withFollower) {
        $follower=$summary.actors | Where-Object {$_.role -eq 'follower'}
        Assert ($follower.base -eq @('0x000A2C8E','0x000A2C8F','0x000A2C91','0x000A2C90','0x000A2C8C')[$case.followerIndex]) 'wrong follower selection'
    }
    $key=[string]$withFollower
    if($callCounts.ContainsKey($key)) {Assert ($scenarioTestState.calls.Count -eq $callCounts[$key]) 'selection added game calls'}
    else {$callCounts[$key]=$scenarioTestState.calls.Count}
    $inventory=$scenarioTestState.actors[$enemy.formId].items
    Assert ($inventory.Count -eq 2 -and '0x00000004' -in $inventory -and '0x00012EB7' -in $inventory) 'enemy armor removed or spare combat equipment retained'
    Assert (@($summary.actors | Where-Object {$_.role -eq 'follower' -and -not $_.hostileToPlayer -and $_.teammate}).Count -eq [int]$withFollower) 'follower role wrong'
    Assert (@($scenarioTestState.calls | Where-Object {$_.args.function -in @('StartCombat','DamageActorValue','Kill','SetDontMove')}).Count -eq 0) 'setup forced attacks, death or movement lock'
}
$scenarioTestState=@{actors=@{};calls=[Collections.Generic.List[object]]::new();failLabel=$true};$summary=[ordered]@{};$rejected=$false
try {& (Join-Path $PSScriptRoot '../scripts/Setup-Scenario.ps1') -WithFollower | Out-Null} catch {
    Assert ($_.Exception.Message -eq 'Scenario label did not apply') 'unexpected setup failure'
    $rejected=$true
}
Assert ($rejected -and -not $summary.scenarioReady -and $summary.actorCleaned -and $scenarioTestState.actors.Count -eq 2) 'partial failure not reported'
foreach($actor in $scenarioTestState.actors.Values) {Assert ($actor.deleted -and -not $actor.enabled) 'partial failure leaked owned actor'}
$scenarioTestState=@{actors=@{};calls=[Collections.Generic.List[object]]::new();failPerk=$true};$summary=[ordered]@{};$rejected=$false
try {& (Join-Path $PSScriptRoot '../scripts/Setup-Scenario.ps1') | Out-Null} catch {
    Assert ($_.Exception.Message -eq 'Interaction perk missing') 'unexpected perk failure'
    $rejected=$true
}
Assert ($rejected -and -not $summary.scenarioReady -and $scenarioTestState.actors.Count -eq 0) 'missing interaction perk allowed manual handoff'
foreach($failure in @(@{flag='failSex';message='Enemy fixture must be female'},@{flag='failEquipment';message='Enemy fixture sword-only equipment incorrect'})) {
    $scenarioTestState=@{actors=@{};calls=[Collections.Generic.List[object]]::new()};$scenarioTestState[$failure.flag]=$true
    $summary=[ordered]@{};$rejected=$false
    try {& (Join-Path $PSScriptRoot '../scripts/Setup-Scenario.ps1') | Out-Null} catch {
        Assert ($_.Exception.Message -eq $failure.message) 'unexpected enemy fixture failure'
        $rejected=$true
    }
    Assert ($rejected -and -not $summary.scenarioReady -and $summary.actorCleaned -and $scenarioTestState.actors.Count -eq 1) 'invalid enemy reached manual handoff'
    foreach($actor in $scenarioTestState.actors.Values) {Assert ($actor.deleted -and -not $actor.enabled) 'invalid enemy leaked owned actor'}
}
. (Join-Path $PSScriptRoot 'Npc-Papyrus.ps1')
$scenarioTestState=@{actors=@{};calls=[Collections.Generic.List[object]]::new()};$rejected=$false
try {Set-NpcEnemyEquipment '0x00000014' | Out-Null} catch {
    Assert ($_.Exception.Message -eq 'Enemy fixture must be a disposable actor') 'unexpected persistent actor failure'
    $rejected=$true
}
Assert ($rejected -and $scenarioTestState.calls.Count -eq 0) 'persistent actor inventory could be changed'
$scenarioTestState.actors['0xFF000001']=@{enabled=$true;ref=@{base=@{formId='0x000A2C8E'}}};$rejected=$false
try {Set-NpcEnemyEquipment '0xFF000001' | Out-Null} catch {
    Assert ($_.Exception.Message -eq 'Unexpected enemy fixture base') 'unexpected foreign base failure'
    $rejected=$true
}
Assert ($rejected -and @($scenarioTestState.calls | Where-Object {$_.args.function -in @('RemoveItem','AddItem','EquipItem')}).Count -eq 0) 'foreign NPC inventory could be changed'
Write-Output 'PASS: all 3 Forsworn / 5 follower choices, unchanged call counts, sword-only equipment, handoff, ownership guards and failure cleanup; mocked DevBench'
