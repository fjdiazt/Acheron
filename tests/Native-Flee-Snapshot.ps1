function Read-FleeProbe([string] $ActorId, [int] $Action=2, [switch] $AfterPrompt) {
    if($Action -ne 0) {Resolve-YieldStartupPrompts}
    $start=(Get-Content $logPath -Raw).Length
    if(-not (Invoke-NpcPapyrus Acheron ProbeNativeFlee '' @(@{form=$ActorId},$Action)).returned) {throw 'Native flee diagnostic rejected actor/action'}
    $deadline=(Get-Date).AddSeconds(3)
    do {
        $log=Get-Content $logPath -Raw
        if($log.Length -ge $start) {
            foreach($match in [regex]::Matches($log.Substring($start),'\[NativeFleeProbe\] (?<json>\{[^\r\n]*\})')) {
                $sample=$match.Groups['json'].Value|ConvertFrom-Json
                if($sample.actor -eq $ActorId -and $sample.action -eq $Action) {
                    if($sample.paused -and $Action -ne 0) {
                        $declines=[int]$summary.survivalPromptDeclines
                        Resolve-YieldStartupPrompts
                        if($AfterPrompt -or [int]$summary.survivalPromptDeclines -le $declines) {throw 'Native flee snapshot paused without a newly handled Survival prompt'}
                        $summary.promptPausedSnapshots+=,$sample
                        # Resnapshot only; never repeat a flight mutation after dismissing a late modal.
                        return Read-FleeProbe $ActorId 2 -AfterPrompt
                    }
                    return $sample
                }
            }
        }
        Start-Sleep -Milliseconds 25
    } while((Get-Date) -lt $deadline)
    throw 'Native flee task did not produce snapshot'
}
