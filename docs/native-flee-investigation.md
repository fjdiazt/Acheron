# Native fleeing qualification

Tracking: `skyrim-6a1`. Desktop SE 1.6.1170; DevBench 1.27.0.

Approved behavior remains planned: enemy-only **Get out of here.** and Test
Fleeing entry; Acheron pacification during flight; unchanged health, Aggression
and Confidence; no healing. Finish at 4096 units from player or 30 real seconds,
then remove owned overrides. No prisoner hold or wandering budget consumed.

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

Reproduce current distance probe with
`pwsh -NoProfile -File tests/Invoke-PacificationTests.ps1 -Test native-flee-probe`.
Test-only `ProbeNativeFlee` actions: 0 stop, 1 published example, 2 snapshot,
3 `fleeFromDist=4096`. Desktop dynamic NPCs only, no defeated/managed actors.
The harness declines only the exact Survival prompt with matching Yes/No buttons;
unknown prompts fail. `Test-YieldStartupPrompts.ps1` verifies this boundary.

Next useful evidence: qualify reachable path/target and package procedure data
with the now-unpaused world; retry the original package controls under the same
guard. Do not promote direct native entry or change actor values on these results.

## Preserved work and isolation

Incomplete pure-state implementation and harness registration archived in
`build/flee-investigation/incomplete-integration.patch`; diagnostic script and
package YAML beside it. Removed from production source/records pending movement
qualification. Pure-state tests passed before archival; no runtime controller,
dialogue, serialization or actual Fleeing integration completed.

Probe deployments restored original desktop files by hash; game and test INIs
restored. No permanent candidate deployment, saves or screenshots. VR untouched.
Do not run prohibited `npc-recovery-2s` / `npc-recovery-3s` regressions.
