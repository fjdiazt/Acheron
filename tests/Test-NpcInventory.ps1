$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Npc-Papyrus.ps1')
function Invoke-YieldTool([string] $Name, [hashtable] $Arguments) {
    if($Name -ne 'inspect' -or $Arguments.kind -ne 'inventory' -or $Arguments.formId -ne '0x00000014' -or $Arguments.limit -ne 100) {throw 'Wrong inventory request'}
    $script:requests++
    $snapshot=@{owner=@{formId='0x00000014';formType='ACHR'};count=2;returned=2;truncated=$false;items=@(
        @{formId='0x00012EB7';formType='WEAP';count=2},@{formId='0x0000000F';formType='MISC';count=10})}
    switch($failure) {
        'empty' {$snapshot.count=0;$snapshot.returned=0;$snapshot.items=@()}
        'wrongOwner' {$snapshot.owner.formId='0xFF000001'}
        'wrongType' {$snapshot.owner.formType='CONT'}
        'truncated' {$snapshot.truncated=$true}
        'missingTruncated' {$snapshot.Remove('truncated')}
        'missingCount' {$snapshot.Remove('count')}
        'missingReturned' {$snapshot.Remove('returned')}
        'missingItems' {$snapshot.Remove('items')}
        'incomplete' {$snapshot.returned=1}
        'invalidId' {$snapshot.items[0].formId='bad'}
        'missingType' {$snapshot.items[0].Remove('formType')}
        'invalidType' {$snapshot.items[0].formType=41}
        'missingItemCount' {$snapshot.items[0].Remove('count')}
        'invalidCount' {$snapshot.items[0].count=1.5}
        'zeroCount' {$snapshot.items[0].count=0}
        'negativeCount' {$snapshot.items[0].count=-1}
        'duplicate' {$snapshot.items[1].formId=$snapshot.items[0].formId}
        'timeout' {throw '504: fixture timeout'}
    }
    # Match REST JSON integer types, rather than testing only PowerShell literals.
    return $snapshot | ConvertTo-Json -Depth 5 | ConvertFrom-Json
}
$requests=0
$cases=@('none','empty','wrongOwner','wrongType','truncated','missingTruncated','missingCount','missingReturned','missingItems','incomplete','invalidId','missingType','invalidType','missingItemCount','invalidCount','zeroCount','negativeCount','duplicate','timeout')
foreach($failure in $cases) {
    $valid=$failure -in @('none','empty');$rejected=$false
    try {
        $items=@(Get-NpcInventory '0x00000014')
        if($valid -and ($items.Count -ne $(if($failure -eq 'empty'){0}else{2}) -or ($failure -eq 'none' -and $items[0].count -ne 2))) {throw 'Wrong inventory results'}
    } catch {if($valid){throw};$rejected=$true}
    if($rejected -eq $valid) {throw "Incorrect snapshot acceptance: $failure"}
}
if($requests -ne $cases.Count) {throw 'Inventory snapshot retried a request'}
'PASS: single inventory snapshot, empty inventory, owner/completeness/item validation, no retries'
