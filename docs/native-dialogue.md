# Native defeated dialogue

Desktop replaces Hunter Pride's custom menu with normal Skyrim Talk dialogue.
The interaction perk supplies the Talk label. Desktop player activation uses a
scoped `TESNPC::Activate` vtable adapter (slot `0x37`) and the actor's native
`SetDialogueWithPlayer(true, false, nullptr)` entry. No custom menu SWFs,
option-registration APIs or custom selection events remain. Hunter Pride's combat
eligibility and attack toggle remain separate.

Entry requires a living, loaded humanoid NPC, permitted PC dialogue, no active
scene, activation block or NPC combat, Acheron pacification, and either defeat or
peaceful-controller ownership. An already-open dialogue rejects entry. Non-player activation, unmanaged
actors, corpses, quest scenes, VR and native entry failure use original activation.
Talk changes no FSM state; choices still dispatch the existing native INFO actions.

New defeated and peaceful actors keep their original Aggression. PC/bleedout dialogue
permissions remain temporary; Acheron combat and damage protection remains intact.
No Aggression `0` or `1` fallback is applied. This preserves actor values; it does
not guarantee antagonistic spoken greetings. Greeting selection stays native.

Defeated cosave version 2 and peaceful records keep their existing serialized
ownership fields for compatibility; new records write zero aggression debt. Load
reconciliation removes an old owned temporary suppression only when the modifier
matches `before - ownedAmount`; an already-restored modifier clears debt without
adding again. Ambiguous external modifiers remain untouched and logged. Version 1
records without aggression ownership cannot safely identify an old suppression.
Dialogue flags restore on release; relationship rank still intentionally remains.

### Historical aggression comparisons

Controlled runs on 2026-10-12: baseline `cfbc1105-e85b-4a05-9be8-44c35f229522`
opened selectable native choices twice while Yielding and twice while peacefully
managed. Temporary candidate `3699f109-79b5-4267-970e-27d134d55d2b` omitted aggression
suppression at defeat and peaceful entry; effective aggression remained `2` before
and after each attempt. Real crosshair/E input opened no dialogue in all four
attempts. Actors stayed pacified and out of combat; `CanTalkToPlayer()` returned
true even when actual activation failed. Installed files and configs were restored.
The comparison did not establish the engine's exact rejection condition. Dialogue
flags or `CanTalkToPlayer()` alone did not qualify removing suppression; the scoped
native entry below supplies the independently tested route.

Aggression `1` follow-up: fresh baseline `9e62e1f8-2c75-442d-9347-233f08d3de14`
opened all four choices at `0`. Candidate `f9990622-bd76-43d8-a618-11f2888aa691`
lowered the original `2` to `1` using the same temporary modifier ownership.
Native choices opened twice in Yielding and twice during peaceful movement;
effective aggression stayed `1` before/after interaction, pacification remained,
and the NPC never entered combat. Candidate/source changes were reverted and
installed files/configs restored. This probe validates choice availability only;
command execution, save/load, other actors and VR at aggression `1` remain untested.

### Scoped native entry probe

Desktop `1.6.1170` inspection located the normal activation call to the actor's
native `SetDialogueWithPlayer(true, false, nullptr)` virtual method (slot `0x41`).
The native `TESNPC::Activate` implementation calls it after preceding eligibility
checks. Calling this same entry directly opened native dialogue without changing
aggression. No engine bytes, faction relationships or UI flags were patched.
The exact earlier aggression-dependent rejection instruction remains unidentified.

Diagnostic-only `Acheron.ProbeNativeDialogue` queues that call on the game thread.
Both request and execution require a living, loaded, non-player actor outside
combat, permitted PC dialogue, Acheron pacification, and either defeat or an owned
peaceful controller. Execution also rejects an already-open dialogue menu. Its
return value means queued; `[NativeDialogueProbe]` logs the actual native return,
and the harness separately verifies selectable native choices and selected INFO.
This API is registered only under `ACHERON_YIELD_TESTS`. It now reuses the same
scoped entry as the production player-activation adapter; real E is tested separately.

Temporary unsuppressed candidates:

| Run | Choices | Action | Controls |
| --- | --- | --- | --- |
| `7a84c828-bc8e-4a68-a820-b9f378a81c07` | 4/4, two Yielding and two Wandering | Native On your knees. INFO; FSM entered ready Kneeling | Unmanaged enemy rejected |
| `c75061d6-e177-45c3-9d42-f9039918be01` | 4/4, two Yielding and two Wandering | Same native action and FSM result | Unmanaged enemy and merely pacified enemy without controller/defeat ownership rejected |

Evidence: `build/test-results/<run>/summary.json`, `Acheron.log`, `tools.jsonl`.
Aggression stayed `2` before/after every interaction; pacification stayed active and
combat stayed false. The repeat records ordinary E activation leaving the menu
closed before each direct entry, then the native call returning true and choices
becoming selectable. Action selection used real keyboard input, not a direct FSM
command. Kneeling animation playback was not separately asserted in this probe.

Candidates were restored by the deployment wrapper; all installed original hashes
matched. Disposable actors were deleted, games closed, configs restored, and
source aggression suppression restored and rebuilt. No saves written; VR untouched.
These are historical direct-entry probes. Production routing and its regression
evidence are separate from this earlier experiment.

Desktop enemies hostile to the player before managed entry receive
native relationship rank -3 (Enemy), enabling resentful vanilla greetings while
combat remains blocked. Defeat and direct peaceful entry share this policy;
player teammates, commanded actors and non-hostile civilians are excluded.
Release deliberately does not restore relationship rank. Factions remain unchanged.
Native rank persistence for templated actors, quest effects and voice coverage
require manual qualification; this change adds no custom greeting overrides.

Native choices reuse existing action logic: Rescue, Plunder, Execute and Drain.
Execute/Drain are hidden for essential actors; Drain requires a vampire player
and a living, non-undead target. On your knees. enters owned Kneeling without
healing; Bind remains available from Kneeling. On your feet. is available only
from unbound Kneeling and resumes avoidance/wandering after the matching pose
exit, without healing or resetting either timer. Desktop qualification passed in
run `186bdc37-d88e-46cf-a7c1-37150419d1f1`; bound posture commands remain planned.

Planned **On the ground.** adds commanded unbound Sitting from the same sources as
Kneeling and from Kneeling itself. Sitting offers On your knees. -> Kneeling,
On your feet. -> peaceful movement, and Bind -> KneelingBound through sitting exit,
kneeling entry and bound pose. No SittingBound state. It shares Kneeling's commanded
hold and cleanup; automatic Surrender Resting remains separate. No Sitting/Sit/topic
implementation or playback qualification exists yet; see [FSM policy](fsm.md#commanded-sitting).

## Desktop evidence

Current real E regression `82ea4472-b1f1-42ac-a587-8e2b990b571d`: 4/4 selectable
native choices (two Yielding, two Wandering), original Aggression `2` before/after
each interaction, pacification retained and no combat. Unmanaged hostile and merely
pacified actors reject diagnostic entry; actual E retains vanilla activation without
opening dialogue or logging adapter acceptance. Candidate kept installed on PASS.
Enemy/civilian standing Talk also passed `eb326102-1b31-405a-885c-02175374d086`.
Direct-entry diagnostic repeat `8edb86d3-1bd1-4689-af82-385b40820ee7` passes
4/4 choices, native On your knees. selection, ownership controls, and unchanged
aggression/pacification. Its wrapper restores the already-qualified installed build.

Native healing regression `1c753254-1387-454f-b84d-91198338a712`: potion, healing
spell, actual Rescue INFO selection, and civilian potion all enter shared peaceful
behavior. Rescue consumes one player potion and adds exactly its 25-point effect.
The fixture now selects native Rescue instead of calling the retired menu script;
civilian spawn ownership uses the existing actor-inventory resolver.

Current save/load regression `db4547c8-626e-4445-9941-0ba4a192496c`: real ESS/cosave
with diagnostic fixtures emulating owned old suppression on one defeated and one
peaceful enemy. Both restore Aggression `2`, retain their original ownership, and
remain at `2` through a second clean save/load. Paused/unloaded wandering time and
marker ownership also pass. These fixtures qualify known owned migration, not
arbitrary external actor-value edits or every historical user save.

Held-state activation regression `ca514f76-d134-45c4-9cb6-791e864e4531`: native
`ObjectReference.Activate` passes through the production adapter; actual native
On your feet./Bind selections, both native pose families, matching exits, bound
Continue. choices, hold restart/expiry and pose persistence pass at original
Aggression `2`. Seated real E aiming remains unqualified; the attempted camera
fixture failed against the unchanged installed baseline too and was removed.

Strict in-place kneeling remains a separate existing failure (`skyrim-zc9`):
candidate `e36d4430-1004-4972-ba75-15c5450f28cb` measured 77.12 units travel;
unchanged installed aggression-0 baseline `96cf66b7-9506-4f75-9073-2444d25af914`
measured 79.31. No pose code or travel assertion was relaxed for this change.

Historical action/animation evidence before this adapter:

- `build/test-results/9f5f0f07-84e1-4070-b142-82df55c1b121/summary.json`:
  real player lethal hit; downed crosshair acquired; E opened native dialogue;
  selected On your knees. INFO; native kneeling occupancy, held pose and Talk;
  native Bind selection/clip, timer restart; original aggression restored;
  native Rescue selection, one potion consumed, 25-point healing, peaceful Wander.
- `build/test-results/2ea50d6b-0d0c-40f3-af49-90805ee46a83/summary.json`:
  enemy/civilian standing crosshair Talk, selectable Continue., preserved
  peaceful ownership and deferred expiry passed.
- C++/Papyrus/plugin builds passed. Dialogue-evidence, manual setup fixture and
  desktop-isolation host checks passed. No routine screenshots.

## Deployment and rollback

Qualified desktop candidate installed by `tests/Invoke-PacificationTests.ps1`.
Backup: `build/pacification-backups/b3cf3bbf-6f88-4f65-a64e-225ddde12763`.
Its `manifest.json` lists original/candidate hashes and all original files,
including translations and scripts. Installed candidate hashes verified against
the manifest. With desktop closed, restore exactly those files from backup through
Desktop-Isolation guards. Earlier custom-menu retirement backup:
`build/pacification-backups/ab2c62da-2017-40bf-a101-4674dcae75fc`.
Restore an older test save/cosave when reverting to a build predating version 2.
Source deletions backed up under `build/retired-hunter-menu-20261012-030934`.

VR production untouched. VR, creature/custom-voice dialogue, ambiguous legacy modifiers,
and native Plunder/Execute/Drain selection remain unchecked. Third-party custom
Hunter Pride menu add-ons need conversion to dialogue; removed menu APIs are
intentionally incompatible. Newly added topics currently use English labels.

## Test submenu (desktop)

Branch 0x834, topic 0x835: `Test`. Two root INFOs (0x836 defeated keyword,
0x837 owned peaceful anchor) link the same nine topics using native INFO `LinkTo`.
Only the root is top-level; command INFOs end dialogue. No special SWF/menu.

| INFO | Command |
| --- | --- |
| 0x839 | Normal |
| 0x83B | Combat |
| 0x83D | Yielding |
| 0x83F | Avoiding combat |
| 0x841 | Wandering |
| 0x843 | Kneel (Regular) |
| 0x845 | Kneel (Blessing) |
| 0x847 | Kneeling bound |
| 0x849 | Dead (kill NPC) |

Selections enter existing engine/owned states with full behavior, not animation-only
previews. Explicit variants are deterministic. Native topic events dispatch through
Pacification::RequestTestState; actor/epoch validation and native held exits remain.
Combat and Normal remove managed dialogue; defeat again to reopen Test. Dead kills
the actor using native rules. Use disposable test NPCs.

Desktop qualification: `build/test-results/9862c8ae-b917-44b1-b3fe-1ab477a7f455/summary.json`
passed all nine native selections. Regular/blessing/bound clips, bound-to-regular,
health/pacification, hold restart, Test visibility from all five managed source states,
Normal/Combat/Yielding/Dead outcomes and avoidance-to-wandering were checked.
Historical qualified DLL B2D0A6F192FE6A3E70A8E78BC75950E5C5739C7860874AA14870BD4510793BC1;
ESM B3C4E35E94E0D4C75A90F4EE3307773C37471F0E47D7F03D9CDA39A1C6A59ADC.
Desktop settings restored and game closed; VR remains unqualified.
