# Native fleeing qualification

Tracking: `skyrim-6a1`. Desktop SE 1.6.1170; DevBench 1.27.0.

Approved behavior remains planned: enemy-only **Get out of here.** and Test
Fleeing entry; Acheron pacification during flight; unchanged health, Aggression
and Confidence; no healing. Finish at 4096 units from player or 30 real seconds,
then remove owned overrides. No prisoner hold or wandering budget consumed.

**Current desktop result:** direct native fleeing starts successfully for the
pacified Forsworn with all installed SKSE plugins active, twice, using the
qualified-path fixture below. No conflicting mod established. This does not
implement the Fleeing FSM, prove arbitrary-position reliability, or qualify
4096-distance completion / the planned 30-second timer. VR remains untested.

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

No reliable sustained native fleeing established. Evidence does not isolate
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
3 `fleeFromDist=4096`. Desktop dynamic NPCs only, no defeated/managed actors.
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

## Preserved work and isolation

Incomplete pure-state implementation and harness registration archived in
`build/flee-investigation/incomplete-integration.patch`; diagnostic script and
package YAML beside it. Removed from production source/records pending movement
qualification. Pure-state tests passed before archival; no runtime controller,
dialogue, serialization or actual Fleeing integration completed.

Probe deployments restored original desktop files by hash; game and test INIs
restored. No permanent candidate deployment, saves or screenshots. VR untouched.
Do not run prohibited `npc-recovery-2s` / `npc-recovery-3s` regressions.
