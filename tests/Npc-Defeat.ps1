param([string] $RunId, [string] $RunDirectory, [ValidateSet('none','physical','magic','essential')] [string] $FinishMode = 'none', [ValidateSet(0,2,3)] [int] $RecoverySeconds = 0)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Npc-Defeat-Evidence.ps1')
. (Join-Path $PSScriptRoot 'Npc-Papyrus.ps1')
. (Join-Path $PSScriptRoot 'Npc-Recovery-Evidence.ps1')

$player = '0x00000014'
$actor = $null
$essentialBase = $null
$summary.actorCleaned = $false
$logPath = Join-Path (Split-Path -Parent $PrefsPath) 'SKSE\Acheron.log'
try {
    $version = Invoke-NpcPapyrus PapyrusUtil GetVersion ''
    if ($version.returned -ne 46) { throw 'Expected live PapyrusUtil 4.6' }
    $capabilities = Invoke-YieldTool input @{ action='capabilities' }
    $capabilities | ConvertTo-Json -Depth 30 | Set-Content (Join-Path $RunDirectory 'input-capabilities.json')
    $mouse = $capabilities.capabilities.keyboard.keys | Where-Object key -eq 'mouseLeft'
    if (-not $mouse) { throw 'Installed DevBench cannot inject mouseLeft; real melee attack unavailable' }

    $hunterSpell = (Invoke-NpcPapyrus Game GetFormFromFile '' @(0x807,'Acheron.esm')).returned.formId
    $hunterEffect = (Invoke-NpcPapyrus Game GetFormFromFile '' @(0x806,'Acheron.esm')).returned.formId
    if (-not $hunterSpell -or -not $hunterEffect) { throw 'Hunter Pride fixture forms missing' }
    Invoke-NpcPapyrus Actor AddSpell $player @(@{form=$hunterSpell},$false) | Out-Null
    $deadline = (Get-Date).AddSeconds(5)
    do {
        $hunterActive = (Invoke-NpcPapyrus Actor HasMagicEffect $player @(@{form=$hunterEffect})).returned
        if ($hunterActive -eq $true) { break }
        Start-Sleep -Milliseconds 100
    } while ((Get-Date) -lt $deadline)
    if ($hunterActive -ne $true) { throw 'Hunter Pride ability did not become active' }
    $summary.hunterPrideActive = $hunterActive

    Invoke-NpcPapyrus Actor SetActorValue $player @('Health',10000.0) | Out-Null
    $yaw = ((Invoke-NpcPapyrus ObjectReference GetAngleZ $player).returned + 180.0) % 360.0
    Invoke-NpcPapyrus ObjectReference SetAngle $player @(0.0,0.0,$yaw) | Out-Null
    Draw-YieldPlayerWeapon
    $spawn = Invoke-NpcPapyrus ObjectReference PlaceAtMe $player @(@{form=$yieldEnemyBase},1,$true,$false)
    $spawnId = $spawn.returned.formId
    if (-not $spawnId -or $spawnId -notmatch '^0xFF[0-9A-Fa-f]{6}$') { throw 'Spawn did not return a disposable actor reference' }
    $actor = $spawnId
    $summary.actorId = $actor
    Invoke-NpcPapyrus Actor EnableAI $actor @($false) | Out-Null
    Set-NpcEnemyEquipment $actor | Out-Null
    if ((Invoke-NpcPapyrus Actor IsEssential $actor).returned) { throw 'Fixture enemy is essential' }
    # Hold only fixture movement for the damage test; combat AI remains enabled.
    Invoke-NpcPapyrus Actor SetDontMove $actor @($true) | Out-Null
    Invoke-NpcPapyrus Actor SetActorValue $actor @('HealRate',0.0) | Out-Null
    Invoke-NpcPapyrus Actor SetActorValue $actor @('HealRateMult',0.0) | Out-Null
    Invoke-NpcPapyrus Actor SetActorValue $actor @('Health',1.0) | Out-Null
    $radians = $yaw * [math]::PI / 180.0
    Invoke-NpcPapyrus ObjectReference MoveTo $actor @(@{form=$player},([math]::Sin($radians)*85.0),([math]::Cos($radians)*85.0),0.0,$false) | Out-Null
    $summary.before = Invoke-YieldTool inspect @{ kind='refs'; formId=$actor }
    if ((Invoke-NpcPapyrus Actor IsDead $actor).returned -or (Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$actor})).returned) { throw 'Fixture already dead/defeated before player attack' }
    Invoke-NpcPapyrus Actor EnableAI $actor @($true) | Out-Null
    $logStart = (Get-Content -LiteralPath $logPath -Raw).Length
    Invoke-YieldTool input @{ action='tap'; device='keyboard'; key='mouseLeft'; durationMs=100; owner=$RunId } | Out-Null
    if ($RecoverySeconds) {
        # Papyrus round trips can outlast a 2s yield; observe native heartbeats first.
        $deadline = (Get-Date).AddSeconds(10)
        $registered = $false
        do {
            $recoveryLog = (Get-Content -LiteralPath $logPath -Raw).Substring($logStart)
            $id = $actor -replace '^0x',''
            if (-not $registered -and $recoveryLog -match ('\[YieldTest\] target=' + $id + ' .*registered=true')) {
                $registered = $true
                $deadline = (Get-Date).AddSeconds($RecoverySeconds + 2)
                Set-YieldActionCamera $actor
            }
            $recovered = $recoveryLog -match ('\[YieldTest\] target=' + $id + ' [^\r\n]*registered=true[\s\S]*?\[YieldAttack\] source=' + $id + ' [^\r\n]*defeated=false pacified=false dead=false') -and
                $recoveryLog -match ($id + ' \([^\r\n]*\) has been rescued')
            if ($registered -and $recovered) { break }
            Start-Sleep -Milliseconds 50
        } while ((Get-Date) -lt $deadline)
        $summary.recovery = Measure-YieldRecovery $recoveryLog $actor $RecoverySeconds
        $dead = (Invoke-NpcPapyrus Actor IsDead $actor).returned
        $defeated = (Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$actor})).returned
        $pacified = (Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$actor})).returned
        $health = (Invoke-NpcPapyrus Actor GetActorValue $actor @('Health')).returned
        if ($dead -ne $false -or $defeated -ne $false -or $pacified -ne $false -or -not [double]::IsFinite($health) -or $health -le 0) { throw 'Automatic recovery did not leave a living unprotected NPC' }
        $summary.after = @{ dead=$dead; defeated=$defeated; pacified=$pacified; health=$health }
        return [pscustomobject]@{ message="PASS: automatic NPC recovery at ${RecoverySeconds}s"; screenshot=$null }
    }
    $deadline = (Get-Date).AddSeconds(10)
    do {
        $defeated = (Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$actor})).returned
        if ($defeated -eq $true) { break }
        Start-Sleep -Milliseconds 100
    } while ((Get-Date) -lt $deadline)
    $dead = (Invoke-NpcPapyrus Actor IsDead $actor).returned
    $pacified = (Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$actor})).returned
    $health = (Invoke-NpcPapyrus Actor GetActorValue $actor @('Health')).returned
    $log = Get-Content -LiteralPath $logPath -Raw
    Assert-YieldDefeatEvidence $log $actor $dead $defeated $pacified $health
    $summary.after = @{ dead=$dead; defeated=$defeated; pacified=$pacified; health=$health }
    Set-YieldActionCamera $actor
    if ($FinishMode -ne 'none') {
        if ($FinishMode -eq 'essential') {
            $essentialBase = (Invoke-NpcPapyrus Actor GetActorBase $actor).returned.formId
            if (-not $essentialBase) { throw 'Essential test base missing' }
            Invoke-NpcPapyrus ActorBase SetEssential $essentialBase @($true) | Out-Null
            if ((Invoke-NpcPapyrus Actor IsEssential $actor).returned -ne $true) { throw 'Essential fixture flag did not apply' }
        }
        $modes = if ($FinishMode -eq 'essential') { @('physical','magic') } elseif ($FinishMode -eq 'physical') { @('physical','physical') } else { @($FinishMode) }
        $summary.finishingChecks = @()
        foreach ($mode in $modes) {
            # Freecam consumes gameplay input; leave it until the player hit resolves.
            Invoke-YieldTool camera @{ action='freecam'; on=$false } | Out-Null
            $nonfatal = $FinishMode -eq 'physical' -and $summary.finishingChecks.Count -eq 0
            if ($nonfatal) {
                Invoke-NpcPapyrus Actor ForceActorValue $actor @('Health',100.0) | Out-Null
            } elseif ($FinishMode -eq 'physical') {
                Invoke-NpcPapyrus Actor ForceActorValue $player @('AttackDamageMult',10000.0) | Out-Null
            }
            $healthBefore = (Invoke-NpcPapyrus Actor GetActorValue $actor @('Health')).returned
            $logStart = (Get-Content -LiteralPath $logPath -Raw).Length
            $allowed = if ($FinishMode -eq 'essential') { 'false' } else { 'true' }
            $expected = if ($mode -eq 'magic' -and $FinishMode -eq 'essential') { '\[YieldMagicApply\]' } else { '\[YieldFinish\]' }
            $expected += ' target=' + ($actor -replace '^0x','') + ' source=00000014 '
            if ($expected.StartsWith('\[YieldFinish\]')) { $expected += 'kind=' + $mode + ' ' }
            $expected += 'allowed=' + $allowed + ' essential=' + $(if ($FinishMode -eq 'essential') { 'true' } else { 'false' })
            $hookFound = $false
            for ($attempt=1; $attempt -le 3; $attempt++) {
                if ($mode -eq 'physical') {
                    Invoke-NpcPapyrus ObjectReference SetAngle $player @(30.0,0.0,$yaw) | Out-Null
                    Start-Sleep -Milliseconds 800
                    Invoke-YieldTool input @{action='tap';device='keyboard';key='mouseLeft';durationMs=100;owner=$RunId} | Out-Null
                    Invoke-YieldTool input @{action='releaseAll';device='keyboard';owner=$RunId} | Out-Null
                } else {
                    $firebolt = (Invoke-NpcPapyrus Game GetFormFromFile '' @(0x12FD0,'Skyrim.esm')).returned
                    if ($firebolt.name -ne 'Firebolt') { throw 'Firebolt fixture form mismatch' }
                    Invoke-NpcPapyrus Spell Cast $firebolt.formId @(@{form=$player},@{form=$actor}) | Out-Null
                }
                $deadline = (Get-Date).AddSeconds(3)
                do {
                    $finishLog = (Get-Content -LiteralPath $logPath -Raw).Substring($logStart)
                    if ($finishLog -match $expected) { $hookFound = $true; break }
                    Start-Sleep -Milliseconds 100
                } while ((Get-Date) -lt $deadline)
                if ($hookFound) { break }
            }
            if (-not $hookFound) { throw "No confirmed $mode finishing hook (allowed=$allowed)" }
            $deadline = (Get-Date).AddSeconds(5)
            do {
                $dead = (Invoke-NpcPapyrus Actor IsDead $actor).returned
                $defeated = (Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$actor})).returned
                $pacified = (Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$actor})).returned
                if ($FinishMode -eq 'essential' -or $nonfatal -or ($dead -and -not $defeated -and -not $pacified)) { break }
                Start-Sleep -Milliseconds 100
            } while ((Get-Date) -lt $deadline)
            $healthAfter = (Invoke-NpcPapyrus Actor GetActorValue $actor @('Health')).returned
            if ($nonfatal) {
                if ($dead -or -not $defeated -or -not $pacified -or $healthAfter -le 0 -or $healthAfter -ge $healthBefore) { throw 'Nonfatal player hit failed to damage target while retaining protection' }
            } elseif ($FinishMode -eq 'essential') {
                if ($dead -or -not $defeated -or -not $pacified) { throw 'Player damaged essential defeat protection' }
                if ($healthAfter -ne $healthBefore) { throw 'Essential health changed from blocked player hit' }
            } elseif (-not $dead -or $defeated -or $pacified) { throw 'Player finish did not cause death and clear Acheron flags' }
            $finishLog = (Get-Content -LiteralPath $logPath -Raw).Substring($logStart)
            if ($finishLog.Contains('Register Defeat for Victim ' + ($actor -replace '^0x',''))) { throw 'Finishing attack re-defeated target' }
            $summary.finishingChecks += @{mode=$mode;nonfatal=$nonfatal;essential=($FinishMode -eq 'essential');hookFound=$hookFound;dead=$dead;defeated=$defeated;pacified=$pacified;healthBefore=$healthBefore;healthAfter=$healthAfter}
            Set-YieldActionCamera $actor
        }
        return [pscustomobject]@{message="PASS: player finishing $FinishMode";screenshot=$null}
    }
    [pscustomobject]@{ message='PASS: real lethal player hit left NPC alive, defeated and pacified'; screenshot=$null }
} finally {
    Invoke-YieldTool input @{ action='releaseAll'; device='keyboard'; owner=$RunId } | Out-Null
    if ($actor) {
        if ($essentialBase) { Invoke-NpcPapyrus ActorBase SetEssential $essentialBase @($false) | Out-Null }
        if ((Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$actor})).returned) {
            Invoke-NpcPapyrus Acheron RescueActor '' @(@{form=$actor},$true) | Out-Null
        }
        $deadline = (Get-Date).AddSeconds(5)
        do {
            $stillDefeated = (Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$actor})).returned
            $stillPacified = (Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$actor})).returned
            if (-not $stillDefeated -and -not $stillPacified) { break }
            Start-Sleep -Milliseconds 100
        } while ((Get-Date) -lt $deadline)
        if ($stillDefeated -or $stillPacified) { throw 'Fixture remained in Acheron state during cleanup' }
        Invoke-NpcPapyrus Actor SetDontMove $actor @($false) | Out-Null
        Invoke-NpcPapyrus ObjectReference Disable $actor @($false) | Out-Null
        if ((Invoke-NpcPapyrus ObjectReference IsDisabled $actor).returned -ne $true) { throw 'Fixture Disable did not complete' }
        Invoke-NpcPapyrus ObjectReference Delete $actor | Out-Null
        $summary.actorCleaned = $true
    }
}
