# Native fleeing qualification

Tracking: `skyrim-6a1`. Desktop SE 1.6.1170; DevBench 1.27.0.

Implemented behavior: enemy-only **Get out of here.** and Test
Fleeing entry; Acheron pacification during flight; unchanged health, Aggression
and Confidence; no healing. Finish at 4096 units from player or 30 real seconds,
then remove owned overrides. No prisoner hold or wandering budget consumed.

**Current desktop result:** the existing FSM owner now runs production FleeFrom
`00088A:Acheron.esm`, with native dialogue and Test entry, separate 30-real-second
budget, 4096-horizontal-unit boundary and shared cleanup. Entry, lifetime and
lifecycle qualification passed; evidence below. Bound release and automatic yield
outcomes remain planned. Arbitrary-position routing and VR remain unqualified.

**Feasibility result:** package-driven FleeFrom and FleeTo move the actual
yielded Forsworn after no-heal exit, with all hooks/plugins active and no Travel
warm-up or player relocation. Both passed twice; final repetitions explicitly
prove horizontal movement. Prefer FleeFrom for integration because it needs no
escape-marker selection. Earlier direct-call flight required a prepared route;
its actual-Yielding probe stalled. No conflicting mod established. These probes
alone did not qualify the later FSM implementation.

## Gameplay implementation qualification

Production package 88A reuses the qualified vanilla Find/Flee template; private
880/881 fixtures are absent from ordinary compiled staging. No escape-marker
selection or Travel warm-up. Health, Aggression and Confidence remain unchanged,
with Acheron pacification throughout flight. Held poses use the shared exit
pipeline; rescued wounded-locomotion scope does not extend into Fleeing.

| Run | Case | Result |
| --- | --- | --- |
| `aa75bccf-91c2-4fcf-917a-60c85f8ace73` | `flee-entry` | PASS: native entry from Yielding, Wandering, AvoidingCombat, Kneeling and SittingWounded; Test entry, player/follower/civilian/bound exclusions, short deadline and cleanup. |
| `569080d3-9b01-4acc-8905-7d383424dc5e` | Final `flee-entry -KeepInstalled` | PASS: adds positive-health Sitting, Test Wandering to Test Fleeing, rescued-marker removal and repeated-command budget checks; matching desktop candidate retained. |
| `d598298d-d520-441b-878a-dbb2e7162fbb` | `flee-lifetime` | PASS: default expiry observed at 30.72 seconds; real horizontal flight about 201 to 1589 units; distance boundary ends at 4170.85 units with 21.09 seconds remaining. |
| `ac06030c-cd96-4c61-8d10-c09f8ef30047` | `flee-lifecycle` | PASS: save/load preserves remaining budget; death, follower eligibility loss, renewed defeat, pause deadline and unload/reload cleanup. |

The distance-boundary test moves the player 4200 units from the actor **after**
independently proving real flight. It proves the 4096 predicate and cleanup, not
that the NPC navigates a complete 4096-unit route. Native pathing remains dependent
on navmesh and spawn context; an actor at a different exterior spawn position
stalled in `a7effd8d-3330-44bb-b429-2a1d45f30069`, although its default timer passed.
The passing lifetime fixture uses the same 150,0 spawn offset as the qualified
package probe; no production movement workaround was added.

Earlier lifecycle `ab087dd4-f96e-452e-a018-3ce4b0b07296` failed a test assumption:
corpses retain a cached native current-package pointer after actual overrides
are removed. Dead fixtures now require ActorUtil override count zero; living
fixtures still reject an owned current package. Host counterexamples cover both.
Run `1a26f0ac-8c0d-4368-880d-6f6d421ea12e` failed during the deliberately paused
console fixture; the runner now waits for Console to close before checking the
unpaused snapshot. Both original failed summaries remain unchanged.

Cosave version 5 appends the independent flight budget and retains reads of
versions 1-4. Steady-clock time includes pause/unloaded intervals when observation
resumes; physical cleanup waits for actor updates. Time with Skyrim closed does
not count. Normal underlying hostility can return after flight ends. No healing,
potions, civilian flight, automatic outcome resolver or bound-release integration.

Native dialogue log confirms Yielding rows 0 Rescue, 1 Get out of here., followed
by the existing actions. Final candidate backup:
`build/pacification-backups/a18552b8-696b-489f-b695-ad784578b014/manifest.json`.
Game closed, both INIs restored, owned actors/saves removed; VR untouched.
Build, pure FSM tests, compiled dialogue/package gate, PowerShell host tests and
generated FSM view checks pass. `peaceful-suite` now includes `flee-entry`; the
30-second lifetime and lifecycle qualification remain explicit cases.

**Qualification correction:** run `0066be5d-c79f-4258-ab02-1b48e5a906f8`
captured the native **Enable Survival Mode?** Yes/No dialog pausing the exterior
world. Earlier package probes below did not check that prompt. Their stationary
results cannot establish a Flee package defect or incompatibility with Acheron.
Reassess them with modal-menu handling before drawing that conclusion.

## Evidence

Runtime artifacts live under `build/test-results/<runId>/`.

| Run | Setup | Result |
| --- | --- | --- |
| `aca307fa-e82f-4730-93c7-1c188d61f4e3` | Vanilla DB08AntonFlee, pacified | Selected package; distance about 250 to 306, then stationary. Vanilla distance input unset. |
| `c124e421-8e08-4239-aa53-29ff3b6d48cd` | Custom FleeFrom, player target, 4096 distance, pacified | Selected package; distance about 151 to 230, then stationary. Subsequent unpacified control selected a different package; invalid comparison. |
| `8fbacb38-572d-4f69-a466-218e86099b55` | FleeTo, explicit linked marker about 4096 units away, pacified | Selected package; distance about 146 to 145, then stationary. Borrowed peaceful owner for linked marker; marker ownership/path reachability not independently qualified. |
| `5c0b7155-4659-4960-8073-8f5d2c94d835` | Fresh unpacified Forsworn, custom FleeFrom, WhiterunExterior16 | Correct package remained selected; distance about 252 to 375, then stationary for remaining observation. Aggression/Confidence unchanged. Second, pacified actor failed sword-equipment fixture before flight began. |

Spriggit readback confirmed custom FleeFrom fields survived compilation:
template `0197F1:Skyrim.esm`, player target `000014:Skyrim.esm`, distance 4096,
search radius 10000, IgnoreCombat/WeaponsUnequipped/NoCombatAlert flags.
Compiled field correctness and package selection do not prove procedure progress.

Earlier rescue investigation (`skyrim-dre`) also observed FleeTo stationary
without pacification. Existing rescue movement instead uses qualified native
Sandbox packages; that does not prove distant flight.

At that earlier stage, no reliable sustained native fleeing was established. Evidence did not isolate
Acheron as cause or establish native fleeing as impossible. Exterior spawn
collision, reachable navmesh goals and Find/Flee procedure progress still need
separate controls. Before production integration, qualify movement over a known
reachable route and compare identical fresh actors with/without pacification.
A native Travel-to-escape-goal alternative would need its own qualification;
do not silently replace the approved native Flee approach or alter actor values.

## Direct InitiateFlee probe

Author example: [Scary Saves source](https://github.com/Toxijuice/ScarySaves/blob/main/src/Mod.cpp).
Uses `InitiateFlee(player,true,true,false,nullptr,nullptr,0.0f,50.0f)`;
its stop function calls `StopAlarmOnActor`. This is an implementation example,
not a guarantee of sustained fleeing for aggressive or pacified enemies.

Run `3c71d889-979e-4dbc-ac3a-760263778a2c` declined the exact Survival prompt
and ran two fresh female Forsworn controls. Unpacified control entered combat,
moved toward the player and lost health: unsuitable as a peaceful-flight control.
Pacified control remained noncombatant with unchanged health/Aggression/Confidence,
but distance only changed from about 372 to 388. Neither observed `isFleeing=true`.

Run `8899c20f-3063-48e1-b198-4db5cd108995` changed only native
`fleeFromDist` from 0 to 4096 for a fresh pacified actor. Distance remained about
215 throughout eight seconds. All snapshots reported `paused=false`, unchanged
health 50, Aggression 2, Confidence 4, pacification true, combat false. A dynamic
package was selected; `isFleeing` remained false. Stop call completed and actor
was deleted. No sustained flight qualified in this fixture. Native flag meaning,
path reachability and interaction with Acheron detection remain unisolated.

Test-only `ProbeNativeFlee` actions: 0 stop, 1 published example, 2 snapshot,
3 `fleeFromDist=4096`. Desktop dynamic NPCs only. Read-only action2 accepts
defeated actors; mutations reject them, and all actions reject managed actors.
The harness declines only the exact Survival prompt with matching Yes/No buttons;
unknown prompts fail. `Test-YieldStartupPrompts.ps1` verifies this boundary.

## Hook and plugin isolation

Same diagnostic DLL and native call; hooks disabled at process startup only in
`ACHERON_YIELD_TESTS` desktop builds. `-DisableAcheronHooks` skips
`Hooks::Install`; diagnostic APIs and event sinks remain. This is hook isolation,
not complete removal of Acheron. Fresh worlds, exact Survival prompt handling,
native Travel to an escape marker, unchanged health/Aggression/Confidence and
combat/pause assertions precede flight. No gameplay faction or actor-value edits.

| Run | Control | Result |
| --- | --- | --- |
| `a6e0ac64-e8de-40c4-a042-e9aee25ad27c` | Hooks off; native friendly guard, unpacified and pacified | Both Travel controls pass; both flee about 163 to 2147 units. |
| `7b8c4937-599f-4bfd-a6b5-2b98bb6a5f77` | Hooks on; same guard controls | Both Travel controls pass; flee about 163 to 2185 / 165 to 2461 units. |
| `3b1106a9-8c73-47d4-8469-a752eae38448` | Hooks on; pacified Forsworn; old teleport-back fixture | Travel passes; flight stalls about 170 to 178 units. |
| `dedbec4c-b3e7-4abf-8077-685818ee369d` | Hooks off; pacified Forsworn | Reenters combat. Invalid peaceful comparison, even though Travel reaches goal. |
| `211b95cb-3563-4a25-b90e-949935f3b301` | Forsworn; OAR, AnimationQueueFix, MediaKeysFix omitted | Flight about 228 to 2076 units, but starting position differs by hundreds of units. Not causal proof against DLLs. |
| `41ed527c-3742-4634-a90a-f79b441ecfdd` | Forsworn; OAR alone omitted; old fixture | Flight still stalls about 234 to 235 units. |
| `07eb0795-5db5-472e-821c-cac15d914690` | Corrected fixture; all hooks/plugins active | Pacified Forsworn flees about 205 to 977 units; invariants and stop pass. |
| `593b3b7f-986b-45b8-9fe7-94155fa3765b` | Same corrected fixture, repeated; all hooks/plugins active | Flees about 210 to 789 units; invariants and stop pass. |

The corrected fixture starts flight at the actual Travel arrival point and places
the player farther along the approach vector, so escape reverses the proven route.
It does not teleport the NPC back to its potentially unsuitable spawn position.
The positional/path-context difference is the leading explanation; exact native
pathing failure mechanism remains unisolated. Full-stack success disproves a
blanket hook/plugin block in this qualified setup, not every possible interaction.

Actual native flee package type is **22**, while `middleHigh->isFleeing` stays
false even during measured flight. Outcome evidence accepts native package types
10/22 plus more than 350 units of distance gain within eight seconds and unchanged
actor/pause/combat/hook invariants. It never accepts a package or flag alone.
The original `a6e0ac64` summary's `fleeQualified=false` used a type-10-only
classifier; preserved raw type-22 samples establish flight under the corrected
classifier. Stop returns type 22 to the actor's normal type-18 package. Host
counterexamples live in `Test-NativeFleeEvidence.ps1`.

Both final runs loaded Acheron, AnimationQueueFix, DevBench, MediaKeysFix, OAR and
PapyrusUtil. Each used a disposable female Forsworn with iron sword, no shield,
health 50, Aggression 2 and Confidence 4; pacification stayed active, combat and
pause stayed false during flight. All omitted DLLs were restored by hash.

### Reproduction

Build the test-diagnostic DLL normally, then compile the private Travel record:

```powershell
pwsh -NoProfile -File tests/Build-NativeFleeFixture.ps1
pwsh -NoProfile -File tests/Invoke-PacificationTests.ps1 -Test native-flee-probe -DisableAcheronHooks
pwsh -NoProfile -File tests/Invoke-PacificationTests.ps1 -Test native-flee-probe
pwsh -NoProfile -File tests/Invoke-PacificationTests.ps1 -Test native-flee-enemy-probe
```

`native-flee-probe` uses native friendly guards without actor-value edits;
`native-flee-enemy-probe` uses the actual pacified female Forsworn fixture.
`-MinimalFleePlugins` temporarily omits OAR/AnimationQueueFix/MediaKeysFix;
`-ExcludeFleePlugins OpenAnimationReplacer.dll` omits just that allowed DLL.
These options are restricted to restoring flee probes; `-KeepInstalled` is
rejected. The wrapper restores original process environment and target files.

Fixture record 880 exists only in `tests/fixtures/native-flee` and the compiled
probe ESM. Its build script removes its temporary `res/Packages` input in finally.
Recompile ordinary `res` after probing to reset staging. Protocol PASS means
observations collected safely; per-control `fleeQualified` determines flight.
Never treat a protocol PASS with `fleeQualified=false` as behavior qualification.

Production integration remains separate: use the existing FSM owner, preserve
pacification/stats, and qualify actual yield/held-pose entry, bounded lifetime,
distance end and cleanup without a test-only Travel warm-up or player relocation.

## Actual Yielding entry qualification (2026-10-16)

Run `15153cd0-2373-405e-a6c5-e4e27e36160f` tests the missing production-like
entry with all hooks/plugins active and ordinary staging ESM. Disposable female
Forsworn, sword only, no Travel warm-up and no player relocation. Fixture disables
health regeneration before defeat; no health, Aggression or Confidence changes
are allowed after entering Yielding.

Actual Acheron `DefeatActor` acquired defeated ownership, its BlankPackage and
`kNoBleedoutRecovery`. Existing `RescueActor(false)` then removed all three,
retaining pacification and health about 0.05, Aggression 2 and Confidence 4.
Native flight selected package type 22, but distance stayed about 194 units:
initial 194.66; 34 samples ranged 193.64 to 194.29 over eight seconds. Player
remained stationary; no combat/pause or actor-value changes. Stop restored
normal package type 18. **Movement qualification failed.** Prepared-route success
does not establish reliable flight from actual Yielding.

Two earlier runs (`3a502194-f241-4dfc-8207-333478faa4a0` and
`ec14f75e-f6b4-414b-a984-07171d36a645`) never attempted flight: their entry guard
incorrectly required native `ActorState::IsBleedingOut()`. CommonLib implements
that as native life states EssentialDown/Bleedout; Acheron uses its own defeated
ownership and plays the bleedout idle, without assigning those life states.
First run also left fixture AI disabled; second enabled it and still demonstrated
the life-state mismatch. Corrected guard requires Acheron ownership, lock and
BlankPackage. Diagnostics allow read-only defeated snapshots; flight/stop actions
still reject defeated actors and every managed peaceful actor.

Reproduce with ordinary diagnostic DLL and ordinary production-record staging:

```powershell
pwsh -NoProfile -File tests/Invoke-PacificationTests.ps1 -Test native-flee-yield-probe
```

This case requires the full plugin/hook stack, always restores installed files,
and fails if flight does not gain 350 units. Native flee evidence also rejects
lingering defeat ownership, bleedout lock or BlankPackage during observations.
Counterexamples and isolation-boundary host tests pass. Latest run cleaned its
actor, closed gracefully, restored both INIs and all 130 original file targets by
hash; VR untouched.

No gameplay Fleeing integration or FSM behavior change. Next investigation must
distinguish unfinished bleedout animation exit from native route/context failure:
trace exit/procedure evidence and compare an unyielded actor at the same stable
position before selecting an implementation. Do not add Travel warm-up, teleport
the player, heal the NPC or change actor values as a workaround.

## Package alternatives from actual Yielding (2026-10-16)

Clean retest addresses the Survival-popup confound in the original package runs.
Same female Forsworn, actual DefeatActor ownership followed by existing no-heal
RescueActor(false), full installed hook/plugin stack, no Travel warm-up or player
relocation. Actual health about 0.05, Aggression 2, Confidence 4 and pacification
remain unchanged throughout each valid run. Native snapshots include package,
procedure, knock state, position and horizontal distance; none requires the native
life state or knock flag to mean Acheron's logical Yielding state.

FleeFrom 880 derives from vanilla FleeFrom 0197F1: Find player into object list,
then Flee with distance 4096. FleeTo 881 derives from vanilla FleeTo 0C7039 and
uses a linked XMarker 900 units south of the player on the corridor traversed by
the earlier independent Travel control. This is a short movement qualification,
not proof that an arbitrary escape marker is reachable or that 4096 is reached.
Spriggit round-trip readback confirms both compiled templates and inputs.

| Run | Route | Result |
| --- | --- | --- |
| `a3c03b3b-826f-4858-a5b0-2879c281166c` | FleeFrom | PASS; distance 229 to 2098 units; exact package 880 selected, invariants and stop pass. |
| `651cbd4a-8137-46ac-9c9b-51b0e0463bd4` | FleeTo | PASS; distance 208 to 795; goal distance falls to 250; invariants and stop pass. |
| `f6759323-ec06-4c00-977f-e048e10d535d` | FleeFrom repeat | FAIL remains recorded: movement 204 to 1505, but one snapshot paused by exact Survival popup opening after guard. No actor-value change; stop passes. |
| `d479ae80-eea6-475e-841e-c03a99949790` | FleeFrom; horizontal metric | PASS; horizontal distance 226 to 1793 units; all invariants, stationary player, stop and cleanup pass. |
| `e986a871-1a66-4f68-a807-c2f1c0b9190a` | FleeTo; horizontal metric | PASS; horizontal distance 190 to 788; goal distance falls to 293; all invariants, stationary player, stop and cleanup pass. |

Run `8ad9a8e5-6bb9-49f6-b3c5-0b06531d0188` stopped before spawning: DevBench
returns blank EditorIDs for packages. Fixture presence check now uses package type
and local form ID; compiled readback and deployment hashes establish record identity.

Qualification now requires more than 350 units of horizontal distance gain while
the explicit fixture package is active. These template-based packages have generic
type 18; native-created package 10/22 classification alone is insufficient. Host
counterexamples reject wrong package, unrelated-package movement, vertical-only
movement, missing horizontal baseline and actor-invariant failures.

Late modal handling records the paused snapshot, validates/dismisses the exact
Survival prompt and requests one fresh read-only snapshot. It never repeats a
flight mutation or silently accepts unknown/unexplained/persistent pauses. The
extra decline counter distinguishes a newly handled prompt from an earlier one.
Mocked boundary tests cover these races; final live repetitions pass with the
updated helper. Original failed summaries remain unchanged.

```powershell
pwsh -NoProfile -File tests/Build-NativeFleeFixture.ps1 -FleePackages
pwsh -NoProfile -File tests/Invoke-PacificationTests.ps1 -Test native-flee-from-probe
pwsh -NoProfile -File tests/Invoke-PacificationTests.ps1 -Test native-flee-to-probe
```

Both fixture records are private test inputs; builder removes temporary source
copies even on compile failure. All package probes reject KeepInstalled and hook/
DLL-isolation switches. Six restoring deployments audited: all 130 original target
hashes match, game closed, both INIs restored, ordinary staging rebuilt from res,
VR untouched. No screenshots or recovery 2s/3s runs.

At the feasibility gate, the recommendation was FleeFrom integration with the
approved 4096-unit or 30-real-second lifetime and no healing/stat changes.
Held-pose exit, persistence/death/unload handling and lifetime tests were still
required. Those probes established movement feasibility only; the implementation
qualification above supersedes that gate and preserves the investigation history.

## Earlier archived work and isolation

Before movement qualification, incomplete pure-state implementation and harness registration were archived in
`build/flee-investigation/incomplete-integration.patch`; diagnostic script and
package YAML beside it. Removed from production source/records pending movement
qualification. Pure-state tests passed before archival; no runtime controller,
dialogue, serialization or actual Fleeing integration existed at that stage.

Probe deployments restored original desktop files by hash; game and test INIs
restored. Those probes left no permanent candidate deployment, saves or screenshots.
VR untouched. Gameplay qualification uses the ordinary candidate wrapper; explicit
`-KeepInstalled` retains a qualified desktop candidate for manual testing.
Do not run prohibited `npc-recovery-2s` / `npc-recovery-3s` regressions.
