$ErrorActionPreference='Stop'
$tokens=$null; $parseErrors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'Rescue-Locomotion.ps1'),[ref]$tokens,[ref]$parseErrors)
if($parseErrors) {throw ($parseErrors | Out-String)}
$request=$ast.Find({param($node)
    $node -is [Management.Automation.Language.TryStatementAst] -and
    $node.Body.Statements.Count -eq 1 -and $node.Body.Extent.Text -like "*function='PathToReference'*"
},$true)
if(-not $request) {throw 'Walking request boundary missing'}
$request=[scriptblock]::Create($request.Extent.Text)
$ActorId='0xFF000001'; $player='0x00000014'
function Invoke-YieldTool {
    $exception=[Exception]::new('fixture response')
    $exception | Add-Member Response ([pscustomobject]@{StatusCode=$script:status})
    $record=[Management.Automation.ErrorRecord]::new($exception,'fixture',[Management.Automation.ErrorCategory]::InvalidOperation,$null)
    $record.ErrorDetails=[Management.Automation.ErrorDetails]::new((@{error=$script:message}|ConvertTo-Json -Compress))
    throw $record
}
foreach($case in @(
    @{status=504;message="papyrus call 'Actor.PathToReference' was dispatched but did not complete within 1000ms";pending=$true},
    @{status=504;message="papyrus call 'Actor.PathToReference' was not dispatched within 1000ms";pending=$false},
    @{status=504;message="papyrus call 'Actor.EnableAI' was dispatched but did not complete within 1000ms";pending=$false},
    @{status=404;message="papyrus call 'Actor.PathToReference' was dispatched but did not complete within 1000ms";pending=$false},
    @{status=504;message='Gateway unavailable';pending=$false}
)) {
    $script:status=$case.status; $script:message=$case.message
    $pathPending=$false; $rejected=$false
    try {. $request} catch {$rejected=$true}
    if($case.pending -ne $pathPending -or $rejected -eq $case.pending) {throw "Walking request boundary failed: $($case.message)"}
}
'PASS: only dispatched PathToReference completion timeout becomes pending; other failures reject'
