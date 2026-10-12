param([string] $RunId, [string] $RunDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Pacification-Fixture.ps1')
$player='0x00000014';$actor=$null;$summary.actorCleaned=$false
$saveName='YieldPeaceful_'+($RunId -replace '-','')
$saveDir=(Invoke-YieldTool game @{action='list';filter=$saveName}).dir
Assert-DesktopWritePath $saveDir
if(Get-ChildItem -LiteralPath $saveDir -Filter ($saveName+'*')) {throw 'Owned save name already exists'}
$configs=@()
foreach($relative in @('Data\SKSE\Acheron\Settings.yaml','Data\SKSE\Acheron\Consequences\Weights.yaml')) {
    $path=Join-Path $GameRoot $relative
    Assert-DesktopWritePath $path
    $configs+=@{path=$path;bytes=if(Test-Path -LiteralPath $path){[IO.File]::ReadAllBytes($path)}else{$null};hash=if(Test-Path -LiteralPath $path){(Get-FileHash -LiteralPath $path).Hash}else{$null}}
}
try {
    $actor=(Invoke-NpcPapyrus ObjectReference PlaceAtMe $player @(@{form=$yieldEnemyBase},1,$true,$false)).returned.formId
    if($actor -notmatch '^0xFF[0-9a-fA-F]{6}$') {throw 'Persistence actor missing'}
    Invoke-NpcPapyrus Actor EnableAI $actor @($false) | Out-Null
    Set-NpcEnemyEquipment $actor | Out-Null
    Invoke-NpcPapyrus ObjectReference MoveTo $actor @(@{form=$player},-120.0,-85.0,0.0,$false) | Out-Null
    Invoke-NpcPapyrus Actor StopCombat $player | Out-Null
    $aggression=(Invoke-NpcPapyrus Actor GetActorValue $actor @('Aggression')).returned
    Invoke-NpcPapyrus Acheron BeginPeacefulState '' @(@{form=$actor},30) | Out-Null
    Invoke-NpcPapyrus Actor EnableAI $actor @($true) | Out-Null
    Wait-PeacefulPhase $actor 2 | Out-Null
    Invoke-YieldTool menu @{action='open';name='Console'} | Out-Null
    if((Invoke-YieldTool menu @{action='list'}).openMenus -notcontains 'Console') {throw 'Pause menu did not open'}
    $paused=Read-PeacefulState $actor
    Start-Sleep -Milliseconds 1500
    $afterPause=Read-PeacefulState $actor
    if([math]::Abs($paused.remaining-$afterPause.remaining) -gt 0.05) {throw 'Paused gameplay consumed wandering time'}
    Invoke-YieldTool menu @{action='close';name='Console'} | Out-Null
    $beforeUnload=Read-PeacefulState $actor
    Invoke-YieldTool console @{action='exec';command='coc qasmoke'} | Out-Null
    $deadline=(Get-Date).AddSeconds(15)
    do {
        $unloaded=Read-PeacefulState $actor
        if(-not $unloaded.loaded) {break}
    } while((Get-Date) -lt $deadline)
    if($unloaded.loaded) {throw 'Actor cell did not detach'}
    Start-Sleep -Milliseconds 1500
    $afterUnload=Read-PeacefulState $actor
    if([math]::Abs($unloaded.remaining-$afterUnload.remaining) -gt 0.05) {throw 'Unloading consumed wandering time'}
    Invoke-YieldTool console @{action='exec';command='coc UnownedCell'} | Out-Null
    Wait-PeacefulPhase $actor 2 | Out-Null
    $beforeSave=Read-PeacefulState $actor
    $save=Invoke-YieldTool scenario @{steps=@(@{tool='game';args=@{action='save';name=$saveName}},@{waitFor='saveGame';timeoutMs=10000})}
    if($save.ok -ne $true) {throw 'Save lifecycle event missing'}
    $listing=Invoke-YieldTool game @{action='list';filter=$saveName}
    if($listing.count -ne 1 -or $listing.dir -ne $saveDir -or $listing.saves[0].name -notlike ($saveName+'*')) {throw 'Owned save not found'}
    $request=Invoke-YieldTool scenario @{async=$true;steps=@(@{tool='game';args=@{action='load';name=$listing.saves[0].name}},@{waitFor='postLoadGame';timeoutMs=15000})}
    $deadline=(Get-Date).AddSeconds(17)
    do {
        $load=Invoke-YieldTool scenario @{action='status';runId=$request.runId}
        if($load.done) {break}
        $menus=Invoke-YieldTool menu @{action='list'}
        if($menus.messageBoxOpen) {
            $summary.loadPrompt=Invoke-YieldTool menu @{action='describe'}
            # Acknowledge only this vanilla warning for our GUID-owned save; never missing-content prompts.
            if($summary.loadPrompt.bodyText -eq 'Creations are currently loaded. Note: Achievements are disabled.  Do you wish to continue loading this save?' -and
               ($summary.loadPrompt.buttons -join '|') -eq 'Yes|No') {
                Invoke-YieldTool menu @{action='accept';index=0} | Out-Null
            } else {throw ('Load gated by prompt: '+($summary.loadPrompt|ConvertTo-Json -Compress -Depth 10))}
        }
        Start-Sleep -Milliseconds 100
    } while((Get-Date) -lt $deadline)
    if(-not $load.done -or $load.ok -ne $true -or $load.result.ok -ne $true) {throw 'Load lifecycle event missing'}
    $restored=Wait-PeacefulPhase $actor 2
    if($restored.anchor -ne $beforeSave.anchor -or $restored.goal -ne $beforeSave.goal -or
       $restored.remaining -gt $beforeSave.remaining+0.1 -or $restored.remaining -lt $beforeSave.remaining-5 -or
       (Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$actor})).returned -ne $true) {throw 'Cosave did not preserve ownership and remaining time'}
    $summary.persistence=@{paused=$paused;afterPause=$afterPause;beforeUnload=$beforeUnload;unloaded=$unloaded;afterUnload=$afterUnload;beforeSave=$beforeSave;restored=$restored}
    Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$actor}) | Out-Null
    Invoke-NpcPapyrus Actor EnableAI $actor @($false) | Out-Null
    Assert-PeacefulReleased $actor $aggression
    return @{message='PASS: menu pause, unload pause and real save/load preserve peaceful state';screenshot=$null}
} finally {
    Invoke-YieldTool menu @{action='close';name='Console'} | Out-Null
    if($actor) {
        if((Invoke-NpcPapyrus Acheron IsPeacefulState '' @(@{form=$actor})).returned) {Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$actor}) | Out-Null}
        Invoke-NpcPapyrus ObjectReference Disable $actor @($false) | Out-Null
        Invoke-NpcPapyrus ObjectReference Delete $actor | Out-Null
    }
    # GUID-owned saves only; archive evidence before deleting exact files, never existing user saves.
    foreach($file in Get-ChildItem -LiteralPath $saveDir -Filter ($saveName+'*') -File) {
        Assert-DesktopWritePath $file.FullName
        if($file.DirectoryName -ne [IO.Path]::GetFullPath($saveDir).TrimEnd('\') -or $file.BaseName -notlike ($saveName+'*')) {throw 'Owned save path escaped its directory'}
        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $RunDirectory $file.Name)
        Remove-Item -LiteralPath $file.FullName
    }
    foreach($config in $configs) {
        Assert-DesktopWritePath $config.path
        if($null -ne $config.bytes) {[IO.File]::WriteAllBytes($config.path,$config.bytes)}
        elseif(Test-Path -LiteralPath $config.path) {Remove-Item -LiteralPath $config.path}
        if($config.hash) {
            if((Get-FileHash -LiteralPath $config.path).Hash -ne $config.hash) {throw 'Persistence configuration restoration mismatch'}
        } elseif(Test-Path -LiteralPath $config.path) {throw 'Persistence created configuration remains'}
    }
    $summary.actorCleaned=$true
    $summary.persistenceSettingsRestored=$true
}
