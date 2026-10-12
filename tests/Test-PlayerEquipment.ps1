$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Npc-Papyrus.ps1')
function Assert([bool] $Condition, [string] $Reason) {if(-not $Condition){throw "FAIL: $Reason"}}
function Invoke-YieldTool([string] $Name, [hashtable] $Arguments) {
    if($Name -eq 'inspect') {
        Assert ($Arguments.kind -eq 'inventory' -and $Arguments.formId -eq '0x00000014' -and $Arguments.limit -eq 100) 'wrong inventory snapshot request'
        $items=@(foreach($id in $equipmentState.items.Keys) {
            [pscustomobject]@{formId=$id;formType=$equipmentState.types[$id];count=$equipmentState.items[$id]}
        })
        return [pscustomobject]@{owner=@{formId='0x00000014';formType='ACHR'};count=$items.Count;returned=$items.Count;truncated=$false;items=$items}
    }
    Assert ($Name -eq 'papyrus') 'unexpected player equipment tool'
    $id=$Arguments.self.form;$a=$Arguments.args;$value=$null
    if($Arguments.script -ne 'Form') {Assert ($id -eq '0x00000014') 'player equipment changed another actor'}
    switch($Arguments.function) {
        'UnequipAll' {$equipmentState.right=$null;$equipmentState.shield=$null}
        'GetItemCount' {$value=if($equipmentState.items.Contains($a[0].form)){$equipmentState.items[$a[0].form]}else{0}}
        'RemoveItem' {
            Assert ($a.Count -eq 3 -and $a[2] -eq $true -and $Arguments.fillNeutral -eq $true) 'equipment removal has a destination or is not silent'
            Assert ($a[1] -eq $equipmentState.items[$a[0].form]) 'spare equipment not removed completely'
            if(-not $equipmentState.failRemove) {$equipmentState.items.Remove($a[0].form)}
        }
        'AddItem' {$equipmentState.items[$a[0].form]=$a[1]}
        'EquipItem' {
            if(-not $equipmentState.failEquip) {
                if($a[0].form -eq '0x00012EB7') {$equipmentState.right=$a[0].form}else{$equipmentState.shield=$a[0].form}
            }
        }
        'GetEquippedWeapon' {if(-not $a[0] -and $equipmentState.right){$value=@{formId=$equipmentState.right}}}
        'GetEquippedShield' {if($equipmentState.shield){$value=@{formId=$equipmentState.shield}}}
        default {throw "Unexpected player equipment call: $($Arguments.function)"}
    }
    return @{called=$true;returned=$value}
}
foreach($failure in @('none','failRemove','failEquip')) {
    $equipmentState=@{items=[ordered]@{'0x00012EB7'=2;'0x00012EB6'=3;'0x00000001'=1;'0x00000002'=1;'0x00000003'=1;'0x00000004'=20;'0x0000000F'=10;'0x0003EADD'=2};types=@{'0x00012EB7'='WEAP';'0x00012EB6'='ARMO';'0x00000001'='ARMO';'0x00000002'='ARMO';'0x00000003'='WEAP';'0x00000004'='AMMO';'0x0000000F'='MISC';'0x0003EADD'='ALCH'}}
    if($failure -ne 'none'){$equipmentState[$failure]=$true}
    $rejected=$false
    try {
        $result=Set-YieldPlayerEquipment
        if($failure -eq 'none') {
            Assert ($result.weapon -eq '0x00012EB7' -and $result.shield -eq '0x00012EB6' -and $result.armor -eq $false) 'wrong equipment summary'
            Assert ($equipmentState.items.Count -eq 4 -and $equipmentState.items['0x00012EB7'] -eq 1 -and $equipmentState.items['0x00012EB6'] -eq 1) 'armor, spare weapons or duplicate equipment retained'
            Assert ($equipmentState.items['0x0000000F'] -eq 10 -and $equipmentState.items['0x0003EADD'] -eq 2) 'non-equipment inventory lost'
            Set-YieldPlayerEquipment | Out-Null
            Assert ($equipmentState.items['0x00012EB7'] -eq 1 -and $equipmentState.items['0x00012EB6'] -eq 1) 'repeated equipment setup stacked items'
        }
    } catch {
        if($failure -eq 'none'){throw}
        $expected=if($failure -eq 'failRemove'){'Player fixture equipment removal failed'}else{'Player fixture sword/shield equipment incorrect'}
        Assert ($_.Exception.Message -eq $expected) 'unexpected equipment failure'
        $rejected=$true
    }
    Assert ($rejected -eq ($failure -ne 'none')) 'failed removal/equipping accepted'
}
'PASS: player sword/shield only, no armor, inventory preserved, repeat and failure checks; mocked DevBench'
