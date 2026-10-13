param([string] $RunId, [string] $RunDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Pacification-Fixture.ps1')
$player='0x00000014';$actor=$null;$defeatedActor=$null;$summary.actorCleaned=$false
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
    Invoke-NpcPapyrus Acheron BeginPeacefulState '' @(@{form=$actor},120) | Out-Null
    Invoke-NpcPapyrus Actor EnableAI $actor @($true) | Out-Null
    Wait-PeacefulPhase $actor 2 | Out-Null
    Invoke-YieldTool menu @{action='open';name='Console'} | Out-Null
    $deadline=(Get-Date).AddSeconds(3)
    do {$menus=Invoke-YieldTool menu @{action='list'}} while($menus.openMenus -notcontains 'Console' -and (Get-Date) -lt $deadline)
    if($menus.openMenus -notcontains 'Console') {throw 'Pause menu did not open'}
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
    if((Invoke-NpcPapyrus Actor GetActorValue $actor @('Aggression')).returned -ne $aggression) {throw 'New peaceful owner changed aggression'}
    $defeatedActor=(Invoke-NpcPapyrus ObjectReference PlaceAtMe $player @(@{form=$yieldEnemyBase},1,$true,$true)).returned.formId
    if($defeatedActor -notmatch '^0xFF[0-9a-fA-F]{6}$') {throw 'Legacy defeated fixture missing'}
    Invoke-NpcPapyrus Actor EnableAI $defeatedActor @($false) | Out-Null
    Invoke-NpcPapyrus ObjectReference MoveTo $defeatedActor @(@{form=$player},120.0,-85.0,0.0,$false) | Out-Null
    Invoke-NpcPapyrus ObjectReference Enable $defeatedActor @($false) | Out-Null
    $defeatedAggression=(Invoke-NpcPapyrus Actor GetActorValue $defeatedActor @('Aggression')).returned
    Invoke-NpcPapyrus Acheron DefeatActor '' @(@{form=$defeatedActor}) | Out-Null
    $deadline=(Get-Date).AddSeconds(3)
    do {$defeated=(Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$defeatedActor})).returned} while(-not $defeated -and (Get-Date) -lt $deadline)
    if(-not $defeated -or $aggression -le 0 -or $defeatedAggression -le 0) {throw 'Legacy fixtures need aggressive managed actors'}
    if((Invoke-NpcPapyrus Actor GetActorValue $defeatedActor @('Aggression')).returned -ne $defeatedAggression) {throw 'New defeat owner changed aggression'}
    foreach($id in @($actor,$defeatedActor)) {
        Invoke-NpcPapyrus Acheron ProbeLegacyDialogueAggression '' @(@{form=$id}) | Out-Null
        $deadline=(Get-Date).AddSeconds(3)
        do {$legacy=(Invoke-NpcPapyrus Actor GetActorValue $id @('Aggression')).returned} while($legacy -ne 0 -and (Get-Date) -lt $deadline)
        if($legacy -ne 0) {throw 'Owned legacy modifier fixture missing'}
    }
    $beforeSave=Read-PeacefulState $actor
    $save=Invoke-YieldTool scenario @{steps=@(@{tool='game';args=@{action='save';name=$saveName}},@{waitFor='saveGame';timeoutMs=10000})}
    if($save.ok -ne $true) {throw 'Save lifecycle event missing'}
    $listing=Wait-PeacefulSave $saveName $saveDir
    Load-PeacefulSave $listing.saves[0].name
    $restored=Wait-PeacefulPhase $actor 2
    if($restored.anchor -ne $beforeSave.anchor -or $restored.goal -ne $beforeSave.goal -or
       $restored.remaining -gt $beforeSave.remaining+0.1 -or $restored.remaining -lt $beforeSave.remaining-5 -or
       (Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$actor})).returned -ne $true) {throw 'Cosave did not preserve ownership and remaining time'}
    $summary.persistence=@{paused=$paused;afterPause=$afterPause;beforeUnload=$beforeUnload;unloaded=$unloaded;afterUnload=$afterUnload;beforeSave=$beforeSave;restored=$restored}
    $summary.legacyMigration=@()
    foreach($cycle in @('legacy','clean')) {
        if($cycle -eq 'clean') {
            $cleanName=$saveName+'_clean'
            $save=Invoke-YieldTool scenario @{steps=@(@{tool='game';args=@{action='save';name=$cleanName}},@{waitFor='saveGame';timeoutMs=10000})}
            if($save.ok -ne $true) {throw 'Clean save lifecycle event missing'}
            $listing=Wait-PeacefulSave $cleanName $saveDir
            Load-PeacefulSave $listing.saves[0].name
            Wait-PeacefulPhase $actor 2 | Out-Null
        }
        foreach($id in @($actor,$defeatedActor)) {
            $expected=if($id -eq $actor) {$aggression}else{$defeatedAggression}
            $deadline=(Get-Date).AddSeconds(5)
            do {$actual=(Invoke-NpcPapyrus Actor GetActorValue $id @('Aggression')).returned} while($actual -ne $expected -and (Get-Date) -lt $deadline)
            $pacified=(Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$id})).returned
            $defeated=(Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$id})).returned
            $summary.legacyMigration+=@{cycle=$cycle;actor=$id;expectedAggression=$expected;aggression=$actual;pacified=$pacified;defeated=$defeated}
            if($actual -ne $expected -or -not $pacified -or $defeated -ne ($id -eq $defeatedActor)) {throw 'Load changed aggression or defeat/pacification ownership'}
        }
    }
    Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$actor}) | Out-Null
    Invoke-NpcPapyrus Actor EnableAI $actor @($false) | Out-Null
    Assert-PeacefulReleased $actor $aggression
    Invoke-NpcPapyrus Acheron RescueActor '' @(@{form=$defeatedActor},$true) | Out-Null
    return @{message='PASS: pause/unload/save/load ownership; legacy defeated and peaceful aggression migrate once, clean reload preserves originals';screenshot=$null}
} finally {
    Invoke-YieldTool menu @{action='close';name='Console'} | Out-Null
    if($actor) {
        if((Invoke-NpcPapyrus Acheron IsPeacefulState '' @(@{form=$actor})).returned) {Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$actor}) | Out-Null}
        Invoke-NpcPapyrus ObjectReference Disable $actor @($false) | Out-Null
        Invoke-NpcPapyrus ObjectReference Delete $actor | Out-Null
    }
    if($defeatedActor) {
        if((Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$defeatedActor})).returned) {Invoke-NpcPapyrus Acheron RescueActor '' @(@{form=$defeatedActor},$true) | Out-Null}
        Invoke-NpcPapyrus ObjectReference Disable $defeatedActor @($false) | Out-Null
        Invoke-NpcPapyrus ObjectReference Delete $defeatedActor | Out-Null
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
