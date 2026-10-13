param(
    [ValidateSet('suite','god-preset','npc-defeat','follower-pacification','npc-pacification','follower-defeat','npc-lethal','player-finish-physical','player-finish-magic','essential-protection','npc-recovery-2s','npc-recovery-3s','native-peaceful-probe','native-talk-probe','native-aggression-probe','greeting-probe','native-dialogue-bypass-probe','peaceful-state','peaceful-healing','peaceful-movement','peaceful-lifecycle','peaceful-persistence','peaceful-talk','peaceful-reset','peaceful-kneeling','peaceful-kneeling-variants','peaceful-test-dialogue','peaceful-bind','injured-locomotion','rescue-locomotion','setup-enemy','setup-enemy-follower')]
    [string] $Test = 'suite',
    [string] $GameRoot = 'S:\games\The Elder Scrolls V - Skyrim Special Edition',
    [string] $PrefsPath = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'My Games\Skyrim Special Edition\SkyrimPrefs.ini'),
    [string] $ResultsRoot = (Join-Path $PSScriptRoot '..\build\test-results')
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Desktop-Isolation.ps1')

function Set-YieldTestDisplay([string] $Text, [int] $Width=800, [int] $Height=600) {
    $sections = [regex]::Matches($Text, '(?ims)^\[Display\][ \t]*\r?\n.*?(?=^\[|\z)')
    if ($sections.Count -ne 1) { throw 'Expected one [Display] section' }
    $section = $sections[0]
    $block = $section.Value
    foreach ($entry in @{ 'iSize W'=$Width; 'iSize H'=$Height; 'bFull Screen'=0; 'bBorderless'=0 }.GetEnumerator()) {
        $pattern = '(?im)^' + [regex]::Escape($entry.Key) + '[ \t]*=[^\r\n]*'
        if ([regex]::Matches($block, $pattern).Count -ne 1) { throw "Expected one Display setting: $($entry.Key)" }
        $block = [regex]::Replace($block, $pattern, "$($entry.Key)=$($entry.Value)")
    }
    return $Text.Substring(0, $section.Index) + $block + $Text.Substring($section.Index + $section.Length)
}

function Enable-YieldBackground([string] $Text) {
    $sections=[regex]::Matches($Text,'(?ims)^\[General\][ \t]*\r?\n.*?(?=^\[|\z)')
    if($sections.Count -ne 1) {throw 'Expected one [General] section'}
    $section=$sections[0]; $block=$section.Value
    $pattern='(?im)^bAlwaysActive[ \t]*=[^\r\n]*'
    $matches=[regex]::Matches($block,$pattern)
    if($matches.Count -gt 1) {throw 'Ambiguous bAlwaysActive setting'}
    if($matches.Count) {$block=[regex]::Replace($block,$pattern,'bAlwaysActive=1')}
    else {$block=[regex]::Replace($block,'^(\[General\][ \t]*\r?\n)','$1bAlwaysActive=1' + "`r`n")}
    return $Text.Substring(0,$section.Index)+$block+$Text.Substring($section.Index+$section.Length)
}

function Test-YieldProcessOwnership($Candidate, [string] $GameExe, [int] $LoaderId, [datetime] $StartedAt) {
    return $null -ne $Candidate -and $Candidate.ParentProcessId -eq $LoaderId -and
        [string]::Equals($Candidate.ExecutablePath, $GameExe, [StringComparison]::OrdinalIgnoreCase) -and
        $Candidate.CreationDate -ge $StartedAt.AddSeconds(-1)
}

function Disable-YieldTestAutosaves([string] $Text) {
    $sections = [regex]::Matches($Text, '(?ims)^\[MAIN\][ \t]*\r?\n.*?(?=^\[|\z)')
    if ($sections.Count -ne 1) { throw 'Expected one [MAIN] section' }
    $section = $sections[0]
    $block = $section.Value
    foreach ($key in @('bSaveOnPause','bSaveOnTravel','bSaveOnWait','bSaveOnRest')) {
        $pattern = '(?im)^' + $key + '[ \t]*=[^\r\n]*'
        if ([regex]::Matches($block, $pattern).Count -ne 1) { throw "Expected one autosave setting: $key" }
        $block = [regex]::Replace($block, $pattern, "$key=0")
    }
    return $Text.Substring(0, $section.Index) + $block + $Text.Substring($section.Index + $section.Length)
}

function Test-YieldBenchIdentity($Health, $Owned) {
    return $null -ne $Owned -and $Health.pid -eq $Owned.ProcessId -and $Health.vr -eq $false -and
        [string]::Equals($Health.exe, [IO.Path]::GetFileName($Owned.ExecutablePath), [StringComparison]::OrdinalIgnoreCase)
}

function Test-YieldLiveProcess($Current, $Owned) {
    # Parentage was verified at launch; path and birth time pin that same instance.
    return $null -ne $Current -and $Current.Id -eq $Owned.ProcessId -and
        [string]::Equals($Current.Path, $Owned.ExecutablePath, [StringComparison]::OrdinalIgnoreCase) -and
        [math]::Abs(($Current.StartTime - $Owned.CreationDate).TotalMilliseconds) -lt 1
}

function Assert-YieldCaseResult([string] $ExpectedTest, [int] $ExitCode, $Result) {
    if ($ExitCode -ne 0 -or $Result.test -ne $ExpectedTest -or $Result.status -ne 'PASS' -or
        $Result.actorCleaned -ne $true -or $Result.gracefulExit -ne $true -or $Result.settingsRestored -ne $true) {
        throw "Suite case failed or incomplete: $ExpectedTest"
    }
    if ($ExpectedTest -like 'npc-recovery-*' -and $Result.recoverySettingsRestored -ne $true) { throw 'NPC recovery timer restoration not verified' }
}

function Set-YieldRecoveryTimer([string] $Text, [ValidateSet(2,3)] [int] $Seconds) {
    if ([regex]::Matches($Text, '(?m)^iNPCRescueTimer:').Count -ne 1) { throw 'Expected one NPC recovery timer' }
    $setting = [regex]::Match($Text, '(?m)^(iNPCRescueTimer:[ \t]*)\d+([ \t]*(?:#[^\r\n]*)?)(?=\r?$)')
    if (-not $setting.Success) { throw 'Invalid NPC recovery timer' }
    return $Text.Substring(0, $setting.Index) + $setting.Groups[1].Value + $Seconds + $setting.Groups[2].Value + $Text.Substring($setting.Index + $setting.Length)
}

function Invoke-YieldTool([string] $Name, [hashtable] $Arguments) {
    $health = Invoke-RestMethod "$benchUri/api/health" -TimeoutSec 3
    $current = Get-Process -Id $ownedProcess.ProcessId -ErrorAction SilentlyContinue
    if (-not (Test-YieldBenchIdentity $health $ownedProcess) -or
        -not (Test-YieldLiveProcess $current $ownedProcess)) {
        throw 'DevBench instance identity changed; refusing command'
    }
    $record = [ordered]@{ runId=$runId; time=[datetime]::UtcNow.ToString('o'); tool=$Name; args=$Arguments }
    try {
        $response = Invoke-RestMethod "$benchUri/api/tool/$Name" -Method Post -ContentType 'application/json' -Body ($Arguments | ConvertTo-Json -Depth 20 -Compress) -TimeoutSec 20
        $record.response = $response
        if ($response.error) { throw $response.error }
        return $response
    } catch {
        $record.error = $_.Exception.Message
        if ($_.ErrorDetails.Message) { $record.details = $_.ErrorDetails.Message }
        throw
    } finally {
        $record | ConvertTo-Json -Depth 30 -Compress | Add-Content -LiteralPath (Join-Path $runDirectory 'tools.jsonl') -Encoding utf8
    }
}

function Set-YieldActionCamera([string] $Target) {
    $freeCamera = Invoke-YieldTool camera @{ action='freecam'; on=$true }
    if (-not $freeCamera.freeCam) { throw 'Action camera did not enter freecam' }
    $summary.actionCamera = Invoke-YieldTool camera @{ action='frame'; formId=$Target; aroundDeg=135; distance=450; eyeHeight=1.2; pitchDeg=20 }
}

function Stop-ScenarioGame([string] $GameExe, [string] $LoaderExe) {
    foreach($process in @(Get-Process SkyrimSE,skse64_loader -ErrorAction SilentlyContinue | Where-Object {
        $_.Path -eq $GameExe -or $_.Path -eq $LoaderExe
    })) {
        Stop-Process -InputObject $process -Force -ErrorAction Stop
        if(-not $process.WaitForExit(5000)) {throw 'Targeted Skyrim did not exit; refusing scenario startup'}
    }
}

# Dot sourcing exposes only the real boundary checks to the self-test.
if ($MyInvocation.InvocationName -eq '.') { return }

$setupOnly = $Test -in @('setup-enemy','setup-enemy-follower')

if ($Test -eq 'suite') {
    Assert-DesktopWritePath $ResultsRoot
    $suiteDirectory = Join-Path ([IO.Path]::GetFullPath($ResultsRoot)) ('suite-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $suiteDirectory | Out-Null
    $suite = [ordered]@{ test='suite'; status='FAIL'; cases=@() }
    try {
        foreach ($case in @('npc-defeat','follower-pacification','npc-pacification','follower-defeat','npc-lethal','player-finish-physical','player-finish-magic','essential-protection','npc-recovery-2s','npc-recovery-3s')) {
            $caseRoot = Join-Path $suiteDirectory $case
            & pwsh -NoProfile -File $PSCommandPath -Test $case -GameRoot $GameRoot -PrefsPath $PrefsPath -ResultsRoot $caseRoot
            $caseExit = $LASTEXITCODE
            $resultFile = Get-ChildItem -LiteralPath $caseRoot -Filter summary.json -Recurse -File -ErrorAction Stop
            if (@($resultFile).Count -ne 1) { throw "Expected one result for $case" }
            $result = Get-Content -LiteralPath $resultFile.FullName -Raw | ConvertFrom-Json
            $suite.cases += [pscustomobject]@{ test=$case; exitCode=$caseExit; status=$result.status; results=$resultFile.DirectoryName }
            Assert-YieldCaseResult $case $caseExit $result
        }
        $suite.status = 'PASS'
    } catch { $suite.error = $_.Exception.Message; Write-Warning $suite.error }
    $suite | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $suiteDirectory 'summary.json') -Encoding utf8
    Write-Output "$($suite.status): suite; results=$suiteDirectory"
    if ($suite.status -eq 'PASS') { exit 0 } else { exit 1 }
}

$script:gameExe = [IO.Path]::GetFullPath((Join-Path $GameRoot 'SkyrimSE.exe'))
foreach($path in @($GameRoot,$PrefsPath,$ResultsRoot,(Join-Path $GameRoot 'Data\SKSE'),(Join-Path (Split-Path -Parent $PrefsPath) 'SKSE'))) {Assert-DesktopWritePath $path}
foreach($relative in @('Data\SKSE\Plugins\devbench\runtime.json','Data\SKSE\Plugins\OpenAnimationReplacer.ini','Data\SKSE\Acheron\Settings.yaml','Data\SKSE\Acheron\Consequences\Weights.yaml')) {Assert-DesktopWritePath (Join-Path $GameRoot $relative)}
$loaderExe = [IO.Path]::GetFullPath((Join-Path $GameRoot 'skse64_loader.exe'))
foreach ($file in @($gameExe, $loaderExe, $PrefsPath,
    (Join-Path $GameRoot 'Data\SKSE\Plugins\devbench.dll'),
    (Join-Path $GameRoot 'Data\SKSE\Plugins\versionlib-1-6-1170-0.bin'))) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing prerequisite: $file" }
}
if ((Get-Item -LiteralPath $gameExe).VersionInfo.FileVersion -ne '1.6.1170.0') { throw 'Smoke setup requires Skyrim 1.6.1170.0' }
if (-not $setupOnly -and (Get-Process SkyrimSE,skse64_loader -ErrorAction SilentlyContinue)) { throw 'Skyrim already running; refusing to take over user session' }
foreach ($relative in @('Data\Acheron.esm','Data\Scripts\Acheron.pex','Data\SKSE\Plugins\Acheron.dll','Data\SKSE\Plugins\PapyrusUtil.dll','Data\SkyUI_SE.esp')) {
    if (-not (Test-Path -LiteralPath (Join-Path $GameRoot $relative))) { throw "NPC test prerequisite missing: $relative" }
}
if($setupOnly) {Stop-ScenarioGame $gameExe $loaderExe}

$script:runId = [guid]::NewGuid().ToString()
$script:runDirectory = Join-Path ([IO.Path]::GetFullPath($ResultsRoot)) $runId
New-Item -ItemType Directory -Path $runDirectory | Out-Null
$originalPrefs = [IO.File]::ReadAllBytes($PrefsPath)
$mainIni=Join-Path (Split-Path -Parent $PrefsPath) 'Skyrim.ini'
Assert-DesktopWritePath $mainIni
$originalIni=[IO.File]::ReadAllBytes($mainIni)
$activeIni=Enable-YieldBackground ([IO.File]::ReadAllText($mainIni))
[IO.File]::WriteAllBytes((Join-Path $runDirectory 'Skyrim.ini.before'),$originalIni)
$smallPrefs = if($setupOnly) {Set-YieldTestDisplay ([IO.File]::ReadAllText($PrefsPath)) 1920 1080} else {Disable-YieldTestAutosaves (Set-YieldTestDisplay ([IO.File]::ReadAllText($PrefsPath)))}
[IO.File]::WriteAllBytes((Join-Path $runDirectory 'SkyrimPrefs.ini.before'), $originalPrefs)
$summary = [ordered]@{ schema=1; runId=$runId; test=$Test; status='FAIL'; resolution=$(if($setupOnly){'1920x1080'}else{'800x600'}); screenshot=$null; gracefulExit=$false; settingsRestored=$false }
$summary.build=@{}
foreach($relative in @('Data\Acheron.esm','Data\SKSE\Plugins\Acheron.dll','Data\Scripts\Acheron.pex')) {
    $summary.build[$relative]=(Get-FileHash -LiteralPath (Join-Path $GameRoot $relative) -Algorithm SHA256).Hash
}
$recoverySeconds = switch ($Test) { 'npc-recovery-2s' { 2 }; 'npc-recovery-3s' { 3 }; default { 0 } }
$originalSettings = $null
if ($recoverySeconds) {
    $settingsPath = Join-Path $GameRoot 'Data\SKSE\Acheron\Settings.yaml'
    Assert-DesktopWritePath $settingsPath
    $originalSettings = [IO.File]::ReadAllBytes($settingsPath)
    $shortSettings = Set-YieldRecoveryTimer ([IO.File]::ReadAllText($settingsPath)) $recoverySeconds
    [IO.File]::WriteAllBytes((Join-Path $runDirectory 'Settings.yaml.before'), $originalSettings)
    $summary.recoverySeconds = $recoverySeconds
    $summary.recoverySettingsRestored = $false
}
$script:ownedProcess = $null
$script:benchUri = $null
$loader = $null
$exitCode = 1

try {
    # Runtime setini cannot run if startup is already paused after losing focus.
    Assert-DesktopWritePath $mainIni
    [IO.File]::WriteAllText($mainIni,$activeIni,[Text.UTF8Encoding]::new($false))
    Assert-DesktopWritePath $PrefsPath
    [IO.File]::WriteAllText($PrefsPath, $smallPrefs, [Text.UTF8Encoding]::new($false))
    $running = @(Get-Process SkyrimSE,skse64_loader -ErrorAction SilentlyContinue)
    if($setupOnly) {$running=@($running | Where-Object {$_.Path -eq $gameExe -or $_.Path -eq $loaderExe})}
    if ($running.Count) { throw 'Game appeared during preflight; refusing launch' }
    if ($recoverySeconds) { [IO.File]::WriteAllText($settingsPath, $shortSettings, [Text.UTF8Encoding]::new($false)) }
    $startedAt = Get-Date
    $loader = Start-Process -FilePath $loaderExe -WorkingDirectory $GameRoot -WindowStyle Hidden -PassThru
    $summary.loaderPID = $loader.Id
    $deadline = (Get-Date).AddSeconds(120)
    $runtimeFile = Join-Path $GameRoot 'Data\SKSE\Plugins\devbench\runtime.json'
    do {
        $candidates = @(Get-CimInstance Win32_Process -Filter "Name='SkyrimSE.exe'")
        if (-not $ownedProcess) {
            $script:ownedProcess = $candidates | Where-Object { Test-YieldProcessOwnership $_ $gameExe $loader.Id $startedAt } | Select-Object -First 1
        }
        if ($ownedProcess -and -not ($candidates.ProcessId -contains $ownedProcess.ProcessId)) { throw 'Owned game exited during startup' }
        if ($ownedProcess -and (Test-Path -LiteralPath $runtimeFile) -and (Get-Item -LiteralPath $runtimeFile).LastWriteTime -ge $startedAt.AddSeconds(-1)) {
            try {
                $runtime = Get-Content -LiteralPath $runtimeFile -Raw | ConvertFrom-Json
                if ($runtime.port -lt 1 -or $runtime.port -gt 65535) { throw 'Invalid DevBench port' }
                $script:benchUri = "http://127.0.0.1:$($runtime.port)"
                $health = Invoke-RestMethod "$benchUri/api/health" -TimeoutSec 2
                if (-not (Test-YieldBenchIdentity $health $ownedProcess)) { throw 'DevBench identity mismatch' }
                $state = Invoke-YieldTool inspect @{ kind='state' }
                $menus = Invoke-YieldTool menu @{ action='list' }
                if ($menus.openMenus -contains 'Main Menu') { break }
            } catch { $summary.lastStartupError = $_.Exception.Message }
        }
        Start-Sleep -Milliseconds 250
    } while ((Get-Date) -lt $deadline)
    if (-not $menus -or -not ($menus.openMenus -contains 'Main Menu')) { throw 'Timed out waiting for owned DevBench main menu' }
    $summary.gamePID = $ownedProcess.ProcessId
    $summary.devbench = $state
    $summary.endpoint = $benchUri
    # Losing window focus otherwise stops the main-thread queue used by DevBench.
    Invoke-YieldTool console @{ action='exec'; command='setini "bAlwaysActive:General" 1' } | Out-Null
    # Papyrus calls need a running world, not the main menu VM.
    Invoke-YieldTool console @{ action='exec'; command='coc UnownedCell' } | Out-Null
    $deadline = (Get-Date).AddSeconds(60)
    do {
        $state = Invoke-YieldTool inspect @{ kind='state' }
        $menus = Invoke-YieldTool menu @{ action='list' }
        if ($state.playerLoaded -and -not ($menus.openMenus -contains 'Main Menu') -and -not ($menus.openMenus -contains 'Loading Menu')) { break }
        Start-Sleep -Milliseconds 250
    } while ((Get-Date) -lt $deadline)
    if (-not $state.playerLoaded -or $menus.openMenus -contains 'Main Menu' -or $menus.openMenus -contains 'Loading Menu') { throw 'Timed out entering fresh UnownedCell world' }
    $summary.world = $state
    . (Join-Path $PSScriptRoot 'Npc-Papyrus.ps1')
    $summary.backgroundActive = (Invoke-NpcPapyrus Utility GetINIBool '' @('bAlwaysActive:General')).returned
    if ($summary.backgroundActive -ne $true) { throw 'Skyrim background execution not enabled' }
    $summary.player = Set-YieldPlayerAppearance
    # Character creation owns the camera; establish the case view after it closes.
    Invoke-YieldTool console @{ action='exec'; command='fov 120' } | Out-Null
    $pov = if($setupOnly) {'first'} else {'third'}
    $summary.camera = Invoke-YieldTool camera @{ action='setPov'; pov=$pov }
    if ($summary.camera.pov -ne $pov) { throw "Camera did not enter $pov person" }
    $summary.fovRequested = 120
    $summary.player.equipment = Set-YieldPlayerEquipment
    $policyLog = Get-Content -LiteralPath (Join-Path (Split-Path -Parent $PrefsPath) 'SKSE\Acheron.log') -Raw
    if ($policyLog -notmatch '\[YieldPolicy\] npcDefeat=false followerDefeat=true hunterPrideFollower=true lethalNPC=100 processing=true consequence=false') { throw 'Native combat policy mismatch' }
    $summary.policyVerified = $true
    $hunterSpell = (Invoke-NpcPapyrus Game GetFormFromFile '' @(0x807,'Acheron.esm')).returned.formId
    # Main-menu coc bypasses normal new-game/load events; case setup activates the ability.
    $summary.hunterEnabledAtBootstrap = (Invoke-NpcPapyrus Actor HasSpell '0x00000014' @(@{form=$hunterSpell})).returned
    $caseScript = switch ($Test) {
        'god-preset' { 'God-Preset.ps1' }
        'npc-defeat' { 'Npc-Defeat.ps1' }
        'follower-pacification' { 'Pacification.ps1' }
        'npc-pacification' { 'Pacification.ps1' }
        'follower-defeat' { 'Pacification.ps1' }
        'npc-lethal' { 'Pacification.ps1' }
        'player-finish-physical' { 'Npc-Defeat.ps1' }
        'player-finish-magic' { 'Npc-Defeat.ps1' }
        'essential-protection' { 'Npc-Defeat.ps1' }
        'npc-recovery-2s' { 'Npc-Defeat.ps1' }
        'npc-recovery-3s' { 'Npc-Defeat.ps1' }
        'native-peaceful-probe' { 'Native-Peaceful-Probe.ps1' }
        'native-talk-probe' { 'Native-Peaceful-Probe.ps1' }
        'native-aggression-probe' { 'Native-Aggression-Probe.ps1' }
        'greeting-probe' { 'Greeting-Probe.ps1' }
        'native-dialogue-bypass-probe' { 'Native-Aggression-Probe.ps1' }
        'peaceful-state' { 'Pacification-State.ps1' }
        'peaceful-healing' { 'Pacification-Healing.ps1' }
        'peaceful-movement' { 'Pacification-Movement.ps1' }
        'peaceful-lifecycle' { 'Pacification-Lifecycle.ps1' }
        'peaceful-persistence' { 'Pacification-Persistence.ps1' }
        'peaceful-talk' { 'Pacification-Talk.ps1' }
        'peaceful-reset' { 'Pacification-Reset.ps1' }
        'peaceful-kneeling' { 'Pacification-Kneeling.ps1' }
        'peaceful-kneeling-variants' { 'Pacification-KneelingVariants.ps1' }
        'peaceful-test-dialogue' { 'Pacification-TestDialogue.ps1' }
        'peaceful-bind' { 'Pacification-Kneeling.ps1' }
        'injured-locomotion' { 'Injured-Locomotion.ps1' }
        'rescue-locomotion' { 'Rescue-Locomotion.ps1' }
        'setup-enemy' { '../scripts/Setup-Scenario.ps1' }
        'setup-enemy-follower' { '../scripts/Setup-Scenario.ps1' }
    }
    $caseArguments = @{ RunId=$runId; RunDirectory=$runDirectory }
    if ($Test -eq 'peaceful-bind') { $caseArguments.BindOnly = $true }
    if ($Test -eq 'native-talk-probe') { $caseArguments.DialogueOnly = $true }
    if ($Test -eq 'native-aggression-probe') { $caseArguments.RequireOriginalTalk = $true }
    if ($Test -eq 'native-dialogue-bypass-probe') { $caseArguments.Bypass = $true }
    if ($Test -in @('npc-pacification','npc-lethal')) { $caseArguments.AttackerFixture = 'guard' }
    if ($Test -in @('follower-defeat','npc-lethal')) { $caseArguments.DefeatByAttacker = $true }
    if ($Test -eq 'player-finish-physical') { $caseArguments.FinishMode = 'physical' }
    if ($Test -eq 'player-finish-magic') { $caseArguments.FinishMode = 'magic' }
    if ($Test -eq 'essential-protection') { $caseArguments.FinishMode = 'essential' }
    if ($recoverySeconds) { $caseArguments.RecoverySeconds = $recoverySeconds }
    if ($Test -eq 'setup-enemy-follower') { $caseArguments.WithFollower = $true }
    $testResult = & (Join-Path $PSScriptRoot $caseScript) @caseArguments
    $summary.message = $testResult.message
    $summary.screenshot = $testResult.screenshot
    if($setupOnly) {
        if($summary.scenarioReady -ne $true) {throw 'Scenario did not qualify for manual handoff'}
        $summary.camera = Invoke-YieldTool camera @{ action='setPov'; pov='first' }
        if($summary.camera.pov -ne 'first') {throw 'Scenario camera did not stay in first person'}
    }
    $exitCode = 0
} catch {
    $summary.error = $_.Exception.Message
    Write-Warning $summary.error
} finally {
    if($setupOnly -and $exitCode -eq 0) {
        $summary.gameLeftOpen=$true
        $summary.displaySettingsKept=$true
    } else {
        if ($ownedProcess) {
            $current = Get-CimInstance Win32_Process -Filter "ProcessId=$($ownedProcess.ProcessId)"
            if ($current -and (Test-YieldProcessOwnership $current $gameExe $loader.Id $startedAt) -and $current.CreationDate -eq $ownedProcess.CreationDate) {
                try { Invoke-YieldTool console @{ action='exec'; command='qqq' } | Out-Null } catch { $summary.shutdownRequestError = $_.Exception.Message }
                $process = Get-Process -Id $ownedProcess.ProcessId -ErrorAction SilentlyContinue
                if ($process -and -not $process.WaitForExit(15000)) {
                    $current = Get-CimInstance Win32_Process -Filter "ProcessId=$($ownedProcess.ProcessId)"
                    if ($current -and (Test-YieldProcessOwnership $current $gameExe $loader.Id $startedAt) -and $current.CreationDate -eq $ownedProcess.CreationDate) {
                        Stop-Process -InputObject $process -Force
                        $process.WaitForExit(5000) | Out-Null
                        $summary.error = 'Graceful shutdown timed out; owned game terminated'
                        $exitCode = 1
                    }
                } else { $summary.gracefulExit = $true }
            } elseif (-not $current) { $summary.gracefulExit = $false }
        }
        if ($loader -and -not $loader.HasExited -and -not $loader.WaitForExit(5000)) {
            Stop-Process -InputObject $loader -Force
            $summary.error = 'Owned SKSE loader did not exit; terminated'
            $exitCode = 1
        }
        if (-not (Get-Process SkyrimSE -ErrorAction SilentlyContinue)) {
            if ($null -ne $originalSettings) {
                try {
                    Assert-DesktopWritePath $settingsPath
                    [IO.File]::WriteAllBytes($settingsPath, $originalSettings)
                    $summary.recoverySettingsRestored = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes($settingsPath))) -eq [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($originalSettings))
                } catch { $summary.error = "Recovery settings restoration failed: $($_.Exception.Message)"; $exitCode = 1 }
            }
            Assert-DesktopWritePath $PrefsPath
            [IO.File]::WriteAllBytes($PrefsPath, $originalPrefs)
            $summary.settingsRestored = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes($PrefsPath))) -eq [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($originalPrefs))
            if ($recoverySeconds -and -not $summary.recoverySettingsRestored) { $summary.settingsRestored = $false }
        } else { $summary.error = 'Game still running; settings backup retained, restoration deferred'; $exitCode = 1 }
        if (-not $summary.settingsRestored -or -not $summary.gracefulExit) { $exitCode = 1 }
    }
    try {
        Assert-DesktopWritePath $mainIni
        if([IO.File]::ReadAllText($mainIni) -cne $activeIni) {throw 'Skyrim.ini changed externally; backup retained'}
        [IO.File]::WriteAllBytes($mainIni,$originalIni)
        $summary.startupIniRestored=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes($mainIni))) -eq [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($originalIni))
        if(-not $summary.startupIniRestored) {throw 'Skyrim.ini restoration mismatch'}
    } catch {$summary.error=$_.Exception.Message; $exitCode=1}
    foreach ($log in @('skse64.log','devbench.log','Acheron.log','PapyrusUtilDev.log','OpenAnimationReplacer.log','AnimationQueueFix.log')) {
        $source = Join-Path (Split-Path -Parent $PrefsPath) "SKSE\$log"
        if (Test-Path -LiteralPath $source) { Copy-Item -LiteralPath $source -Destination (Join-Path $runDirectory $log) }
    }
    $summary.status = if ($exitCode -ne 0) { 'FAIL' } elseif($setupOnly) { 'READY' } else { 'PASS' }
    $summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $runDirectory 'summary.json') -Encoding utf8
}
Write-Output "$($summary.status): $Test; results=$runDirectory"
exit $exitCode
