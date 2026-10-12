$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Injured-Animation-Evidence.ps1')
$injured='AnimationLogEntry: Activated animation "walk" (Project: DefaultMale, Clip: Walk) - Legacy / 5000 (DynamicAnimationReplacer\_CustomConditions\5000\mt_walkforward.hkx)'
$healthy='AnimationLogEntry: Activated animation "walk" (Project: DefaultMale, Clip: Walk) - original (mt_walkforward.hkx)'
if(-not (Find-InjuredLocomotion $injured $true) -or -not (Find-InjuredLocomotion $healthy $false)) {throw 'Valid clip evidence rejected'}
if((Find-InjuredLocomotion $injured $false) -or (Find-InjuredLocomotion $healthy $true) -or (Find-InjuredLocomotion ($injured -replace 'mt_walkforward','mt_idle') $true)) {throw 'Wrong control or idle accepted'}
'PASS: actual locomotion paths, injury/control separation'
$rescued=$injured -replace '5000','5001'
if(-not (Find-InjuredLocomotion $rescued $true 5001) -or (Find-InjuredLocomotion $injured $true 5001) -or (Find-InjuredLocomotion $rescued $false 5001)) {throw 'Rescue override confused with health-based pack or normal control'}
'PASS: rescue override distinguished from health-based replacement'
$femaleSword=$injured -replace 'DefaultMale','DefaultFemale' -replace 'mt_walkforward','1hm_walkforward'
if(-not (Find-InjuredLocomotion $femaleSword $true) -or (Find-InjuredLocomotion ($femaleSword -replace '1hm_walkforward','1hm_idle') $true)) {throw 'Female sword locomotion rejected or idle accepted'}
'PASS: female one-handed sword locomotion accepted; idle rejected'
