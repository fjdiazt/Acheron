param([switch] $FleePackages)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Desktop-Isolation.ps1')
$repo=Split-Path -Parent $PSScriptRoot
$names=if($FleePackages){@('AcheronProbeFleeFrom - 000880_Acheron.esm.yaml','AcheronProbeFleeTo - 000881_Acheron.esm.yaml')}else{@('AcheronProbeTravel - 000880_Acheron.esm.yaml')}
$output=Join-Path $repo 'build/staging/peaceful/Acheron.esm'
$log=Join-Path $repo 'build/flee-isolation-records.log'
foreach($path in @($output,$log)) {Assert-DesktopWritePath $path}
foreach($name in $names) {
    $record=Join-Path $repo ('res/Packages/'+$name)
    Assert-DesktopWritePath $record
    if(Test-Path -LiteralPath $record) {throw 'Fixture record path occupied; refusing overwrite'}
}
$copied=@()
try {
    foreach($name in $names) {
        $record=Join-Path $repo ('res/Packages/'+$name)
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('fixtures/native-flee/'+$name)) -Destination $record
        $copied+=$record
    }
    & (Join-Path $repo 'build/tools/Spriggit/Spriggit.CLI.exe') deserialize -i (Join-Path $repo 'res') -o $output *> $log
    if($LASTEXITCODE) {throw "Native flee fixture compile failed; see $log"}
} finally {
    foreach($record in $copied) {
        Assert-DesktopWritePath $record
        if(Test-Path -LiteralPath $record) {Remove-Item -LiteralPath $record}
    }
}
'PASS: native flee fixtures compiled; production records unchanged'
