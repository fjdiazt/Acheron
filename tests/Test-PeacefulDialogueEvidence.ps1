$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Peaceful-Dialogue-Evidence.ps1')
$actor='0xFF000123';$info='0x05000817'
$good=@{actor=$actor;speaker=$actor;menuOpen=$true;questStopped=$false;canTalk=$true;goodbye=$false;greeting=$false;speaking=$false;fadedIn=$true;visible=$true;menuState=1;allowProgress=$true;selectedIndex=0;choices=@(@{row=0;topicIndex=4;text='Continue.'})}
if((Assert-PeacefulDialogueChoice $good $actor).row -ne 0) {throw 'Valid choice rejected'}
foreach($field in @('speaker','menuOpen','questStopped','canTalk','goodbye','greeting','speaking','fadedIn','visible','menuState','allowProgress','choices')) {
    $bad=$good.Clone()
    $bad[$field]=switch($field) {'speaker' {'0xFF000999'} 'menuState' {0} 'choices' {@(@{row=0;topicIndex=4;text='Hello'})} {$_ -in @('questStopped','goodbye','greeting','speaking')} {$true} default {$false}}
    $rejected=$false
    try {Assert-PeacefulDialogueChoice $bad $actor | Out-Null} catch {$rejected=$true}
    if(-not $rejected) {throw "False dialogue acceptance: $field"}
}
$duplicate=$good.Clone();$duplicate.choices=@($good.choices[0],$good.choices[0])
try {Assert-PeacefulDialogueChoice $duplicate $actor | Out-Null;throw 'Duplicate accepted'} catch {if($_.Exception.Message -eq 'Duplicate accepted') {throw}}
foreach($field in @('selectedIndex','row','topicIndex')) {
    foreach($value in @($null,-1,256,0.5,[double]::NaN,'0',$false)) {
        $bad=$good.Clone();$bad.choices=@($good.choices[0].Clone())
        if($field -eq 'selectedIndex') {$bad[$field]=$value} else {$bad.choices[0][$field]=$value}
        $rejected=$false
        try {Assert-PeacefulDialogueChoice $bad $actor | Out-Null} catch {$rejected=$true}
        if(-not $rejected) {throw "Invalid index accepted: $field=$value"}
    }
}
$event='[PeacefulTopic] actor=FF000123 info=05000817 begin=true'
Assert-PeacefulTopicSelected $event $actor $info | Out-Null
foreach($bad in @('', $event.Replace('FF000123','FF000999'),$event.Replace('05000817','05000818'),$event.Replace('begin=true','begin=false'))) {
    $rejected=$false
    try {Assert-PeacefulTopicSelected $bad $actor $info | Out-Null} catch {$rejected=$true}
    if(-not $rejected) {throw 'Missing/wrong topic execution accepted'}
}
'PASS: dialogue evidence rejects greetings, hidden choices, wrong speaker and unexecuted selections'
