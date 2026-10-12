$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Npc-Papyrus.ps1')
$original = [pscustomobject]@{ formId='0x000A2C94'; formType='ACHR'; base=@{formId='0x000A2C8E'} }
$spawn = [pscustomobject]@{ formId='0xFF000123'; formType='ACHR'; base=@{formId='0x000A2C8E'} }
$before = @{truncated=$false;refs=@($original)}
$after = @{truncated=$false;refs=@($original,$spawn)}
if ((Resolve-NpcSpawn $before $after '0x000A2C8E') -ne $spawn.formId) { throw 'New Lydia copy not resolved' }
foreach ($bad in @(
    @{truncated=$true;refs=@($spawn)},
    @{truncated=$false;refs=@($original)},
    @{truncated=$false;refs=@($spawn,([pscustomobject]@{formId='0xFF000124';formType='ACHR';base=@{formId='0x000A2C8E'}}))},
    @{truncated=$false;refs=@([pscustomobject]@{formId='0xFF000125';formType='ACHR';base=@{formId=$yieldEnemyBase}})}
)) {
    $rejected=$false
    try { Resolve-NpcSpawn $before $bad '0x000A2C8E' | Out-Null } catch { $rejected=$true }
    if (-not $rejected) { throw 'Ambiguous, foreign or incomplete spawn ownership accepted' }
}
$rejected=$false
try { Resolve-NpcSpawn $after $after '0x000A2C8E' | Out-Null } catch { $rejected=$true }
if (-not $rejected) { throw 'Pre-existing dynamic actor accepted' }
$guard = [pscustomobject]@{formId='0xFF000126';formType='ACHR';base=@{formId='0xFF000127';formType='NPC_'}}
$afterGuard = @{truncated=$false;refs=@($original,$guard)}
if ((Resolve-NpcSpawn $before $afterGuard '0x000D3154' $guard.formId) -ne $guard.formId) { throw 'Returned guard with generated base rejected' }
foreach ($returnedId in @('', '0xFF000128', $original.formId)) {
    $rejected=$false
    try { Resolve-NpcSpawn $before $afterGuard '0x000D3154' $returnedId | Out-Null } catch { $rejected=$true }
    if (-not $rejected) { throw 'Generated base accepted without matching spawn return' }
}
$rejected=$false
try { Resolve-NpcSpawn $before $after '0x000D3154' $spawn.formId | Out-Null } catch { $rejected=$true }
if (-not $rejected) { throw 'Wrong static base accepted via returned ID' }
'PASS: owned spawn identification rejects original, stale, foreign and ambiguous references'
