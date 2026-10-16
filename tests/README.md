# Desktop test harness

`Invoke-PacificationTests.ps1 -Test native-flee-probe` probes direct native
`Actor::InitiateFlee` on native friendly guard controls, outside routine suites.
`native-flee-enemy-probe` uses the actual pacified female Forsworn with sword only.
Requires test diagnostics and `Build-NativeFleeFixture.ps1` before first use.
Native Travel qualifies a route; flight begins at arrival, reversing that route.
Uses `fleeFromDist=4096`, native package10/22 and actual movement; `isFleeing=false`
alone does not reject flight. Records health/stats/combat/pause and stop evidence.
Exact Survival prompt is declined; unknown dialogs fail. Protocol PASS reports
safe observations, while each `fleeQualified` field reports flight behavior.
Hook/DLL isolation switches always restore files; KeepInstalled is rejected.
Desktop results and limits: [flee investigation](../docs/native-flee-investigation.md).

`Invoke-PacificationTests.ps1 -Test native-flee-yield-probe` tests actual Acheron
Yielding entry, then existing no-heal `RescueActor(false)` and native flight.
Uses ordinary staging ESM; no Travel fixture, path warm-up or player relocation.
Requires full hooks/plugins; isolation switches and KeepInstalled are rejected.
Verifies defeat ownership/immobilization before exit and release before flight.
Fails on missing movement; package selection alone cannot pass. Latest desktop
result stalls after successful no-heal exit; gameplay Fleeing remains unimplemented.

Package alternatives use the same actual Yielding entry and actor invariants:

```powershell
pwsh -NoProfile -File tests/Build-NativeFleeFixture.ps1 -FleePackages
pwsh -NoProfile -File tests/Invoke-PacificationTests.ps1 -Test native-flee-from-probe
pwsh -NoProfile -File tests/Invoke-PacificationTests.ps1 -Test native-flee-to-probe
```

Private FleeFrom 880 uses the vanilla Find/Flee template with player threat and
4096-unit distance input. FleeTo 881 uses vanilla Flee with a linked marker on the
previously traversed 900-unit southern corridor. Neither warms up through Travel
or moves the player. Qualification requires more than 350 horizontal units away
while the exact fixture package is active; generic package type 18 is expected.
Late exact Survival modals are recorded, dismissed and resampled once without
repeating a flight mutation; unknown or unexplained/persistent pauses still fail.
All cases restore installed files; rebuild ordinary `res` afterward to reset staging.

`Invoke-PacificationTests.ps1 -Test greeting-probe` records repeated native spoken
greetings while kneeling at disposable relationship controls -3/0. It checks
native choices/actions and actor invariants; PASS does not mean the lines are
antagonistic. See [greeting evidence](../docs/greeting-probes.md).

`silent-greeting-probe` is a candidate-only discovery mode, outside routine suites.
Requires private fixture records in `tests/fixtures/silent-greeting` and temporary
scoped native entry. Verifies blank opening text and rendered captions, original
rank/aggression/health, regular kneeling, native commands and unmanaged speech.
`Test-SilentGreetingRecord.py` checks compiled candidate data without game launch.

### Original aggression/native Talk probe

```powershell
pwsh -NoProfile -File tests/Run-YieldTests.ps1 -Test native-aggression-probe
```

Regression, outside the routine suite. One disposable female Forsworn;
read original aggression before defeat, then drive real crosshair/E input twice
in Yielding and twice in peaceful movement. Retain dialogue flags and pacification;
assert original aggression, native choice readiness and combat state. `PASS`
requires all four real E attempts to open selectable native choices with unchanged
original aggression and pacification. Test a built candidate with the restoring wrapper:
`Invoke-PacificationTests.ps1 -Test native-aggression-probe`.

Also rejects unmanaged enemies and merely pacified actors without controller/defeat
ownership, using both diagnostic entry and actual E input. Save/load regression
`peaceful-persistence` checks owned legacy aggression migration and a second clean
reload without adding twice. `peaceful-healing` selects actual native Rescue INFO.
Current desktop evidence and deployment backup: [native dialogue](../docs/native-dialogue.md#desktop-evidence).
Desktop baseline `cfbc1105-e85b-4a05-9be8-44c35f229522` opened all four choices at
aggression `0`; candidate `3699f109-79b5-4267-970e-27d134d55d2b` opened none at
original aggression `2`. Neither case entered combat. Candidate changes were
reverted. These are historical comparisons before scoped player activation.
See [native dialogue](../docs/native-dialogue.md).

Follow-up `f9990622-bd76-43d8-a618-11f2888aa691`: aggression `1` opened selectable
choices in all four attempts, confirmed before/after each interaction. Fresh
zero control `9e62e1f8-2c75-442d-9347-233f08d3de14` also opened all four choices.
Probe summaries now include `aggressionOneAttempts` and `aggressionOneTalkPassed`;
the latter is null when four aggression-1 observations were not made. Pacification
remained active and combat stayed false. These historical probes changed no gameplay policy;
candidate DLL, source and config changes were restored after the experiment.

Scoped native entry diagnostic:

```powershell
pwsh -NoProfile -File tests/Invoke-PacificationTests.ps1 -Test native-dialogue-bypass-probe
```

Requires original aggression at both defeat and peaceful entry, with
`ACHERON_YIELD_TESTS` enabled. Reuses the same disposable fixture and restores
installed files by default. Calls the scoped test-only API directly, independently
of real E activation (qualified by `native-aggression-probe`), then checks actual
choice readiness, unchanged aggression/pacification and native On your knees. INFO
execution into the Kneeling FSM. Unmanaged and merely pacified actors must reject.
`bypassTalkPassed` records the native entry outcome. Historical runs
`7a84c828-bc8e-4a68-a820-b9f378a81c07` and
`c75061d6-e177-45c3-9d42-f9039918be01` opened 4/4 each at original aggression `2`.
See [scope, restoration and limits](../docs/native-dialogue.md#scoped-native-entry-probe).

Manual starting scenarios: [scripts/README.md](../scripts/README.md).

All enemy fixtures now use female `EncForsworn01Melee1HBretonF01` (`00043BE1`),
one iron sword (`00012EB7`), no shield or spare weapons, and retained armor.
`Npc-Papyrus.ps1` holds the shared base and equipment setup; each enemy is configured
with AI off before its test stimulus. Guards, followers, civilians and the persistent
reset actor retain their specific roles. Nearby combat formerly using wolves now
uses the same Forsworn enemy. Health/timer overrides remain scenario-specific.
Locomotion evidence accepts normal and one-handed sword walk/run clips.

Earlier qualified runs below used the old bandit/wolf fixtures; their evidence is
historical and does not qualify the new suite. Shared setup/ownership/evidence host
checks pass; the expanded Forsworn runtime cases have not been rerun.

### Production isolation

VR Mad God is production; desktop is development. Desktop configs, save directories,
load order and candidate builds must be independent copies. VR paths are read-only
sources, never deployment/restoration destinations. Desktop setup shutdown remains
scoped to its exact game/loader paths and never closes VR.

On 2026-10-11, the two desktop `Mods\Shared` junctions (Alternate Start and USSEP)
were removed. Active desktop `Data` installations already had independent copies,
so no additional copy was needed. No reparse links remain in the desktop installation;
all 499 files in the two VR source folders retained their hashes. Audit manifest:
`build/isolation-backups/a2fa481f-b819-43ff-9e4e-2f1b02776450/manifest.json`.
OAR/AQF/injury assets are also independent desktop copies, with VR source hashes
unchanged. Never edit shared condition files; edit the desktop copy.

`Desktop-Isolation.ps1` guards test configs, preference restoration, save cleanup,
results and candidate deployment. It rejects known VR roots, linked files (including
hardlinks) and linked ancestors even when the destination file does not yet exist.
This is a harness safeguard, not a Windows permission change. Use independent copies
for desktop mods; do not recreate shared links. New deployment scripts must use the
same guard. Host verification (no game launch):

```powershell
pwsh -NoProfile -File tests/Test-DesktopIsolation.ps1
```

### Injured enemy locomotion

```powershell
pwsh -NoProfile -File tests/Invoke-InjuredAnimationTests.ps1
pwsh -NoProfile -File tests/Test-InjuredAnimationEvidence.ps1
```

Desktop dependencies mirror the enabled VR assets: Open Animation Replacer 2.3.6,
Animation Queue Fix 1.0.1, Injured Animations Dynamic Replacer SE 1.1. Desktop
deployment copied 186 DLL/condition/HKX files, hash verified, with manifest at
`build/animation-backups/b4fa25cc-57ff-4b44-9ebf-96ff09f37879/manifest.json`.
VR assets/config remain unchanged. DAR DLL and EVG Conditional Idles are not needed.

Vanilla desktop DefaultMale uses `Animations\male\MT_Walk*.hkx`, while this pack
places male locomotion at the condition folder root. A byte-identical desktop
mapping of its 11 `mt_walk*`, `mt_run*`, `mt_sprint*` files into `5000\male\`
is recorded in the same manifest (197 installed files total). Without that mapping,
runtime logs showed normal male walks even at 10% health. Original root and female
assets remain present; VR behavior files and pack are untouched.

This standalone case uses the installed build, an unsaved world and one disposable
peaceful Forsworn per control. Script sets health before AI movement: 100% for the
healthy control and 10% for the injured control, without hits. For each phase,
require actual movement and OAR's selected
locomotion path, not merely a matching health predicate or idle clip. Console
selection is verified against the owned actor before logging. Wrapper temporarily
enables OAR text logging and restores the original INI (or removes its test-created
INI) after the owned game closes. Normal runner restores preferences and cleans up.
This case is separate from the default suite; bleedout 2s/3s cases remain unrun.

Installed `5000\_conditions.txt` uses `IsActorValuePercentageLessThan(24, 0.3)`:
strictly below 30% actual health. The separate rescue override below does not change it.
Animation selection alone does not impose a movement-speed limit. Full Rescue
interaction, healing reversal, other sexes/races, combat avoidance and VR visual acceptance need
their own checks.

Run `4ed6c200-d9b7-4087-9f3b-085d991d3302` passed both controls on 2026-10-11:
100% selected an original male walk; 10% selected the mapped `5000\male\`
wounded walk while moving and peacefully managed. Both actors cleaned up,
game closed gracefully, preferences restored, temporary OAR INI removed.
All 197 installed/source hashes verified. User separately observed the expected
wounded animation during an earlier run; that observation did not qualify the
whole test. Earlier dynamic-health runs froze and failed; `skyrim-toe` tracks
that unresolved stability issue. The direct setup case does not prove healing
reversal or explain those freezes.

### Commanded kneeling and binding

Random unbound variants and native **On your feet.**:

```powershell
python scripts/Stage-KneelingAnimations.py
pwsh -NoProfile -File tests/Invoke-PacificationTests.ps1 -Test peaceful-kneeling-variants -KeepInstalled
```

Focused sustained hold and repeated native Talk regressions:

```powershell
python tests/Test-KneelingAnimations.py
pwsh -NoProfile -File tests/Invoke-PacificationTests.ps1 -Test peaceful-kneeling-hold
pwsh -NoProfile -File tests/Invoke-PacificationTests.ps1 -Test peaceful-child-kneeling
pwsh -NoProfile -File tests/Invoke-PacificationTests.ps1 -Test peaceful-child-kneeling-male
```

Uses a disposable actor, 12-second hold, three Talk opens, then On your feet.
Child cases also re-enter child pose and Bind, verifying direct handoff without child exit or bound enter into bound
idle, restarted hold, marker cleanup and bound dialogue. Female remains default
for other tests/scenarios; male coverage uses explicit Forsworn base 0x43BDD.
Asserts no premature exit, actual sit state 3, selected family, scoped OAR
replacement paths and cleanup, unchanged health/aggression/pacification.
Checks repeated loop events and original-clip playback outside commanded Kneeling.
Candidate wrapper backs up/restores new animation files as well as plugin/DLL.
Clip contents/overrides are described in [animation catalog](../docs/animations-bookmarks.md#commanded-kneeling-variants).

Desktop run `186bdc37-d88e-46cf-a7c1-37150419d1f1` passed on the female Forsworn
fixture: regular/blessing native enter/loop/exit, saved non-default blessing across
real save/load, no reroll on Refresh/ignored Kneel, native On your feet selection
to Wandering and nearby-combat AvoidingCombat, retained health/pacification,
matching exit before Bind, bound pose and restarted hold. GUID-owned saves were
archived/removed; settings restored and desktop closed. Qualified DLL and plugin
remain installed; backup `build/pacification-backups/b0e81b89-15b8-4d9a-9bd0-7247ddda57fe`.

Selection is uniform over the three enabled clip families; the qualification
probe bounds random coverage attempts and reports missing coverage as inconclusive.
Three-family qualification `30e6235a-9fb9-485e-840a-52761eb8af2e` passed random
coverage, child save/load, both Resume destinations, Bind and hold expiry. Dedicated
child hold/Talk/exit/Bind cases passed on male (`28904db0`) and female (`ecfddef7`)
adult Forsworn. Desktop deployment receipt:
`build/pacification-backups/f4092851-f227-412f-aa80-094ffc6c5785/manifest.json`.
Native dialogue helpers wait for post-cursor progression and complete UI closure;
random re-entry waits for the previous Talk UI to close before its next command.
The broader native Test-tree gate remains failing after its pose-switch checks:
`f86d2721`, `71e8167d` and `3fc29002` stalled during combat-fixture cleanup / automatic
AvoidingCombat -> Wandering. The last diagnostic confirmed all owned actors and
player were out of combat. Root cause remains open in Beads `skyrim-1ir`; this is
not a passing full-tree result. See the animation catalog for probe details.
Forced fallback, old-cosave migration and VR remain unqualified.
The separate in-place-entry regression below still covers the unresolved native
furniture walking detour. This pass does not claim that detour fixed.

```powershell
pwsh -NoProfile -File tests/Invoke-PacificationTests.ps1 -Test peaceful-kneeling -KeepInstalled
```

Standalone desktop regression: enter owned `Kneeling` from Yielding,
AvoidingCombat and Wandering; verify each command requests exactly one package
(phase 3). Assert unchanged health, pacification, native
`KneelingMarker` furniture occupancy, held pose, Talk choices, real dialogue
selection, resume and release. The standing dialogue action uses its native
INFO event; yielded native dialogue also exposes **On your knees.**
The same regression selects **Bind** from kneeling dialogue, requires owned
phase 4 and owned `AcheronPeacefulBoundMarker` (`000822`) occupancy plus native
bound-kneeling clip selection in OAR logs, checks unchanged
health/pacification, Talk retention, hidden repeat Bind and release from the bound pose.
Use `-Test peaceful-bind` for the shorter Yielding → Kneeling → Bind case.

Desktop run `09f5f07a-9b49-443a-bf7c-a6eb29ca7e6a` passed direct package-entry
checks for Yielding, Wandering and AvoidingCombat: exactly one phase-3 request
per command, native kneeling occupancy, unchanged health and retained Talk.
Bind, hold reset, bound clip, release and Rescue checks also passed. Candidate
DLL installed; game closed and test settings restored. Native exit animations
remain required; this does not establish instantaneous pose changes or VR behavior.

In-place entry is now a separate, **failing** regression. Command-time origin is
captured in `[PeacefulKneelEntry]`; checks require a level marker within 1 unit,
then sample actor position through furniture occupancy, allowing 10 units of
settling movement. Existing final-pose assertions missed the walking detour.
Probe `acf847b5-5ef0-43e8-a8fa-652bed4159c3` measured 79.90 units of travel
despite aligned furniture and one phase-3 request. Temporarily allowing instant
furniture entry only during package evaluation did not remove native `SitTarget`
approach; that failed probe was removed. Candidate was rolled back. In-place
animation entry remains unresolved; the current candidate aligns markers but
does not remove the native walking detour.
Both cases temporarily enable OAR clip logging and restore its configuration.

**Commanded Hold Duration** uses `CommandHoldDurationSeconds = 1800` real
seconds. Combat and peaceful-duration refresh do not reset or pause it.
Binding restarts this timer at 1800 real seconds; the test compares before/after
hold budgets. Restart occurs on acceptance, before the native exit; exit/entry
consume that budget and never restart it. Host checks cover the reset, combat,
expiry and rejected standing Bind. The variants regression additionally rejects
paused Bind/Resume, checks acceptance/completion timer logs, refreshes an expired
hold during dialogue, then requires native bound exit before the movement package.
Diagnostic-only `ProbeCommandHold(actor, seconds)` shortens the owned hold for this
check; it leaves phase and peaceful budget intact. Production holds remain 1800 seconds.
Desktop qualification `6e36fee3-eae6-4d81-b3b6-252cfb6de161` passed these checks:
Bind hold 1800 at acceptance, 1799.2229 after native exit, 1798.265 at bound readiness;
expired hold stayed bound during dialogue/Refresh, then native exit completed before
the Wandering package. Health/pacification, both variants, save/load and both Resume
destinations also passed. Candidate retained; game closed and test settings restored.
Unloaded command races, forced exit timeout and VR remain unqualified.
Legacy Bind qualification below used furniture exit/re-entry; direct kneeling Bind now retains geometry. Default sitting Bind still waits for the
controller's 15-second entry deadline. Timer checks account for time elapsed
since selection instead of assuming animation entry finishes within 10 seconds.
The existing wandering budget stays separate. Host FSM checks simulate expiry;
the runtime test does not wait 30 minutes. Paused/unloaded time catches up on
resumption; closed-game time is excluded. `KneelActor`, `BindActor` and
`ResumePeacefulState` returning true means queued, not animation completion.

Focused desktop Bind qualification: **7f18b370-3472-4a55-9655-dcc1555641e6 PASS**.
Native dialogue executed INFO `000820`; phase 4 occupied our marker and selected
the original `AOBoundKneesIdle.hkx`. Hold budget reset from 1787.862 to 1798.5082
seconds on the next sample; wandering budget stayed 60. Health stayed
0.0498046875, pacification and Talk remained, and release played
`AOBoundKneesExit.hkx` then reached SitState 0. `IdleBoundKneesEnterInstant`
enters the bound pose after furniture entry; `IdleBoundKneesStart` was rejected.
Full kneeling regression **43cf7404-ffb2-4666-8c67-30949fefb055 PASS** covered
all three entry paths, standing dialogue selection, combat isolation and Bind.
Binding reset hold from 1776.1367 to 1798.9097 seconds while the separate
wandering budget stayed 2 seconds. Actors cleaned up, game exited gracefully,
display and OAR logging settings restored; matching candidate retained on desktop.
Final focused repeat **86dca3f5-bec4-49f2-a750-d2e25c8e5c7a PASS** required the
exact bound idle clip and confirmed dialogue closure preserves SitState 3.
Hold reset 1787.523 → 1798.5095; elapsed-aware evidence replay gives 1800.794
seconds including furniture exit. The earlier six-second readiness wait timed
out in run `5bacd9a1-b2a4-4271-9699-a5f5bc71c2b8`; no gameplay assertion was relaxed.

Serialization version 2 adds the hold budget and reads version 1 records.
Older builds cannot restore version 2 owners. VR, custom-menu selection and
kneeling/bound save/load require separate runtime checks. Previous builds that
do not recognize phase 4 cannot restore KneelingBound ownership.

Desktop run `41ad10cd-5d47-4398-8c62-cf51b39b2798` passed all three entry
paths on 2026-10-11. Native `GetSitState == 3` and furniture base `000E8E4E`
confirmed occupancy; health stayed `0.0498046875`. Real selection executed
INFO `FE00381C`; seated Talk retained **Continue.** Resume and explicit release
returned `GetSitState == 0`. Refreshing wandering to 2 seconds left Kneeling
active after 8 seconds. Owned actors cleaned up; graceful shutdown and preference
restoration passed. Full-duration expiry is covered by host FSM simulation.
The early failed launches were caused by requiring a Topic INFO object at
DataLoaded; dispatch now stores its resolved form ID instead.

Broader healing run `a1d23624-3a16-42b4-aa20-dd5468f343bc` exposed an
overly strict Wandering-only assertion: the Hunter Pride potion healed by 25
and correctly entered AvoidingCombat while combat lingered. The fixture now
accepts either peaceful phase. Rerun `fbfb6a03-6f5e-4149-82df-5380c568b601`
passed native potion/spell controls but stopped at the separately tracked
`skyrim-kt2` DevBench quest-script binding `404`. It does not qualify the full
healing suite; no production healing behavior was changed for that failure.
Existing peaceful persistence run `9fd4040f-cce7-4dc9-9504-c3524d2c34b9`
passed menu/unload pause, real save/load with the version 2 record, ownership
restoration and cleanup. This checks Wandering persistence, not Kneeling
furniture restoration or migration from a version 1 cosave.

### Rescued NPC locomotion

```powershell
pwsh -NoProfile -File scripts/Install-RescueAnimations.ps1
pwsh -NoProfile -File tests/Invoke-PacificationTests.ps1 -Test rescue-locomotion -KeepInstalled
# Installed-build regression only:
pwsh -NoProfile -File tests/Invoke-InjuredAnimationTests.ps1 -Test rescue-locomotion
pwsh -NoProfile -File tests/Test-RescueLocomotionFixture.ps1
```

The installer copies only the 33 installed injury walk/run/sprint clips into
independent desktop `5001` paths and records hashes under `build/rescue-animation-installs`.
It refuses different existing content and linked/VR destinations. No injury assets
are bundled into this source checkout. Priority 5001 uses
`IsInFaction("Acheron.esm" | 0x000819)`; the hidden per-actor faction is owned by
the rescue FSM. This uses OAR's existing [faction condition](https://github.com/ersh1/OpenAnimationReplacer/blob/main/src/Conditions.cpp).
Healing a defeated eligible NPC adds the marker, both peaceful phases retain it,
and owner cleanup removes it. Generic `BeginPeacefulState` does not add the marker;
refreshing a rescued owner preserves it. Save/load retains that ownership using
bit 4 of the existing saved dialogue flags byte; earlier records remain readable.

The standalone regression defeats a disposable Forsworn, consumes a native healing
potion on that actor to enter the shared production rescue path, verifies consumption and recovery
to full health, then requires movement and selected `5001` clips in AvoidingCombat
and Wandering. Player God mode prevents fixture crossfire from causing death
and an automatic quicksave reload. Nearby guard/Forsworn combat drives the first phase; actors have
high health applied after 3D loads. After each settled phase, AI is briefly
disabled for repositioning to the tested floor location, then re-enabled.
Native `Actor.PathToReference` requests walking toward the player. A specific
DevBench 504 confirming dispatch without completion is recorded as a pending
latent request; other failures propagate. Live FSM phase and managed package must remain correct.
Actual displacement and fresh selected clips are required; arrival is not an
animation assertion. Bleedout root motion cannot pass. Package roaming behavior
is covered separately by `peaceful-movement`. A shortened
three-second wandering duration checks automatic marker removal and original
locomotion on that same actor after generic re-entry. A different healthy
actor entering the generic peaceful API must select original locomotion without
the marker. This is separate from the unrun bleedout recovery cases. No screenshots.
An unexpected cosave load invalidates the test; cleanup skips stale references
instead of modifying actors in the replacement world.
This isolates rescue effects; it does not exercise the menu selection UI. Direct
DevBench calls to the Hunter Pride quest script proved unreliable across fresh
launches; its resolver can bind a different attached quest script, a suspected
cause tracked separately as `skyrim-kt2`.

Wandering time is already configurable through `iPeacefulWanderDuration` (1–600s).
It pauses during nearby combat, unloaded/paused gameplay and defers expiry during
player dialogue. Animation override lasts for that same managed lifecycle.

Desktop qualification, 2026-10-11: [`df985e2b-78c2-4710-8d7b-aaf12d8a42b6`](../build/test-results/df985e2b-78c2-4710-8d7b-aaf12d8a42b6/summary.json)
**PASS**. Native potion consumption ended bleedout and restored full health.
Selected OAR `5001` walking clips and actual displacement were recorded with
AvoidingCombat package `813` and Wandering package `814` active. Three-second
expiry removed the rescued faction. The same actor then selected original walking;
a different healthy bandit using generic pacification also selected original
walking without the marker. Candidate DLL/ESM hashes are recorded in the result;
the matching 22-file deployment remains installed. All owned actors cleaned,
game exited gracefully, preferences restored, zero screenshots. Independent
[`preservation-audit.json`](../build/test-results/df985e2b-78c2-4710-8d7b-aaf12d8a42b6/preservation-audit.json)
records installed-file verification and preservation checks.

Earlier attempts retained their failure artifacts: roaming observation could
miss clips during idling/repositioning; native walking calls exceeded transport
waits; two runs loaded an existing quicksave after wolf attacks on the player.
The user confirmed no interaction during the latter run. God mode prevents
fixture player death, and unexpected loads skip stale-reference cleanup. The
transport self-check rejects undelivered requests, wrong functions/statuses and
unrelated failures. No arrival result is claimed for pending latent requests.
VR, Rescue menu selection, new marker save/load, and running/sprinting clips
remain unqualified; the earlier dynamic-health freeze issue remains open.

### Standing peaceful dialogue regression

```powershell
pwsh -NoProfile -File tests/Invoke-PacificationTests.ps1 -Test peaceful-talk
pwsh -NoProfile -File tests/Test-PeacefulDialogueEvidence.ps1
```

The wrapper temporarily installs the staged candidate, verifies hashes, runs the
case, and restores installed originals. `summary.json.build` records the ESM,
DLL and Papyrus API SHA256 hashes actually used; manual play can use another build.

The case spawns disposable Forsworn and civilian clones. Acheron's interaction perk
is active before either enters peaceful wandering. It verifies the crosshair
target, presses the actual Interact key (`E`), waits for visible, selectable
`Continue.` with greeting/voice/fade readiness, then selects through real input.
The native INFO begin event, speaker and selected topic must match. Selection
must preserve pacification, original aggression, controller generation and anchor.
Peaceful expiry defers while talking and resumes after the menu closes.

Generic greetings or merely opening `Dialogue Menu` cannot pass. Scripted
`ObjectReference.Activate` returned false in the already-active-perk fixture;
normal `E` opened the choices. Perk flag/entry-removal experiments were reverted.
`Enter` did not qualify selection; the real `E` selection emitted INFO `000817`.
Native probes are compiled only with `ACHERON_YIELD_TESTS`; no screenshots.

Runs `50058c06-f33d-44d2-b190-be988842dd2e` and final-build
`6fc330cc-eddd-4a82-af53-62af79eda978` passed both actors on 2026-10-11.
These historical runs qualify standing interaction on the older adapter. Downed
interaction now also uses native Talk; current qualification is in
[Native defeated dialogue](../docs/native-dialogue.md). The 2s refresh
here checks peaceful dialogue deferral, not the unrun bleedout 2s/3s cases.

Run from this checkout with PowerShell 7:

```powershell
pwsh -NoProfile -File tests/Run-YieldTests.ps1
pwsh -NoProfile -File tests/Run-YieldTests.ps1 -Test npc-defeat
pwsh -NoProfile -File tests/Run-YieldTests.ps1 -Test follower-pacification
pwsh -NoProfile -File tests/Run-YieldTests.ps1 -Test npc-pacification
pwsh -NoProfile -File tests/Run-YieldTests.ps1 -Test follower-defeat
pwsh -NoProfile -File tests/Run-YieldTests.ps1 -Test npc-lethal
pwsh -NoProfile -File tests/Run-YieldTests.ps1 -Test player-finish-physical
pwsh -NoProfile -File tests/Run-YieldTests.ps1 -Test player-finish-magic
pwsh -NoProfile -File tests/Run-YieldTests.ps1 -Test essential-protection
pwsh -NoProfile -File tests/Run-YieldTests.ps1 -Test npc-recovery-2s
pwsh -NoProfile -File tests/Run-YieldTests.ps1 -Test npc-recovery-3s
```

The default command runs the routine suite: `npc-defeat`,
`follower-pacification`, `npc-pacification`, `follower-defeat`, `npc-lethal`,
`player-finish-physical`, `player-finish-magic`, `essential-protection`,
`npc-recovery-2s`, then `npc-recovery-3s`. Individual cases remain
selectable through `-Test`. Each gets a fresh game process and unsaved
`UnownedCell` world, temporarily runs at 800x600 with autosaves disabled,
cleans up its owned actors, requests `qqq`, and restores preferences exactly.
After world loading, every case issues `fov 120` and switches to third person
through DevBench. The returned camera POV must be `third`; the requested FOV
and camera response are recorded in `summary.json`. Camera/FOV are runtime
changes with no explicit restoration; display/autosave preferences still restore.
NPC combat and post-hit observation use native freecam (`tfc` behavior without
freezing time), framed on the enemy at 450 units, 135 degrees around its heading,
20-degree downward tilt and 1.2 times its height. Player attacks briefly leave
freecam so real gameplay input reaches the character, then reframe after their
assertions. DevBench camera calls and the latest framing response are archived;
no screenshots are required. Camera composition still needs visual acceptance.
Camera regressions passed on 2026-10-11: `33387005` (nonfatal/fatal melee),
`06a22746` (guard combat and 20.693 seconds of cessation), and `a437af9c`
(player Firebolt finish). All cleaned up, exited gracefully and restored
preferences. Full eight-case suite was not rerun for this camera-only change.
The suite stops on the first failure and writes an aggregate `summary.json`
under `build/test-results/suite-<GUID>/`, with links to per-case results. Exit 0
requires all ten cases to pass, exit 0, close gracefully and restore settings.
Existing saves are neither loaded nor written. Hello World was removed after
qualifying startup; its historical results remain archived. No screenshots.

### Short automatic recovery regressions

The 2s and 3s cases reuse the real player lethal-hit Forsworn fixture. Before
launch, only `iNPCRescueTimer` in the desktop `Data/SKSE/Acheron/Settings.yaml`
is temporarily changed; each run archives the original bytes as
`Settings.yaml.before` and restores them after shutdown, including failed cases.
Timer restoration is required for suite success. Linked settings files are
rejected. The normal 90s setting is not changed by adding these tests.

Native hit timestamps, defeat registration, 250ms actor heartbeats and rescue
completion prove automatic recovery. The last defeated sample must reach within
500ms of the requested timer, and the first alive, unpacified, undefeated sample
must arrive no later than 500ms afterward. Observation gaps over 500ms fail;
live reads also require positive health and cleared flags. Slow Papyrus calls
follow timing capture so they cannot hide a short yield. No manual rescue can
satisfy the test; rescue is allowed only in teardown after a failed assertion.
Durations total five seconds of yielding, plus process startup/setup, sampling
and cleanup. The 500ms tolerance is provisional until runtime calibration.

Added on 2026-10-11 at the user's request; **not run in Skyrim**. Parser and
host self-checks use synthetic evidence only. The historical eight-case PASS
below does not qualify these two new cases or the expanded ten-case suite.

Every fresh test player uses vanilla female Argonian preset 0. Shared bootstrap
opens native character creation, selects Argonian through `ChangeRace`, female
through `ChangeSex`, then applies `ChangeHeadPreset`. Direct `Actor.SetRace` and
`player.sexchange` left the original Nord head/mouth and incompatible face data.
Bootstrap verifies female race/sex, the female Argonian head and mouth, and each
head part's valid-race list before confirming the name and closing the menu.
`summary.player` records race, sex, preset and head parts. This runs only in the
fresh disposable world, before equipment and case-specific stats. No RaceMenu
dependency or changes to existing saves. Requires the vanilla character menu.
Camera/FOV are applied after character creation closes. Player melee fixtures
wait for DevBench's native `hands.weaponSettledDrawn` before proceeding; sending
attack input during the draw animation can discard the hit.
Desktop verification (2026-10-12): setup `be07b31b-8d99-4867-8565-d687d3a01500`
passed head-part checks; `player-appearance.png` shows the correct Argonian face
without human hair. Defeat regression `eb2e75aa-f0ae-48de-8242-4203b834e7c6`
passed real player lethal-hit interception, live defeat state and cleanup with
this preset, including graceful exit and preferences restoration. Full suite
and VR were not run.
Shared bootstrap also removes armor/clothing and spare weapons/ammo, then equips
one iron sword (`00012EB7`) and iron shield (`00012EB6`). Live equipment reads must
confirm sword in the right hand, no left-hand weapon, and the shield equipped.
Removed gear counts must be zero; other inventory is preserved. All test cases
and manual scenarios use this setup, recorded under `summary.player.equipment`.
Melee cases retain sword/shield; lethal-hit fixtures use player `AttackDamageMult`
instead of unarmed damage. Normal/nonfatal hits retain normal sword damage.
Host verification: `pwsh -NoProfile -File tests/Test-PlayerEquipment.ps1`.
The equipment change and sword-based combat cases have not been rerun in-game.
Run `ef93c755-92ec-41b0-ae03-3b80f93260c2` passed live race/sex checks and
nonfatal/fatal player melee finishing, including cleanup, graceful exit and
preferences restoration. Appearance and the full suite were not rechecked.

The NPC case enables and verifies Acheron's Hunter Pride ability on the fresh
player, spawns one disposable nonessential Forsworn, disables its regeneration,
sets its health to 1, and holds its movement with `SetDontMove`. Combat AI stays
enabled. DevBench injects a normal mouse-left tap for a player sword attack.
Passing requires exactly one native hook record for this owned actor with player
source `00000014`, damage at least its pre-hit health, and registered defeat;
live reads must also report alive, defeated, pacified and positive health.
Cleanup releases Acheron's state, verifies it cleared, verifies the actor is
disabled, and requests deletion before discarding the unsaved world.

NPC prerequisites: this fork's test-enabled DLL, Acheron.esm and compiled scripts,
desktop PapyrusUtil 4.6 and SkyUI 5.2 SE, enabled plugins, and deterministic settings
`bNPCDefeat: false`, `bHunterPrideFollower: true`, `bFollowerDefeat: true`,
`fLethalNPC: 100.0`, `ConsequenceEnabled: false`. Before each case, the native
startup policy record verifies loaded settings. Main-menu `coc` bypasses normal
new-game/load messages, so case setup activates and verifies Hunter Pride;
automatic activation on ordinary new game/load remains a separate check.
DevBench cannot dispatch this installed MCM's native
member getter, so the harness uses the existing native logger. Desktop files
were installed with hash manifests under the game's `Mods/Install-backups/`:
`AcheronBaseline-20261011-025205` and `SkyUI52-20261011-025348`.

The DLL's default-off xmake option `--yield_test_diagnostics=y` adds hook evidence
to the existing logger; no custom attack bridge or test plugin is required.
Build tooling is local under ignored `build/tools/`: xmake 3.1.1, author Caprica
0.3.0a, Spriggit 0.40.0 and Papyrus imports. Native release build used MSVC 2026;
seven Papyrus scripts compiled and Spriggit generated the ESM. `xmake.lua` now
creates `dist/SKSE/Plugins` before copying DLL/PDB, fixing an upstream packaging
collision when that directory did not yet exist.

### Combat policy and finishing checks

`follower-defeat` reuses the Lydia fixture, first proves a damaging attack, then
lowers the enemy to 1 health and waits for a real follower lethal hit. Requires
one source-matched native defeat registration, living defeated/pacified target,
healthy attacker and the same attack-cessation observation as the player case.
`npc-lethal` uses natural guard hostility with no forced combat start, verifies a
real lethal guard hit kills the standing Forsworn, and rejects defeat registration.

Physical finishing uses a second ordinary player mouse-left attack against the
downed Forsworn. Magic finishing uses native `Spell.Cast` for a verified vanilla
Firebolt with the player as the actual source. Both require the corresponding
native permission record, death, cleared flags and no second defeat. Essential
coverage temporarily marks this disposable Forsworn base essential, confirms both
melee and Firebolt are blocked while defeat persists, then restores the base.
Injected input or requested casts alone are insufficient evidence. Pacification
regressions cover natural melee combat and attack cessation. Non-player spell
blocking has two positive native observations, but its casting fixture was
unreliable; repeatable non-player spell automation remains unqualified.

DevBench's REST interface uses the same registered tools as MCP. This harness
uses REST directly, so no MCP-client registration or host restart is needed.
The default game path is `S:\games\The Elder Scrolls V - Skyrim Special Edition`.
`-GameRoot`, `-PrefsPath` and `-ResultsRoot` can select explicit desktop paths.
This first setup requires runtime 1.6.1170, SKSE 2.2.6, DevBench 1.27.0 and its
matching Address Library database. It is not a VR launcher.

Each run has a GUID directory under `build/test-results/`, containing original
preferences, JSONL tool evidence, archived game/plugin logs and
`summary.json`. Exit 0 requires the selected case's assertions,
graceful game exit and verified settings restoration. Exit 1 indicates an incomplete/failed
run. Preflight failures stop before launch/settings changes.

An existing Skyrim/loader session is refused. Only a process with the expected
executable path, loader parent and creation time can receive commands or be
terminated. Startup has a 120-second deadline, first attacker hit 25 seconds,
HTTP requests at most 20 seconds and graceful shutdown 15 seconds. Forced
termination of an owned stalled game is reported as a failure. If a game remains
running, settings restoration is deferred; use the saved original preferences
after closing it. Do not run concurrent harnesses.

Self-checks:

```powershell
pwsh -NoProfile -File tests/Test-RunYieldTests.ps1
pwsh -NoProfile -File tests/Test-NpcDefeatEvidence.ps1
pwsh -NoProfile -File tests/Test-NpcSpawn.ps1
pwsh -NoProfile -File tests/Test-PacificationEvidence.ps1
```

These check INI edit boundaries and process/endpoint identity rejection. Actual
launch, shutdown and restoration require the live smoke run.
The NPC evidence check rejects foreign actors/attackers, missing or nonlethal
hits and invalid live death/defeat/pacification/health results.

Verified on 2026-10-11: three consecutive unattended runs passed; Hello world was
observed through the native message-box data and an 800x600 screenshot. All three
games exited through `qqq` and preferences restored byte for byte. The repeat
also preserved every existing save's SHA-256 and left no Skyrim/loader process.
An attempt while Skyrim was already running was refused without changing
preferences or stopping that game. Failed development runs retain their logs.

First NPC pass: `build/test-results/0ca686cb-39f3-4e0c-b383-a2d4dabd25f9/summary.json`.
Native evidence: target `FF000825`, source `00000014`, pre-hit health 1,
damage 3.1408, lethal/registered/defeated/pacified all true. Live actor remained
alive at health 1; cleanup, graceful shutdown and exact settings restoration passed.
The earlier failed run `b4f56027-9f83-477a-aeaa-2ffb6a9c9be9` remains archived:
Hunter Pride was off, so upstream's player-hit gate allowed the lethal hit through.
The fixture now enables that existing ability; production gate behavior was unchanged.
Repeat `30e6bf32-c02d-4c5d-a09d-e32d6712d2ab` also passed. Independent audit
`build/test-results/npc-repeat-audit.json` confirmed all four save files and the
preferences unchanged by SHA-256, with no Skyrim or loader process left running.

This proves one physical damage interception and state transition. The actor was
held stationary; navigation, crawling, combat target switching, recovery timing,
magic hits, follower attacks, dialogue and VR remain untested. The after-hit frame
does not clearly show the bandit's pose; screenshot presence is not visual acceptance.
This milestone used the diagnostics-enabled build; an ordinary-build runtime
comparison remains pending.

`follower-pacification` is a routine regression promoted from the original
discovery case. It uses the player, one Forsworn, and one disposable
Lydia copy labeled `Test Follower (Lydia copy)`. Original Lydia is untouched.
Before/after reference inventories must identify exactly one new `FF` actor of
the requested base; this handles DevBench's missing form ID for scripted actors
without guessing or taking ownership of existing references. Actors start disabled
with AI off; equipment setup waits for enabled, loaded 3D. Both actors' AI is
enabled before combat and stays enabled throughout observation. Enemy movement
is held briefly only to deliver the player sword attack, then released.

The teammate must first land a damaging hit and show native attack activity
against the enemy. The player's lethal sword hit then registers defeat/pacification.
Player moves to the enemy's opposite side from the follower before striking.
Each attempt uses the solo case's 85-unit staging, checks live distance within
100 units and verifies drawn fists. At most three normal input attempts may
establish the player hit; each rechecks the lane. Failure to deliver defeat or
accidentally downing the attacker fails the case. Hit-hook evidence is required
regardless of input acceptance; no direct damage/defeat calls substitute for it.
Native diagnostics record attack-state changes plus 250ms heartbeats and physical
hits before the immunity guard, including blocked hits. Live combat target/state
and enemy flags supplement these records. A two-second settling interval records
residual attack activity separately; at least ten seconds of subsequent native
observations are required. Outcome distinguishes stopped attacks, continued
activity/hits, and lingering combat without attacks. `PASS` now requires
`stopped-attacking`: zero post-settling attack activity/hits and no combat target.
Continued attacks, blocked hits, lingering combat or invalid evidence fail.
Original archived discovery results only classified outcomes; they are historical.
Native heartbeats and live snapshots must also prove the follower stays alive,
undefeated and unpacified; a downed follower cannot establish this discovery.

This qualifies the built-in teammate behavior in this desktop fixture. It does
not establish real follower quest/package behavior, NFF, other NPC attackers,
target switching, spell/AOE damage or VR. Damage guards remain unchanged.

`npc-pacification` reuses the same evidence and cleanup with a
disposable Whiterun Guard (`000D3154`) and Forsworn. The guard keeps its original
factions, is not a player teammate, and must be nonhostile to the player and
hostile to the Forsworn. The Forsworn must be hostile to the player. Neither actor
receives a forced `StartCombat` in this variant; a real guard hit and attack
activity must establish that the encounter started naturally. Native diagnostics
also observe dynamically spawned actors, so non-teammates have the same evidence.
The attacker must stay alive, undefeated, unpacified and nonhostile to the player.
Skyrim can generate a dynamic NPC base for the guard. That case requires the
exact `PlaceAtMe` returned reference to be newly present in both-inventory
comparison with a dynamic NPC base; a missing/mismatched returned ID is rejected.
The initial guard setup run `4871bf5d-ef71-413e-8a77-09ee8b03854b` failed that
ownership check before combat. Its unsaved world was discarded; both INIs and
all saves remained unchanged. This is not AI-behavior evidence.

Discovery evidence, 2026-10-11: run
`cd89cd2e-1fcf-46e8-a097-b9b1a6ab6640` used bandit `FF00082C` and verified
nonhostile teammate `FF00082E`, base Lydia `000A2C8E`. Before defeat she landed
a 12.96-damage hit. After the player's lethal hit, 68 native observations spanning
17.76 seconds beyond settling showed no attack activity, hits or combat target.
Five live snapshots also reported no combat/target while the enemy stayed
defeated/pacified. Cleanup, shutdown and exact preference restoration passed.
This supports using Acheron's existing pacification for ordinary teammate
targeting in this fixture; it does not justify removing damage guards against
in-flight attacks, collateral damage or untested integrations.

Earlier runs remain archived. `a5037d0d-28ba-4e52-9586-01f2f693cce7` showed the
same stop with a converted bandit, but both models looked hostile and they could
attack during initial setup. The corrected fixture uses distinct Lydia, a clear
label and inactive AI until setup finishes. `2235218c-babf-4505-ae80-e1cebcc7422d`
failed because DevBench cannot encode a `None` argument; fixture gear now goes to
the disposable player. `903e044f-b66a-4dd0-bd84-f3e045dcfe64` exited during
unequipping an unloaded disabled actor; equipment calls now wait for loaded 3D.
`f84c02d1-62d5-4dab-8cf0-22f37c24846a` lacked the scripted actor's returned ID;
strict reference inventory comparison now resolves ownership. Health buffers
are set and verified after 3D initialization because early values can reset.
Diagnostic DLL/PDB hashes and backups are in desktop
`Mods/Install-backups/PacificationDiscovery-20261011-032744/installed-files.json`.

Qualified repeat `e0ae7440-d34b-4385-bac8-ceb81a6d5536` passed with bandit
`FF00081A` and Lydia copy `FF00081D`: a real teammate hit preceded player defeat,
then 83 native observations over 21.736 seconds beyond settling showed zero
attacks/hits/targets. The follower stayed alive, undefeated and unpacified.
Cleanup/shutdown passed; `preservation-audit.json` independently confirms all
four saves and both desktop INIs unchanged by SHA-256, with no game/loader left.
Existing `npc-defeat` regression `64fa8b1f-f4db-499b-8091-d7bb00da1e32` also passed.

Repeat `af724a6c-d70b-4357-85c9-7fd6128b116d` is INVALID despite its original
summary saying PASS: the player also downed the follower. Its original evidence
is preserved with `discovery-review.json`; it does not support the conclusion.
This exposed the missing follower-state guard, now covered by a negative
self-check and native/live assertions. The player attack lane was corrected.

Native screenshots include the HUD; DevBench marks them degraded/inconclusive
for image comparison. Here they are evidence of the message, not a pixel-perfect
visual acceptance test. `bAllowScreenshot=1` must already be enabled in Skyrim.ini.

References: [DevBench](https://github.com/alandtse/devbench),
[test approach](../test-plan.md), [implementation plan](../docs/superpowers/plans/2026-10-11-yield-test-harness.md).

Guard discovery `6fa50cb8-10c4-497d-bb1b-54c392febab5` passed: guard
`FF000821` (requested base `000D3154`, generated base `FF000825`) versus bandit
`FF00081D`. Both were naturally hostile to each other; only the bandit was
hostile to the player, and neither actor was a player teammate. No faction edits
or forced `StartCombat` were used. A real 16-damage guard hit and native attack
activity preceded the player's lethal hit and Acheron defeat/pacification.
After two seconds of settling (7 residual attack-state samples, zero hits),
70 native samples over 18.297 seconds showed zero attacks, hits or combat targets.
The guard stayed alive, undefeated, unpacified and nonhostile to the player.
The user also visually confirmed that the guard stopped attacking. Cleanup and
shutdown passed; `preservation-audit.json` confirms four saves and both INIs
unchanged, with no game/loader left. Diagnostic deployment backup:
`Mods/Install-backups/GuardDiscovery-20261011-033525/installed-files.json`.

Routine screenshots were removed afterward at the user's request. NPC cases use
native hit/attack hooks and live state assertions. Hello World was later removed
from the suite and selectable cases. The `screenshot` summary field
remains null. Existing archived images stay intact. Capture images only when
code, hooks, logs or state reads cannot establish a visual requirement. The screenshot removal initially passed static checks without another game run
after the user's stop; the subsequently authorized regression suite checks it live.
This single guard fixture does not establish all factions, projectile/AOE or VR
behavior and does not justify removing damage protection.

Scope decision after the user's visual confirmation: reuse existing Acheron
pacification and damage immunity. Extra NPC/follower blocking checkboxes and
targeting suppression are removed from requirements. Keep the current guards;
ordinary direct-player finishing is implemented through the existing physical
and magic guards. Current qualification is recorded below.

### Player/party policy qualification, 2026-10-11

Complete eight-case suite
[`suite-729bf61b-0044-4e43-8d04-650f5441c44f`](../build/test-results/suite-729bf61b-0044-4e43-8d04-650f5441c44f/summary.json)
**PASS**. Every case cleaned its actors, exited gracefully and restored settings.
Independent `preservation-audit.json` confirms four save hashes and both INIs
unchanged, no Skyrim/loader process remaining and zero screenshot calls.

| Case | Verified result |
| --- | --- |
| `npc-defeat` | Real player lethal melee hit leaves Forsworn alive, defeated and pacified. |
| `follower-pacification` | Healthy teammate stops attacking; 22.242 seconds, zero post-settling attacks/hits/targets. |
| `npc-pacification` | Healthy guard stops attacking; 17.477 seconds, zero post-settling attacks/hits/targets. |
| `follower-defeat` | Real follower lethal hit causes yield; 21.450 seconds of cessation. |
| `npc-lethal` | Real guard lethal hit kills standing Forsworn without defeat registration. |
| `player-finish-physical` | Nonfatal ordinary melee damage retains defeat; subsequent lethal melee causes death and clears flags. |
| `player-finish-magic` | Player-source Firebolt kills yielded Forsworn and clears flags. |
| `essential-protection` | Player melee and Firebolt reach blocking hooks, cause no health loss and preserve defeat. |

Desktop-only qualification. Normal new-game/load Hunter Pride activation remains
unverified because this harness uses main-menu `coc`. VR/NFF/PLANCK, enchantments,
summon attribution, collateral cases and reliable non-player spell automation
remain unqualified. Native diagnostics are enabled only in this test build.

Native release build and all four host self-checks passed. Individual player
finishing runs `e1e02339-4b41-4d54-8fda-cc7d79fe83c5` (real melee) and
`70b0c22d-7aff-4f20-a6a5-4e2d7e46d761` (Firebolt) passed: target died, both
Acheron flags cleared and no second defeat was registered. The routine physical
case additionally verifies a nonfatal hit damages the NPC while retaining both
flags before the lethal finish.

Suite `646b8fd4-2d9f-49d3-807e-2919046d5718` passed the first defeat case, then
failed during follower fixture setup before combat because DevBench reported a
nonadvancing main-thread frame counter. Owned process shutdown timed out; the
harness terminated only that process and restored preferences. User reported
possible accidental game interaction. Its `review.json` marks the gameplay
result inconclusive; original failure artifacts remain intact. This does not
establish a plugin defect or a passing follower case. An unchanged unattended
suite rerun was started.

Unattended rerun `suite-90b5b4bb-2128-4a88-80b8-7a43bb0e0638` passed
NPC defeat and follower cessation, including actual Lydia-source Firebolt
rejection. Guard cessation also met its quiet-window assertion, but an extra
guard spell probe never reached the native hook. Three isolated guard casting
trials retained that delivery failure (`cc36c4f5`, `f0822403`, `63a685dc`);
neither `Cast` nor `RemoteCast` qualified the guard as a spell fixture.
Guard regressions retain all natural-combat cessation assertions. Non-player
magic coverage uses the qualified Lydia fixture instead; guard spell delivery
remains unqualified. No gameplay code changed in response to these misses.

Suite `suite-81b314f2-4cd6-4cce-8111-2cf099b3fcf2` passed the first three
cases, then failed follower-defeat evidence parsing. The follower did register
defeat, but lowering base health after its baseline hit left a damage modifier:
native pre-hit health was `-11.96`. Separate restore/set calls also raced the
next real attack (`b870c72a`). The fixture now stages current health with one
native `ForceActorValue` call, retaining the positive pre-hit health assertion.
The gameplay policy was unchanged; original failures are retained.
The next follower-defeat run (`df26334b`) confirmed health `1`, lethal follower
damage, defeat, and 19.330 seconds of cessation, then failed its duplicate spell
delivery probe. That probe belongs only to `follower-pacification`; the
follower-defeat case retains real lethal-hit and attack-cessation assertions.
Full rerun `suite-a24a39cb-6884-442f-9558-0115b31fbbfd` again met follower
cessation assertions but missed the extra spell probe. That unrequested probe
was removed from cessation cases rather than treating an undelivered cast as
a pass. Required cessation and lethal-hit assertions remain unchanged;
player spell finishing and essential spell rejection remain routine cases.

Promotion to routine regressions, 2026-10-11: the default suite runs NPC defeat,
follower pacification and normal NPC pacification. Hello World was removed.
The first suite `suite-31245929-174b-4a08-8897-930b45a1a893` correctly failed
and stopped at follower setup because accepted player input produced no hit.
Its evidence is retained; four saves and both INIs were unchanged. Controlled
melee staging was tightened and bounded ordinary attack attempts added; the
attack-cessation and valid-fixture assertions were retained.

Routine suite `suite-c8713c12-4e00-48ee-b57c-1ea6e9f1b19d` passed all three
cases on 2026-10-11. NPC defeat: `fcf6e5b8-cb17-4847-bfd4-0322b4054751`.
Follower: `18a21f1b-22a7-41b4-a406-657d562ee002`, 78 observations over
20.431 seconds after settling. Guard: `eae4938c-5427-4a5b-9e80-864c01c2e503`,
77 observations over 20.166 seconds. Both landed a real hit before defeat,
then had zero post-settling attacks/hits/targets; attackers stayed alive,
undefeated and unpacified. Each player hit landed on its first normal input
attempt at a verified distance of approximately 85 units with fists drawn.
All actors cleaned up, all games closed gracefully and preferences restored.
No capture tool calls occurred. Suite `preservation-audit.json` confirms all
four saves and both desktop INIs unchanged, with no remaining game/loader.
Negative self-checks reject continued attacks, immune hits, lingering combat,
disabled attackers and failed/incomplete child results. Further repetition,
real follower quests/NFF, other factions, collateral damage and VR remain open.

### Native Test dialogue regression

```powershell
pwsh -NoProfile -File tests/Invoke-PacificationTests.ps1 -Test peaceful-test-dialogue -KeepInstalled
```

Owns disposable female Forsworn fixtures. Selects native Test root and linked choices,
verifies executed INFOs, exact regular/blessing/bound animation clips, hold restart,
health/pacification, bound-to-regular override, Yielding/Normal/Combat/Dead routes,
and avoidance during nearby combat followed by wandering. Logs first; no screenshots.
Does not run 2s/3s recovery cases. Candidate remains installed only on PASS.

Startup temporarily enables `bAlwaysActive=1` in desktop Skyrim.ini before SKSE
launch; runtime console `setini` arrives too late if startup already stops on focus
loss. Original INI bytes are archived and restored, with an external-edit check.
Summary includes `startupIniRestored`; no VR config is written.

Build-time record gate: `python tests/Test-TestDialogueRecords.py`. This checks the
compiled ESM root response/conditions and 26 native links, catching malformed YAML
that Spriggit accepts while discarding INFO fields.

Qualified desktop run: `9862c8ae-b917-44b1-b3fe-1ab477a7f455` (all command indices
0-8, native dialogue selections and expected outcomes; actor cleanup, graceful close,
preferences and startup INI restoration confirmed). The Combat destination is checked
before isolating later scenarios on a fresh actor. Separate discovery `skyrim-1ay`
records an inconclusive direct synthetic-combat -> DefeatActor settling probe; that
extra bootstrap is not a prerequisite for talkable-source Test commands.
Acheron's animation-driven defeat can differ from native IsBleedingOut; use its own
flag/package plus fresh targeted OAR bleedout/locomotion clips for transition readiness.

## Commanded sitting and direct pose transitions

```powershell
python scripts/Stage-SittingAnimations.py
pwsh -NoProfile -File tests/Invoke-PacificationTests.ps1 -Test peaceful-sitting
pwsh -NoProfile -File tests/Invoke-PacificationTests.ps1 -Test peaceful-sitting-poses
pwsh -NoProfile -File tests/Invoke-PacificationTests.ps1 -Test peaceful-sitting-poses-male
```

`peaceful-suite` includes the core `peaceful-sitting` regression; complete pose
qualification stays explicit. `peaceful-sitting` uses real native Sit/Heal/On your feet/Kneel/Bind topics,
exact zero-injury baseline, yielding/sitting save-load, failed no-potion treatment,
an actual consumed healing potion and an external native healing spell.
It asserts unchanged occupied marker/native sitting, no enter/exit clips on Heal,
preserved remaining hold/peaceful budget, and a fresh unbound menu without Heal.
Default posture changes and sitting Bind retain their requested exit/entry sequence.
Pose cases select each native Test entry and require its actual scoped OAR enter and loop;
male case excludes female-only families. Every variant has its own Test choice.
Each asset case uses a fresh actor; repeated marker-entry stress is separate.
Pose selection preserves engine health; real injury routing is tested separately
through actual defeat and On the ground. Forced wounded Test poses use a diagnostic
injury baseline, not health damage.
Visual seating geometry, swaps and VR remain separate acceptance checks.

Direct Kneeling -> KneelingBound now shares the held package/marker and skips exit
and enter, resetting hold once at acceptance. Regular/blessing/child hold cases
assert that contract; older exit-before-Bind results above describe superseded code.
Regular uses the Test bound choice; blessing and child use the ordinary Bind choice.
Routine evidence remains logs/hooks, with no automatic screenshots.

2026-10-15 desktop qualification: core sitting `7f6938bd-25ff-44b9-b892-b2f09caa8f0e`,
all16 female poses `e560ab49`,13 male poses `186f2737`, regular/Test-bound `8d297cb7`,
blessing/Bind `41a9015b`, child/Bind `76dbfbae`, real player-hit defeat `fdaa3914`.
Candidate retained with130 deployment hashes verified; owned actors/saves cleaned,
desktop closed, INI/Prefs/config snapshots restored. Full receipts and limits live in
[the animation catalog](../docs/animations-bookmarks.md#sitting-asset-staging).
The long one-actor pose sweep stalls after nine entries (`skyrim-emh`); asset tests
use fresh actors and do not claim that stress case fixed. Visual seating/blends,
mortality scheduling and VR remain unqualified.
