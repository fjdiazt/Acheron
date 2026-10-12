$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Desktop-Isolation.ps1')
function Assert-Rejected([string] $Path) {
    try {Assert-DesktopWritePath $Path} catch {return}
    throw "Unsafe path accepted: $Path"
}
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('yield-isolation-'+[guid]::NewGuid())
$junction=Join-Path $fixture 'shared'
try {
    New-Item -ItemType Directory -Path (Join-Path $fixture 'source') -Force | Out-Null
    $source=Join-Path $fixture 'source\config.ini'
    Set-Content -LiteralPath $source -Value 'unchanged'
    Assert-DesktopWritePath (Join-Path $fixture 'local\new.ini')
    Assert-DesktopWritePath $source
    New-Item -ItemType Junction -Path $junction -Target (Join-Path $fixture 'source') | Out-Null
    Assert-Rejected $junction
    Assert-Rejected (Join-Path $junction 'config.ini')
    Assert-Rejected (Join-Path $junction 'missing\new.ini')
    $hardlink=Join-Path $fixture 'shared.ini'
    New-Item -ItemType HardLink -Path $hardlink -Target $source | Out-Null
    Assert-Rejected $hardlink
    foreach($path in @('C:\bin\wabbajack\SkyrimVRMods\mods\new.ini','S:\SteamLibrary\steamapps\common\SkyrimVR\Data\new.ini',(Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'My Games\Skyrim VR\SkyrimPrefs.ini'))) {Assert-Rejected $path}
    if((Get-Content -LiteralPath $source -Raw).Trim() -ne 'unchanged') {throw 'Shared source changed'}
    'PASS: regular paths allowed; VR paths, linked files and linked ancestors rejected'
} finally {
    # Remove junction itself before recursive fixture cleanup; never traverse its target.
    if(Test-Path -LiteralPath $junction) {[IO.Directory]::Delete($junction)}
    $resolved=[IO.Path]::GetFullPath($fixture)
    if(-not $resolved.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()),[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($resolved) -notlike 'yield-isolation-*') {throw 'Unsafe fixture cleanup path'}
    if(Test-Path -LiteralPath $resolved) {Remove-Item -LiteralPath $resolved -Recurse -Force}
}
