# Reusable Desktop Pacification Plan

**Status:** approved on 2026-10-11; FSM, Skyrim adapter, native healing entry, MCM and cosave implemented. Native movement/Talk prerequisite passed. Desktop qualification evidence below; reset/delete remain separate qualification gaps.

**Execution:** single-agent implementation after confirmation. Use Beads for tracking; no Markdown task checkboxes, automatic commits, or subagents.

**Goal:** give healed opponents a reusable temporary peaceful state: avoid active fighting nearby, then wander locally and remain available for interaction until a configurable timer expires.

**Architecture:** one `Acheron::Pacification` module owns phases, temporary movement overrides, timer, and cleanup. Reuse Acheron's existing combat suppression and PapyrusUtil package overrides. Healing calls this module; dialogue and later actions can call the same interface without copying AI/timer logic.

**Tech stack:** existing SKSE C++, Papyrus/PapyrusUtil, Spriggit package records, MCM, DevBench desktop harness. No new dependencies.

**Requirements:** [yield.md](../../../yield.md), Rescue section, plus the user's approved post-combat timer and extensible FSM requirements.

## FSM structure and extension rules

Use a small explicit FSM, with engine-independent decisions and a Skyrim adapter for effects. One per-reference record owns the current phase, remaining time, anchor, and owned overrides. The manager serializes all changes on the main thread; callers send intent rather than directly changing packages or flags.

Implement only `AvoidingCombat` and `Wandering` now. Normal AI means no managed record, not an idle controller ticking forever. Existing Acheron defeat remains its own authority; this module observes it and relinquishes ownership. Future prisoner, following, and unconscious behavior must be added with their feature, not as placeholder branches now.

| Current phase | Event and guard | Result |
| --- | --- | --- |
| Unmanaged | Begin accepted; eligible actor, valid duration, no foreign pacification | Acquire ownership; choose avoidance if nearby combat exists, otherwise wandering. |
| Either managed phase | Real nearby combat active | AvoidingCombat; preserve remaining wandering time. |
| AvoidingCombat | Nearby combat ended | Wandering; resume remaining time. |
| Wandering | Valid loaded, unpaused gameplay delta | Decrease remaining time; release when exhausted and not in player dialogue. |
| Either managed phase | Reapply accepted | Refresh duration in the existing record; no second owner, package, or anchor set. |
| Either managed phase | Death, reset, deletion, re-defeat, or explicit release | Exit once; remove only owned effects. Re-defeat preserves Acheron's new state. |
| Persisted phase | Load resolves a valid actor | Restore remaining time and ownership; reevaluate nearby combat before selecting a package. |

Keep these boundaries explicit:

- **Facts:** one validated actor/encounter snapshot supplies health, eligibility, combat, dialogue, and elapsed time. Reads do not mutate state.
- **Guards:** small named predicates own individual conditions. Adding a health/confidence rule extends the relevant guard; do not scatter the same rule across damage hooks, dialogue scripts, and updates.
- **Decision:** a pure function produces the next phase and remaining time from the current record and event/facts. Same input, same decision. Any future random outcome receives an explicit sampled value and is persisted once.
- **Transition:** one path applies exit cleanup and entry effects, then publishes the new phase. Failed package/marker setup must unwind acquired effects; never report a successful phase with missing effects. Refresh and same-phase updates do not repeat entry work.
- **Effects:** Skyrim calls, package overrides, linked markers, and combat suppression stay in the adapter. Cleanup is idempotent and removes only resources acquired by this record. One timer owner; unloading cannot expire it through wall-clock time.

Priority is lifecycle invalidation first, then combat transition, then wandering expiry. Death/re-defeat cannot be overwritten by a late heal, timer, or queued update. Queued work resolves an actor handle and checks the current record generation before applying; refresh/exit invalidates obsolete work.

Avoid combinatorial states such as `WoundedFollowingPrisoner`. Injury is data and guards; posture and behavior need separate dimensions only when an implemented feature actually requires them. No generic FSM library, event bus, dynamic guard registry, inheritance hierarchy, configurable rule language, or unused future states.

Each new phase must define allowed entry events, named guards, exit/entry effects, timer ownership, save/load behavior, and transition tests. Stable persisted phase values and a versioned payload prevent enum reordering from changing saved meaning. Unit tests cover decision/priority/refresh/pause rules without Skyrim; runtime tests prove the adapter's actual movement, Talk, and cleanup.

## Behavior and proposed decisions

| Situation | Behavior |
| --- | --- |
| Eligible bleeding opponent receives real healing | End bleedout and downed damage immunity; immediately enter peaceful state. |
| Fighting continues nearby | Do not attack player, civilians, or other actors. Move clear locally without leaving the encounter. |
| Nearby fighting ends | Enter local wandering; start the configured duration. Remain peaceful and talkable. |
| Fighting resumes | Return to local avoidance; pause remaining wandering time. Resume remaining time after fighting ends; do not reset to a full duration. |
| Wandering time expires | Remove this module's overrides; restore ordinary AI. Original enemies may become hostile again. Defer final release while the NPC is in player dialogue. |
| Same state applied again | Refresh duration on the same actor; one state and one owned package set, no stacked timers. |
| NPC dies, resets, is deleted, or becomes defeated again | Remove this module's state/packages. A new defeat retains its own pacification and immunity. |

Proposed MCM **Peaceful Wander Duration** (`iPeacefulWanderDuration`): **60 seconds**, range **1–600**, step **1**. Replaces the planned Rescue Effect Duration label for this shared behavior; separate from `iNPCRescueTimer` and future yield min/max settings. Zero is rejected, preventing an accidental indefinite state.

Timer counts loaded, unpaused gameplay seconds only while wandering. Combat avoidance and unloading pause it. Save/load preserves phase and remaining time. Loading never restarts a full timer. Nearby combat is recomputed after load.

Proposed spatial limits: encounter combat within **1,500 game units** of the NPC's entry position, local avoidance/wandering within **800 units** of that same anchor. Other fights elsewhere must not hold this NPC in avoidance. Radii stay implementation constants, not extra MCM sliders. The NPC is not made a follower and does not follow the player across the map.

First callers are real healing rescues of non-player, non-follower humanoid opponents and civilians. Ordinary timer recovery, follower combat-end recovery, commanded actors, and player defeat keep their current behavior. The shared module can later serve other explicitly approved actions.

Nonhostility is temporary behavior, not a permanent faction/relationship rewrite. Native faction-hostility queries may still report original enmity; the acceptance requirement is no initiated or resumed combat while the state is active, plus successful normal interaction.

## Current source findings

- `Defeat::RescueActor(actor, true)` ends bleedout, removes the blank package, clears victim immunity, and releases pacification.
- `Defeat::Pacify` stops combat and alarm; `Hooks::UpdateCombat` and `DoDetect` keep pacified actors out of combat detection.
- `IsDamageImmune` checks the Victims map, independently of the Pacified set. Peaceful standing actors need not retain downed immunity.
- Existing interaction perk also filters activation of hostile, standing pacified actors. That filter must exempt this module's actors so normal Talk remains available.
- Hunter Pride Rescue equips a selected potion; if still defeated, its script adds a fixed 25 health and releases pacification. That fallback does not meet actual-potion healing requirements.
- Existing pacification does not establish local avoidance or wandering. Its detection suppression means a pacified actor's own `IsInCombat` cannot indicate whether the encounter is still active.

## File boundaries and interfaces

| Files | Responsibility |
| --- | --- |
| New `src/Acheron/Pacification.h` and `.cpp`, small engine-independent state header | Per-reference phases, elapsed time, movement packages, ownership, lifecycle, serialization payload. Pure decision rules remain usable in host tests without SKSE. |
| `src/Acheron/Hooks/Hooks.cpp` | Update shared state on character updates; integrate successful healing recovery. Existing unrelated damage/defeat policies remain intact. |
| `src/Acheron/EventSink.cpp` | Clear managed state on death/reset/delete; observe local combat transitions. |
| `src/Serialization/Serialize.h` and `.cpp` | New, separately versioned cosave record; preserve existing defeated/pacified records. |
| `src/Serialization/mcm.def`, `dist/Source/Scripts/AcheronMCM.psc`, `dist/Interface/Translations/Acheron_ENGLISH.txt` | One duration setting, validation, slider, explanatory text. New keys in other existing `Acheron_*.txt` files get the same English fallback until translated. |
| `src/GameForms.h`, `res/Keywords/`, `res/Packages/` | Owned per-reference linked-marker keys and selected local movement package records. Never add managed-state keywords to a shared NPC base. |
| `res/Perks/AcheronInteraction - 000803_Acheron.esm.yaml` | Allow normal activation of managed standing actors; preserve defeated-target menu pending native-dialogue work. |
| `src/Papyrus/Functions.h`, `.cpp`, `dist/Source/Scripts/Acheron.psc` | Reusable Papyrus entry and state query for other approved actions and tests. |
| `dist/Source/Scripts/AcheronHunterPride.psc` | Reuse healing integration; remove arbitrary extra 25 health after native potion recovery is qualified. |
| `tests/Run-YieldTests.ps1`, new `tests/Pacification-State.ps1`, `tests/Pacification-State-Evidence.ps1`, `tests/Test-PacificationStateEvidence.ps1` | Desktop lifecycle, movement, healing, and short duration cases. |

Proposed public contract, main-thread execution:

- `bool Pacification::Begin(RE::Actor* actor, int durationSeconds)` — validate eligible, living, standing actor and finite duration; acquire this module's pacification or refresh its existing state. Refuse to take ownership of unrelated preexisting pacification.
- `void Pacification::End(RE::FormID actorId)` — release only this module's state and overrides; preserve a newer defeat or external state. Form ID permits cleanup after the actor reference is deleted.
- `bool Pacification::IsActive(const RE::Actor* actor)` — query module membership, not generic Acheron pacification.
- `void Pacification::Update(RE::Actor* actor, float deltaSeconds)` — advance phase/time; no per-frame full-world scans. Character updates can run on workers: accumulate elapsed time and batch queued main-thread work; never mutate packages or actor state there. Refresh a bounded local encounter check on combat events and at most once per second.
- Papyrus: `bool Function BeginPeacefulState(Actor akActor, int aiDurationSeconds) native global` and `bool Function IsPeacefulState(Actor akActor) native global`.

Papyrus entry queues the operation on the main thread; its boolean confirms request acceptance, not completed state. Callers/tests confirm native entry evidence and state query. Cosave load reconciles this module's persisted ownership with the existing Pacified set after all records load; it must not mistake its own restored state for external pacification. Reject unresolved actor IDs and remove stale owned markers safely.

Healing recovery releases defeat and starts the shared state in the same main-thread operation, before normal AI resumes. Preserve the existing `RescueActor` API's meaning for unrelated callers. The module does not consume potions, calculate healing, or perform dialogue selection.

## Implementation sequence after confirmation

### 1. Qualify native movement and interaction

Inspect actual desktop escort/noncombatant package records and native flee/sandbox procedures. Reuse a suitable package; otherwise derive minimal temporary packages from the game's templates. Do not substitute a generic Fear spell that sends targets far away.

Probe a standing pacified disposable NPC in a navmeshed fixture. Require real local displacement during nearby combat, local wandering afterward, and normal activation. Supply threat references from the local encounter rather than relying on the pacified actor's disabled combat detection. Respect active quest scenes; do not overwrite shared NPC bases or other packages.

Record chosen package/template IDs and flags before implementing them. If native avoidance cannot stay within the proposed radius or preserve interaction, report that result and revise this part of the plan before writing a custom movement controller.

### 2. Build shared state and cleanup

Implement the contract above, keyword/package ownership, combat-aware phases, fixed entry anchor, duration validation, and cosave lifecycle. Keep package operations on the main thread. If the chosen template needs a per-actor marker, create and persist one owned marker; remove it with state cleanup. Never reuse another actor's anchor.

Native diagnostics under the existing test flag record actor, entry source, phase, package, position, combat participants, remaining time, and monotonic timestamp. Phase transitions must be observable independently of test requests. A diagnostic flag is evidence, not proof of movement.

### 3. Connect healing and MCM

Eligible positive healing of a defeated NPC triggers normal recovery and then the module. Both real healing spells and Hunter Pride potion use reach this same behavior; ordinary automatic recovery does not. Ignore ineffective or non-health effects. Do not erase unrelated active effects or alter actor factions/relationships.

Keep potion choice/consumption in the existing handler; actual healing remains native. No extra 25 health. Missing potion or ineffective healing must not falsely report a successful rescue. Add the duration slider and clamp/reject invalid persisted/API values consistently.

### 4. Qualify desktop regressions

| Case | Required evidence |
| --- | --- |
| Real healing entry | Player defeats target, then applies real healing. Health increases by expected native effect, defeat/immunity ends, shared state begins before renewed combat. Potion variant consumes exactly one correct potion. |
| Local avoidance | Two other actors keep nearby combat active. Managed NPC remains alive and peaceful, moves locally clear, stays within anchor radius; wandering countdown does not run. |
| Post-combat wandering | Encounter ends; module enters wandering, changes to the qualified package, and remaining time starts decreasing. Positions show local movement; normal Talk/Activate opens dialogue without releasing the state. |
| Short expiry | Separate **2s and 3s** wandering durations. Native transitions show automatic expiry within provisional 500ms tolerance; cleanup restores normal AI. No test-invoked End/Release may satisfy expiry. |
| Combat restart | Resume combat during wandering; remaining duration pauses, then resumes without a full reset. Distant unrelated combat has no effect. |
| Lifecycle/ownership | Reapplication does not stack state; save/load preserves remaining time; death/reset/delete clean packages and anchors. Re-defeat retains new defeat protection. Existing external pacification is not released. |
| Actor isolation | Two instances of one NPC base keep separate anchors/timers. Player, follower, and commanded-actor exclusions remain intact. |

Host/parser tests reject early/late expiry, missing events, wrong actor/source, fake movement, incomplete restoration, and stale state. Use logs, hooks, package/position reads; screenshots only if no code evidence can establish the visual requirement. Initial probe must prove fixture navmesh suitability.

Reuse the existing launch/ownership/cleanup harness. Back up and restore changed settings; disposable unsaved actors only. Existing 2s/3s **bleedout recovery** cases are separate and remain unrun per the earlier instruction. Do not automatically run them while developing this feature.

### 5. Desktop handoff

Build DLL, Papyrus scripts, and ESM; install only to the desktop test setup after approval, with backup/hash manifest. Qualify affected cases before adding them to the default suite. Native downed-target dialogue/Rescue selection follows this module; existing ordinary Talk on standing managed targets must already work.

Update `yield.md`, test documentation, and Beads with accepted timer semantics and measured results. No VR deployment or headset claims.

## Review focus and limits

- Native Sandbox template `01C254:Skyrim.esm` qualified local avoidance and wandering; this is a derived temporary package, not a discovered escort-status switch. Packages `813/814` use per-reference goal/anchor links `812/811`, with radii 80/800. Nearby combat scan radius is 1500.
- Current Acheron detection suppression can conceal combat from the actor; nearby fight detection belongs to the module, not the actor's combat flag.
- Ending this state must not clear a new defeat or another owner's pacification.
- Talkability must be tested through activation; a keyword or CanTalk flag alone is insufficient.
- Package removal and native faction-hostility readbacks do not themselves prove correct visible movement or absence of attacks.

Approved decisions: **timer starts after combat**, **pause/resume on new combat**, **60s default**, and the proposed local radii. Native qualification must pass before controller implementation; custom movement would require revising that boundary.

## Implementation and qualification evidence

The pure FSM is `src/Acheron/PacificationState.h`; the main-thread Skyrim adapter is `src/Acheron/Pacification.cpp`. `BeginPeacefulState` queues accepted requests, `IsPeacefulState` queries ownership, and `ReleaseActor` releases owned effects. World epochs discard queued work from an earlier save. No unused prisoner/following/unconscious states or generic FSM dependency were added.

Native healing is observed after actual positive Health gain in active-effect Start/Update. Actor recovery and shared-state entry occur together on the main thread. Hunter Pride uses the native potion amount without its old fixed-25 fallback for eligible desktop actors. Player, follower, commanded actor and active-scene exclusions preserve their existing flows.

Engine qualification found two concrete issues: negative `RestoreActorValue` did not clamp defeated health, so the clamp now uses `DamageActorValue`; CommonLib `TESQuest::IsRunning()` also accepted a never-started dialogue quest, so the controller checks `IsStopped()` and dispatches native Papyrus `Quest.Start`.

| Check | Evidence |
| --- | --- |
| Native movement/Talk prerequisite | `6a09d6f7-04dd-47ed-9508-b7f0ca2c12b0` passed before adapter implementation. |
| Pure FSM and evidence parsers | Host checks pass transitions, lifecycle priority, refresh, pause/resume, validation, movement and expiry negative cases. |
| Controller movement/interaction | `daccc7e8-9d0b-401a-a6d4-045ce83d6f02` passed actual local avoidance/wandering, combat restart pause/resume, menu opening with interaction perk, and deferred dialogue expiry. That interaction check did not prove visible choices or selection. |
| Standing native choices | Final-build `6fc330cc-eddd-4a82-af53-62af79eda978` and preceding `50058c06-f33d-44d2-b190-be988842dd2e` passed bandit/civilian clones with perk already active: verified crosshair, real `E`, visible `Continue.`, native INFO selection, unchanged peaceful ownership and deferred expiry. Scripted activation and `Enter` did not qualify these checks; rejected perk experiments were reverted. See tests/README.md for the explicit case. |
| Lifecycle | `c08c5455-d2a7-46cd-9593-9b84f5304212` passed MCM clamp, eligibility, foreign-pacification refusal, refresh, independent actors, re-defeat and death cleanup. |
| Native healing | `034ef89f-7e94-4c42-a5de-9be234f379a0` passed real potion, healing spell and Hunter Pride potion. Civilian variant added; latest qualification recorded in test-plan.md. |
| Save/load | `266f1c6c-9d74-432b-aa9d-a3546ad47b5d` passed menu/unload pauses and real cosave restoration. Final cleanup/hash assertions added; latest evidence recorded in test-plan.md. |
| Short peaceful expiry | `fb5e41a3-6473-48fc-8eaa-33aa62c2afac` measured 1985ms/2992ms for 2s/3s. These are not bleedout recovery tests. |

`peaceful-reset` remains an explicit probe outside the default pacification suite. Created actors and original non-respawning Nazeem did not release the controller after `ObjectReference.Reset(None)`; a persistent respawning guard fixture is being qualified. Two earlier Whiterun transitions exited the process before state entry. Preserve failures; do not claim reset or actual form-deletion acceptance. Beads `skyrim-asp` tracks this gap.

Native downed-target dialogue choices remain the next separate feature; the current standing dialogue exposes only `Continue.` to qualify interaction. MCM visual acceptance, other navmesh layouts, VR/NFF/PLANCK and existing bleedout 2s/3s tests remain unchecked. Navmesh sampling chooses local triangle points; native AI owns pathfinding, and disconnected islands have not been qualified.

## References

- [Acheron source](https://github.com/KrisV-777/Acheron) and [Nexus baseline](https://www.nexusmods.com/skyrimspecialedition/mods/108159).
- [GetCurrentAIPackage](https://ck.uesp.net/wiki/GetCurrentAIPackage) documents native flee/sandbox package categories; it does not prove this encounter behavior.
- [EvaluatePackage](https://ck.uesp.net/wiki/EvaluatePackage) explains package reevaluation limits; reevaluation alone does not change combat or pathing.
- [Magic Effect](https://ck.uesp.net/wiki/Magic_Effect) describes Demoralize; generic fear remains unsuitable unless local behavior is proven.
