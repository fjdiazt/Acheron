param(
    [ValidateSet('peaceful-suite','god-preset','peaceful-state','peaceful-healing','peaceful-movement','peaceful-lifecycle','peaceful-persistence','peaceful-talk','peaceful-reset','peaceful-kneeling','peaceful-kneeling-hold','peaceful-kneeling-variants','peaceful-test-dialogue','peaceful-bind','npc-defeat','player-finish-physical','rescue-locomotion','native-aggression-probe','greeting-probe','silent-greeting-probe','native-dialogue-bypass-probe')]
    [string] $Test='peaceful-suite',
    [string] $GameRoot='S:\games\The Elder Scrolls V - Skyrim Special Edition',
    [switch] $KeepInstalled
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Desktop-Isolation.ps1')
Assert-DesktopWritePath $GameRoot
$repo=Split-Path -Parent $PSScriptRoot
if(Get-Process SkyrimSE,skse64_loader -ErrorAction SilentlyContinue) {throw 'Skyrim running; refusing candidate deployment'}
$backup=Join-Path $repo ('build\pacification-backups\'+[guid]::NewGuid())
$files=@(
    @{target='Data\Acheron.esm';source='build\staging\peaceful\Acheron.esm'},
    @{target='Data\SKSE\Plugins\Acheron.dll';source='build\windows\x64\release\Acheron.dll'}
)
foreach($script in @('Acheron','AcheronHunterPride','AcheronMCM')) {
    $files+=@{target="Data\Scripts\$script.pex";source="build\staging\peaceful\Scripts\$script.pex"}
}
foreach($translation in Get-ChildItem (Join-Path $repo 'dist\Interface\Translations') -Filter 'Acheron_*.txt' -File) {
    $files+=@{target=('Data\Interface\Translations\'+$translation.Name);source=('dist\Interface\Translations\'+$translation.Name)}
}
foreach($asset in Get-ChildItem (Join-Path $repo 'build\staging\peaceful\meshes\actors\character\animations\DynamicAnimationReplacer\_CustomConditions') -File -Recurse) {
    $relative=$asset.FullName.Substring((Join-Path $repo 'build\staging\peaceful').Length+1)
    $files+=@{target=('Data\'+$relative);source=('build\staging\peaceful\'+$relative)}
}
foreach($retired in @('Data\Interface\Acheron\AcheronHunterPride.swf','Data\Interface\Acheron\AcheronIcons.swf','Data\Scripts\PRKF_AcheronInteraction_05000805.pex')) {
    if(Test-Path -LiteralPath (Join-Path $GameRoot $retired)) {$files+=@{target=$retired;source=$null}}
}
Assert-DesktopWritePath $backup
New-Item -ItemType Directory -Path $backup | Out-Null
foreach($entry in $files) {
    $entry.path=Join-Path $GameRoot $entry.target
    Assert-DesktopWritePath $entry.path
    $entry.originalHash=if(Test-Path -LiteralPath $entry.path) {(Get-FileHash -LiteralPath $entry.path).Hash}else{$null}
    $entry.backup=Join-Path $backup $entry.target
    New-Item -ItemType Directory -Path (Split-Path -Parent $entry.backup) -Force | Out-Null
    if($entry.originalHash) {Copy-Item -LiteralPath $entry.path -Destination $entry.backup}
    $entry.candidateHash=if($entry.source) {(Get-FileHash -LiteralPath (Join-Path $repo $entry.source)).Hash}else{$null}
}
$files|ConvertTo-Json|Set-Content (Join-Path $backup 'manifest.json')
$installed=@();$passed=$false
try {
    foreach($entry in $files) {
        Assert-DesktopWritePath $entry.path
        if($entry.source) {
            New-Item -ItemType Directory -Path (Split-Path -Parent $entry.path) -Force | Out-Null
            Copy-Item -LiteralPath (Join-Path $repo $entry.source) -Destination $entry.path
        }
        else {Remove-Item -LiteralPath $entry.path}
        $installed+=$entry
        if($entry.source) {
            if((Get-FileHash -LiteralPath $entry.path).Hash -ne $entry.candidateHash) {throw 'Candidate deployment hash mismatch'}
        } elseif(Test-Path -LiteralPath $entry.path) {throw 'Retired custom-menu file remains'}
    }
    $cases=if($Test -eq 'peaceful-suite') {@('peaceful-state','peaceful-healing','peaceful-movement','peaceful-lifecycle','peaceful-persistence','peaceful-talk')}else{@($Test)}
    foreach($case in $cases) {
        $runner=if($case -in @('rescue-locomotion','peaceful-bind','peaceful-kneeling','peaceful-kneeling-hold','peaceful-kneeling-variants','peaceful-test-dialogue')) {'Invoke-InjuredAnimationTests.ps1'}else{'Run-YieldTests.ps1'}
        & pwsh -NoProfile -File (Join-Path $PSScriptRoot $runner) -Test $case -GameRoot $GameRoot
        if($LASTEXITCODE) {throw "Pacification case failed: $case"}
    }
    $passed=$true
} finally {
    if(Get-Process SkyrimSE -ErrorAction SilentlyContinue) {throw "Game still running; restoration deferred. Backup: $backup"}
    if(-not ($KeepInstalled -and $passed)) {
        foreach($entry in $installed) {
            Assert-DesktopWritePath $entry.path
            if($entry.source) {
                if((Get-FileHash -LiteralPath $entry.path).Hash -ne $entry.candidateHash) {throw "Candidate target changed externally; preserve backup: $backup"}
            } elseif(Test-Path -LiteralPath $entry.path) {throw "Retired target recreated externally; preserve backup: $backup"}
            if($entry.originalHash) {
                Copy-Item -LiteralPath $entry.backup -Destination $entry.path
                if((Get-FileHash -LiteralPath $entry.path).Hash -ne $entry.originalHash) {throw 'Candidate restoration hash mismatch'}
            } else {
                Remove-Item -LiteralPath $entry.path
                if(Test-Path -LiteralPath $entry.path) {throw 'New candidate asset was not removed'}
            }
        }
        "Original files restored; backup=$backup"
    } else {"Qualified candidate installed; backup=$backup"}
}
