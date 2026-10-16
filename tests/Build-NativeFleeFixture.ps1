$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Desktop-Isolation.ps1')
$repo=Split-Path -Parent $PSScriptRoot
$name='AcheronProbeTravel - 000880_Acheron.esm.yaml'
$record=Join-Path $repo ('res/Packages/'+$name)
$output=Join-Path $repo 'build/staging/peaceful/Acheron.esm'
$log=Join-Path $repo 'build/flee-isolation-records.log'
foreach($path in @($record,$output,$log)) {Assert-DesktopWritePath $path}
if(Test-Path -LiteralPath $record) {throw 'Fixture record path occupied; refusing overwrite'}
try {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('fixtures/native-flee/'+$name)) -Destination $record
    & (Join-Path $repo 'build/tools/Spriggit/Spriggit.CLI.exe') deserialize -i (Join-Path $repo 'res') -o $output *> $log
    if($LASTEXITCODE) {throw "Native flee fixture compile failed; see $log"}
} finally {
    Assert-DesktopWritePath $record
    if(Test-Path -LiteralPath $record) {Remove-Item -LiteralPath $record}
}
'PASS: native flee Travel fixture compiled; production records unchanged'
