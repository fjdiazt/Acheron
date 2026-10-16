$ErrorActionPreference='Stop'
$file=Join-Path $PSScriptRoot 'Pacification-Fixture.ps1'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($file,[ref]$tokens,[ref]$errors)
if($errors) {throw $errors}
$function=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Read-PeacefulState'},$true)
Invoke-Expression $function.Extent.Text
$logPath='mock.log';$script:reads=0
$line='[PeacefulSnapshot] actor=FF000904 phase=7 remaining=60 generation=17 anchor=FF000905 goal=FF000906 ready=true loaded=true commandHoldRemaining=0 selectedKneelingVariant=0 selectedSittingVariant=0 injuryHealth=0 fleeRemaining='
function Invoke-NpcPapyrus {}
function Get-Content {
    param($Path,[switch]$Raw)
    $script:reads++
    if($script:reads -eq 1) {return ''}
    if($script:reads -eq 2) {return ($line+'2')}
    return ($line+"29.732937`r`n")
}
$result=Read-PeacefulState '0xFF000904'
if($result.fleeRemaining -ne 29.732937 -or $result.generation -ne 17) {throw 'Partial log line accepted as a completed snapshot'}
'PASS: snapshots wait for complete log lines before parsing timer values'
