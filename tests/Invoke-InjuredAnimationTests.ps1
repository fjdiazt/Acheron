param(
    [string] $GameRoot='S:\games\The Elder Scrolls V - Skyrim Special Edition',
    [ValidateSet('injured-locomotion','rescue-locomotion','peaceful-bind','peaceful-kneeling','peaceful-child-kneeling','peaceful-child-kneeling-male','peaceful-kneeling-hold','peaceful-kneeling-variants','peaceful-test-dialogue')] [string] $Test='injured-locomotion'
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Desktop-Isolation.ps1')
Assert-DesktopWritePath $GameRoot
if(Get-Process SkyrimSE,skse64_loader -ErrorAction SilentlyContinue) {throw 'Close desktop before animation test'}
foreach($relative in @('SKSE\Plugins\OpenAnimationReplacer.dll','SKSE\Plugins\AnimationQueueFix.dll','meshes\actors\character\animations\DynamicAnimationReplacer\_CustomConditions\5000\_conditions.txt')) {
    if(-not (Test-Path -LiteralPath (Join-Path "$GameRoot\Data" $relative))) {throw "Missing animation dependency: $relative"}
}
$ini=Join-Path $GameRoot 'Data\SKSE\Plugins\OpenAnimationReplacer.ini'
Assert-DesktopWritePath $ini
$original=if(Test-Path $ini) {[IO.File]::ReadAllBytes($ini)} else {$null}
try {
    [IO.File]::WriteAllText($ini,"[UI]`nbEnableAnimationLog=true`nbAnimationLogWriteToTextLog=true`nuAnimationActivateLogMode=2`nbAnimationLogOnlyActiveGraph=true`n")
    & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Run-YieldTests.ps1') -Test $Test -GameRoot $GameRoot
    $code=$LASTEXITCODE
} finally {
    if(Get-Process SkyrimSE -ErrorAction SilentlyContinue) {throw 'Game remains open; OAR config restoration deferred'}
    Assert-DesktopWritePath $ini
    if($null -ne $original) {[IO.File]::WriteAllBytes($ini,$original)} else {Remove-Item -LiteralPath $ini -ErrorAction SilentlyContinue}
}
exit $code
