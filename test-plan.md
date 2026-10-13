# NPC yielding test plan

Requirements and approach, recorded 2026-10-11. The proposed implementation is
in [the harness implementation plan](docs/superpowers/plans/2026-10-11-yield-test-harness.md).
Routine desktop harness: [tests/README.md](tests/README.md).
The default suite covers real player-hit NPC defeat, follower and normal NPC
attack cessation, follower-caused defeat, ordinary NPC lethal combat, physical
and spell player finishes, essential protection, and 2s/3s automatic recovery.
The recovery regressions are added but have not been run. The earlier discovery cases are now strict
regressions. Hello World is removed; broader gameplay coverage remains pending.

Gameplay requirements: [yield.md](yield.md).
Manual room/setup commands: [test-room.md](test-room.md).

## Combat policy qualification

Use the existing player/party Hunter Pride path with `bNPCDefeat=false` and
`bHunterPrideFollower=true`; unrelated NPC fights must remain lethal. Keep
`bFollowerDefeat=true` and deterministic `fLethalNPC=100`. Check actual MCM
settings through native startup evidence before each fresh-world case.
Main-menu `coc` bypasses normal new-game/load messages; fixtures activate and
verify Hunter Pride. Verify automatic activation separately on normal load.
Direct player finishing bypasses the damage guard without running defeat again;
existing native death cleanup removes both flags. Use actual sources, preserve
essential restrictions and keep immunity for every non-player source.

The routine suite adds `follower-defeat`, `npc-lethal`,
`player-finish-physical`, `player-finish-magic`, and `essential-protection`.
Reuse existing fixtures; no test-specific gameplay bridge. Require native hook
evidence plus live state. Non-player spell delivery proved unreliable in the
cessation fixture; repeatable coverage remains pending. Full VR, NFF, PLANCK,
enchantments and summoned-caster acceptance
remain separate coverage until tested.

## Goal

Test the system inside desktop Skyrim: spawn NPCs, injure them, heal them,
interact with them, and check that they behave as specified. Automate repeatable
checks where practical, run them quickly, and retain enough evidence to diagnose
failures. Follow with acceptance testing in Skyrim VR and the actual mod profile.

## Fully unattended execution

Provide a host-side entry point the developer/agent can run without the user
launching Skyrim, loading a save, opening the console, attacking an NPC, or
answering prompts during an automated scenario. It launches the matched SKSE
loader, loads a dedicated fixture save, starts the chosen suite, collects
machine-readable results, shuts down its game session, and restores temporary
settings. The console batch remains available for interactive investigation.

- Require actual player-source physical and magic hits in the unattended
  integration suite; a manual attack prompt is an interim milestone only.
- Record unique run IDs, per-case evidence, summary, logs, runtime/load order,
  and process exit information so the agent can diagnose failures independently.
- Bound startup, cases, completion and shutdown. Crashes, missing output, stale
  results, timeouts, cleanup failures and skipped required checks cannot pass.
- Refuse to take over an already running user game. Close/terminate only the
  session started and identified by the harness; preserve other games/saves.
- The agent can inspect a failure, apply a targeted fix within agreed scope,
  rebuild and rerun affected checks. Preserve failed-run evidence; never weaken
  assertions or invent undecided gameplay to obtain a pass.
- Automated state/logic/integration results remain separate from manual visual,
  audio and headset acceptance. Hands-off execution does not require the engine
  to support a headless rendering mode.

## Environment requirements

- Use a separate desktop test profile and disposable saves. Record the installed
  Skyrim edition/runtime, SKSE version, fork revision, plugin load order, relevant
  mod versions, and MCM settings for every run.
- Begin with the smallest setup needed for the fork. Add relevant overhaul and
  follower integrations after the baseline works; record which combinations ran.
- Keep desktop and VR results separate. Desktop success does not establish VR
  dialogue, PLANCK hit handling, headset animation, or Mad God compatibility.
- Prefer `UnownedCell` following the room review; `qasmoke` remains available.
  Verify usable floor space, navigation, combat, and movement
  before treating it as an AI test arena. If unsuitable, select or prepare a
  suitable room later; do not assume a console teleport proves navigation works.
- Spawn disposable enemy, civilian, teammate/follower, and essential test actors.
  Identify each actor instance and role. Avoid real quest NPCs for destructive tests.
- Use a neutral test-character loadout for controlled damage. Keep the maxed
  character setup available for exploration; its perks and gear must not silently
  change measured hit damage, stagger, or spell effects.
- Keep AI, combat AI, and detection enabled for behavior scenarios. AI-off mode is
  for isolated pose experiments only. Restore settings after each run.

## Testing approach

### Selected tools: DevBench first, houseCARL for authoring

Only these two MCP tools are selected for this project:

| Tool | Role and limits | References |
| --- | --- | --- |
| DevBench | Selected for live testing. Provides MCP and REST access to the running game, console commands/output, save loading, live inspection, Papyrus calls with return values, input injection, event waits and timed scenarios. Desktop startup, world entry, real player melee defeat, teammate/guard attack cessation, state reads, cleanup and shutdown passed locally. Hello World is retired; routine screenshots are removed. Save loading, broader AI behavior and VR remain unverified. Input injection is not proof that an attack landed: require Acheron hook evidence. | [Source/documentation](https://github.com/alandtse/devbench), [Nexus](https://www.nexusmods.com/skyrimspecialedition/mods/181326), [releases](https://github.com/alandtse/devbench/releases) |
| houseCARL | Development/authoring support: plugin records, load-order conflicts, dialogue validation, Papyrus compilation and asset inspection. Requires an MO2 instance/profile. Its runtime-layer audits inspect files, not the running game; it cannot replace live integration tests. Defer setup until needed. | [Source/documentation](https://github.com/Avick3110/houseCARL), [Nexus](https://www.nexusmods.com/skyrimspecialedition/mods/181738) |

Start by qualifying DevBench on desktop: connect and verify runtime/PID, load a
disposable baseline save, spawn and identify one owned NPC, deliver a real player
hit, read Acheron's defeated/pacified state, and clean up. Use its existing REST,
Papyrus and scenario interfaces before writing a custom game-control bridge.
Add only the fixture-scoped damage observations and assertions those interfaces
cannot provide. A successful API call or scenario transcript alone is not a
passed gameplay assertion.

The host still owns startup, unique run IDs, bounded execution, result checking
and shutdown. Keep DevBench on localhost; preserve the existing user-session
ownership rules. Verify relevant checks again in the actual VR profile.

Setup snapshot, 2026-10-11: official DevBench v1.27.0 archive downloaded to
`S:\games\The Elder Scrolls V - Skyrim Special Edition\Mods\devbench-v1.27.0.7z`
and passed archive integrity testing. DevBench v1.27.0 and
[Address Library All in One v13](https://www.nexusmods.com/skyrimspecialedition/mods/32444?tab=files)
are now installed under desktop `Data\SKSE\Plugins`. The archive contains the
required `versionlib-1-6-1170-0.bin`; all 30 deployed files match their source
SHA-256 hashes. Installation manifest:
`S:\games\The Elder Scrolls V - Skyrim Special Edition\Mods\Install-backups\DevBench127-20261011-022752\installed-files.json`.
No existing files were replaced and VR was untouched.

After explicit user approval, the unattended smoke passed three times on 2026-10-11.
OS metadata and `/api/health` confirmed the owned desktop PID; SKSE's archived
log confirms 2.2.6 and DevBench reports 1.27.0. The host used REST on localhost,
entered a fresh `UnownedCell` world, called Papyrus `Debug.MessageBox`, observed
the unique message, captured 800x600 output, dismissed it and exited with `qqq`.
Preferences restored exactly; repeated execution preserved all existing save
hashes and left no game/loader process. No user save was loaded.
See [smoke commands and limitations](tests/README.md). Machine-readable evidence:
`build/test-results/0eb6167d-859c-4c04-8571-91284868b727/summary.json` and
`build/test-results/cf128aff-c55a-4d67-bdb3-865d316fbf6a/summary.json`.
Papyrus at main menu timed out; a loaded world was required for this call.
Native captures are UI evidence, not validated image comparisons. houseCARL is
not installed. Fixture-save loading, AI behavior and VR are still pending.

First NPC milestone: build/install of the NPC-only fork, PapyrusUtil 4.6 and
desktop SkyUI 5.2 SE completed. `Run-YieldTests.ps1 -Test npc-defeat` enables and
verifies Hunter Pride, spawns one owned nonessential female Forsworn at 1 health with
regeneration disabled and movement held, then injects a normal player sword attack.
Run `0ca686cb-39f3-4e0c-b383-a2d4dabd25f9` recorded native source `00000014`,
damage 3.1408 against health 1, and registered defeat. Live reads confirmed alive,
defeated, pacified and positive health. Cleanup cleared both Acheron flags,
disabled the actor and requested deletion; game exited and preferences restored.
Earlier failed run `b4f56027-9f83-477a-aeaa-2ffb6a9c9be9` exposed the existing
Hunter Pride gate: player hits remain lethal when that ability is off. Enabling
the fixture ability resolved this without changing the production gate.
No custom quest or attack bridge was needed. This stationary damage fixture does
not establish navigation, crawling, follower target selection or broader recovery.
Repeat `30e6bf32-c02d-4c5d-a09d-e32d6712d2ab` passed; independent SHA-256 audit
confirmed all four saves and preferences unchanged, with no game/loader remaining.

### Pacification discovery: one enemy, player and one teammate

Originally a discovery experiment; now a routine `follower-pacification`
regression per the user's later instruction. Continued attacks or lingering
combat after settling fail the test, even when damage immunity prevents injury.
Use one disposable female sword-only Forsworn and a clearly labeled Lydia copy. Confirm the teammate
is nonhostile to the player and actually attacks/damages the enemy before the
player defeats it. Observe native attack states and hits, including those blocked
by immunity; unchanged health alone cannot establish that attacks stopped.
Record two seconds of settling separately and at least ten seconds afterward,
with combat target/state and defeated/pacified flags as supporting evidence.
Require the follower to remain alive, undefeated and unpacified throughout;
otherwise stopping attacks could be caused by the follower's own defeat.
No forced teammate combat stop is permitted until teardown. Do not change
production damage permissions or pacification behavior to obtain a result.

Run `cd89cd2e-1fcf-46e8-a097-b9b1a6ab6640` completed: Lydia copy landed a
12.96-damage hit, then stopped after player defeat/pacification. Across 68 native
observations over 17.76 seconds after settling, there were no attacks or hits,
and her combat target cleared. Cleanup/shutdown/preferences restoration passed.
The native frame shows the distinct Lydia model; automated flags establish role.
Existing Acheron pacification appears sufficient for ordinary teammate targeting
in this case. Other NPCs, in-flight/collateral attacks, real follower packages,
NFF and VR remain separate questions; damage guards stay unchanged.

Qualified repeat `e0ae7440-d34b-4385-bac8-ceb81a6d5536` adds that missing actor
eligibility guard: 83 observations over 21.736 seconds after settling found no
attacks/hits/targets while the follower stayed alive, undefeated and unpacified.
Cleanup and independent SHA-256 preservation checks passed for four saves and
both INIs. A preceding repeat `af724a6c-d70b-4357-85c9-7fd6128b116d` was
invalidated: its player punch also downed the follower, so its initial PASS was
false evidence. Preserve its review and logs. Negative self-checks now reject
this confounder; player approaches opposite the follower for the defeat hit.

### Pacification discovery: normal guard versus enemy

Run the routine regression with `-Test npc-pacification`. Use a
fresh Whiterun Guard copy and female sword-only Forsworn with original factions, no teammate flags,
and no forced combat start. Require mutual hostility, a guard friendly to the
player, a Forsworn hostile to the player, and an actual damaging guard hit before
player defeat. Use the same native activity and attacker-eligibility checks.

Run `6fa50cb8-10c4-497d-bb1b-54c392febab5` passed: one 16-damage baseline hit,
then 70 samples over 18.297 seconds after settling with zero attack activity,
hits or targets. Seven residual attack-state samples occurred during settling,
with no hits. Guard remained alive and unaffected by defeat/pacification; the
user visually confirmed attacks stopped. Cleanup/shutdown and independent hashes
confirmed all four saves and both INIs unchanged. This supports ordinary guard
AI in this desktop fixture, not all NPC factions or collateral-damage safety.

Use logs, hooks and native state/UI reads as evidence. Routine screenshots are
unnecessary; capture only when those observations cannot prove a visual behavior.

Scope decision, 2026-10-11: rely on Acheron's existing pacification and damage
immunity. No additional NPC/follower protection system, targeting suppression,
or independent damage-block checkboxes are planned. Retain the existing guards;
the remaining damage-policy feature is ordinary direct-player finishing.
Discovery established attack cessation in these two desktop fixtures; collateral
damage and VR integrations remain unverified, not reasons to add new controls.

### Routine suite entry point

From the checkout, run `pwsh -NoProfile -File tests/Run-YieldTests.ps1`.
The default suite runs ten cases sequentially in fresh game
sessions. It fails on any failed or incomplete case, archives each case, and
returns success only when all ten pass with cleanup, shutdown and settings
restoration. No screenshots or Hello World case. `-Test <case>` selects an
individual regression; selectors are listed in the test README.

`npc-recovery-2s` and `npc-recovery-3s` temporarily set the existing NPC recovery
timer before launch, use a real lethal player hit, and require native timing
evidence plus living recovered state. Five seconds total yielding, plus startup,
setup and cleanup. Native heartbeats bracket recovery with a provisional 500ms
tolerance; missing/stalled observations fail. No forced rescue counts as success.
Restore the original settings bytes after each case, even on failure. These new
regressions are statically checked only; the ten-case suite is not yet qualified.

The complete eight-case suite passed as
`suite-729bf61b-0044-4e43-8d04-650f5441c44f` on 2026-10-11. All cases cleaned
up, exited gracefully and restored preferences. Independent audit confirmed
four saves and both INIs unchanged, zero screenshot calls and no remaining game
process. Detailed case evidence and remaining coverage limits are in the test
README's Player/party policy qualification section.

Pacification cases require a real attacker hit before player defeat, a living
and unaffected attacker throughout, and at least ten seconds after two seconds
of settling with zero attacks/hits/targets. Residual settling activity stays
recorded separately. The same baseline and evidence guards apply to both roles.

The earlier three-case suite passed as `suite-c8713c12-4e00-48ee-b57c-1ea6e9f1b19d`
on 2026-10-11: all three cases passed with cleanup, graceful game exit and
settings restoration. Follower and guard observations showed zero post-settling
attacks/hits/targets for 20.431 and 20.166 seconds respectively. No screenshot
calls. Independent audit confirmed four saves and both INIs unchanged.
The earlier suite correctly failed on missing player-hit delivery and stopped;
its evidence remains archived. The fixture now verifies approximately 85-unit
melee staging and drawn fists, allowing at most three ordinary input attempts;
it still requires actual native player-hit and defeat evidence.

### Fast logic checks

Check probability formulas, configuration boundaries, attacker classification,
deadline selection, state transitions, and outcome selection without waiting for
live combat. Use controlled random inputs or seeds where feasible. Verify both
branches of a chance-based decision, not just a fortunate outcome.

These checks must exercise the production rules. A separate imitation of those
rules in the test script would not establish correctness.

### Scripted in-game scenarios

A proposed runner prepares actors, starts a scenario, observes the result, reports
it, then restores the fixture. Qualify DevBench's existing controls first; combine
them with Skyrim scripting and native diagnostics only where necessary. Exact
scenario/API calls remain subject to local runtime verification.

Use real physical attacks and damaging spell effects for damage-hook integration
tests. Record actual incoming damage and predicted remaining health. Account for
armor, resistance, difficulty, and healing. Directly changing health or calling
the defeat action is useful for fixture setup and isolated state tests, but cannot
replace proof that an ordinary attack reaches the interception path.

Use bounded waits for events or state changes. A missing hit or an actor that never
starts moving must produce a failure or an explicit infrastructure error, not a
pass based on the absence of damage. Exact damage delivery and observations remain
to be investigated.

### Manual acceptance

Verify visible crawling, kneeling, bound poses, unconscious bodies, native dialogue,
target labels, and sounds. Confirm movement makes sense to the player and targets
remain reachable. Automated state or animation-event observations support these
checks; they do not prove the visible animation or interaction works.

## Required scenario coverage

| Area | Scenario and expected evidence |
| --- | --- |
| NPC-only scope | Player damage/settings/API attempts cannot enable player defeat or pacification. NPC/follower features still operate as agreed. |
| Yield entry | At default threshold 20%, predicted health above 20% has 0% health-based yield chance; at 20% it is 50%, at 10% 75%, at 5% 87.5%, and at zero/below 100%. Test configurable thresholds 25% and 50% too. |
| Failed yield check | Ordinary damage applies; victim does not acquire defeated state or immunity. |
| Successful yield check | Victim is alive, downed, and registered once. Stored injury reflects predicted health before Acheron's forced health value. |
| Roll frequency | One entry check per relevant damaging hit; idle frames do not add chances. Allowed follow-up damage does not defeat the same target again. |
| Attack paths | Player physical and spell hits reach early nonlethal entry; Hunter Pride cannot silently restrict them to lethal-only entry. Test ongoing spell damage and distinguish an old effect from a new finishing attack. |
| Attacker permissions | Retain Acheron's existing protection from non-player attackers; no new blocking toggles. Add only the direct-player finishing exception and verify physical and magic paths. |
| Attacker identity | A summoned actor is not treated as the direct player. Record actual attacker/caster and resulting permission decision. |
| Blocked hit evidence | Attacker delivered a hit; target's meaningful injury and survival state were unaffected by that blocked hit. No-hit scenarios cannot prove protection. |
| Player finishing | Normal player attacks can kill eligible downed NPCs without compulsory menu execution. No second defeat, stale protection, or lingering original-hit damage causes unintended death. |
| Essentials | Essential actors remain protected from finishing, optional Execute, and wound death. |
| Follower targeting | With several enemies, followers abandon yielded targets and engage active threats. Damage immunity alone is not proof of correct target selection. |
| Native dialogue | Normal Talk/Activate opens applicable choices on downed actors. Ordinary dialogue still works. Enemies get Rescue and Get out of here.; civilians get Rescue without dismissal. Preserve pre-defeat category despite pacification. |
| Standing peaceful dialogue prerequisite | Test disposable enemy and civilian with interaction perk active before pacification. Verify actual crosshair/Interact input, visible eligible choices after greeting/voice readiness, native selected INFO and speaker, preserved controller ownership, and deferred expiry. Generic greetings and menu-open flags alone cannot pass. Record candidate hashes separately from manual installation. |
| Rescue potion | Most effective eligible potion is selected and consumed once; actual healing is reflected in injury tracking. Check missing-potion behavior without unintended fallback healing. |
| Rescue state | Downed state/protection ends; actor is alive, standing, nonhostile, talkable, and moves locally clear of fighting. Enemy and civilian behavior match. |
| Rescue after combat | Actor wanders nearby peacefully instead of attacking civilians or immediately restoring hostile AI. Combat end does not cancel Rescue. |
| Rescue locomotion | Native healing ends bleedout. At full health, rescued actor selects wounded walk/run/sprint during AvoidingCombat and Wandering. Require selected OAR clip, actual movement and matching live FSM phase. On expiry, rescue marker clears and original movement returns; another healthy actor using generic pacification retains original movement. Use independent desktop animation copies. |
| Rescue expiry | Peaceful Wander Duration starts after combat, pauses during new combat/unload, and resumes remaining time. Overrides clear at expiry and normal AI can resume; no permanent faction changes. |
| Shared FSM | Pure decision tests cover named guards, lifecycle priority, phase changes, refresh without stacking, pause/resume, and deferred dialogue expiry. Adapter tests prove actual effects and owned cleanup; future states get transition tests with their features. |
| Get out of here. | Eligible enemies leave the encounter; civilian option is hidden. Expiry restores normal AI. Final distance, duration, and healing rules require decisions before exact assertions. |
| On your knees. | Enter owned Kneeling from Yielding, AvoidingCombat or Wandering without healing. Actor remains alive, pacified, unbound and talkable. Commanded Hold Duration is 1800 real seconds, independent of combat and wandering budget. Resume/expiry returns to avoidance or wandering; release restores normal AI. Host checks simulate expiry; desktop checks prove all three entry paths, pose occupancy, dialogue, unchanged health and cleanup. |
| Defeated native interaction regression | `peaceful-kneeling` and `peaceful-bind` start with a real player lethal hit, acquire the downed actor in the crosshair, press E, select On your knees. through native dialogue and assert the selected INFO plus held furniture pose. Native Rescue selection consumes exactly one potion and enters peaceful wandering. Original aggression stays unchanged through entry, dialogue and release. Scoped desktop player activation enters native Talk; unmanaged activation stays vanilla. Custom Hunter Pride menu is retired; see `docs/native-dialogue.md` for evidence and compatibility. |
| Bind | Offered only while owned Kneeling. Real dialogue selection enters KneelingBound using an owned furniture marker and native bound-kneeling animation; require OAR clip evidence. Health unchanged, pacification and Talk retained. Restart Commanded Hold Duration at 1800 real seconds; preserve wandering budget. Verify held pose, hidden repeated Bind, release cleanup and host expiry simulation. |
| You're my prisoner now. | Future standing target enters standing-bound pose. Kneeling binding uses Bind above. Binding is finite and releases correctly once standing-state rules are agreed. |
| Yield deadlines | Default min/max are 15/90 seconds. One duration is chosen per defeat within limits; different actors resolve independently. Deadline persists through save/load. |
| Wound resolution | Meaningful injury plus healing drives the separate survival curve. Resolution is not based on forced defeated health. Stored/random outcome is not repeatedly rerolled by frames or loading. |
| Recovery decision | Survivors flee or return to combat according to meaningful health and Confidence. Critical 1% injury overrides bravery unless sufficient healing occurs. Later hits may yield a recovered fighter again. |
| Early intervention | Rescue or another agreed manual action before resolution does not race into duplicate death/recovery. Treatment and manual-action precedence must be settled for exact outcome assertions. |
| MCM persistence | Threshold, duration limits, attacker toggles, Rescue duration, and any retained knockout settings survive save/load and affect behavior, not just displayed controls. |
| Competing recovery | Check healing recovery, follower combat-end recovery, cell unload/reload, and consequence paths against the agreed yield deadlines and manual outcomes. |
| Cleanup | Death, recovery, effect expiry, and repeated defeats leave no stale immunity, AI override, timer, label, or restraint. Other instances of the same NPC base are unaffected. |

## Features marked for feasibility review

These remain in coverage, matching the asterisks in `yield.md`. Report unresolved
or excluded cases explicitly; do not count them as passed core tests.

| Feature | Test requirement |
| --- | --- |
| Knockout | Dialogue option before optional Execute forces a living unconscious state. Automatic knockout and the qualifying player-finishing toggle use the agreed rules. Do not substitute an ordinary stagger or dead body. |
| Knockout wounds | Same injury/healing survival ramp as yielding; no second independent mortality curve or repeated uncontrolled rolls across the transition. |
| Knockout identification | Native targeting distinguishes unconscious from dead; indicator clears on wake/death and preserves original names and other actor instances. |
| Knockout sounds | If feasible, existing pain/groan sounds signal a living unconscious actor; stop on wake/death and avoid overlapping sound spam. |
| Plunder | Looting works. If the native assault alarm is retained, observe witness/crime and pacified-target reactions. No assumed custom alarm behavior. |
| Execute | If retained, eligible actors die correctly without animation/state failures; essentials remain protected. Normal player finishing must work independently. |
| Drain | Check eligible vampire feeding and rejection for ineligible player/targets. |

## Repeatability and speed

- Prefer one NPC and a small scenario for fault isolation; then run the dungeon
  case with ten enemies and followers. Outcomes must resolve independently while
  the player can intervene, without requiring ten manual surrender commands.
- Provide a quick regression selection and a broader behavior/compatibility run.
  Measure elapsed time before choosing a runtime budget.
- Use short, explicitly logged timer settings for fast state tests; also run real
  default 15-90 second yield timing and configured effect durations. Accelerated
  checks alone cannot prove production timing.
- Do not globally fast-forward the game to fake timer coverage: it can change AI,
  spell, combat, and clock behavior together. Clarify which clock each timer uses.
- Control randomness only in test mode where feasible. Record seed or supplied
  draws; scripted AI/hit timing may still vary even with the same random inputs.
- Use repeat samples only when checking live random behavior. Agree sample size
  and tolerance first; do not demand an exact 50/50 split in a handful of trials.
- Abort hung scenarios with a bounded timeout, retain failure evidence, and clean
  up only actors created by the runner. Restore changed settings and avoid saving
  temporary test overrides into the main playthrough.

## Results and evidence

Each scenario reports **PASS**, **FAIL**, **SKIP**, or **UNDECIDED**, with a reason.
Manual checks remain **PENDING** until observed. A suite with skipped required
checks is not a complete pass.

Record scenario ID, environment/settings, actor roles and instance IDs, attack
source/type, health before/predicted after the hit, stored injury, healing,
probability and random input when available, chosen deadlines, observed state
transitions, expected result, actual result, and elapsed time. Save logs for
failures; screenshots/video support visual and movement checks where useful.

Use observable evidence alongside internal state: actor alive/dead, delivered hit,
actual healing, inventory/potion change, combat target, movement, and UI behavior.
A flag called "rescued" alone does not prove the actor avoided combat or wandered.

## Decisions required before exact assertions

Follow the open decisions in `yield.md`; tests must not invent gameplay rules:

- Mortality anchors/boundary (earlier 25% versus later approximate 20%), curve
  above the boundary, treatment override, and knockout resolution timing.
- Health/Confidence cutoffs, civilian automatic outcomes, and ambiguous actor
  classification. Civilian quest safety must not be bypassed by automatic fleeing.
- Threshold/min/max validation, clock semantics, and competing recovery policy.
- Rescue/dismissal movement distances and tolerances, effect durations, and
  preservation of quest/escort AI packages.
- Standing binding duration and overlap, knockout attack
  eligibility/default/duration, optional Execute, and Plunder alarm retention.
- Feasible test controls and observations for real attacks, RNG, engine state,
  native dialogue, animation, and reset without bypassing the system under test.

## Acceptance

The desired result is a repeatable desktop run covering the agreed core scenarios,
with failures that identify the case and evidence rather than require guessing.
The automated suite must run unattended from the host, including game startup,
fixture-save loading, player attack delivery, result collection and teardown.
The agent must be able to inspect results, fix a scoped defect and rerun without
requiring the user to operate Skyrim. Manual input cannot satisfy this gate.
AI movement and native interactions also need manual acceptance. Repeat relevant
integration scenarios in the actual VR profile, including PLANCK physical hits,
follower behavior, native Talk/Activate, poses, sounds, and state persistence.

The first real player melee defeat and teammate/guard attack cessation cases
are built and locally verified. They form the routine regression suite. Broader
NPC behavior and VR acceptance remain unverified; Hello World is retired.
Implementation work stays tracked in Beads, not in this plan.

## Papyrus references supplied by the user

Injured locomotion: use `tests/Invoke-InjuredAnimationTests.ps1` for a standalone
desktop integration case. One active peaceful enemy at a time; direct scripted
health setup at 100% and 10% before movement, OAR selected walk/run paths plus
real displacement. Reuse
VR injury assets and their OAR/Animation Queue Fix dependencies. Installed injury
threshold is strictly below 30%; no manual attacks required. Keep animation
selection proof separate from visual/speed acceptance and the complete Rescue
flow. See [harness notes](tests/README.md#injured-enemy-locomotion).

- [Papyrus concepts/tutorials](https://ck.uesp.net/wiki/Category:Papyrus)
- [Papyrus function list](https://ck.uesp.net/wiki/List_of_Papyrus_Functions)
- [Events](https://ck.uesp.net/wiki/Category:Events)
- [Default scripts](https://ck.uesp.net/wiki/Default_Scripts_List)
- [Arcane University scripting best practices](https://wiki.beyondskyrim.org/wiki/Arcane_University:Scripting_Best_Practices)

Use existing default scripts and APIs before adding new ones. Favor engine events
over frequent Papyrus polling; asynchronous waits need bounded cancellation and
cleanup. Check traces when diagnosing scripts. Keep live integration and visible
acceptance separate. The four Creation Kit pages returned HTTP 403 during this
review; they remain references, not freshly verified API signatures. Confirm
signatures against installed `.psc` sources and DevBench's live VM descriptions.

## God preset regression

Focused command: `pwsh -NoProfile -File tests/Invoke-PacificationTests.ps1 -Test god-preset -KeepInstalled`.
Fresh, unsaved desktop world: press actual G; verify level, every skill, four stats,
representative perk/spell/power/ability/shout and all three Unrelenting Force words.
Reject NPC/quest/transformation abilities. Repeat G: no duplicate unlocks; preserve a
higher carry capacity. Unbind and remap through native MCM settings; verify old key
stops and new key works. Restore binding, close game, restore display settings.
No screenshots or VR deployment. Standard recovery cases remain independently selectable.

Desktop qualification: `0130a3e0-2162-46f0-87d8-9d9872418172` passed. Native
evidence: 395 perks, 163 spells/powers/abilities and 27 shouts added; repeat and
remapped presses add zero duplicates. The fresh `coc` fixture resets/starts only
its unsaved Acheron quest before calling MCM methods; without initialization
DevBench could not resolve the attached script's member functions. No reset is
part of the gameplay hotkey. Actual MCM UI clicks and save/reload remain unchecked.


## Shared enemy fixture

All current enemy tests and manual scenarios use female Forsworn `00043BE1`, one
iron sword `00012EB7`, no shield or spare weapons, and retained armor. The shared
base/equipment setup lives in `tests/Npc-Papyrus.ps1`. Guards, followers, civilian
controls and the persistent reset actor keep their roles. Health and timer overrides
remain local to each scenario. Earlier run evidence above used bandits/wolves;
it does not qualify the changed suite. Host checks pass; runtime requalification
remains pending. The 2s/3s recovery cases remain unrun.

All cases/manual scenarios also share a female Argonian player with one iron sword
(`00012EB7`), one iron shield (`00012EB6`), and no other armor/clothing or spare
weapons. Bootstrap verifies equipment; gold, potions and other non-equipment items
remain available. Melee fixtures keep the sword and use `AttackDamageMult` only
where a high-damage finishing hit is needed. Host equipment checks pass; sword
combat and the updated player setup await in-game qualification.
