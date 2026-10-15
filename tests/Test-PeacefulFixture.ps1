$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Peaceful-Dialogue-Evidence.ps1')
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'Pacification-Fixture.ps1'),[ref]$tokens,[ref]$errors)
foreach($name in @('Close-PeacefulDialogue','Select-PeacefulDialogueChoice')) {
    $function=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name},$true)
    Invoke-Expression $function.Extent.Text
}
$actor='0xFF000123'
$snapshot=@{actor=$actor;speaker=$actor;menuOpen=$true;questStopped=$false;canTalk=$true;goodbye=$false;greeting=$false;speaking=$false;fadedIn=$true;visible=$true;menuState=1;allowProgress=$true;selectedIndex=0;choices=@(@{row=0;topicIndex=0;text='Continue.'},@{row=1;topicIndex=1;text='Test'})}
function Read-PeacefulDialogue([string] $ActorId) {
    $value=$snapshot.Clone()
    if($fixture.mode -eq 'close') {$value.menuOpen=$false;return $value}
    if($fixture.moves) {
        $fixture.cursorReads++
        $value.selectedIndex=1
        $value.allowProgress=$fixture.cursorReads -ge 2
    }
    return $value
}
function Invoke-NpcPapyrus($Script,$Function,$SelfId,$Arguments) {
    if($Script -eq 'UI' -and $Function -eq 'IsMenuOpen') {
        $fixture.uiReads++
        return @{returned=($fixture.uiReads -lt 2)}
    }
    if($Script -eq 'Game' -and $Function -eq 'GetFormFromFile') {return @{returned=@{formId='0xFE00384F'}}}
    throw 'Unexpected fixture Papyrus call'
}
function Invoke-YieldTool($Tool,$Arguments) {
    if($Tool -ne 'input') {throw 'Unexpected fixture tool'}
    switch($Arguments.key) {
        'tab' {$fixture.tabs++}
        's' {$fixture.moves++}
        'e' {
            if($fixture.cursorReads -lt 2) {throw 'Confirmed while native progression was blocked'}
            $fixture.confirmed++
            Add-Content -LiteralPath $logPath '[PeacefulTopic] actor=FF000123 info=FE00384F begin=true'
        }
        default {throw 'Unexpected key'}
    }
}
$fixture=@{mode='close';uiReads=0;tabs=0}
Close-PeacefulDialogue $actor 'test'
if($fixture.uiReads -ne 2 -or $fixture.tabs) {throw 'Closing UI was treated as already closed or dismissed twice'}
$logPath=[IO.Path]::GetTempFileName()
try {
    $fixture=@{mode='select';moves=0;cursorReads=0;confirmed=0}
    $result=Select-PeacefulDialogueChoice $actor 'Test' 0x84F 'test' -AlreadyOpen
    if($fixture.moves -ne 1 -or $fixture.cursorReads -ne 2 -or $fixture.confirmed -ne 1 -or $result -notmatch 'info=FE00384F') {throw 'Native cursor readiness regression'}
} finally {Remove-Item -LiteralPath $logPath}
'PASS: closing UI waited, post-cursor readiness waited, correct native INFO confirmed once'
