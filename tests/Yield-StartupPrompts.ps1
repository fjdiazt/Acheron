function Resolve-YieldStartupPrompts {
    $deadline=(Get-Date).AddSeconds(3)
    do {
        $menus=Invoke-YieldTool menu @{action='list'}
        if(-not $menus.messageBoxOpen) {return}
        $prompt=Invoke-YieldTool menu @{action='describe'}
        $summary.blockingDialog=$prompt
        $expected='Survival Mode Survival adds the need to eat, sleep, and stay warm. It also adds additional challenges, such as no fast travel, reduced carry weight, and leveling up only when you sleep. See the "Survival Mode" entry in Help for details. Enable Survival Mode? (You can enable or disable Survival Mode at any time from the Gameplay Settings menu.)'
        if(($prompt.bodyText -replace '\s+',' ').Trim() -cne $expected -or ($prompt.buttons -join '|') -cne 'Yes|No') {
            throw 'Unexpected message box blocked test; inspect blockingDialog'
        }
        Invoke-YieldTool menu @{action='accept';index=1} | Out-Null
        $summary.survivalPromptDeclined=$true
        Start-Sleep -Milliseconds 25
    } while((Get-Date) -lt $deadline)
    throw 'Survival prompt did not close'
}
