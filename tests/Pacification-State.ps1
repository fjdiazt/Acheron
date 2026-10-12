param([string] $RunId, [string] $RunDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Npc-Papyrus.ps1')
. (Join-Path $PSScriptRoot 'Pacification-State-Evidence.ps1')
$player='0x00000014'
$owned=@()
$summary.actorCleaned=$false
$summary.expiry=@()
$logPath=Join-Path (Split-Path -Parent $PrefsPath) 'SKSE\Acheron.log'
try {
    foreach($seconds in @(2,3)) {
        $actor=(Invoke-NpcPapyrus ObjectReference PlaceAtMe $player @(@{form=$yieldEnemyBase},1,$true,$false)).returned.formId
        if($actor -notmatch '^0xFF[0-9a-fA-F]{6}$') { throw 'Disposable peaceful actor missing' }
        $owned+=$actor
        Invoke-NpcPapyrus Actor EnableAI $actor @($false) | Out-Null
        Set-NpcEnemyEquipment $actor | Out-Null
        Invoke-NpcPapyrus ObjectReference MoveTo $actor @(@{form=$player},-120.0,-85.0,0.0,$false) | Out-Null
        Invoke-NpcPapyrus Actor StopCombat $actor | Out-Null
        Invoke-NpcPapyrus Actor StopCombat $player | Out-Null
        $aggression=(Invoke-NpcPapyrus Actor GetActorValue $actor @('Aggression')).returned
        $start=(Get-Content $logPath -Raw).Length
        if((Invoke-NpcPapyrus Acheron BeginPeacefulState '' @(@{form=$actor},$seconds)).returned -ne $true) { throw 'Peaceful request rejected' }
        Invoke-NpcPapyrus Actor EnableAI $actor @($true) | Out-Null
        $deadline=(Get-Date).AddSeconds(12)
        do {
            $log=(Get-Content $logPath -Raw).Substring($start)
            if($log -match ('\[PeacefulState\] actor='+($actor -replace '^0x','')+' phase=0')) { break }
            Start-Sleep -Milliseconds 50
        } while((Get-Date) -lt $deadline)
        $summary.expiry += Measure-PeacefulExpiry $log $actor $seconds
        Invoke-NpcPapyrus Actor EnableAI $actor @($false) | Out-Null
        Invoke-NpcPapyrus Actor StopCombat $actor | Out-Null
        Invoke-NpcPapyrus Actor StopCombat $player | Out-Null
        if((Invoke-NpcPapyrus Acheron IsPeacefulState '' @(@{form=$actor})).returned -ne $false -or
           (Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$actor})).returned -ne $false -or
           (Invoke-NpcPapyrus Actor IsDead $actor).returned -ne $false) { throw 'Expiry did not release living actor' }
        if((Invoke-NpcPapyrus Actor GetActorValue $actor @('Aggression')).returned -ne $aggression) { throw 'Expiry changed original aggression' }
        $package=(Invoke-NpcPapyrus Actor GetCurrentPackage $actor).returned.formId
        if($package -match '(813|814)$') { throw 'Owned package remains after expiry' }
    }
    return @{message='PASS: peaceful FSM automatic expiry 2s and 3s'; screenshot=$null}
} finally {
    foreach($actor in $owned) {
        if((Invoke-NpcPapyrus Acheron IsPeacefulState '' @(@{form=$actor})).returned) { Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$actor}) | Out-Null }
        Invoke-NpcPapyrus ObjectReference Disable $actor @($false) | Out-Null
        Invoke-NpcPapyrus ObjectReference Delete $actor | Out-Null
    }
    $summary.actorCleaned=$true
}
