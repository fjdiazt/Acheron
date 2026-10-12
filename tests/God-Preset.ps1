param([string] $RunId, [string] $RunDirectory)
$player='0x00000014'
$spellId=(Invoke-NpcPapyrus Game GetFormFromFile '' @(0x807,'Acheron.esm')).returned.formId
if($spellId -notmatch '^0x[0-9A-Fa-f]{8}$') {throw 'Acheron load mapping unavailable'}
# DevBench omits IDs for script-bearing quests; use verified spell mapping.
$mcm='0x{0:X8}' -f ([Convert]::ToUInt32($spellId.Substring(2),16)-7)
Invoke-YieldTool console @{action='exec';command="resetquest $mcm"}|Out-Null
Start-Sleep -Milliseconds 500
Invoke-NpcPapyrus Quest Start $mcm | Out-Null
$oldKey=(Invoke-NpcPapyrus AcheronMCM GetSettingInt $mcm @('iGodKey')).returned
$logPath=Join-Path (Split-Path -Parent $PrefsPath) 'SKSE\Acheron.log'
$skills=@('OneHanded','TwoHanded','Marksman','Block','Smithing','HeavyArmor','LightArmor','Pickpocket','Lockpicking','Sneak','Alchemy','Speechcraft','Alteration','Conjuration','Destruction','Illusion','Restoration','Enchanting')
function Tap-GodKey([string] $Key) {
    Invoke-YieldTool input @{action='tap';device='keyboard';key=$Key;durationMs=60;owner=$RunId}|Out-Null
    Start-Sleep -Milliseconds 500
}
function God-Log {Get-Content -LiteralPath $logPath -Raw}
function Assert-GodCharacter {
    if((Invoke-NpcPapyrus Actor GetLevel $player).returned -lt 252) {throw 'God level missing'}
    foreach($av in $skills) {
        if((Invoke-NpcPapyrus Actor GetBaseActorValue $player @($av)).returned -lt 100) {throw "Skill below 100: $av"}
    }
    foreach($av in @('Health','Magicka','Stamina','CarryWeight')) {
        if((Invoke-NpcPapyrus Actor GetBaseActorValue $player @($av)).returned -lt 100000) {throw "Stat below 100000: $av"}
    }
    foreach($sample in @(@('HasPerk',0xBE123,'Skyrim.esm'),@('HasSpell',0x12FCD,'Skyrim.esm'),@('HasSpell',0xE40D5,'Skyrim.esm'),@('HasSpell',0xCC79A,'Skyrim.esm'))) {
        $form=(Invoke-NpcPapyrus Game GetFormFromFile '' @($sample[1],$sample[2])).returned.formId
        if(-not $form -or (Invoke-NpcPapyrus Actor $sample[0] $player @(@{form=$form})).returned -ne $true) {throw "Missing unlock: $($sample -join ',')"}
    }
    foreach($word in @(0x13E22,0x13E23,0x13E24)) {
        if((Invoke-NpcPapyrus Game IsWordUnlocked '' @(@{form=('0x{0:X8}' -f $word)})).returned -ne $true) {throw 'Unrelenting Force word not unlocked'}
    }
    foreach($excluded in @(0x10F71F,0x10FF0B,0x92C48)) {
        if((Invoke-NpcPapyrus Actor HasSpell $player @(@{form=('0x{0:X8}' -f $excluded)})).returned -eq $true) {throw 'NPC/quest/transformation ability granted'}
    }
}
try {
    if($oldKey -ne 34) {throw 'Expected default G binding (34)'}
    $offset=(God-Log).Length
    Tap-GodKey 'g'
    if((God-Log).Substring($offset) -notmatch '\[GodPreset\].*god=true') {throw 'G did not enable God preset'}
    if((God-Log).Substring($offset) -notmatch 'addedShouts=27\b') {throw 'Expected all 27 standard shouts newly granted'}
    Assert-GodCharacter
    Invoke-NpcPapyrus Actor SetActorValue $player @('CarryWeight',150000.0)|Out-Null
    $offset=(God-Log).Length
    Tap-GodKey 'g'
    if((God-Log).Substring($offset) -notmatch 'addedPerks=0 addedSpells=0 addedShouts=0') {throw 'Repeated God action granted duplicates'}
    if((Invoke-NpcPapyrus Actor GetBaseActorValue $player @('CarryWeight')).returned -ne 150000) {throw 'God action reduced higher stat'}
    Invoke-NpcPapyrus AcheronMCM SetSettingInt $mcm @('iGodKey',-1)|Out-Null
    $offset=(God-Log).Length
    Tap-GodKey 'g'
    if((God-Log).Substring($offset) -match '\[GodPreset\]') {throw 'Unbound key still triggered'}
    Invoke-NpcPapyrus AcheronMCM SetSettingInt $mcm @('iGodKey',35)|Out-Null
    $offset=(God-Log).Length
    Tap-GodKey 'g'
    if((God-Log).Substring($offset) -match '\[GodPreset\]') {throw 'Old key still triggered after remap'}
    Tap-GodKey 'h'
    if((God-Log).Substring($offset) -notmatch '\[GodPreset\]') {throw 'Remapped H key did not trigger'}
    $summary.godPresetVerified=$true
    $summary.actorCleaned=$true
    @{message='PASS: G preset, skills/stats/unlocks, repeat, higher stat, unbind, remap';screenshot=$null}
} finally {
    Invoke-NpcPapyrus AcheronMCM SetSettingInt $mcm @('iGodKey',$oldKey)|Out-Null
    Copy-Item -LiteralPath $logPath -Destination (Join-Path $RunDirectory 'GodPreset-Acheron.log')
}
