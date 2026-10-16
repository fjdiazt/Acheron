# Native fleeing qualification

Tracking: `skyrim-6a1`. Desktop SE 1.6.1170; DevBench 1.27.0.

Approved behavior remains planned: enemy-only **Get out of here.** and Test
Fleeing entry; Acheron pacification during flight; unchanged health, Aggression
and Confidence; no healing. Finish at 4096 units from player or 30 real seconds,
then remove owned overrides. No prisoner hold or wandering budget consumed.

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

## Preserved work and isolation

Incomplete pure-state implementation and harness registration archived in
`build/flee-investigation/incomplete-integration.patch`; diagnostic script and
package YAML beside it. Removed from production source/records pending movement
qualification. Pure-state tests passed before archival; no runtime controller,
dialogue, serialization or actual Fleeing integration completed.

Probe deployments restored original desktop files by hash; game and test INIs
restored. No permanent candidate deployment, saves or screenshots. VR untouched.
Do not run prohibited `npc-recovery-2s` / `npc-recovery-3s` regressions.
