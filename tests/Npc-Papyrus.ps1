$yieldEnemyBase='0x00043BE1' # EncForsworn01Melee1HBretonF01

function Invoke-NpcPapyrus([string] $Script, [string] $Function, [string] $SelfId, [array] $Arguments = @()) {
    $args = @{ action='call'; script=$Script; function=$Function; args=$Arguments }
    if ($SelfId) { $args.self = @{ form=$SelfId } }
    $result = Invoke-YieldTool papyrus $args
    if (-not $result.called) { throw "Papyrus call not executed: $Script.$Function" }
    return $result
}

function Set-YieldPlayerAppearance {
    $raceId='0x00013740'
    $base=(Invoke-NpcPapyrus Actor GetActorBase '0x00000014').returned.formId
    $menu='RaceSex Menu'
    $panel='_root.RaceSexMenuBaseInstance.RaceSexPanelsInstance'
    Invoke-YieldTool console @{action='exec';command='showracemenu'} | Out-Null
    $deadline=(Get-Date).AddSeconds(10)
    do {
        $ready=(Invoke-NpcPapyrus UI GetString '' @($menu,"$panel._SubList1.entryList.0.text")).returned
        if($ready) {break}
        Start-Sleep -Milliseconds 100
    } while((Get-Date) -lt $deadline)
    if(-not $ready) {throw 'Vanilla character creation did not initialize'}
    $count=(Invoke-NpcPapyrus UI GetInt '' @($menu,"$panel._SubList1.entryList.length")).returned
    if($count -lt 1 -or $count -gt 32) {throw 'Invalid character creation race list'}
    $index=-1
    for($i=0;$i -lt $count;$i++) {
        if((Invoke-NpcPapyrus UI GetString '' @($menu,"$panel._SubList1.entryList.$i.text")).returned -eq 'Argonian') {$index=$i;break}
    }
    if($index -lt 0) {throw 'Argonian missing from character creation'}
    # The menu's ChangeRace callback rebuilds head/mouth parts; Actor.SetRace does not.
    Invoke-NpcPapyrus UI SetInt '' @($menu,"$panel._SubList1.selectedIndex",$index) | Out-Null
    Invoke-NpcPapyrus UI InvokeInt '' @($menu,"$panel.onNarrowListMoveDown",0) | Out-Null
    $deadline=(Get-Date).AddSeconds(5)
    do {
        $race=(Invoke-NpcPapyrus Actor GetRace '0x00000014').returned
        $loading=(Invoke-NpcPapyrus UI GetBool '' @($menu,'_root.RaceSexMenuBaseInstance.LoadingIconInstance._visible')).returned
        if($race.formId -eq $raceId -and -not $loading) {break}
        Start-Sleep -Milliseconds 100
    } while((Get-Date) -lt $deadline)
    if($race.formId -ne $raceId -or $loading) {throw 'Native Argonian race selection failed'}
    Invoke-NpcPapyrus UI SetInt '' @($menu,"$panel._CategoriesList.selectedIndex",1) | Out-Null
    Invoke-NpcPapyrus UI InvokeInt '' @($menu,"$panel.ShowItemsList",0) | Out-Null
    foreach($slider in @(@{index=0;callback='ChangeSex';value=1},@{index=1;callback='ChangeHeadPreset';value=0})) {
        Invoke-NpcPapyrus UI SetInt '' @($menu,"$panel._SubList2.selectedIndex",$slider.index) | Out-Null
        Invoke-NpcPapyrus UI InvokeInt '' @($menu,"$panel._SubList2.UpdateList",0) | Out-Null
        $path="$panel._SubList2.SelectedEntry.SliderInstance"
        if((Invoke-NpcPapyrus UI GetString '' @($menu,"$path.callbackName")).returned -ne $slider.callback) {throw 'Unexpected vanilla appearance slider'}
        Invoke-NpcPapyrus UI SetInt '' @($menu,"$path.position",$slider.value) | Out-Null
        Invoke-NpcPapyrus UI InvokeInt '' @($menu,"$path.changedCallback",0) | Out-Null
    }
    $sex=(Invoke-NpcPapyrus ActorBase GetSex $base).returned
    if($sex -ne 1) {throw 'Native female selection failed'}
    $count=(Invoke-NpcPapyrus ActorBase GetNumHeadParts $base).returned
    if($count -lt 1 -or $count -gt 16) {throw 'Invalid Argonian head part count'}
    $parts=@(for($i=0;$i -lt $count;$i++) {
        $part=(Invoke-NpcPapyrus ActorBase GetNthHeadPart $base @($i)).returned
        $valid=(Invoke-NpcPapyrus HeadPart GetValidRaces $part.formId).returned
        if(-not $valid.formId -or (Invoke-NpcPapyrus FormList HasForm $valid.formId @(@{form=$raceId})).returned -ne $true) {throw "Incompatible Argonian head part: $($part.editorId)"}
        $part
    })
    if('FemaleHeadArgonian' -notin $parts.editorId -or 'FemaleMouthArgonian' -notin $parts.editorId) {throw 'Female Argonian head/mouth missing'}
    Invoke-NpcPapyrus UI InvokeInt '' @($menu,"$panel.onDoneClicked",0) | Out-Null
    $dialog=Invoke-YieldTool menu @{action='describe'}
    if(-not $dialog.messageBoxOpen -or $dialog.buttons[0] -ne 'Ok') {throw 'Unexpected character creation confirmation'}
    Invoke-YieldTool menu @{action='accept';index=0} | Out-Null
    $deadline=(Get-Date).AddSeconds(5)
    do {
        $mode=(Invoke-NpcPapyrus UI GetInt '' @($menu,"$panel.Mode")).returned
        if($mode -eq 0) {break}
        Start-Sleep -Milliseconds 100
    } while((Get-Date) -lt $deadline)
    if($mode -ne 0) {throw 'Character name entry did not open'}
    Invoke-NpcPapyrus UI SetString '' @($menu,"$panel._TextEntryField.TextInputInstance.text",'Yield Tester') | Out-Null
    Invoke-NpcPapyrus UI InvokeInt '' @($menu,"$panel._TextEntryField.onAccept",0) | Out-Null
    $deadline=(Get-Date).AddSeconds(5)
    do {
        $open=(Invoke-NpcPapyrus UI IsMenuOpen '' @($menu)).returned
        if(-not $open) {break}
        Start-Sleep -Milliseconds 100
    } while((Get-Date) -lt $deadline)
    if($open) {throw 'Character creation did not close'}
    return @{race=$race;sex=$sex;preset=0;headParts=$parts}
}

function Draw-YieldPlayerWeapon {
    Invoke-NpcPapyrus Actor DrawWeapon '0x00000014' | Out-Null
    $deadline=(Get-Date).AddSeconds(5)
    do {
        $hands=(Invoke-YieldTool inspect @{kind='player'}).hands
        if($hands.weaponSettledDrawn -eq $true) {return}
        Start-Sleep -Milliseconds 100
    } while((Get-Date) -lt $deadline)
    throw "Player weapon did not finish drawing: $($hands.weaponState)"
}

function Get-NpcInventory([string] $Actor) {
    $snapshot=Invoke-YieldTool inspect @{kind='inventory';formId=$Actor;limit=100}
    if($snapshot.owner.formId -ne $Actor -or $snapshot.owner.formType -ne 'ACHR' -or
       $snapshot.truncated -isnot [bool] -or $snapshot.truncated -or
       -not $snapshot.PSObject.Properties['count'] -or
       ($snapshot.count -isnot [int] -and $snapshot.count -isnot [long]) -or $snapshot.count -lt 0 -or
       $snapshot.returned -ne $snapshot.count -or @($snapshot.items).Count -ne $snapshot.count) {
        throw 'Fixture inventory snapshot invalid or truncated'
    }
    $seen=@{}
    foreach($item in $snapshot.items) {
        if($item.formId -notmatch '^0x[0-9A-Fa-f]{8}$' -or $item.formType -isnot [string] -or
           [string]::IsNullOrWhiteSpace($item.formType) -or -not $item.PSObject.Properties['count'] -or
           ($item.count -isnot [int] -and $item.count -isnot [long]) -or $item.count -le 0 -or $seen.ContainsKey($item.formId)) {
            throw 'Fixture inventory snapshot item invalid'
        }
        $seen[$item.formId]=$true
    }
    return $snapshot.items
}

function Resolve-NpcSpawn($Before, $After, [string] $BaseId, [string] $ReturnedId = '') {
    if ($Before.truncated -or $After.truncated) { throw 'Actor inventory truncated; spawn ownership unproven' }
    $newActors = @($After.refs | Where-Object {
        $_.formId -match '^0xFF[0-9A-Fa-f]{6}$' -and $_.formType -eq 'ACHR' -and
        (-not $ReturnedId -or $_.formId -eq $ReturnedId) -and
        ($_.base.formId -eq $BaseId -or
            ($ReturnedId -and $_.base.formId -match '^0xFF[0-9A-Fa-f]{6}$' -and $_.base.formType -eq 'NPC_')) -and
        $_.formId -notin @($Before.refs.formId)
    })
    if ($newActors.Count -ne 1) { throw 'Expected exactly one new disposable actor with requested base' }
    return $newActors[0].formId
}

function Set-NpcEnemyEquipment([string] $Actor) {
    if($Actor -notmatch '^0xFF[0-9A-Fa-f]{6}$') {throw 'Enemy fixture must be a disposable actor'}
    $deadline=(Get-Date).AddSeconds(5)
    do {$loaded=(Invoke-NpcPapyrus ObjectReference Is3DLoaded $actor).returned} while($loaded -ne $true -and (Get-Date) -lt $deadline)
    if($loaded -ne $true) {throw 'Enemy fixture did not load'}
    $actorBase=(Invoke-NpcPapyrus ObjectReference GetBaseObject $actor).returned.formId
    if($actorBase -ne $yieldEnemyBase) {throw 'Unexpected enemy fixture base'}
    $sex=(Invoke-NpcPapyrus ActorBase GetSex $actorBase).returned
    if($sex -ne 1) {throw 'Enemy fixture must be female'}
    # Preserve armor; remove weapons, ammunition and shields from this disposable copy only.
    foreach($entry in Get-NpcInventory $actor) {
        $item=$entry.formId
        $type=$entry.formType
        if($type -in @('WEAP','AMMO') -or ($type -eq 'ARMO' -and ((Invoke-NpcPapyrus Armor GetSlotMask $item).returned -band 512))) {
            $removed=Invoke-YieldTool papyrus @{action='call';script='ObjectReference';function='RemoveItem';self=@{form=$actor};args=@(@{form=$item},$entry.count,$true);fillNeutral=$true}
            if(-not $removed.called) {throw 'Enemy fixture equipment removal did not execute'}
        }
    }
    $sword='0x00012EB7'
    Invoke-NpcPapyrus ObjectReference AddItem $actor @(@{form=$sword},1,$true) | Out-Null
    Invoke-NpcPapyrus Actor EquipItem $actor @(@{form=$sword},$false,$true) | Out-Null
    if((Invoke-NpcPapyrus Actor GetEquippedWeapon $actor @($false)).returned.formId -ne $sword -or
       (Invoke-NpcPapyrus Actor GetEquippedWeapon $actor @($true)).returned -or
       (Invoke-NpcPapyrus Actor GetEquippedShield $actor).returned -or
       (Invoke-NpcPapyrus ObjectReference GetItemCount $actor @(@{form=$sword})).returned -ne 1) {throw 'Enemy fixture sword-only equipment incorrect'}
    return @{sex=$sex;weapon=$sword;shield=$false}
}

function Set-YieldPlayerEquipment {
    $player='0x00000014';$sword='0x00012EB7';$shield='0x00012EB6'
    Invoke-NpcPapyrus Actor UnequipAll $player | Out-Null
    foreach($entry in Get-NpcInventory $player) {
        $item=$entry.formId
        if($entry.formType -in @('ARMO','WEAP','AMMO')) {
            $removed=Invoke-YieldTool papyrus @{action='call';script='ObjectReference';function='RemoveItem';self=@{form=$player};args=@(@{form=$item},$entry.count,$true);fillNeutral=$true}
            if(-not $removed.called -or (Invoke-NpcPapyrus ObjectReference GetItemCount $player @(@{form=$item})).returned -ne 0) {throw 'Player fixture equipment removal failed'}
        }
    }
    foreach($item in @($sword,$shield)) {
        Invoke-NpcPapyrus ObjectReference AddItem $player @(@{form=$item},1,$true) | Out-Null
        Invoke-NpcPapyrus Actor EquipItem $player @(@{form=$item},$false,$true) | Out-Null
    }
    if((Invoke-NpcPapyrus Actor GetEquippedWeapon $player @($false)).returned.formId -ne $sword -or
       (Invoke-NpcPapyrus Actor GetEquippedWeapon $player @($true)).returned -or
       (Invoke-NpcPapyrus Actor GetEquippedShield $player).returned.formId -ne $shield) {throw 'Player fixture sword/shield equipment incorrect'}
    return @{weapon=$sword;shield=$shield;armor=$false}
}
