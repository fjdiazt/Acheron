. (Join-Path $PSScriptRoot 'Npc-Papyrus.ps1')
. (Join-Path $PSScriptRoot 'Peaceful-Dialogue-Evidence.ps1')
$logPath=Join-Path (Split-Path -Parent $PrefsPath) 'SKSE\Acheron.log'
function Read-PeacefulDialogue([string] $ActorId) {
    $start=(Get-Content $logPath -Raw).Length
    Invoke-NpcPapyrus Acheron ProbePeacefulState '' @(@{form=$ActorId}) | Out-Null
    $deadline=(Get-Date).AddSeconds(3)
    do {
        $log=Get-Content $logPath -Raw
        $matches=if($log.Length -ge $start) {[regex]::Matches($log.Substring($start),'\[PeacefulDialogue\] (?<json>\{[^\r\n]*\})')}else{@()}
        foreach($match in $matches) {
            $snapshot=$match.Groups['json'].Value | ConvertFrom-Json
            if($snapshot.actor -eq $ActorId) {return $snapshot}
        }
        Start-Sleep -Milliseconds 25
    } while((Get-Date) -lt $deadline)
    throw 'Native dialogue snapshot missing'
}
function Read-PeacefulState([string] $ActorId) {
    $start=(Get-Content $logPath -Raw).Length
    Invoke-NpcPapyrus Acheron ProbePeacefulState '' @(@{form=$ActorId}) | Out-Null
    $pattern='\[PeacefulSnapshot\] actor='+($ActorId -replace '^0x','')+' phase=(?<phase>\d+) remaining=(?<remaining>[0-9.eE+-]+) generation=(?<generation>\d+) anchor=(?<anchor>[0-9A-F]+) goal=(?<goal>[0-9A-F]+) ready=(?<ready>true|false) loaded=(?<loaded>true|false)(?: commandHoldRemaining=(?<kneeling>[0-9.eE+-]+))?'
    $deadline=(Get-Date).AddSeconds(3)
    do {
        $log=Get-Content $logPath -Raw
        $match=if($log.Length -ge $start) {[regex]::Match($log.Substring($start),$pattern)}else{$null}
        if($match -and $match.Success) {
            return @{phase=[int]$match.Groups['phase'].Value;remaining=[double]$match.Groups['remaining'].Value;generation=[long]$match.Groups['generation'].Value;anchor='0x'+$match.Groups['anchor'].Value;goal='0x'+$match.Groups['goal'].Value;ready=$match.Groups['ready'].Value -eq 'true';loaded=$match.Groups['loaded'].Value -eq 'true';commandHoldRemaining=if($match.Groups['kneeling'].Success){[double]$match.Groups['kneeling'].Value}else{$null}}
        }
        Start-Sleep -Milliseconds 25
    } while((Get-Date) -lt $deadline)
    throw 'Native peaceful snapshot missing'
}
function Wait-PeacefulPhase([string] $ActorId, [int] $Phase, [int] $TimeoutSeconds=6) {
    $deadline=(Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $state=Read-PeacefulState $ActorId
        if($state.ready -and $state.phase -eq $Phase) {return $state}
    } while((Get-Date) -lt $deadline)
    throw 'Peaceful phase did not settle'
}
function Close-PeacefulDialogue([string] $ActorId, [string] $Owner) {
    if((Read-PeacefulDialogue $ActorId).menuOpen) {
        Invoke-YieldTool input @{action='tap';device='keyboard';key='tab';durationMs=50;owner=$Owner} | Out-Null
        $deadline=(Get-Date).AddSeconds(3)
        do {$dialogue=Read-PeacefulDialogue $ActorId} while($dialogue.menuOpen -and (Get-Date) -lt $deadline)
        if($dialogue.menuOpen) {throw 'Native dialogue did not end'}
    }
}
function Assert-PeacefulReleased([string] $ActorId, [double] $Aggression, [bool] $Defeated=$false) {
    if((Invoke-NpcPapyrus Acheron IsPeacefulState '' @(@{form=$ActorId})).returned -ne $false) {throw 'Controller owner remains'}
    foreach($offset in @(0x811,0x812)) {
        $key=(Invoke-NpcPapyrus Game GetFormFromFile '' @($offset,'Acheron.esm')).returned.formId
        if((Invoke-NpcPapyrus ObjectReference GetLinkedRef $ActorId @(@{form=$key})).returned.formId) {throw 'Owned marker link remains'}
    }
    if((Invoke-NpcPapyrus Actor GetActorValue $ActorId @('Aggression')).returned -ne $Aggression) {throw 'Original aggression not restored'}
    if((Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$ActorId})).returned -ne $Defeated -or
       (Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$ActorId})).returned -ne $Defeated) {throw 'Exit damaged defeat/pacification ownership'}
    $package=(Invoke-NpcPapyrus Actor GetCurrentPackage $ActorId).returned.formId
    if($package -match '(813|814|81A|81E)$') {throw 'Owned package remains'}
}
