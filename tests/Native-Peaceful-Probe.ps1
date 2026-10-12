param([string] $RunId, [string] $RunDirectory, [switch] $DialogueOnly)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Npc-Papyrus.ps1')
. (Join-Path $PSScriptRoot 'Native-Peaceful-Evidence.ps1')
$player = '0x00000014'
$owned = @()
$probeErrors = @()
$summary.actorCleaned = $false
$logPath = Join-Path (Split-Path -Parent $PrefsPath) 'SKSE\Acheron.log'
function Read-ProbeActor([string] $ActorId) {
    $ref = (Invoke-YieldTool inspect @{kind='refs';formId=$ActorId}).refs[0]
    $package = (Invoke-NpcPapyrus Actor GetCurrentPackage $ActorId).returned
    return [pscustomobject]@{ time=[datetime]::UtcNow.ToString('o'); ref=$ref; package=$package }
}
try {
    Invoke-NpcPapyrus Actor SetActorValue $player @('Health',10000.0) | Out-Null
    $roles = if ($DialogueOnly) { @('subject') } else { @('subject','enemy','guard') }
    foreach ($role in $roles) {
        $base = if ($role -eq 'guard') { '0x000D3154' } else { $yieldEnemyBase }
        $before = Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
        $spawn = (Invoke-NpcPapyrus ObjectReference PlaceAtMe $player @(@{form=$base},1,$true,$true)).returned
        $after = Invoke-YieldTool inspect @{kind='refs';formType='Actor';limit=100}
        $id = Resolve-NpcSpawn $before $after $base $spawn.formId
        $owned += $id
        Set-Variable -Name $role -Value $id
        Invoke-NpcPapyrus Actor EnableAI $id @($false) | Out-Null
        $offsetX = if ($role -eq 'subject') { -120.0 } elseif ($role -eq 'guard') { 80.0 } else { 0.0 }
        Invoke-NpcPapyrus ObjectReference MoveTo $id @(@{form=$player},$offsetX,-85.0,0.0,$false) | Out-Null
        Invoke-NpcPapyrus ObjectReference Enable $id @($false) | Out-Null
        $deadline = (Get-Date).AddSeconds(5)
        do {
            $loaded = (Invoke-NpcPapyrus ObjectReference Is3DLoaded $id).returned
            if ($loaded -eq $true) { break }
            Start-Sleep -Milliseconds 100
        } while ((Get-Date) -lt $deadline)
        if ($loaded -ne $true) { throw 'Probe actor 3D did not load' }
        if($base -eq $yieldEnemyBase) {Set-NpcEnemyEquipment $id | Out-Null}
        Invoke-NpcPapyrus ObjectReference MoveTo $id @(@{form=$player},$offsetX,-85.0,0.0,$false) | Out-Null
        Invoke-NpcPapyrus Actor SetActorValue $id @('Health',10000.0) | Out-Null
        if ((Invoke-NpcPapyrus Actor GetActorValue $id @('Health')).returned -ne 10000.0) { throw 'Probe health buffer did not apply' }
        Invoke-NpcPapyrus Actor SetActorValue $id @('Confidence',4.0) | Out-Null
    }
    Invoke-NpcPapyrus Acheron PacifyActor '' @(@{form=$subject}) | Out-Null
    Invoke-NpcPapyrus Actor AllowPCDialogue $subject @($true) | Out-Null
    Invoke-NpcPapyrus Actor SetActorValue $subject @('Aggression',0.0) | Out-Null
    Invoke-NpcPapyrus Actor EnableAI $subject @($true) | Out-Null
    $flee = (Invoke-NpcPapyrus Game GetFormFromFile '' @(0x813,'Acheron.esm')).returned
    $wander = (Invoke-NpcPapyrus Game GetFormFromFile '' @(0x814,'Acheron.esm')).returned
    if (-not $flee.formId -or -not $wander.formId) { throw 'Native peaceful movement packages absent' }
    $summary.subject = $subject
    $summary.flee = $flee
    $summary.wander = $wander
    $anchor = (Invoke-NpcPapyrus ObjectReference PlaceAtMe $subject @(@{form='0x0000003B'},1,$true,$false)).returned.formId
    if (-not $anchor) { throw 'Probe anchor missing' }
    $summary.anchor = (Invoke-YieldTool inspect @{kind='refs';formId=$anchor}).refs[0]
    $goal = (Invoke-NpcPapyrus ObjectReference PlaceAtMe $subject @(@{form='0x0000003B'},1,$true,$false)).returned.formId
    if (-not $goal) { throw 'Probe local safe goal missing' }
    # UnownedCell NAVM is roughly 1768..2209 in X/Y; the earlier leftward goal left it.
    Invoke-NpcPapyrus ObjectReference MoveTo $goal @(@{form=$subject},-30.0,240.0,0.0,$false) | Out-Null
    $summary.goal = (Invoke-YieldTool inspect @{kind='refs';formId=$goal}).refs[0]
    Invoke-NpcPapyrus Acheron ProbePeacefulLinks '' @(@{form=$subject},@{form=$anchor},@{form=$goal}) | Out-Null
    if (-not $DialogueOnly) {
    foreach ($id in @($enemy,$guard)) { Invoke-NpcPapyrus Actor EnableAI $id @($true) | Out-Null }
    Invoke-NpcPapyrus Actor StartCombat $guard @(@{form=$enemy}) | Out-Null
    Set-YieldActionCamera $subject
    $baselinePattern = '\[YieldHit\] target=' + ($enemy -replace '^0x','') + ' source=' + ($guard -replace '^0x','') + ' damage=(?<damage>[0-9.eE+-]+) immune=false'
    $deadline = (Get-Date).AddSeconds(25)
    do {
        $baselineLog = Get-Content -LiteralPath $logPath -Raw
        if ($baselineLog -match $baselinePattern -and [double]::Parse($Matches.damage,[Globalization.CultureInfo]::InvariantCulture) -gt 0) { break }
        Start-Sleep -Milliseconds 200
    } while ((Get-Date) -lt $deadline)
    if ($baselineLog -notmatch $baselinePattern -or [double]::Parse($Matches.damage,[Globalization.CultureInfo]::InvariantCulture) -le 0) { throw 'Probe nearby combat has no confirmed guard hit' }
    $baselineLog | Set-Content (Join-Path $RunDirectory 'combat-baseline.log')
    Invoke-NpcPapyrus ActorUtil AddPackageOverride '' @(@{form=$subject},@{form=$flee.formId},31,1) | Out-Null
    Invoke-NpcPapyrus Actor EvaluatePackage $subject | Out-Null
    $samples = @()
    for ($i=0; $i -lt 10; $i++) {
        $samples += Read-ProbeActor $subject
        Start-Sleep -Milliseconds 500
    }
    $samples | ConvertTo-Json -Depth 20 | Set-Content (Join-Path $RunDirectory 'avoidance.json')
    try { Assert-NativePeacefulMovement $samples $subject $flee.formId $summary.anchor } catch { $probeErrors += $_.Exception.Message }
    if ((Invoke-NpcPapyrus Actor IsInCombat $guard).returned -ne $true -or (Invoke-NpcPapyrus Actor IsDead $enemy).returned) { throw 'Probe nearby combat ended before avoidance observation' }
    # Control isolates native pathing from Acheron suppression; never counts as qualification.
    Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$subject}) | Out-Null
    Invoke-NpcPapyrus Actor EvaluatePackage $subject | Out-Null
    $samples = @()
    for ($i=0; $i -lt 6; $i++) {
        $samples += Read-ProbeActor $subject
        Start-Sleep -Milliseconds 500
    }
    $samples | ConvertTo-Json -Depth 20 | Set-Content (Join-Path $RunDirectory 'avoidance-unpacified-control.json')
    try { Assert-NativePeacefulMovement $samples $subject $flee.formId $summary.anchor; $summary.unpacifiedControlMoved=$true } catch { $summary.unpacifiedControlMoved=$false }
    Invoke-NpcPapyrus Acheron PacifyActor '' @(@{form=$subject}) | Out-Null
    foreach ($id in @($enemy,$guard)) {
        Invoke-NpcPapyrus Actor EnableAI $id @($false) | Out-Null
        Invoke-NpcPapyrus Actor StopCombat $id | Out-Null
    }
    Invoke-NpcPapyrus ActorUtil RemovePackageOverride '' @(@{form=$subject},@{form=$flee.formId}) | Out-Null
    }
    Invoke-NpcPapyrus ActorUtil AddPackageOverride '' @(@{form=$subject},@{form=$wander.formId},31,1) | Out-Null
    Invoke-NpcPapyrus Actor EvaluatePackage $subject | Out-Null
    $samples = @()
    $sampleCount = if ($DialogueOnly) { 2 } else { 12 }
    for ($i=0; $i -lt $sampleCount; $i++) {
        $samples += Read-ProbeActor $subject
        Start-Sleep -Milliseconds 500
    }
    $samples | ConvertTo-Json -Depth 20 | Set-Content (Join-Path $RunDirectory 'wandering.json')
    if (-not $DialogueOnly) {
        try { Assert-NativePeacefulMovement $samples $subject $wander.formId $summary.anchor } catch { $probeErrors += $_.Exception.Message }
    }
    Invoke-YieldTool camera @{action='freecam';on=$false} | Out-Null
    Invoke-NpcPapyrus Actor StopCombat $player | Out-Null
    # DevBench omits formId when GetFormFromFile returns an attached quest script.
    if ($flee.formId -notmatch '813$') { throw 'Unexpected probe package form mapping' }
    $quest = $flee.formId -replace '813$','818'
    $summary.dialogueQuestStarted = (Invoke-NpcPapyrus Quest Start $quest).returned
    Start-Sleep -Milliseconds 300
    $summary.dialogueQuestRunning = (Invoke-NpcPapyrus Quest IsRunning $quest).returned
    if ($summary.dialogueQuestRunning -ne $true) { throw 'Probe dialogue quest did not start' }
    $summary.interactionPerk = (Invoke-NpcPapyrus Actor HasPerk $player @(@{form=($flee.formId -replace '813$','803')})).returned
    Invoke-NpcPapyrus ObjectReference Activate $subject @(@{form=$player},$false) | Out-Null
    $deadline = (Get-Date).AddSeconds(3)
    do {
        $summary.dialogue = Invoke-YieldTool menu @{action='list'}
        if ($summary.dialogue.openMenus -contains 'Dialogue Menu') { break }
        Start-Sleep -Milliseconds 100
    } while ((Get-Date) -lt $deadline)
    if ($summary.dialogue.openMenus -notcontains 'Dialogue Menu') { $probeErrors += 'Normal activation did not open dialogue' }
    $summary.actorInDialogue = (Invoke-NpcPapyrus Actor IsInDialogueWithPlayer $subject).returned
    Invoke-NpcPapyrus Acheron ProbePeacefulLinks '' @(@{form=$subject},@{form=$anchor},@{form=$goal}) | Out-Null
    $summary.probeErrors = $probeErrors
    if ($probeErrors.Count) { throw ($probeErrors -join '; ') }
    return @{message='Native movement and Talk probe';screenshot=$null}
} finally {
    if ($subject -and $flee.formId) { Invoke-NpcPapyrus ActorUtil RemovePackageOverride '' @(@{form=$subject},@{form=$flee.formId}) | Out-Null }
    if ($subject -and $wander.formId) { Invoke-NpcPapyrus ActorUtil RemovePackageOverride '' @(@{form=$subject},@{form=$wander.formId}) | Out-Null }
    if ($anchor) { Invoke-NpcPapyrus ObjectReference Disable $anchor @($false) | Out-Null; Invoke-NpcPapyrus ObjectReference Delete $anchor | Out-Null }
    if ($goal) { Invoke-NpcPapyrus ObjectReference Disable $goal @($false) | Out-Null; Invoke-NpcPapyrus ObjectReference Delete $goal | Out-Null }
    foreach ($id in $owned) {
        if ((Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$id})).returned) {
            Invoke-NpcPapyrus Acheron RescueActor '' @(@{form=$id},$true) | Out-Null
        }
        if ((Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$id})).returned) {
            Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$id}) | Out-Null
        }
        if ((Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$id})).returned -or (Invoke-NpcPapyrus Acheron IsPacified '' @(@{form=$id})).returned) { throw 'Probe cleanup retained Acheron state' }
        Invoke-NpcPapyrus ObjectReference Disable $id @($false) | Out-Null
        Invoke-NpcPapyrus ObjectReference Delete $id | Out-Null
    }
    $summary.actorCleaned = $true
}
