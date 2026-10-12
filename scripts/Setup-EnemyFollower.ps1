param([string] $GameRoot='S:\games\The Elder Scrolls V - Skyrim Special Edition')
& pwsh -NoProfile -File (Join-Path $PSScriptRoot '../tests/Run-YieldTests.ps1') -Test setup-enemy-follower -GameRoot $GameRoot
exit $LASTEXITCODE
