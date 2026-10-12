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
    $pattern='\[PeacefulSnapshot\] actor='+($ActorId -replace '^0x','')+' phase=(?<phase>\d+) remaining=(?<remaining>[0-9.eE+-]+) generation=(?<generation>\d+) anchor=(?<anchor>[0-9A-F]+) goal=(?<goal>[0-9A-F]+) ready=(?<ready>true|false) loaded=(?<loaded>true|false)(?: commandHoldRemaining=(?<kneeling>[0-9.eE+-]+))?(?: selectedKneelingVariant=(?<variant>\d+))?'
    $deadline=(Get-Date).AddSeconds(3)
    do {
        $log=Get-Content $logPath -Raw
        $match=if($log.Length -ge $start) {[regex]::Match($log.Substring($start),$pattern)}else{$null}
        if($match -and $match.Success) {
            return @{phase=[int]$match.Groups['phase'].Value;remaining=[double]$match.Groups['remaining'].Value;generation=[long]$match.Groups['generation'].Value;anchor='0x'+$match.Groups['anchor'].Value;goal='0x'+$match.Groups['goal'].Value;ready=$match.Groups['ready'].Value -eq 'true';loaded=$match.Groups['loaded'].Value -eq 'true';commandHoldRemaining=if($match.Groups['kneeling'].Success){[double]$match.Groups['kneeling'].Value}else{$null};selectedKneelingVariant=if($match.Groups['variant'].Success){[int]$match.Groups['variant'].Value}else{$null}}
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
function Wait-PeacefulSave([string] $Name, [string] $Directory) {
    $deadline=(Get-Date).AddSeconds(5)
    do {
        $listing=Invoke-YieldTool game @{action='list';filter=$Name}
        if($listing.dir -ne $Directory -or $listing.count -gt 1) {throw 'Owned peaceful save listing changed unexpectedly'}
        if($listing.count -eq 1 -and $listing.saves[0].name -like ($Name+'*')) {return $listing}
        Start-Sleep -Milliseconds 100
    } while((Get-Date) -lt $deadline)
    throw 'Owned peaceful save did not finish writing'
}
function Load-PeacefulSave([string] $Name) {
    $request=Invoke-YieldTool scenario @{async=$true;steps=@(@{tool='game';args=@{action='load';name=$Name}},@{waitFor='postLoadGame';timeoutMs=15000})}
    $deadline=(Get-Date).AddSeconds(20)
    do {
        $load=Invoke-YieldTool scenario @{action='status';runId=$request.runId}
        if($load.done) {break}
        $menus=Invoke-YieldTool menu @{action='list'}
        if($menus.messageBoxOpen) {
            $summary.loadPrompt=Invoke-YieldTool menu @{action='describe'}
            if($summary.loadPrompt.bodyText -eq 'Creations are currently loaded. Note: Achievements are disabled.  Do you wish to continue loading this save?' -and
               ($summary.loadPrompt.buttons -join '|') -eq 'Yes|No') {
                Invoke-YieldTool menu @{action='accept';index=0} | Out-Null
            } else {throw ('Load gated by prompt: '+($summary.loadPrompt|ConvertTo-Json -Compress -Depth 10))}
        }
        Start-Sleep -Milliseconds 100
    } while((Get-Date) -lt $deadline)
    if(-not $load.done -or $load.ok -ne $true -or $load.result.ok -ne $true) {throw 'Load lifecycle event missing'}
}
function Close-PeacefulDialogue([string] $ActorId, [string] $Owner) {
    if((Read-PeacefulDialogue $ActorId).menuOpen) {
        Invoke-YieldTool input @{action='tap';device='keyboard';key='tab';durationMs=50;owner=$Owner} | Out-Null
        $deadline=(Get-Date).AddSeconds(3)
        do {$dialogue=Read-PeacefulDialogue $ActorId} while($dialogue.menuOpen -and (Get-Date) -lt $deadline)
        if($dialogue.menuOpen) {throw 'Native dialogue did not end'}
    }
}
function Select-PeacefulDialogueChoice([string] $ActorId, [string] $Text, [int] $InfoOffset, [string] $Owner, [switch] $AlreadyOpen) {
    if(-not $AlreadyOpen) {Invoke-NpcPapyrus ObjectReference Activate $ActorId @(@{form='0x00000014'},$false) | Out-Null}
    $deadline=(Get-Date).AddSeconds(8)
    do {
        $snapshot=Read-PeacefulDialogue $ActorId
        try {$choice=Assert-PeacefulDialogueChoice $snapshot $ActorId $Text; break} catch {}
    } while((Get-Date) -lt $deadline)
    if(-not $choice) {throw "Native dialogue choice unavailable: $Text"}
    $delta=[int]$choice.row-[int]$snapshot.selectedIndex
    $key=if($delta -lt 0) {'w'}else{'s'}
    for($i=0;$i -lt [math]::Abs($delta);$i++) {Invoke-YieldTool input @{action='tap';device='keyboard';key=$key;durationMs=50;owner=$Owner} | Out-Null}
    $selected=Read-PeacefulDialogue $ActorId
    $choice=Assert-PeacefulDialogueChoice $selected $ActorId $Text
    if($selected.selectedIndex -ne $choice.row) {throw 'Wrong native dialogue row selected'}
    $start=(Get-Content $logPath -Raw).Length
    $info=(Invoke-NpcPapyrus Game GetFormFromFile '' @($InfoOffset,'Acheron.esm')).returned.formId
    Invoke-YieldTool input @{action='tap';device='keyboard';key='e';durationMs=50;owner=$Owner} | Out-Null
    $deadline=(Get-Date).AddSeconds(5)
    do {
        try {return Assert-PeacefulTopicSelected ((Get-Content $logPath -Raw).Substring($start)) $ActorId $info} catch {}
    } while((Get-Date) -lt $deadline)
    throw "Native dialogue action did not execute: $Text"
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
