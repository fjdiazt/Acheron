function Assert-NativePeacefulMovement([array] $Samples, [string] $ActorId, [string] $PackageId, $Anchor, [array] $InitialPosition = @()) {
    if ($Samples.Count -lt 2 -or $Anchor.position.Count -ne 3 -or -not $Anchor.cell.formId) { throw 'Native movement evidence incomplete' }
    $first = if ($InitialPosition.Count) { $InitialPosition } else { $Samples[0].ref.position }
    if ($first.Count -ne 3) { throw 'Native movement baseline invalid' }
    $maxDisplacement = 0.0
    foreach ($sample in $Samples) {
        if ($sample.ref.formId -ne $ActorId -or $sample.package.formId -ne $PackageId -or
            $sample.ref.actor.alive -ne $true -or $sample.ref.actor.loaded3D -ne $true -or
            $sample.ref.cell.formId -ne $Anchor.cell.formId -or $sample.ref.position.Count -ne 3) {
            throw 'Native movement actor/package invalid'
        }
        $radiusSquared = 0.0; $displacementSquared = 0.0
        for ($axis=0; $axis -lt 3; $axis++) {
            foreach ($value in @($sample.ref.position[$axis],$Anchor.position[$axis],$first[$axis])) {
                if ($null -eq $value -or -not [double]::IsFinite([double]$value)) { throw 'Native movement position invalid' }
            }
            $radiusSquared += [math]::Pow(($sample.ref.position[$axis] - $Anchor.position[$axis]),2)
            $displacementSquared += [math]::Pow(($sample.ref.position[$axis] - $first[$axis]),2)
        }
        if ($radiusSquared -gt 800*800) { throw 'Native movement left local radius' }
        $maxDisplacement = [math]::Max($maxDisplacement,[math]::Sqrt($displacementSquared))
    }
    if ($maxDisplacement -lt 40) { throw 'Native package selected but no local movement proven' }
}
