$ErrorActionPreference = 'Stop'
$runner = Join-Path $PSScriptRoot 'Run-YieldTests.ps1'
if (-not (Test-Path -LiteralPath $runner)) { throw 'FAIL: smoke runner not implemented' }
. $runner

function Assert([bool] $Condition, [string] $Reason) {
    if (-not $Condition) { throw "FAIL: $Reason" }
}

# Catches edits outside Display, missing/duplicate keys, and accepting a foreign process.
$original = "[Other]`r`niSize W=999`r`n[Display]`r`niSize W=1920`r`niSize H=1080`r`nbFull Screen=1`r`nbBorderless=1`r`n[AudioMenu]`r`nfAudioMasterVolume=0.1`r`n"
$small = Set-YieldTestDisplay $original
$expected = "[Other]`r`niSize W=999`r`n[Display]`r`niSize W=800`r`niSize H=600`r`nbFull Screen=0`r`nbBorderless=0`r`n[AudioMenu]`r`nfAudioMasterVolume=0.1`r`n"
Assert ($small -ceq $expected) 'display edit changed unrelated settings or wrong dimensions'
Assert ((Set-YieldTestDisplay $original 1920 1080) -ceq $original.Replace('bFull Screen=1','bFull Screen=0').Replace('bBorderless=1','bBorderless=0')) 'scenario display edit changed unrelated settings or wrong dimensions'
$autosaves = "[Other]`r`nbSaveOnTravel=1`r`n[MAIN]`r`nbSaveOnPause=0`r`nbSaveOnTravel=1`r`nbSaveOnWait=1`r`nbSaveOnRest=1`r`n"
Assert ((Disable-YieldTestAutosaves $autosaves) -ceq "[Other]`r`nbSaveOnTravel=1`r`n[MAIN]`r`nbSaveOnPause=0`r`nbSaveOnTravel=0`r`nbSaveOnWait=0`r`nbSaveOnRest=0`r`n") 'autosave edit escaped MAIN or left saves enabled'
foreach ($bad in @('[Other]', $autosaves.Replace('bSaveOnWait=1', "bSaveOnWait=1`r`nbSaveOnWait=0"))) {
    $rejected = $false
    try { Disable-YieldTestAutosaves $bad | Out-Null } catch { $rejected = $true }
    Assert $rejected 'ambiguous/missing autosave settings accepted'
}
foreach ($bad in @('[Other]', $original.Replace('iSize H=1080', "iSize H=1080`r`niSize H=900"))) {
    $rejected = $false
    try { Set-YieldTestDisplay $bad | Out-Null } catch { $rejected = $true }
    Assert $rejected 'ambiguous/missing Display settings accepted'
}
$started = [datetime]'2026-10-11T12:00:00'
$owned = [pscustomobject]@{ ProcessId=42; ParentProcessId=7; ExecutablePath='S:\game\SkyrimSE.exe'; CreationDate=$started.AddSeconds(1) }
Assert (Test-YieldProcessOwnership $owned 'S:\game\SkyrimSE.exe' 7 $started) 'owned game rejected'
foreach ($foreign in @(
    [pscustomobject]@{ ProcessId=42; ParentProcessId=8; ExecutablePath='S:\game\SkyrimSE.exe'; CreationDate=$started.AddSeconds(1) },
    [pscustomobject]@{ ProcessId=42; ParentProcessId=7; ExecutablePath='S:\other\SkyrimSE.exe'; CreationDate=$started.AddSeconds(1) },
    [pscustomobject]@{ ProcessId=42; ParentProcessId=7; ExecutablePath='S:\game\SkyrimSE.exe'; CreationDate=$started.AddMinutes(-1) }
)) {
    Assert (-not (Test-YieldProcessOwnership $foreign 'S:\game\SkyrimSE.exe' 7 $started)) 'foreign/preexisting game accepted'
}
Assert (Test-YieldBenchIdentity ([pscustomobject]@{pid=42;exe='SkyrimSE.exe';vr=$false}) $owned) 'valid runtime identity rejected'
$live=[pscustomobject]@{Id=42;Path=$owned.ExecutablePath;StartTime=$owned.CreationDate}
Assert (Test-YieldLiveProcess $live $owned) 'same live instance rejected'
# CIM timestamps lose sub-microsecond precision; Get-Process retains it.
Assert (Test-YieldLiveProcess ([pscustomobject]@{Id=42;Path=$owned.ExecutablePath;StartTime=$owned.CreationDate.AddTicks(1)}) $owned) 'native timestamp precision rejected'
foreach($foreign in @($null,
    [pscustomobject]@{Id=43;Path=$owned.ExecutablePath;StartTime=$owned.CreationDate},
    [pscustomobject]@{Id=42;Path='S:\other\SkyrimSE.exe';StartTime=$owned.CreationDate},
    [pscustomobject]@{Id=42;Path=$owned.ExecutablePath;StartTime=$owned.CreationDate.AddSeconds(1)}
)) {Assert (-not (Test-YieldLiveProcess $foreign $owned)) 'foreign or reused PID accepted'}
foreach ($foreignHealth in @(
    [pscustomobject]@{pid=43;exe='SkyrimSE.exe';vr=$false},
    [pscustomobject]@{pid=42;exe='SkyrimVR.exe';vr=$false},
    [pscustomobject]@{pid=42;exe='SkyrimSE.exe';vr=$true}
)) {
    Assert (-not (Test-YieldBenchIdentity $foreignHealth $owned)) 'wrong endpoint identity accepted'
}

$goodCase=@{test='follower-pacification';status='PASS';actorCleaned=$true;gracefulExit=$true;settingsRestored=$true}
Assert-YieldCaseResult 'follower-pacification' 0 $goodCase
foreach ($field in @('test','status','actorCleaned','gracefulExit','settingsRestored')) {
    $badCase=$goodCase.Clone()
    $badCase[$field]=if ($field -in @('test','status')) { 'wrong' } else { $false }
    $rejected=$false
    try { Assert-YieldCaseResult 'follower-pacification' 0 $badCase } catch { $rejected=$true }
    Assert $rejected 'Failed or unrelated child case accepted by suite'
}
$rejected=$false
try { Assert-YieldCaseResult 'follower-pacification' 1 $goodCase } catch { $rejected=$true }
Assert $rejected 'Nonzero child exit accepted by suite'
$recoveryCase = $goodCase.Clone()
$recoveryCase.test = 'npc-recovery-2s'
$rejected = $false
try { Assert-YieldCaseResult 'npc-recovery-2s' 0 $recoveryCase } catch { $rejected = $true }
Assert $rejected 'Recovery case accepted without timer restoration'
$recoveryCase.recoverySettingsRestored = $true
Assert-YieldCaseResult 'npc-recovery-2s' 0 $recoveryCase
$yaml = "Other: 7`r`niNPCRescueTimer: 90 # desktop`r`nLast: true`r`n"
foreach ($seconds in @(2,3)) {
    Assert ((Set-YieldRecoveryTimer $yaml $seconds) -ceq $yaml.Replace('90 #', "$seconds #")) 'Recovery timer edit changed unrelated YAML'
}
foreach ($bad in @('Other: 7', "iNPCRescueTimer: 90`niNPCRescueTimer: 60", 'iNPCRescueTimer: invalid')) {
    $rejected = $false
    try { Set-YieldRecoveryTimer $bad 2 | Out-Null } catch { $rejected = $true }
    Assert $rejected 'Missing/ambiguous/invalid recovery timer accepted'
}
& {
    $scenarioCheckState=@{processes=@();stopped=[Collections.Generic.List[object]]::new()}
    function Get-Process([string[]] $Name, [string] $ErrorAction) {
        Assert (($Name -join ',') -eq 'SkyrimSE,skse64_loader') 'targeted shutdown targeted another game'
        return $scenarioCheckState.processes
    }
    function Stop-Process($InputObject, [switch] $Force, [string] $ErrorAction) {
        Assert ($Force -and $ErrorAction -eq 'Stop') 'targeted shutdown hid termination failures'
        $scenarioCheckState.stopped.Add($InputObject)
    }
    Stop-ScenarioGame 'S:\game\SkyrimSE.exe' 'S:\game\skse64_loader.exe'
    Assert ($scenarioCheckState.stopped.Count -eq 0) 'targeted shutdown attempted termination with no game'
    foreach($id in @(1,2)) {
        $p=[pscustomobject]@{Id=$id;exitWorks=$true;Path=$(if($id -eq 1){'S:\game\SkyrimSE.exe'}else{'S:\game\skse64_loader.exe'})}
        $p|Add-Member ScriptMethod WaitForExit {param($timeout) Assert ($timeout -eq 5000) 'targeted shutdown wait unbounded';return $this.exitWorks}
        $scenarioCheckState.processes+= $p
    }
    $scenarioCheckState.processes+= [pscustomobject]@{Id=3;Path='S:\other\SkyrimSE.exe'}
    $scenarioCheckState.processes+= [pscustomobject]@{Id=4;Path='S:\vr\SkyrimVR.exe'}
    $scenarioCheckState.processes+= [pscustomobject]@{Id=5;Path='S:\other\skse64_loader.exe'}
    $scenarioCheckState.processes+= [pscustomobject]@{Id=6;Path=$null}
    Stop-ScenarioGame 'S:\game\SkyrimSE.exe' 'S:\game\skse64_loader.exe'
    Assert (($scenarioCheckState.stopped.Id -join ',') -eq '1,2') 'shutdown touched another or unidentified installation'
    Assert ($scenarioCheckState.stopped.Count -eq 2) 'targeted shutdown skipped a running instance'
    $scenarioCheckState.processes=@($scenarioCheckState.processes[0]);$scenarioCheckState.processes[0].exitWorks=$false;$rejected=$false
    try {Stop-ScenarioGame 'S:\game\SkyrimSE.exe' 'S:\game\skse64_loader.exe'} catch {
        Assert ($_.Exception.Message -eq 'Targeted Skyrim did not exit; refusing scenario startup') 'unexpected shutdown failure'
        $rejected=$true
    }
    Assert $rejected 'scenario allowed startup with targeted game still running'
}
Write-Output 'PASS: settings boundaries, process ownership, suite result gate and mocked targeted shutdown'
