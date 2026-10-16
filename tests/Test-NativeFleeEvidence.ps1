$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Native-Flee-Evidence.ps1')
$original=@{distance=150;health=252;aggression=1;confidence=4;pacified=$true;paused=$false;combat=$false;hooksEnabled=$false;packageType=18;fleeing=$false}
foreach($type in @(10,22)) {
    $sample=$original.Clone();$sample.distance=700;$sample.packageType=$type
    $control=@{initial=$original;fleeInitial=$original;pacifiedRequested=$true;start=$original;samples=@($sample)}
    $result=Get-NativeFleeOutcome $control $false
    if(-not $result.fleeQualified -or $result.nativeFleeFlagObserved) {throw 'Native flee package/movement rejected because independent flee flag was false'}
}
foreach($failure in @('stationary','wrongPackage','health','aggression','confidence','pacified','paused','combat','hooksEnabled','defeated','bleedoutLocked','defeatPackage')) {
    $sample=$original.Clone();$sample.distance=700;$sample.packageType=22
    switch($failure) {
        'stationary' {$sample.distance=150}
        'wrongPackage' {$sample.packageType=18}
        'health' {$sample.health=200}
        'aggression' {$sample.aggression=0}
        'confidence' {$sample.confidence=0}
        'pacified' {$sample.pacified=$false}
        'paused' {$sample.paused=$true}
        'combat' {$sample.combat=$true}
        'hooksEnabled' {$sample.hooksEnabled=$true}
        'defeated' {$sample.defeated=$true}
        'bleedoutLocked' {$sample.bleedoutLocked=$true}
        'defeatPackage' {$sample.defeatPackage=$true}
    }
    $control.samples=@($sample)
    if((Get-NativeFleeOutcome $control $false).fleeQualified) {throw "Invalid flight accepted: $failure"}
}
'PASS: native package types10/22, false flee flag, actual movement, actor invariants and hook isolation'
