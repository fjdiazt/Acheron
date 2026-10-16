param([string] $RunId, [string] $RunDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Npc-Papyrus.ps1')
. (Join-Path $PSScriptRoot 'Yield-StartupPrompts.ps1')
$player='0x00000014'; $actor=$null; $summary.actorCleaned=$false
$logPath=Join-Path (Split-Path -Parent $PrefsPath) 'SKSE\Acheron.log'
function Read-FleeProbe([string] $ActorId, [int] $Action=2) {
    if($Action -ne 0) {Resolve-YieldStartupPrompts}
    $start=(Get-Content $logPath -Raw).Length
    if(-not (Invoke-NpcPapyrus Acheron ProbeNativeFlee '' @(@{form=$ActorId},$Action)).returned) {throw 'Native flee diagnostic rejected actor/action'}
    $deadline=(Get-Date).AddSeconds(3)
    do {
        $log=Get-Content $logPath -Raw
        if($log.Length -ge $start) {
            foreach($match in [regex]::Matches($log.Substring($start),'\[NativeFleeProbe\] (?<json>\{[^\r\n]*\})')) {
                $sample=$match.Groups['json'].Value|ConvertFrom-Json
                if($sample.actor -eq $ActorId -and $sample.action -eq $Action) {return $sample}
            }
        }
        Start-Sleep -Milliseconds 25
    } while((Get-Date) -lt $deadline)
    throw 'Native flee task did not produce snapshot'
}
try {
    Invoke-YieldTool console @{action='exec';command='coc WhiterunExterior16'} | Out-Null
    $deadline=(Get-Date).AddSeconds(45); $cell=$null
    do {
        try {$cell=(Invoke-YieldTool inspect @{kind='refs';formId=$player}).refs[0].cell.editorId}
        catch {if($_.ErrorDetails.Message -notmatch 'queued task abandoned') {throw}; $cell=$null}
        Start-Sleep -Milliseconds 100
    } while($cell -ne 'WhiterunExterior16' -and (Get-Date) -lt $deadline)
    if($cell -ne 'WhiterunExterior16') {throw 'Outdoor test cell did not load'}
    Resolve-YieldStartupPrompts
    $summary.nativeCall='InitiateFlee(player,true,true,false,nullptr,nullptr,4096.0f,50.0f)'
    $summary.controls=@()
    foreach($pacify in @($true)) {
        $before=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
        $spawn=(Invoke-NpcPapyrus ObjectReference PlaceAtMe $player @(@{form=$yieldEnemyBase},1,$true,$true)).returned
        $after=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
        $actor=Resolve-NpcSpawn $before $after $yieldEnemyBase $spawn.formId
        Invoke-NpcPapyrus Actor EnableAI $actor @($false) | Out-Null
        Invoke-NpcPapyrus ObjectReference MoveTo $actor @(@{form=$player},150.0,0.0,0.0,$false) | Out-Null
        Invoke-NpcPapyrus ObjectReference Enable $actor @($false) | Out-Null
        Set-NpcEnemyEquipment $actor | Out-Null
        if($pacify) {Invoke-NpcPapyrus Acheron PacifyActor '' @(@{form=$actor}) | Out-Null}
        $initial=Read-FleeProbe $actor
        $control=@{pacifiedRequested=$pacify;initial=$initial;actor=(Invoke-YieldTool inspect @{kind='refs';formId=$actor}).refs[0];samples=@()}
        $summary.controls+=,$control
        Invoke-NpcPapyrus Actor EnableAI $actor @($true) | Out-Null
        $control.start=Read-FleeProbe $actor 3
        $deadline=(Get-Date).AddSeconds(8)
        do {
            $sample=Read-FleeProbe $actor
            $control.samples+=,$sample
            Start-Sleep -Milliseconds 150
        } while((Get-Date) -lt $deadline)
        $control.moved=(@($control.samples.distance|Measure-Object -Maximum)[0].Maximum -gt $initial.distance+350)
        $control.nativeFleeObserved=@($control.samples|Where-Object fleeing).Count -gt 0 -or $control.start.fleeing
        $control.invariantsPreserved=@($control.samples|Where-Object {$_.health -ne $initial.health -or $_.aggression -ne $initial.aggression -or $_.confidence -ne $initial.confidence -or $_.pacified -ne $pacify -or $_.paused}).Count -eq 0
        $control.stop=Read-FleeProbe $actor 0
        $deadline=(Get-Date).AddSeconds(3)
        do {$sample=Read-FleeProbe $actor; if(-not $sample.fleeing) {break}; Start-Sleep -Milliseconds 100} while((Get-Date) -lt $deadline)
        $control.stopped=-not $sample.fleeing
        $control.afterStop=$sample
        Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$actor}) | Out-Null
        Invoke-NpcPapyrus ObjectReference Disable $actor @($false) | Out-Null
        Invoke-NpcPapyrus ObjectReference Delete $actor | Out-Null
        $actor=$null
    }
    if(@($summary.controls|Where-Object {-not $_.moved -or -not $_.nativeFleeObserved -or -not $_.invariantsPreserved -or -not $_.stopped}).Count) {throw 'Direct native flee qualification failed; inspect individual controls'}
    return @{message='PASS: direct native fleeing under pacification and cleanup';screenshot=$null}
} finally {
    if($actor) {
        Read-FleeProbe $actor 0 | Out-Null
        Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$actor}) | Out-Null
        Invoke-NpcPapyrus ObjectReference Disable $actor @($false) | Out-Null
        Invoke-NpcPapyrus ObjectReference Delete $actor | Out-Null
    }
    $summary.actorCleaned=$true
}
