param([string] $RunId,[string] $RunDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Pacification-Fixture.ps1')
$player='0x00000014';$owned=[Collections.Generic.List[string]]::new()
$spell=(Invoke-NpcPapyrus Game GetFormFromFile '' @(0x807,'Acheron.esm')).returned.formId
if($spell -notmatch '^0x[0-9A-Fa-f]{8}$') {throw 'Acheron mapping missing'}
$mcm='0x{0:X8}' -f ([Convert]::ToUInt32($spell.Substring(2),16)-7)
# Fresh coc bypasses normal quest initialization; never reset a user's saved quest.
Invoke-YieldTool console @{action='exec';command="resetquest $mcm";capture=$true}|Out-Null
Invoke-YieldTool console @{action='exec';command="startquest $mcm";capture=$true}|Out-Null
$manager='SKI_ConfigManagerInstance'
# DevBench's native Quest fallback can select the other script on AcheronMain.
# SkyUI's typed RegisterMod parameter resolves the actual SKI_ConfigBase instance.
Invoke-YieldTool console @{action='exec';command="resetquest $manager";capture=$true}|Out-Null
Invoke-YieldTool console @{action='exec';command="startquest $manager";capture=$true}|Out-Null
$configId=(Invoke-NpcPapyrus SKI_ConfigManager RegisterMod $manager @(@{form=$mcm},' Acheron')).returned
if($configId -lt 0 -or $configId -ge 128) {throw 'SkyUI registration failed'}
$old=@{}
$sliders=@(
    @{name='iPeacefulWanderDuration';label='Peaceful Wander Duration';value=75;min=1;max=600},
    @{name='iCommandHoldDuration';label='Commanded Hold Duration';value=12;min=1;max=7200},
    @{name='iFleeDuration';label='Fleeing Duration';value=3;min=1;max=300},
    @{name='iFleeDistance';label='Fleeing Distance (units)';value=512;min=128;max=4096})
$root='_root.ConfigPanelFader.configPanel'
$pageList="$root.contentHolder.modListPanel.subListFader.list.entryList"
$options="$root.contentHolder.optionsPanel.optionsList.entryList"
function Read-McmOptions {
    $deadline=(Get-Date).AddSeconds(3)
    do {$count=(Invoke-NpcPapyrus UI GetInt '' @('Journal Menu',"$options.length")).returned}while($count -le 0 -and (Get-Date) -lt $deadline)
    if($count -le 0 -or $count -gt 128) {throw 'SkyUI options missing or invalid'}
    @(for($i=0;$i -lt $count;$i++) {
        @{index=$i;text=(Invoke-NpcPapyrus UI GetString '' @('Journal Menu',"$options.$i.text")).returned;type=(Invoke-NpcPapyrus UI GetInt '' @('Journal Menu',"$options.$i.optionType")).returned;value=(Invoke-NpcPapyrus UI GetFloat '' @('Journal Menu',"$options.$i.numValue")).returned}
    })
}
function Invoke-McmEvent([string] $Event,[string] $Text='',[double] $Value=0) {
    Invoke-NpcPapyrus SKI_ConfigManager $Event $manager @('',$Text,$Value,@{form=$player})|Out-Null
}
function Open-YieldPage {
    if(-not (Invoke-NpcPapyrus UI IsMenuOpen '' @('Journal Menu')).returned) {
        Invoke-YieldTool menu @{action='open';name='Journal Menu'}|Out-Null
        $deadline=(Get-Date).AddSeconds(3)
        do {$count=(Invoke-NpcPapyrus UI GetInt '' @('Journal Menu',"$root.contentHolder.modListPanel.modListFader.list.entryList.length")).returned}while($count -le 0 -and (Get-Date) -lt $deadline)
        if($count -le 0) {throw 'SkyUI mod list did not initialize'}
        Invoke-McmEvent OnModSelect '' $configId
    }
    Invoke-McmEvent OnPageSelect '$Achr_Yield' 4
}
function Read-McmValue([string] $Name) {
    Open-YieldPage
    $row=$controls[$Name]
    (Invoke-NpcPapyrus UI GetFloat '' @('Journal Menu',"$options.$row.numValue")).returned
}
function Set-McmValue([string] $Name,[int] $Value) {
    Open-YieldPage
    if($Name -eq 'iGodKey') {
        Invoke-NpcPapyrus UI SetInt '' @('Journal Menu',"$root.selectedKeyCode",$Value)|Out-Null
        Invoke-McmEvent OnKeymapChange '' $controls[$Name]
    } else {
        Invoke-McmEvent OnSliderSelect '' $controls[$Name]
        Invoke-McmEvent OnSliderAccept '' $Value
    }
}
function Close-Mcm {
    Invoke-YieldTool menu @{action='close';name='Journal Menu'}|Out-Null
    $deadline=(Get-Date).AddSeconds(3)
    do {$open=(Invoke-NpcPapyrus UI IsMenuOpen '' @('Journal Menu')).returned}while($open -and (Get-Date) -lt $deadline)
    if($open) {throw 'MCM did not close before gameplay checks'}
}
function New-McmEnemy {
    $id=(Invoke-NpcPapyrus ObjectReference PlaceAtMe $player @(@{form=$yieldEnemyBase},1,$true,$true)).returned.formId
    if($id -notmatch '^0xFF[0-9A-Fa-f]{6}$') {throw 'MCM fixture spawn not disposable'}
    $owned.Add($id)
    Invoke-NpcPapyrus Actor EnableAI $id @($false)|Out-Null
    Invoke-NpcPapyrus ObjectReference MoveTo $id @(@{form=$player},0.0,-200.0,0.0,$false)|Out-Null
    Invoke-NpcPapyrus ObjectReference Enable $id @($false)|Out-Null
    Set-NpcEnemyEquipment $id|Out-Null
    Invoke-NpcPapyrus Actor SetActorValue $id @('HealRate',0.0)|Out-Null
    Invoke-NpcPapyrus Acheron DefeatActor '' @(@{form=$id})|Out-Null
    Invoke-NpcPapyrus Actor EnableAI $id @($true)|Out-Null
    return $id
}
function Wait-McmFlightEnd([string] $Actor) {
    $deadline=(Get-Date).AddSeconds(6)
    do {$active=(Invoke-NpcPapyrus Acheron IsPeacefulState '' @(@{form=$Actor})).returned;Start-Sleep -Milliseconds 50}while($active -and (Get-Date) -lt $deadline)
    if($active) {throw 'Configured flight did not end'}
    Invoke-NpcPapyrus Actor EnableAI $Actor @($false)|Out-Null
    Assert-PeacefulReleased $Actor 2
}
try {
    Open-YieldPage
    $deadline=(Get-Date).AddSeconds(5)
    do {$count=(Invoke-NpcPapyrus UI GetInt '' @('Journal Menu',"$pageList.length")).returned}while($count -ne 5 -and (Get-Date) -lt $deadline)
    if($count -ne 5) {throw 'Yield page not registered in SkyUI'}
    $summary.mcmPages=@(for($i=0;$i -lt $count;$i++){(Invoke-NpcPapyrus UI GetString '' @('Journal Menu',"$pageList.$i.pageName")).returned})
    if(($summary.mcmPages -join ',') -ne '$Achr_General,$Achr_Defeat,$Achr_Stripping,$Achr_Events,$Achr_Yield') {throw 'Original MCM pages changed'}
    $summary.yieldPageLabel=(Invoke-NpcPapyrus UI GetString '' @('Journal Menu',"$pageList.4.text")).returned
    if($summary.yieldPageLabel -ne 'Yield') {throw 'Yield page label not translated'}
    Open-YieldPage
    $summary.yieldOptions=Read-McmOptions
    $slider=@($summary.yieldOptions|Where-Object {$_.type -eq 4})
    $key=@($summary.yieldOptions|Where-Object {$_.type -eq 7})
    if($slider.Count -ne 4 -or $key.Count -ne 1 -or $key[0].text -ne 'God preset key (desktop)') {throw 'Custom controls missing from Yield page'}
    $controls=@{iGodKey=$key[0].index}
    $old.iGodKey=[int]$key[0].value
    foreach($setting in $sliders) {
        $row=@($slider|Where-Object {$_.text -eq $setting.label})
        if($row.Count -ne 1) {throw "Missing slider: $($setting.name)"}
        $controls[$setting.name]=$row[0].index
        $old[$setting.name]=[int]$row[0].value
    }
    foreach($setting in $sliders) {
        $row=@($slider|Where-Object {$_.text -eq $setting.label})
        if($row.Count -ne 1) {throw "Missing slider: $($setting.name)"}
        foreach($boundary in @(@{value=-1;expected=$setting.min},@{value=999999;expected=$setting.max})) {
            Set-McmValue $setting.name $boundary.value
            if((Read-McmValue $setting.name) -ne $boundary.expected) {throw 'Native setting bounds not enforced'}
        }
        Set-McmValue $setting.name $setting.value
        if((Read-McmValue $setting.name) -ne $setting.value) {throw 'Slider lost native setting binding'}
    }
    Set-McmValue iGodKey 35
    if((Read-McmValue iGodKey) -ne 35) {throw 'Moved key control lost native binding'}
    $summary.originalPages=@()
    foreach($page in @(@{name='$Achr_General';index=0},@{name='$Achr_Defeat';index=1})) {
        Invoke-McmEvent OnPageSelect $page.name $page.index
        $rows=Read-McmOptions
        if(@($rows|Where-Object {$_.text -in ($sliders.label+@('$Achr_GodPresetKey','God preset key (desktop)'))}).Count) {throw 'Custom controls duplicated on original page'}
        $summary.originalPages+=,@{page=$page.name;options=$rows}
    }
    Close-Mcm
    $actor=New-McmEnemy
    Invoke-NpcPapyrus Acheron KneelActor '' @(@{form=$actor})|Out-Null
    $hold=Wait-PeacefulPhase $actor 3 20
    if($hold.commandHoldRemaining -le 0 -or $hold.commandHoldRemaining -gt 12) {throw 'Configured hold duration ignored in gameplay'}
    Set-McmValue iCommandHoldDuration 20
    Close-Mcm
    if((Read-PeacefulState $actor).commandHoldRemaining -gt $hold.commandHoldRemaining) {throw 'Setting edit restarted active hold'}
    Invoke-NpcPapyrus Acheron BindActor '' @(@{form=$actor})|Out-Null
    $bound=Wait-PeacefulPhase $actor 4 20
    if($bound.commandHoldRemaining -le 12 -or $bound.commandHoldRemaining -gt 20) {throw 'Bind did not use updated configured hold'}
    $summary.commandHold=@{kneel=$hold;bind=$bound}
    $actor=New-McmEnemy
    Invoke-NpcPapyrus Actor SetDontMove $actor @($true)|Out-Null
    Invoke-NpcPapyrus Acheron FleeActor '' @(@{form=$actor})|Out-Null
    $flight=Wait-PeacefulPhase $actor 7
    if($flight.fleeRemaining -le 0 -or $flight.fleeRemaining -gt 3) {throw 'Configured flight duration ignored in gameplay'}
    Set-McmValue iFleeDuration 12
    Close-Mcm
    if((Read-PeacefulState $actor).fleeRemaining -gt $flight.fleeRemaining) {throw 'Setting edit restarted active flight'}
    Wait-McmFlightEnd $actor
    $summary.configuredFlight=$flight
    $actor=New-McmEnemy
    Invoke-NpcPapyrus Actor SetDontMove $actor @($true)|Out-Null
    Invoke-NpcPapyrus Acheron FleeActor '' @(@{form=$actor})|Out-Null
    $flight=Wait-PeacefulPhase $actor 7
    Set-McmValue iFleeDistance 128
    Close-Mcm
    Wait-McmFlightEnd $actor
    $pattern='\[FleeEnd\] actor='+($actor -replace '^0x','')+' distance=(?<distance>[0-9.eE+-]+) remaining=(?<remaining>[0-9.eE+-]+)'
    $end=[regex]::Matches((Get-Content $logPath -Raw),$pattern)|Select-Object -Last 1
    if(-not $end -or [double]$end.Groups['distance'].Value -lt 128 -or [double]$end.Groups['distance'].Value -ge 512 -or [double]$end.Groups['remaining'].Value -le 0) {throw 'Configured live distance guard ignored'}
    $summary.distanceGuard=$end.Value
    @{message='PASS: separate Yield page, native handlers/bounds, configured hold/Bind/flight/distance, no countdown restart';screenshot=$null}
} catch {
    $summary.scenarioError=$_.Exception.Message
    throw
} finally {
    foreach($actor in $owned) {
        if((Invoke-NpcPapyrus Acheron IsDefeated '' @(@{form=$actor})).returned) {Invoke-NpcPapyrus Acheron RescueActor '' @(@{form=$actor},$false)|Out-Null}
        Invoke-NpcPapyrus Acheron ReleaseActor '' @(@{form=$actor})|Out-Null
        Invoke-NpcPapyrus ObjectReference Disable $actor @($false)|Out-Null
        Invoke-NpcPapyrus ObjectReference Delete $actor|Out-Null
    }
    $summary.actorCleaned=$true
    $summary.mcmSettingsRestored=$true
    foreach($setting in $old.Keys) {
        Set-McmValue $setting $old[$setting]
        if((Read-McmValue $setting) -ne $old[$setting]) {$summary.mcmSettingsRestored=$false}
    }
    Close-Mcm
    if(-not $summary.mcmSettingsRestored) {throw 'MCM test settings were not restored'}
}
