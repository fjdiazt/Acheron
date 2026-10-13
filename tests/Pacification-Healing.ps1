param([string] $RunId, [string] $RunDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Pacification-Fixture.ps1')
$player='0x00000014'; $owned=@(); $summary.actorCleaned=$false; $summary.healing=@()
$logPath=Join-Path (Split-Path -Parent $PrefsPath) 'SKSE\Acheron.log'
try {
    foreach($kind in @('potion','spell','hunter-potion','civilian-potion')) {
        $base=if($kind -eq 'civilian-potion') {'0x00013BBF'}else{$yieldEnemyBase}
        $refsBefore=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
        $spawn=(Invoke-NpcPapyrus ObjectReference PlaceAtMe $player @(@{form=$base},1,$true,$false)).returned
        $refsAfter=Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
        $actor=Resolve-NpcSpawn $refsBefore $refsAfter $base $spawn.formId
        $owned+=$actor
        Invoke-NpcPapyrus Actor EnableAI $actor @($false) | Out-Null
        if($base -eq $yieldEnemyBase) {Set-NpcEnemyEquipment $actor | Out-Null}
        Invoke-NpcPapyrus ObjectReference MoveTo $actor @(@{form=$player},-120.0,-85.0,0.0,$false) | Out-Null
        Invoke-NpcPapyrus Actor SetActorValue $actor @('HealRate',0.0) | Out-Null
        Invoke-NpcPapyrus Actor SetActorValue $actor @('HealRateMult',0.0) | Out-Null
        # Leave room for the 75-point healing spell even on the level-one Forsworn.
        Invoke-NpcPapyrus Actor SetActorValue $actor @('Health',100.0) | Out-Null
        Invoke-NpcPapyrus Acheron DefeatActor '' @(@{form=$actor}) | Out-Null
        $before=(Invoke-NpcPapyrus Actor GetActorValue $actor @('Health')).returned
        if((Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$actor})).returned -ne $true -or $before -gt 0.1) { throw 'Healing fixture did not enter defeat' }
        $start=(Get-Content $logPath -Raw).Length
        if($kind -eq 'spell') {
            $spell=(Invoke-NpcPapyrus Game GetFormFromFile '' @(0x12FD2,'Skyrim.esm')).returned
            if($spell.formId -ne '0x00012FD2') { throw 'Native healing spell mismatch' }
            Invoke-NpcPapyrus Spell Cast $spell.formId @(@{form=$player},@{form=$actor}) | Out-Null
        } else {
            $potion=(Invoke-NpcPapyrus Game GetFormFromFile '' @(0x3EADD,'Skyrim.esm')).returned
            if($potion.formId -ne '0x0003EADD') { throw 'Native healing potion mismatch' }
            if($kind -eq 'hunter-potion') {
                Invoke-NpcPapyrus ObjectReference AddItem $player @(@{form=$potion.formId},1,$true) | Out-Null
                $inventoryBefore=(Invoke-NpcPapyrus ObjectReference GetItemCount $player @(@{form=$potion.formId})).returned
                Invoke-NpcPapyrus Actor EnableAI $actor @($true) | Out-Null
                $summary.rescueSelection=Select-PeacefulDialogueChoice $actor 'Rescue' 0x826 $RunId
            } else {
                Invoke-NpcPapyrus ObjectReference AddItem $actor @(@{form=$potion.formId},1,$true) | Out-Null
                Invoke-NpcPapyrus Actor EquipItem $actor @(@{form=$potion.formId},$false,$true) | Out-Null
            }
        }
        Invoke-NpcPapyrus Actor EnableAI $actor @($true) | Out-Null
        $deadline=(Get-Date).AddSeconds(8)
        do {
            $log=(Get-Content $logPath -Raw).Substring($start)
            if($log -match ('\[PeacefulState\] actor='+($actor -replace '^0x','')+' phase=[12]')) { break }
            Start-Sleep -Milliseconds 100
        } while((Get-Date) -lt $deadline)
        if($log -notmatch ('\[PeacefulHealing\] actor='+($actor -replace '^0x','')) -or
           $log -notmatch ('\[PeacefulState\] actor='+($actor -replace '^0x','')+' phase=[12]')) {
            $summary.failedHealing=@{kind=$kind;health=(Invoke-NpcPapyrus Actor GetActorValue $actor @('Health')).returned;effects=(Invoke-YieldTool inspect @{kind='effects';formId=$actor})}
            throw "Native $kind healing did not enter a peaceful state"
        }
        $after=(Invoke-NpcPapyrus Actor GetActorValue $actor @('Health')).returned
        $expected=if($kind -eq 'spell') {75}else{25}
        if([math]::Abs($after-$before-$expected) -gt 0.01) {throw 'Healing differs from native effect amount'}
        if($after -le $before -or (Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$actor})).returned -ne $false -or
           (Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$actor})).returned -ne $true) { throw 'Healing did not leave a peaceful living standing actor' }
        if($kind -in @('potion','civilian-potion') -and (Invoke-NpcPapyrus ObjectReference GetItemCount $actor @(@{form=$potion.formId})).returned -ne 0) { throw 'Potion not consumed exactly once' }
        if($kind -eq 'hunter-potion' -and ((Invoke-NpcPapyrus ObjectReference GetItemCount $player @(@{form=$potion.formId})).returned -ne $inventoryBefore-1 -or [math]::Abs($after-$before-25) -gt 0.01)) {throw 'Hunter Pride consumed wrong amount or added non-potion healing'}
        $summary.healing+=@{kind=$kind; actor=$actor; before=$before; after=$after}
        Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$actor}) | Out-Null
        Invoke-NpcPapyrus Actor EnableAI $actor @($false) | Out-Null
        Invoke-NpcPapyrus Actor StopCombat $actor | Out-Null
        Invoke-NpcPapyrus Actor StopCombat $player | Out-Null
    }
    return @{message='PASS: real native spell and potion healing enter shared pacification'; screenshot=$null}
} finally {
    foreach($actor in $owned) {
        if((Invoke-NpcPapyrus Acheron IsPeacefulState '' @(@{form=$actor})).returned) { Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$actor}) | Out-Null }
        if((Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$actor})).returned) { Invoke-NpcPapyrus Acheron RescueActor '' @(@{form=$actor},$true) | Out-Null }
        Invoke-NpcPapyrus ObjectReference Disable $actor @($false) | Out-Null
        Invoke-NpcPapyrus ObjectReference Delete $actor | Out-Null
    }
    $summary.actorCleaned=$true
}
