$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$topic=Join-Path $repo 'res/DialogTopics/AcheronPeacefulStandTopic - 000832_Acheron.esm/RecordData.yaml'
if(-not (Test-Path -LiteralPath $topic)) {throw 'On your feet native dialogue topic missing'}
$record=Get-Content -LiteralPath $topic -Raw
if($record -notmatch 'Value: On your feet\.') {throw 'On your feet command label missing'}
$info=Get-Content -LiteralPath (Join-Path (Split-Path -Parent $topic) 'Responses/000833_Acheron.esm.yaml') -Raw
if($info -notmatch 'Package: 00081A:Acheron.esm' -or $info -match 'Package: 00081E:Acheron.esm') {throw 'On your feet must target only unbound Kneeling'}
'PASS: native On your feet label and Kneeling-only condition'
