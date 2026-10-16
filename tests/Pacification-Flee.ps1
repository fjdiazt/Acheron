param([string] $RunId, [string] $RunDirectory, [ValidateSet('entry','lifetime','lifecycle')] [string] $Mode='entry')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Pacification-Fixture.ps1')
. (Join-Path $PSScriptRoot 'Yield-StartupPrompts.ps1')
. (Join-Path $PSScriptRoot 'Native-Flee-Snapshot.ps1')
$player='0x00000014';$owned=[Collections.Generic.List[string]]::new();$summary.actorCleaned=$false;$summary.flights=@()
$fleePackage=(Invoke-NpcPapyrus Game GetFormFromFile '' @(0x88A,'Acheron.esm')).returned.formId
$saveName='YieldFlee_'+($RunId -replace '-','');$saveDir=$null
function Enter-FleeCell([string] $Cell) {
    Invoke-YieldTool console @{action='exec';command="coc $Cell"}|Out-Null
    $deadline=(Get-Date).AddSeconds(40)
    do {
        try {$current=(Invoke-YieldTool inspect @{kind='refs';formId=$player}).refs[0].cell.editorId}
        catch {if($_.ErrorDetails.Message -notmatch 'queued task abandoned') {throw};$current=$null}
    }while($current -ne $Cell -and (Get-Date) -lt $deadline)
    if($current -ne $Cell) {throw 'Flee test cell did not load'}
    $summary.outdoorFleeFixture=$Cell -eq 'WhiterunExterior16'
    Resolve-YieldStartupPrompts
}
function New-FleeActor([string] $Base=$yieldEnemyBase) {
    $before=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
    $spawn=(Invoke-NpcPapyrus ObjectReference PlaceAtMe $player @(@{form=$Base},1,$true,$true)).returned
    $after=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
    $id=Resolve-NpcSpawn $before $after $Base $spawn.formId
    $owned.Add($id)
    Invoke-NpcPapyrus Actor EnableAI $id @($false)|Out-Null
    Invoke-NpcPapyrus Actor SetDontMove $id @($false)|Out-Null
    $x=if($summary.outdoorFleeFixture){150.0}else{0.0};$y=if($summary.outdoorFleeFixture){0.0}else{-150.0}
    Invoke-NpcPapyrus ObjectReference MoveTo $id @(@{form=$player},$x,$y,0.0,$false)|Out-Null
    Invoke-NpcPapyrus ObjectReference Enable $id @($false)|Out-Null
    if($Base -eq $yieldEnemyBase) {Set-NpcEnemyEquipment $id|Out-Null}
    Invoke-NpcPapyrus Actor SetActorValue $id @('HealRate',0.0)|Out-Null
    Invoke-NpcPapyrus Actor SetActorValue $id @('HealRateMult',0.0)|Out-Null
    Invoke-NpcPapyrus Acheron DefeatActor '' @(@{form=$id})|Out-Null
    Invoke-NpcPapyrus Actor EnableAI $id @($true)|Out-Null
    $deadline=(Get-Date).AddSeconds(5)
    do {$sample=Read-FleeProbe $id;if($sample.defeated -and $sample.defeatPackage -and $sample.pacified) {return $id}}while((Get-Date) -lt $deadline)
    throw 'Flee fixture did not acquire actual Yielding'
}
function Assert-FleeValues($Before,$After) {
    foreach($key in @('health','aggression','confidence')) {if($Before.$key -ne $After.$key){throw "Flee changed $key"}}
    if($After.defeated -or $After.bleedoutLocked -or $After.defeatPackage -or -not $After.pacified -or -not $After.managed -or $After.phase -ne 7) {throw 'Flee lost or retained wrong ownership'}
}
function Start-FleeCase([string] $Actor,[string] $Entry,[switch] $Dialogue) {
    $before=Read-FleeProbe $Actor
    if($Dialogue) {
        $info=if($before.defeated){0x886}else{0x887}
        $selection=Select-PeacefulDialogueChoice $Actor 'Get out of here.' $info $RunId
    } elseif(-not (Invoke-NpcPapyrus Acheron FleeActor '' @(@{form=$Actor})).returned) {throw 'Flee command rejected eligible enemy'}
    $state=Wait-PeacefulPhase $Actor 7 12
    $after=Read-FleeProbe $Actor
    Assert-FleeValues $before $after
    if($after.package -ne $fleePackage -or $state.fleeRemaining -le 0 -or $state.fleeRemaining -gt 30 -or $state.commandHoldRemaining -ne 0) {throw 'Flee package or independent timer missing'}
    $case=@{actor=$Actor;entry=$Entry;before=$before;state=$state;after=$after;selection=$selection}
    $summary.flights+=,$case
    return $case
}
function Release-FleeCase([string] $Actor,[double] $Aggression) {
    Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$Actor})|Out-Null
    $deadline=(Get-Date).AddSeconds(5)
    do {$active=(Invoke-NpcPapyrus Acheron IsPeacefulState '' @(@{form=$Actor})).returned}while($active -and (Get-Date) -lt $deadline)
    Invoke-NpcPapyrus Actor EnableAI $Actor @($false)|Out-Null
    Assert-PeacefulReleased $Actor $Aggression
}
function Remove-FleeActor([string] $Actor) {
    if((Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$Actor})).returned) {Invoke-NpcPapyrus Acheron RescueActor '' @(@{form=$Actor},$false)|Out-Null}
    if((Invoke-NpcPapyrus Acheron IsPeacefulState '' @(@{form=$Actor})).returned -or (Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$Actor})).returned) {Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$Actor})|Out-Null}
    Invoke-NpcPapyrus Actor SetPlayerTeammate $Actor @($false,$false)|Out-Null
    Invoke-NpcPapyrus Actor StopCombatAlarm $Actor|Out-Null
    Invoke-NpcPapyrus ObjectReference Disable $Actor @($false)|Out-Null
    Invoke-NpcPapyrus ObjectReference Delete $Actor|Out-Null
    $owned.Remove($Actor)|Out-Null
}
function Wait-FleeEnd([string] $Actor,$Before,[int] $Seconds=6) {
    $deadline=(Get-Date).AddSeconds($Seconds)
    do {
        $sample=Read-FleeProbe $Actor
        if(-not $sample.managed) {break}
        Assert-FleeValues $Before $sample
        Start-Sleep -Milliseconds 100
    }while((Get-Date) -lt $deadline)
    if($sample.managed) {throw 'Flee deadline did not release owner'}
    Invoke-NpcPapyrus Actor EnableAI $Actor @($false)|Out-Null
    Assert-PeacefulReleased $Actor $Before.aggression
    $pattern='\[FleeEnd\] actor='+($Actor -replace '^0x','')+' distance=(?<distance>[0-9.eE+-]+) remaining=(?<remaining>[0-9.eE+-]+) tickMs=(?<tick>\d+)'
    $end=[regex]::Matches((Get-Content $logPath -Raw),$pattern)|Select-Object -Last 1
    if(-not $end) {throw 'Flee termination evidence missing'}
    return @{distance=[double]$end.Groups['distance'].Value;remaining=[double]$end.Groups['remaining'].Value;tickMs=[long]$end.Groups['tick'].Value;after=$sample}
}
function Begin-FleePeaceful([string] $Actor,[int] $Phase=2) {
    Invoke-NpcPapyrus Acheron RescueActor '' @(@{form=$Actor},$false)|Out-Null
    Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$Actor})|Out-Null
    $deadline=(Get-Date).AddSeconds(4)
    do {$pacified=(Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$Actor})).returned}while($pacified -and (Get-Date) -lt $deadline)
    if(-not (Invoke-NpcPapyrus Acheron BeginPeacefulState '' @(@{form=$Actor},60)).returned) {throw 'Peaceful setup rejected'}
    return Wait-PeacefulPhase $Actor $Phase
}
try {
    Resolve-YieldStartupPrompts
    if($Mode -eq 'entry') {
        foreach($entry in @('Yielding','Wandering','AvoidingCombat','Kneeling','Sitting','SittingHealthy','Test')) {
            $actor=New-FleeActor
            $fighters=@()
            if($entry -eq 'Wandering') {Begin-FleePeaceful $actor|Out-Null}
            if($entry -eq 'AvoidingCombat') {
                foreach($base in @($yieldEnemyBase,'0x000D3154')) {
                    $fighter=New-FleeActor $base;$fighters+=,$fighter
                    Invoke-NpcPapyrus Acheron RescueActor '' @(@{form=$fighter},$true)|Out-Null
                    Invoke-NpcPapyrus Actor SetActorValue $fighter @('Health',100000.0)|Out-Null
                    Invoke-NpcPapyrus Actor SetDontMove $fighter @($true)|Out-Null
                }
                Invoke-NpcPapyrus Actor StartCombat $fighters[1] @(@{form=$fighters[0]})|Out-Null
                $deadline=(Get-Date).AddSeconds(4)
                do {$fighting=(Invoke-NpcPapyrus Actor IsInCombat $fighters[1]).returned}while(-not $fighting -and (Get-Date) -lt $deadline)
                if(-not $fighting) {throw 'Nearby combat control never started'}
                Begin-FleePeaceful $actor 1|Out-Null
            }
            if($entry -in @('Kneeling','Sitting','SittingHealthy')) {
                if($entry -eq 'SittingHealthy') {Invoke-NpcPapyrus Actor RestoreActorValue $actor @('Health',10.0)|Out-Null}
                $command=if($entry -eq 'Kneeling'){'KneelActor'}else{'SitActor'}
                if(-not (Invoke-NpcPapyrus Acheron $command '' @(@{form=$actor})).returned) {throw 'Held pose setup rejected'}
                Wait-PeacefulPhase $actor $(if($entry -eq 'Kneeling'){3}elseif($entry -eq 'SittingHealthy'){5}else{6}) 20|Out-Null
            }
            if($entry -eq 'Test') {
                $before=Read-FleeProbe $actor
                Select-PeacefulDialogueChoice $actor 'Test' 0x836 $RunId|Out-Null
                Select-PeacefulDialogueChoice $actor 'Wandering' 0x841 $RunId -AlreadyOpen|Out-Null
                Wait-PeacefulPhase $actor 2|Out-Null
                Select-PeacefulDialogueChoice $actor 'Test' 0x837 $RunId|Out-Null
                Select-PeacefulDialogueChoice $actor 'Fleeing' 0x883 $RunId -AlreadyOpen|Out-Null
                $state=Wait-PeacefulPhase $actor 7 12
                Assert-FleeValues $before (Read-FleeProbe $actor)
                $case=@{actor=$actor;entry=$entry;before=$before;state=$state};$summary.flights+=,$case
            } else {$case=Start-FleeCase $actor $entry -Dialogue}
            $woundedScope=(Invoke-NpcPapyrus Game GetFormFromFile '' @(0x819,'Acheron.esm')).returned.formId
            if((Invoke-NpcPapyrus Actor IsInFaction $actor @(@{form=$woundedScope})).returned) {throw 'Peaceful wounded locomotion scope leaked into flight'}
            if((Invoke-NpcPapyrus Actor GetSitState $actor).returned -ne 0) {throw 'Flee retained held furniture pose'}
            Release-FleeCase $actor $case.before.aggression
            Remove-FleeActor $actor
            foreach($fighter in $fighters) {Remove-FleeActor $fighter}
        }
        $civilian=New-FleeActor '0x000D3154'
        if((Invoke-NpcPapyrus Acheron FleeActor '' @(@{form=$civilian})).returned) {throw 'Friendly NPC admitted to flight'}
        Invoke-NpcPapyrus ObjectReference Activate $civilian @(@{form=$player},$false)|Out-Null
        $deadline=(Get-Date).AddSeconds(6)
        do {$dialogue=Read-PeacefulDialogue $civilian;if($dialogue.menuOpen -and $dialogue.choices.Count) {break}}while((Get-Date) -lt $deadline)
        if(-not $dialogue.menuOpen -or -not $dialogue.choices.Count -or 'Get out of here.' -in $dialogue.choices.text) {throw 'Civilian dialogue eligibility wrong'}
        $summary.civilianDialogue=$dialogue
        Close-PeacefulDialogue $civilian $RunId;Remove-FleeActor $civilian
        $actor=New-FleeActor
        Invoke-NpcPapyrus Acheron KneelActor '' @(@{form=$actor})|Out-Null;Wait-PeacefulPhase $actor 3 20|Out-Null
        Invoke-NpcPapyrus Acheron BindActor '' @(@{form=$actor})|Out-Null;Wait-PeacefulPhase $actor 4 20|Out-Null
        if((Invoke-NpcPapyrus Acheron FleeActor '' @(@{form=$actor})).returned) {throw 'Flee silently released binding'}
        Remove-FleeActor $actor
        $actor=New-FleeActor
        Invoke-NpcPapyrus Actor SetPlayerTeammate $actor @($true,$false)|Out-Null
        if((Invoke-NpcPapyrus Acheron FleeActor '' @(@{form=$actor})).returned -or (Invoke-NpcPapyrus Acheron FleeActor '' @(@{form=$player})).returned) {throw 'Player/follower admitted to flight'}
        Remove-FleeActor $actor
        $actor=New-FleeActor
        Invoke-NpcPapyrus Actor SetDontMove $actor @($true)|Out-Null
        $case=Start-FleeCase $actor 'short deadline regression'
        $first=Read-PeacefulState $actor
        Invoke-NpcPapyrus Acheron FleeActor '' @(@{form=$actor})|Out-Null
        $repeat=Read-PeacefulState $actor
        if($repeat.generation -ne $first.generation -or $repeat.fleeRemaining -gt $first.fleeRemaining) {throw 'Repeated Flee extended flight budget'}
        Invoke-NpcPapyrus Acheron ProbeFleeDuration '' @(@{form=$actor},2.0)|Out-Null
        $summary.shortDeadline=Wait-FleeEnd $actor $case.before
        if($summary.shortDeadline.remaining -ne 0 -or $summary.shortDeadline.distance -ge 4096) {throw 'Short flight ended through wrong guard'}
        Remove-FleeActor $actor
    } elseif($Mode -eq 'lifetime') {
        $actor=New-FleeActor
        Invoke-NpcPapyrus Actor SetDontMove $actor @($true)|Out-Null
        $started=Get-Date;$case=Start-FleeCase $actor 'default 30 real seconds'
        $summary.defaultDeadline=Wait-FleeEnd $actor $case.before 35
        $summary.defaultDeadline.elapsed=((Get-Date)-$started).TotalSeconds
        if($summary.defaultDeadline.remaining -ne 0 -or $summary.defaultDeadline.distance -ge 4096 -or $summary.defaultDeadline.elapsed -lt 29 -or $summary.defaultDeadline.elapsed -gt 34) {throw 'Default real-time cap failed'}
        Remove-FleeActor $actor
        Enter-FleeCell 'WhiterunExterior16'
        $origin=(Invoke-YieldTool inspect @{kind='refs';formId=$player}).refs[0].position
        $actor=New-FleeActor;$case=Start-FleeCase $actor 'outdoor movement and distance guard'
        $samples=@();$until=(Get-Date).AddSeconds(8)
        do {$sample=Read-FleeProbe $actor;Assert-FleeValues $case.before $sample;$samples+=,$sample;Start-Sleep -Milliseconds 150}while((Get-Date) -lt $until)
        $case.samples=$samples
        if(@($samples|Where-Object {$_.package -eq $fleePackage -and $_.planarDistance -gt $case.after.planarDistance+350}).Count -eq 0) {throw 'Managed Fleeing failed actual horizontal movement'}
        $position=(Invoke-YieldTool inspect @{kind='refs';formId=$actor}).refs[0].position
        Invoke-NpcPapyrus ObjectReference SetPosition $player @(([double]$position[0]+4200),[double]$position[1],[double]$origin[2])|Out-Null
        $summary.distanceGuard=Wait-FleeEnd $actor $case.before
        if($summary.distanceGuard.distance -lt 4096 -or $summary.distanceGuard.remaining -le 0) {throw 'Distance guard failed before time cap'}
        $summary.distanceGuard.stimulus='Player moved 4200 units from actor after independently proved real flight; boundary test, not 4096-unit NPC navigation proof'
        Invoke-NpcPapyrus ObjectReference SetPosition $player @($origin[0],$origin[1],$origin[2])|Out-Null
        Remove-FleeActor $actor
    } else {
        $saveDir=(Invoke-YieldTool game @{action='list';filter=$saveName}).dir
        Assert-DesktopWritePath $saveDir
        if(Get-ChildItem -LiteralPath $saveDir -Filter ($saveName+'*')) {throw 'Owned save name occupied'}
        $actor=New-FleeActor
        Invoke-NpcPapyrus Actor SetDontMove $actor @($true)|Out-Null
        $case=Start-FleeCase $actor 'save/load flight budget'
        $beforeSave=Read-PeacefulState $actor
        Invoke-YieldTool scenario @{steps=@(@{tool='game';args=@{action='save';name=$saveName}},@{waitFor='saveGame';timeoutMs=10000})}|Out-Null
        $listing=Wait-PeacefulSave $saveName $saveDir
        Load-PeacefulSave $listing.saves[0].name
        $afterLoad=Wait-PeacefulPhase $actor 7 12
        Assert-FleeValues $case.before (Read-FleeProbe $actor)
        if($afterLoad.fleeRemaining -le 0 -or $afterLoad.fleeRemaining -gt $beforeSave.fleeRemaining) {throw 'Flight budget reset or lost across load'}
        $summary.persistence=@{before=$beforeSave;after=$afterLoad}
        Invoke-NpcPapyrus Actor Kill $actor @(@{form=$player})|Out-Null
        $deadline=(Get-Date).AddSeconds(5)
        do {$active=(Invoke-NpcPapyrus Acheron IsPeacefulState '' @(@{form=$actor})).returned}while($active -and (Get-Date) -lt $deadline)
        if($active -or -not (Invoke-NpcPapyrus Actor IsDead $actor).returned) {throw 'Death did not clear flight ownership'}
        Assert-PeacefulReleased $actor $case.before.aggression;Remove-FleeActor $actor
        $actor=New-FleeActor;$case=Start-FleeCase $actor 'follower eligibility change'
        Invoke-NpcPapyrus Actor SetPlayerTeammate $actor @($true,$false)|Out-Null
        Wait-FleeEnd $actor $case.before|Out-Null;Remove-FleeActor $actor
        $actor=New-FleeActor;$case=Start-FleeCase $actor 'renewed defeat'
        Invoke-NpcPapyrus Acheron DefeatActor '' @(@{form=$actor})|Out-Null
        $deadline=(Get-Date).AddSeconds(5)
        do {$sample=Read-FleeProbe $actor}while(($sample.managed -or -not $sample.defeated -or -not $sample.defeatPackage) -and (Get-Date) -lt $deadline)
        if($sample.managed -or -not $sample.defeated -or -not $sample.defeatPackage) {throw 'New defeat did not supersede flight'}
        Assert-PeacefulReleased $actor $case.before.aggression $true
        $case=Start-FleeCase $actor 'new flight after renewed defeat'
        Release-FleeCase $actor $case.before.aggression;Remove-FleeActor $actor
        $actor=New-FleeActor
        Invoke-NpcPapyrus Actor SetDontMove $actor @($true)|Out-Null
        $case=Start-FleeCase $actor 'paused real deadline'
        Invoke-NpcPapyrus Acheron ProbeFleeDuration '' @(@{form=$actor},2.0)|Out-Null
        if((Read-PeacefulState $actor).fleeRemaining -gt 2) {throw 'Short pause fixture budget not applied'}
        Invoke-YieldTool menu @{action='open';name='Console'}|Out-Null
        Start-Sleep -Milliseconds 2100
        Invoke-YieldTool menu @{action='close';name='Console'}|Out-Null
        $deadline=(Get-Date).AddSeconds(3)
        do {$open=(Invoke-NpcPapyrus UI IsMenuOpen '' @('Console')).returned}while($open -and (Get-Date) -lt $deadline)
        if($open) {throw 'Pause fixture console did not close'}
        Wait-FleeEnd $actor $case.before|Out-Null;Remove-FleeActor $actor
        $actor=New-FleeActor
        Invoke-NpcPapyrus Actor SetDontMove $actor @($true)|Out-Null
        $case=Start-FleeCase $actor 'unload/reload deadline'
        Invoke-NpcPapyrus Acheron ProbeFleeDuration '' @(@{form=$actor},2.0)|Out-Null
        Enter-FleeCell 'WhiterunExterior16';Start-Sleep -Milliseconds 2100;Enter-FleeCell 'UnownedCell'
        Wait-FleeEnd $actor $case.before|Out-Null;Remove-FleeActor $actor
    }
    return @{message="PASS: managed Fleeing $Mode; native actions, invariant preservation and owned cleanup";screenshot=$null}
} finally {
    Invoke-YieldTool menu @{action='close';name='Console'}|Out-Null
    foreach($id in $owned.ToArray()) {Remove-FleeActor $id}
    if($saveDir) {
        foreach($file in Get-ChildItem -LiteralPath $saveDir -Filter ($saveName+'*') -File) {
            Assert-DesktopWritePath $file.FullName
            if($file.DirectoryName -ne [IO.Path]::GetFullPath($saveDir).TrimEnd('\') -or $file.BaseName -notlike ($saveName+'*')) {throw 'Owned save escaped its directory'}
            Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $RunDirectory $file.Name)
            Remove-Item -LiteralPath $file.FullName
        }
    }
    $summary.actorCleaned=$true
}
