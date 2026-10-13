# Native defeated dialogue

Desktop replaces Hunter Pride's custom menu with normal Skyrim Talk dialogue.
The interaction perk only supplies the Talk label; no activation replacement,
menu SWFs, option-registration APIs or custom selection events remain.
Hunter Pride's combat eligibility and attack toggle remain separate.

Defeated actors temporarily permit PC/bleedout dialogue and suppress aggression.
Desktop comparison retained pacification and both dialogue flags: original
Aggression `2` prevented native Talk choices, while `0` and `1` permitted them.
Zero aggression is sufficient but not necessary on this fixture. This qualifies
the female Forsworn fixture, not every actor or VR. Current code still uses `0`.
Recovery restores prior dialogue flags and removes the owned aggression modifier;
subsequent peaceful states acquire their own ownership. Defeated cosave version 2
stores this state; version 1 still loads. Obsolete menu records are ignored.

Controlled runs on 2026-10-12: baseline `cfbc1105-e85b-4a05-9be8-44c35f229522`
opened selectable native choices twice while Yielding and twice while peacefully
managed. Temporary candidate `3699f109-79b5-4267-970e-27d134d55d2b` omitted aggression
suppression at defeat and peaceful entry; effective aggression remained `2` before
and after each attempt. Real crosshair/E input opened no dialogue in all four
attempts. Actors stayed pacified and out of combat; `CanTalkToPlayer()` returned
true even when actual activation failed. Installed files and configs were restored.
The comparison did not establish the engine's exact rejection condition; do not
remove the override based on the dialogue flags or `CanTalkToPlayer()` alone.

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
This API is registered only under `ACHERON_YIELD_TESTS`; ordinary activation is
unchanged. It is a probe, not a deployed replacement for the aggression override.

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
Next implementation can route player activation only for eligible managed actors
through this entry, leaving other actors' native activation intact. That routing,
all other actions, save/load, additional actor types and VR remain unqualified.

Desktop enemies hostile to the player before aggression suppression receive
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
Backup: `build/pacification-backups/ab2c62da-2017-40bf-a101-4674dcae75fc`.
Its `manifest.json` lists original/candidate hashes and all original files,
including retired SWFs and the interaction perk fragment PEX. With desktop
closed, restore exactly those files from backup through Desktop-Isolation guards.
Restore an older test save/cosave when reverting to a build predating version 2.
Source deletions backed up under `build/retired-hunter-menu-20261012-030934`.

VR production untouched. VR, creature/custom-voice dialogue, old-save migration,
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
Installed DLL B2D0A6F192FE6A3E70A8E78BC75950E5C5739C7860874AA14870BD4510793BC1;
ESM B3C4E35E94E0D4C75A90F4EE3307773C37471F0E47D7F03D9CDA39A1C6A59ADC.
Desktop settings restored and game closed; VR remains unqualified.
