$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$topic=Join-Path $repo 'res/DialogTopics/AcheronPeacefulStandTopic - 000832_Acheron.esm/RecordData.yaml'
if(-not (Test-Path -LiteralPath $topic)) {throw 'On your feet native dialogue topic missing'}
$record=Get-Content -LiteralPath $topic -Raw
if($record -notmatch 'Value: On your feet\.') {throw 'On your feet command label missing'}
$info=Get-Content -LiteralPath (Join-Path (Split-Path -Parent $topic) 'Responses/000833_Acheron.esm.yaml') -Raw
if($info -notmatch 'Faction: 000850:Acheron.esm' -or $info -notmatch 'ComparisonValue: 3' -or
   $info -notmatch 'CompareOperator: GreaterThanOrEqualTo' -or $info -notmatch 'ComparisonValue: 4' -or
   $info -notmatch 'CompareOperator: NotEqualTo' -or $info -match 'GetIsCurrentPackage') {throw 'On your feet must target unbound commanded phases, excluding bound'}
'PASS: native On your feet label and logical unbound-phase conditions'
