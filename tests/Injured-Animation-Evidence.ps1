function Find-InjuredLocomotion([string] $Log, [bool] $Injured, [int] $Priority=5000) {
    foreach($line in ($Log -split "`n")) {
        if($line -notmatch 'AnimationLogEntry:.*(?:mt|1hm)_(walk|run|sprint)[^\r\n]*\.hkx') {continue}
        $replacement=$line -match ('DynamicAnimationReplacer[\\/]_CustomConditions[\\/]'+$Priority+'[\\/]')
        if($replacement -eq $Injured -and ($replacement -or $line -match ' - original ')) {return $line.Trim()}
    }
    return $null
}
