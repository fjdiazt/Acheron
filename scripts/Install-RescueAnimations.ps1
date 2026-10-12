param([string] $GameRoot='S:\games\The Elder Scrolls V - Skyrim Special Edition')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\tests\Desktop-Isolation.ps1')
Assert-DesktopWritePath $GameRoot
if(Get-Process SkyrimSE,skse64_loader -ErrorAction SilentlyContinue) {throw 'Close desktop before installing rescue animations'}
$relative='meshes\actors\character\animations\DynamicAnimationReplacer\_CustomConditions'
$source=Join-Path "$GameRoot\Data" "$relative\5000"
$target=Join-Path "$GameRoot\Data" "$relative\5001"
Assert-DesktopWritePath $source
Assert-DesktopWritePath $target
$clips=@(Get-ChildItem -LiteralPath $source -Recurse -File | Where-Object Name -match '^mt_(walk|run|sprint).*\.hkx$')
if($clips.Count -ne 33) {throw 'Expected 33 installed injury locomotion clips (root, male, female)'}
$files=@($clips | ForEach-Object { @{source=$_.FullName;target=(Join-Path $target $_.FullName.Substring($source.Length+1))} })
$files+=@{source=(Join-Path $PSScriptRoot "..\dist\$relative\5001\_conditions.txt");target=(Join-Path $target '_conditions.txt')}
foreach($file in $files) {
    Assert-DesktopWritePath $file.target
    $file.hash=(Get-FileHash -LiteralPath $file.source).Hash
    if((Test-Path -LiteralPath $file.target) -and (Get-FileHash -LiteralPath $file.target).Hash -ne $file.hash) {throw "Rescue animation path occupied by different content: $($file.target)"}
}
$manifest=Join-Path $PSScriptRoot ('..\build\rescue-animation-installs\'+[guid]::NewGuid()+'.json')
Assert-DesktopWritePath $manifest
New-Item -ItemType Directory -Path (Split-Path -Parent $manifest) -Force | Out-Null
$files | ConvertTo-Json | Set-Content -LiteralPath $manifest
foreach($file in $files) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $file.target) -Force | Out-Null
    Copy-Item -LiteralPath $file.source -Destination $file.target
    if((Get-FileHash -LiteralPath $file.target).Hash -ne $file.hash) {throw 'Rescue animation copy hash mismatch'}
}
"Installed 33 independent rescue locomotion clips and condition; manifest=$manifest"
