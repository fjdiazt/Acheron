$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Native-Peaceful-Evidence.ps1')
function Sample([double] $X, [string] $Actor = '0xFF000111', [string] $Package = '0xFE003813') {
    @{ ref=@{formId=$Actor;position=@($X,0.0,0.0);actor=@{alive=$true;loaded3D=$true};cell=@{formId='0x000EA28B'}}; package=@{formId=$Package} }
}
$anchor = @{position=@(0.0,0.0,0.0);cell=@{formId='0x000EA28B'}}
$valid = @((Sample 0),(Sample 100))
Assert-NativePeacefulMovement @((Sample 100),(Sample 100)) '0xFF000111' '0xFE003813' $anchor @(0,0,0)
Assert-NativePeacefulMovement $valid '0xFF000111' '0xFE003813' $anchor
foreach ($bad in @(
    @((Sample 0),(Sample 0)),
    @((Sample 0),(Sample 801)),
    @((Sample 0),(Sample 100 '0xFF000222')),
    @((Sample 0),(Sample 100 '0xFF000111' '0xFE003814'))
)) {
    $rejected = $false
    try { Assert-NativePeacefulMovement $bad '0xFF000111' '0xFE003813' $anchor } catch { $rejected=$true }
    if (-not $rejected) { throw 'Invalid native movement accepted' }
}
foreach ($flag in @('alive','loaded3D')) {
    $bad = @((Sample 0),(Sample 100)); $bad[1].ref.actor[$flag]=$false
    $rejected=$false
    try { Assert-NativePeacefulMovement $bad '0xFF000111' '0xFE003813' $anchor } catch { $rejected=$true }
    if (-not $rejected) { throw 'Invalid actor accepted' }
}
'PASS: native movement rejects stationary, distant, wrong actor/package and unavailable actors'
