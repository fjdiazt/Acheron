param([string] $RunId, [string] $RunDirectory, [ValidateSet('follower','guard')] [string] $AttackerFixture = 'follower', [switch] $DefeatByAttacker)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Npc-Papyrus.ps1')
. (Join-Path $PSScriptRoot 'Npc-Defeat-Evidence.ps1')
. (Join-Path $PSScriptRoot 'Pacification-Evidence.ps1')
$player = '0x00000014'
$owned = @()
$enemy = $null
$attacker = $null
$summary.actorCleaned = $false
$logPath = Join-Path (Split-Path -Parent $PrefsPath) 'SKSE\Acheron.log'
try {
    $spell = (Invoke-NpcPapyrus Game GetFormFromFile '' @(0x807,'Acheron.esm')).returned.formId
    $effect = (Invoke-NpcPapyrus Game GetFormFromFile '' @(0x806,'Acheron.esm')).returned.formId
    if (-not $spell -or -not $effect) { throw 'Hunter Pride forms missing' }
    Invoke-NpcPapyrus Actor AddSpell $player @(@{form=$spell},$false) | Out-Null
    Invoke-NpcPapyrus Actor SetActorValue $player @('Health',10000.0) | Out-Null
    Invoke-NpcPapyrus Actor ForceActorValue $player @('AttackDamageMult',10000.0) | Out-Null
    if ((Invoke-NpcPapyrus Actor HasMagicEffect $player @(@{form=$effect})).returned -ne $true) { throw 'Hunter Pride inactive' }
    $yaw = ((Invoke-NpcPapyrus ObjectReference GetAngleZ $player).returned + 180.0) % 360.0
    Invoke-NpcPapyrus ObjectReference SetAngle $player @(0.0,0.0,$yaw) | Out-Null
    Draw-YieldPlayerWeapon
    $attackerBaseId = if ($AttackerFixture -eq 'guard') { 0xD3154 } else { 0xA2C8E }
    $attackerName = if ($AttackerFixture -eq 'guard') { 'Whiterun Guard' } else { 'Lydia' }
    $attackerBase = (Invoke-NpcPapyrus Game GetFormFromFile '' @($attackerBaseId,'Skyrim.esm')).returned
    if ($attackerBase.name -ne $attackerName -or $attackerBase.formType -ne '43') { throw 'Unexpected attacker NPC base' }
    foreach ($role in @('enemy','attacker')) {
        $baseId = if ($role -eq 'attacker') { $attackerBase.formId } else { $yieldEnemyBase }
        $beforeSpawn = Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
        if ($beforeSpawn.truncated) { throw 'Actor inventory truncated before spawn' }
        $spawn = (Invoke-NpcPapyrus ObjectReference PlaceAtMe $player @(@{form=$baseId},1,$true,$true)).returned
        $afterSpawn = Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
        $actorId = Resolve-NpcSpawn $beforeSpawn $afterSpawn $baseId $spawn.formId
        $owned += $actorId
        Set-Variable -Name $role -Value $actorId
        Invoke-NpcPapyrus Actor EnableAI $actorId @($false) | Out-Null
        if ((Invoke-NpcPapyrus Actor IsEssential $actorId).returned) { throw 'Fixture actor is essential' }
    }
    $summary.enemyId = $enemy
    $summary.attackerId = $attacker
    $summary.attackerRole = $AttackerFixture
    $label = if ($AttackerFixture -eq 'guard') { 'Test Guard (Whiterun copy)' } else { 'Test Follower (Lydia copy)' }
    if ((Invoke-NpcPapyrus ObjectReference SetDisplayName $attacker @($label,$true)).returned -ne $true) { throw 'Attacker label did not apply' }
    if ($AttackerFixture -eq 'follower') {
        Invoke-NpcPapyrus Actor SetFactionRank $attacker @(@{form='0x00000DB1'},0) | Out-Null
        Invoke-NpcPapyrus Actor SetPlayerTeammate $attacker @($true,$false) | Out-Null
        Invoke-NpcPapyrus Actor SetActorValue $attacker @('Aggression',1.0) | Out-Null
    }
    $isTeammate = (Invoke-NpcPapyrus Actor IsPlayerTeammate $attacker).returned
    if ($isTeammate -ne ($AttackerFixture -eq 'follower')) { throw 'Fixture teammate flag incorrect' }
    if ((Invoke-NpcPapyrus Actor IsHostileToActor $attacker @(@{form=$player})).returned) { throw 'Fixture attacker hostile to player' }
    $radians = $yaw * [math]::PI / 180.0
    $frontX = [math]::Sin($radians)*85.0
    $frontY = [math]::Cos($radians)*85.0
    Invoke-NpcPapyrus ObjectReference MoveTo $enemy @(@{form=$player},$frontX,$frontY,0.0,$false) | Out-Null
    Invoke-NpcPapyrus ObjectReference MoveTo $attacker @(@{form=$player},($frontX+[math]::Cos($radians)*80.0),($frontY-[math]::Sin($radians)*80.0),0.0,$false) | Out-Null
    foreach ($actorId in $owned) { Invoke-NpcPapyrus ObjectReference Enable $actorId @($false) | Out-Null }
    foreach ($actorId in $owned) {
        $deadline = (Get-Date).AddSeconds(5)
        do {
            $loaded = (Invoke-NpcPapyrus ObjectReference Is3DLoaded $actorId).returned
            if ($loaded -eq $true) { break }
            Start-Sleep -Milliseconds 100
        } while ((Get-Date) -lt $deadline)
        if ($loaded -ne $true) { throw 'Fixture actor 3D did not load' }
        Invoke-NpcPapyrus Actor SetActorValue $actorId @('Health',10000.0) | Out-Null
        Invoke-NpcPapyrus Actor SetActorValue $actorId @('HealRate',0.0) | Out-Null
        Invoke-NpcPapyrus Actor SetActorValue $actorId @('HealRateMult',0.0) | Out-Null
        Invoke-NpcPapyrus Actor SetActorValue $actorId @('Confidence',4.0) | Out-Null
        if ((Invoke-NpcPapyrus Actor GetActorValue $actorId @('Health')).returned -ne 10000.0) { throw 'Fixture health buffer did not apply' }
    }
    Set-NpcEnemyEquipment $enemy | Out-Null
    Set-YieldActionCamera $enemy
    foreach ($actorId in $owned) { Invoke-NpcPapyrus Actor EnableAI $actorId @($true) | Out-Null }
    $summary.fixture = Invoke-YieldTool inspect @{ kind='refs'; formType='Actor'; limit=10 }
    if ($AttackerFixture -eq 'guard') {
        $summary.hostility = [ordered]@{
            attackerToEnemy=(Invoke-NpcPapyrus Actor IsHostileToActor $attacker @(@{form=$enemy})).returned;
            enemyToAttacker=(Invoke-NpcPapyrus Actor IsHostileToActor $enemy @(@{form=$attacker})).returned;
            attackerToPlayer=(Invoke-NpcPapyrus Actor IsHostileToActor $attacker @(@{form=$player})).returned;
            enemyToPlayer=(Invoke-NpcPapyrus Actor IsHostileToActor $enemy @(@{form=$player})).returned;
            attackerIsTeammate=$isTeammate }
        if (-not $summary.hostility.attackerToEnemy -or $summary.hostility.attackerToPlayer -or -not $summary.hostility.enemyToPlayer) { throw 'Natural guard/Forsworn hostility not established' }
    } else {
        Invoke-NpcPapyrus Actor StartCombat $attacker @(@{form=$enemy}) | Out-Null
    }
    $deadline = (Get-Date).AddSeconds(25)
    $baselinePattern = '\[YieldHit\] target=' + ($enemy -replace '^0x','') + ' source=' + ($attacker -replace '^0x','') + ' damage=(?<damage>[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?) immune=false'
    do {
        $beforeLog = Get-Content -LiteralPath $logPath -Raw
        if ($beforeLog -match $baselinePattern -and [double]::Parse($Matches.damage,[Globalization.CultureInfo]::InvariantCulture) -gt 0) { break }
        Start-Sleep -Milliseconds 200
    } while ((Get-Date) -lt $deadline)
    if ($beforeLog -notmatch $baselinePattern -or [double]::Parse($Matches.damage,[Globalization.CultureInfo]::InvariantCulture) -le 0) { throw 'Attacker did not land a damaging hit within 25 seconds; test prerequisite failed' }
    $beforeLog | Set-Content (Join-Path $RunDirectory 'before-pacification.log')
    if ($DefeatByAttacker) {
        # Force the current value in one call; separate restore/set calls race real attacks.
        $lethalStart = (Get-Content -LiteralPath $logPath -Raw).Length
        Invoke-NpcPapyrus Actor ForceActorValue $enemy @('Health',1.0) | Out-Null
        $deadline = (Get-Date).AddSeconds(20)
        do {
            $dead = (Invoke-NpcPapyrus Actor IsDead $enemy).returned
            $defeated = (Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$enemy})).returned
            if ($dead -or $defeated) { break }
            Start-Sleep -Milliseconds 100
        } while ((Get-Date) -lt $deadline)
        $lethalLog = (Get-Content -LiteralPath $logPath -Raw).Substring($lethalStart)
        if ($lethalLog -notmatch $baselinePattern -or [double]::Parse($Matches.damage,[Globalization.CultureInfo]::InvariantCulture) -lt 1) { throw 'No confirmed lethal attacker hit' }
        if ($AttackerFixture -eq 'guard') {
            $pacified = (Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$enemy})).returned
            if (-not $dead -or $defeated -or $pacified -or $lethalLog.Contains('Register Defeat for Victim ' + ($enemy -replace '^0x',''))) { throw 'Ordinary NPC attack did not produce normal death' }
            if ((Invoke-NpcPapyrus Actor IsDead $attacker).returned -or (Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$attacker})).returned) { throw 'Attacker unhealthy; policy test invalid' }
            $summary.policy = @{source=$attacker;dead=$dead;defeated=$defeated;pacified=$pacified}
            return [pscustomobject]@{message='PASS: natural guard lethal hit killed standing Forsworn without defeat';screenshot=$null}
        }
    } else {
    Invoke-YieldTool camera @{ action='freecam'; on=$false } | Out-Null
    Invoke-NpcPapyrus Actor SetDontMove $enemy @($true) | Out-Null
    $summary.attackAttempts = @()
    for ($attempt=1; $attempt -le 3; $attempt++) {
        $enemyPosition = (Invoke-YieldTool inspect @{kind='refs';formId=$enemy}).refs[0].position
        $attackerPosition = (Invoke-YieldTool inspect @{kind='refs';formId=$attacker}).refs[0].position
        $awayX = $enemyPosition[0] - $attackerPosition[0]
        $awayY = $enemyPosition[1] - $attackerPosition[1]
        $separation = [math]::Sqrt($awayX*$awayX + $awayY*$awayY)
        if ($separation -lt 1) { throw 'Overlapping actors; safe player attack lane unavailable' }
        $offsetX = $awayX / $separation * 85.0
        $offsetY = $awayY / $separation * 85.0
        Invoke-NpcPapyrus ObjectReference MoveTo $player @(@{form=$enemy},$offsetX,$offsetY,0.0,$false) | Out-Null
        $attackYaw = ([math]::Atan2(-$offsetX,-$offsetY)*180.0/[math]::PI + 360.0) % 360.0
        Invoke-NpcPapyrus ObjectReference SetAngle $player @(0.0,0.0,$attackYaw) | Out-Null
        $distance = (Invoke-NpcPapyrus ObjectReference GetDistance $player @(@{form=$enemy})).returned
        if ($distance -gt 100.0) { throw 'Player outside controlled melee range' }
        $drawn = (Invoke-NpcPapyrus Actor IsWeaponDrawn $player).returned
        if ($drawn -ne $true) { throw 'Player weapon not drawn before melee input' }
        $summary.attackAttempts += [pscustomobject]@{attempt=$attempt;distance=$distance;weaponDrawn=$drawn}
        Invoke-YieldTool input @{ action='tap'; device='keyboard'; key='mouseLeft'; durationMs=100; owner=$RunId } | Out-Null
        Invoke-YieldTool input @{ action='releaseAll'; device='keyboard'; owner=$RunId } | Out-Null
        $deadline = (Get-Date).AddSeconds(3)
        do {
            $defeated = (Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$enemy})).returned
            if ($defeated -eq $true) { break }
            Start-Sleep -Milliseconds 100
        } while ((Get-Date) -lt $deadline)
        if ($defeated -eq $true) { break }
        if ((Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$attacker})).returned) { throw 'Player attack downed the attacker; test invalid' }
    }
    if ($defeated -ne $true) { throw 'Normal player attack attempts did not defeat the enemy' }
    }
    Invoke-NpcPapyrus Actor SetDontMove $enemy @($false) | Out-Null
    $dead = (Invoke-NpcPapyrus Actor IsDead $enemy).returned
    $pacified = (Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$enemy})).returned
    $health = (Invoke-NpcPapyrus Actor GetActorValue $enemy @('Health')).returned
    $defeatSource = if ($DefeatByAttacker) { $attacker } else { $player }
    Assert-YieldDefeatEvidence (Get-Content -LiteralPath $logPath -Raw) $enemy $dead $defeated $pacified $health $defeatSource
    Set-YieldActionCamera $enemy
    $summary.samples = @()
    $deadline = (Get-Date).AddSeconds(15)
    do {
        $snapshot = [ordered]@{ utc=[datetime]::UtcNow.ToString('o');
            attackerInCombat=(Invoke-NpcPapyrus Actor IsInCombat $attacker).returned;
            attackerTarget=(Invoke-NpcPapyrus Actor GetCombatTarget $attacker).returned;
            attackerDefeated=(Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$attacker})).returned;
            attackerPacified=(Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$attacker})).returned;
            attackerHostileToPlayer=(Invoke-NpcPapyrus Actor IsHostileToActor $attacker @(@{form=$player})).returned;
            enemyDefeated=(Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$enemy})).returned;
            enemyPacified=(Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$enemy})).returned }
        $summary.samples += $snapshot
        if (-not $snapshot.enemyDefeated -or -not $snapshot.enemyPacified) { throw 'Enemy left defeated/pacified state during observation' }
        if ($snapshot.attackerHostileToPlayer) { throw 'Attacker turned hostile to player during observation' }
        if ($snapshot.attackerDefeated -or $snapshot.attackerPacified) { throw 'Attacker also defeated/pacified; test invalid' }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)
    if ((Invoke-NpcPapyrus Actor IsDead $attacker).returned -or (Invoke-NpcPapyrus Actor IsDead $enemy).returned) { throw 'Fixture died during observation' }
    $fullLog = Get-Content -LiteralPath $logPath -Raw
    $marker = [regex]::Match($fullLog, [regex]::Escape(($enemy -replace '^0x','')) + ' \([^\r\n]*\) has been pacified')
    if (-not $marker.Success) { throw 'Pacification boundary missing from native log' }
    $afterLog = $fullLog.Substring($marker.Index)
    $afterLog | Set-Content (Join-Path $RunDirectory 'after-pacification.log')
    $summary.pacification = Measure-Pacification $beforeLog $afterLog $attacker $enemy
    Assert-PacificationStopped $summary.pacification
    [pscustomobject]@{ message='PASS: attacker stopped after enemy defeat/pacification'; screenshot=$null }
} finally {
    Invoke-YieldTool input @{ action='releaseAll'; device='keyboard'; owner=$RunId } | Out-Null
    foreach ($actorId in $owned) {
        Invoke-NpcPapyrus Actor StopCombat $actorId | Out-Null
        if ((Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$actorId})).returned) {
            Invoke-NpcPapyrus Acheron RescueActor '' @(@{form=$actorId},$true) | Out-Null
        }
        if ((Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$actorId})).returned -or (Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$actorId})).returned) { throw 'Fixture Acheron flags remained during cleanup' }
        Invoke-NpcPapyrus Actor SetDontMove $actorId @($false) | Out-Null
        Invoke-NpcPapyrus Actor SetPlayerTeammate $actorId @($false,$false) | Out-Null
        Invoke-NpcPapyrus ObjectReference Disable $actorId @($false) | Out-Null
        if ((Invoke-NpcPapyrus ObjectReference IsDisabled $actorId).returned -ne $true) { throw 'Fixture Disable did not complete' }
        Invoke-NpcPapyrus ObjectReference Delete $actorId | Out-Null
    }
    $summary.actorCleaned = $true
}
