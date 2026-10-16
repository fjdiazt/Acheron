$ErrorActionPreference='Stop'
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'Native-Flee-Probe.ps1'),[ref]$null,[ref]$null)
$function=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Read-FleeProbe'},$true)
. ([scriptblock]::Create($function.Extent.Text))
$logPath=Join-Path ([IO.Path]::GetTempPath()) ('flee-snapshot-'+[guid]::NewGuid()+'.log')
function Invoke-NpcPapyrus($Script,$Function,$SelfId,$Arguments) {
    $script:actions.Add([int]$Arguments[1])
    $script:lastPaused=$actions.Count -eq 1 -or $mode -eq 'persistent'
    $sample=@{actor='0xFF000001';action=$Arguments[1];paused=$lastPaused}
    Add-Content -LiteralPath $logPath -Value ('[NativeFleeProbe] '+($sample|ConvertTo-Json -Compress))
    return @{returned=$true}
}
function Resolve-YieldStartupPrompts {
    if(-not $lastPaused) {return}
    if($mode -eq 'unknown') {throw 'Unexpected message box blocked test; inspect blockingDialog'}
    if($mode -ne 'noPrompt') {$summary.survivalPromptDeclines=[int]$summary.survivalPromptDeclines+1;$script:lastPaused=$false}
}
try {
    foreach($mode in @('survival','unknown','noPrompt','persistent')) {
        [IO.File]::WriteAllText($logPath,'')
        $summary=@{};$lastPaused=$false;$actions=[Collections.Generic.List[int]]::new();$failure=$null
        try {$sample=Read-FleeProbe '0xFF000001' 3} catch {$failure=$_.Exception.Message}
        if($mode -eq 'survival') {
            if($failure -or $sample.paused -or ($actions -join ',') -ne '3,2' -or @($summary.promptPausedSnapshots).Count -ne 1) {throw 'Known late prompt did not resnapshot without repeating mutation'}
        } elseif($mode -eq 'unknown') {
            if($failure -ne 'Unexpected message box blocked test; inspect blockingDialog') {throw 'Unknown prompt was swallowed'}
        } elseif($failure -ne 'Native flee snapshot paused without a newly handled Survival prompt') {throw 'Unexplained or persistent pause was accepted'}
    }
} finally {if(Test-Path -LiteralPath $logPath) {Remove-Item -LiteralPath $logPath}}
'PASS: late Survival prompt resnapshots once; flight mutation never repeated; unknown/persistent pauses fail'
