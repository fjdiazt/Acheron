$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Yield-StartupPrompts.ps1')
function Invoke-YieldTool($Name,$Arguments) {
    if($Name -ne 'menu') {throw 'Unexpected tool'}
    switch($Arguments.action) {
        'list' {return @{messageBoxOpen=$mode -ne 'none' -and -not $accepted}}
        'describe' {
            $body='Survival Mode  Survival adds the need to eat, sleep, and stay warm. It also adds additional challenges, such as no fast travel, reduced carry weight, and leveling up only when you sleep. See the "Survival Mode" entry in Help for details. Enable Survival Mode? (You can enable or disable Survival Mode at any time from the Gameplay Settings menu.)'
            return @{bodyText=if($mode -eq 'unknown'){'Unrelated prompt'}else{$body};buttons=if($mode -eq 'wrongButtons'){@('No','Yes')}else{@('Yes','No')}}
        }
        'accept' {
            if($Arguments.index -ne 1) {throw 'Survival enabled by mistake'}
            $script:accepted=$true;$script:accepts++;return @{}
        }
        default {throw 'Unexpected menu action'}
    }
}
foreach($mode in @('none','survival','unknown','wrongButtons')) {
    $summary=@{};$accepted=$false;$accepts=0;$rejected=$false
    try {Resolve-YieldStartupPrompts} catch {
        if($_.Exception.Message -ne 'Unexpected message box blocked test; inspect blockingDialog') {throw}
        $rejected=$true
    }
    if($rejected -ne ($mode -in @('unknown','wrongButtons'))) {throw "Wrong prompt acceptance: $mode"}
    if($accepts -ne $(if($mode -eq 'survival'){1}else{0})) {throw 'Wrong number of prompt mutations'}
    if(($summary.survivalPromptDeclined -eq $true) -ne ($mode -eq 'survival')) {throw 'Wrong survival evidence'}
}
'PASS: exact Survival prompt declined; unknown prompts and reversed buttons rejected'
