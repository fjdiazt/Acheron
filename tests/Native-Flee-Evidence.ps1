function Get-NativeFleeOutcome($Control, [bool] $HooksExpected) {
    $initial=$Control.initial
    $samples=@($Control.samples)
    if(-not $samples.Count) {throw 'Native flee observations missing'}
    $selected=if($Control.expectedPackage){@($samples|Where-Object {$_.package -eq $Control.expectedPackage})}else{@($samples|Where-Object {$_.packageType -in @(10,22)})}
    $metric=if($Control.requirePlanar){'planarDistance'}else{'distance'}
    $start=$Control.fleeInitial.$metric
    $measured=@($selected|Where-Object {$null -ne $_.$metric -and [double]::IsFinite($_.$metric)})
    $moved=$null -ne $start -and [double]::IsFinite($start) -and ($measured.$metric|Measure-Object -Maximum).Maximum -gt $start+350
    $native=@($selected).Count -gt 0
    $preserved=@($samples|Where-Object {
        $_.health -ne $initial.health -or $_.aggression -ne $initial.aggression -or
        $_.confidence -ne $initial.confidence -or $_.pacified -ne $Control.pacifiedRequested -or
        $_.defeated -or $_.bleedoutLocked -or $_.defeatPackage -or
        $_.paused -or $_.combat -or $_.hooksEnabled -ne $HooksExpected
    }).Count -eq 0
    return @{
        moved=$moved;nativePackageObserved=$native
        nativeFleeFlagObserved=(@($samples|Where-Object fleeing).Count -gt 0 -or $Control.start.fleeing)
        invariantsPreserved=$preserved;fleeQualified=$moved -and $native -and $preserved
    }
}
