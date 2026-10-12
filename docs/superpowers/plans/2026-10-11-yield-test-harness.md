# Yield Test Harness Implementation Plan

> Execution guidance: use `superpowers:executing-plans` for sequential implementation. No delegation or commits without explicit user authorization. Beads tracks execution; the steps below specify deliverables.

**Goal:** Run NPC tests unattended from the host, collect evidence, report results, and clean up; retain a console entry point for interactive diagnosis.

**Architecture:** Qualify DevBench first and reuse its MCP/REST, live Papyrus calls, input and scenario controls. A separate test-only quest remains a candidate where fixtures or asynchronous assertions need it. A small optional bridge in Acheron's DLL records real damage-hook observations and writes results using the existing logger; production packages exclude test assets and diagnostics.

A PowerShell host driver owns launch, fixture-save bootstrap, machine-readable result collection, and shutdown. Fully unattended player attacks are required for final automated acceptance; manual prompts are interim coverage only.

**Tech Stack:** Skyrim SE, runtime-matched SKSE, DevBench, Papyrus, existing C++23/CommonLibSSE-NG plugin, xmake >= 3.1.1, existing Spriggit YAML pipeline. houseCARL is selected for authoring support when an isolated MO2 profile is available.

**Spec:** [test-plan.md](../../../test-plan.md), [yield.md](../../../yield.md), [test-room.md](../../../test-room.md).

## Selected transport update: qualify DevBench before custom controls

User selected DevBench for testing and houseCARL for authoring on 2026-10-11.
See [selected tools and setup status](../../../test-plan.md#selected-tools-devbench-first-housecarl-for-authoring).
This selection supersedes the earlier assumption that a new native bootstrap and
quest dispatcher must provide all game control. Tasks below retain coverage and
acceptance requirements; their custom control mechanisms are conditional on gaps
proven after the DevBench smoke test.

First verify desktop dependencies and DevBench's runtime/PID identity. Then prove
baseline save loading, owned NPC spawning, player-source physical damage,
Acheron state reads and cleanup through existing tools. Reuse REST for the host
driver and Papyrus calls/scenarios where sufficient; retain native observations
for actual incoming damage and production decisions. Do not implement
`Probe::Bootstrap()` or duplicate input/save-loading controls unless the existing
transport cannot meet an identified requirement. Fixture ownership, result
validation, timeouts and safe shutdown remain the harness's responsibility.

Official DevBench v1.27.0 and desktop Address Library v13 are installed; archive
integrity and all 30 installed file hashes were verified. The user-approved
[initial Hello world host smoke](../../../tests/README.md) qualified startup by launching SKSE at 800x600,
entering fresh UnownedCell, observing a Papyrus message through native UI data,
then exiting and restoring preferences. Hello World is now removed. Three consecutive live runs passed on 2026-10-11.
The repeat also preserved save hashes and left no Skyrim/loader process.
The first unattended NPC case now verifies owned spawning, a genuine player melee
hit, native defeat registration, living defeated/pacified state and cleanup.
Teammate and natural guard discovery confirmed attacks stopped after
defeat/pacification. Both are now routine regressions, requiring attack cessation
to pass; continued attacks or lingering combat fail. The default host command
runs eight combat-policy cases plus 2s/3s automatic recovery regressions listed
in the test README. Recovery cases are added but intentionally not run. Retain Acheron's protection; new NPC/follower blocking
controls are outside scope. Routine screenshots are unnecessary when native
state reads and hooks prove the case.
See [actual commands, evidence and limits](../../../tests/README.md). Broader AI,
magic variants, recovery, save loading and VR coverage remain pending. The current minimum
implementation uses DevBench directly and a default-off `yield_test_diagnostics`
logger option; proposed custom quest/bridge/bootstrap pieces below are deferred
until a demonstrated gap requires them.

Earlier three-case verification: `suite-c8713c12-4e00-48ee-b57c-1ea6e9f1b19d`
passed NPC defeat plus both pacification regressions. Cases used logs/hooks,
with no screenshot calls or Hello World case. All owned actors were cleaned,
games closed gracefully and original preferences restored; four saves and both
INIs were unchanged. Negative self-checks and a retained failed suite verify
that missing hits, continued attacks or incomplete child results cannot pass.
See the test README for case IDs and bounded player attack staging.

## Global constraints

Combat policy update: default `bNPCDefeat=false`, retain follower defeat and
Hunter Pride follower participation. Activate Hunter Pride on new game/load
under this policy. Ordinary NPCs may kill standing enemies; already yielded
targets remain protected from non-player sources. The routine suite also
includes follower-caused defeat, normal NPC lethal combat, player melee and
Firebolt finishes, and essential melee/spell protection. Permission uses the
actual source; existing death cleanup clears flags without rescue/re-defeat.
See the test README for current case selectors and subsequent runtime evidence.

Desktop qualification: complete eight-case suite
`suite-729bf61b-0044-4e43-8d04-650f5441c44f` passed. Cleanup, graceful exits,
preferences restoration and independent save/INI preservation audit passed.
Normal-load activation, VR integrations and magic variants retain separate
pending acceptance as documented in the test README.

- Desktop first; repeat relevant acceptance in Skyrim VR with Mad God, PLANCK, and NFF.
- Disposable test saves and owned actors only. Preserve the VR installation, unrelated dirty files, and shared mod sources.
- Default yield-entry threshold: 20%; chance 50% at threshold, 100% at zero; formula `100 - 50 * h / T` between them.
- Default yield duration bounds: 15 and 90 seconds; one persistent deadline per defeat.
- Direct player finishing attacks required; retain Acheron's existing non-player protection and essential restrictions. Extra follower/NPC blocking controls and targeting suppression were removed from scope on 2026-10-11 after teammate/guard discovery.
- AI, combat AI, and detection stay enabled in behavior tests. No global time acceleration.
- Gameplay gaps remain explicit: mortality anchors, Confidence cutoffs, treatment overrides, action durations, actor eligibility, and restraint/knockout rules.
- `PASS`, `FAIL`, `SKIP`, `UNDECIDED`; visual/headset checks remain `PENDING` until observed. Skipped required checks prevent a complete pass.
- No manual game launch, save selection, console input, attack input, or prompt response in the final automated suite.
- Implement the harness here; implement gameplay features through their existing Beads issues. The harness must not supply replacement gameplay rules.

## Evidence from this checkout

| Existing interface/file | Implication |
| --- | --- |
| `dist/Source/Scripts/Acheron.psc` | `DefeatActor`, `RescueActor`, `IsDefeated`, `IsPacified`, defeated/rescued events, `PrintConsole` already exist. |
| `src/Papyrus/Functions.cpp` | Defeat/rescue calls queue native tasks. Observe completion; do not assert immediately after calling. |
| `dist/Source/Scripts/AcheronMCM.psc`, `src/Papyrus/Config.cpp` | Typed configuration access exists on the MCM quest script; reuse it and restore every setting changed. |
| `src/Acheron/Hooks/Hooks.cpp` | Physical path: `ProcessHitData`; magic paths: `MagicHit`, `DoesMagicHitApply`. Current protection blocks downed damage. |
| `src/Acheron/Defeat.h` | Current victim data lacks meaningful injury and randomized deadlines. Future assertions depend on gameplay work adding them. |
| `src/Acheron/Defeat.cpp` | Defeat overrides AI through `ActorUtil`; PapyrusUtil is required. `GetSecondsDefeated` measures game-calendar seconds, not elapsed wall time. |
| `src/main.cpp` | Existing Papyrus registration and logger; release logger writes a file, debug logger uses the debugger sink. Use release mode with test diagnostics enabled for initial evidence. |
| `xmake.lua`, `xmake/spriggit/xmake.lua` | Existing script compilation and YAML plugin generation; preserve binary-edit guard stamps. |
| `dist/SKSE/CustomConsole/*.yml` | Custom commands exist upstream, but the harness does not require that additional command provider. |

Installed script sources inspected under `C:\bin\wabbajack\SkyrimVRMods\mods\SKSE Scripts\Scripts\Source` declare `PlaceAtMe`, `StartCombat`, `Spell.Cast`, actor-value reads, `Disable`, `Delete`, and `Utility.GetCurrentRealTime`. Their declarations establish candidate APIs, not successful runtime behavior.

Desktop runtime inspected: `1.6.1170.0`, at `S:\games\The Elder Scrolls V - Skyrim Special Edition`. SKSE 2.2.6 and DevBench 1.27.0 initialize in archived live logs. The NPC-only Acheron fork is now built and installed with PapyrusUtil 4.6 and SkyUI 5.2 SE. Portable xmake 3.1.1, author Caprica 0.3.0a and Spriggit 0.40.0 live under ignored `build/tools/`; MSVC 2026 release build, seven Papyrus script compilations and ESM generation passed. Creation Kit's PapyrusCompiler also exists inside the game directory; author Caprica was used for the fork's scripts. Desktop install manifests preserve hashes and prior plugin lists; VR remains untouched.

## Review focus

1. A paused console must not leave the runner waiting forever: queue work, close console, then start timing.
2. No delivered hit must never count as protection: require hook evidence, target ID, and source ID.
3. Abort, repeat-run, and save/load must not leave spawned actors or modified settings behind.
4. Forced defeated health `0.05` must never masquerade as actual injury severity.
5. UnownedCell may lack suitable navigation/escape space; failed movement must identify arena suitability before being attributed to gameplay AI.

## Planned files and responsibility

All paths below are relative to this repository. New names are design choices, not existing working APIs.

| File | Responsibility |
| --- | --- |
| `tests/README.md` | Exact setup, build, launch, result, recovery, and manual acceptance instructions. |
| `tests/Run-YieldTests.ps1` | Host-owned launch, bootstrap, fresh result collection, exit codes and teardown. |
| `tests/Test-RunYieldTests.ps1` | Assert-based driver protocol, stale-result, timeout and ownership checks without starting Skyrim. |
| `tests/scripts/AcheronYieldTests.psc` | Quest controller, fixture ownership, asynchronous waits, assertions, cleanup. |
| `tests/scripts/AcheronYieldTestProbe.psc` | Declarations for the optional native observation bridge. |
| `tests/res/` | Separate Spriggit source for `AcheronYieldTests.esp`: controller quest, fixture NPCs, test spells and aliases. |
| `tests/console/yield-test.txt`, `yield-test-stop.txt`, `yield-test-01.txt` | Launch quick suite, abort, or run one case. Install beside desktop game executable. |
| `tests/native/Probe.h`, `Probe.cpp` | Fixture-scoped hook counters, last-hit observations, native registration, structured log records. |
| `tests/native/RulesTests.cpp` | Assertions linked to actual production rule functions as those functions become available. |
| `xmake.lua` | Default-off `yield_tests` option; opt-in script/plugin/diagnostic/rule-test targets and separate test output. |
| `src/main.cpp` | Register test natives only in test-enabled builds; invalidate observation sessions on game load/revert. |
| `src/Acheron/Hooks/Hooks.cpp` | Optional observations at actual hook decisions, without changing outcomes. |
| `test-plan.md`, `test-room.md` | Link runnable harness instructions after verified delivery. |

Keep test sources outside `src/**.cpp` and `dist/Source/Scripts/*.psc` production globs. Explicitly include them only when `yield_tests` is enabled. Generate test artifacts under `build/yield-tests/`; do not add them to the normal `xmake pack` package.

## Task 1: Establish a buildable, isolated baseline

**Files:** `tests/README.md`; local ignored build configuration only. Existing references: `README.md`, `xmake.lua`, `.env.example`.

**Produces:** Recorded runtime/dependency/tool versions and a verified baseline Acheron build before harness changes.

1. Verify the C++ workload and compiler, install/locate xmake, Spriggit, Creation Kit compiler and matching desktop Papyrus sources. Use explicit configuration options: `.env.example` uses `XSE_TESV_*` names while xmake defaults reference `XSE_TES5_*`; do not assume the defaults agree.
2. Establish a desktop-only test mod location/load order. Verify runtime-matched SKSE, Address Library, SkyUI and PapyrusUtil requirements from actual binaries/logs and Acheron load calls. Never reuse VR DLLs. The installed runtime is 1.6.1170: select its archived SKSE build, not the current site's latest build for a different runtime.
3. Configure release build, `auto_install` disabled, explicit desktop paths, then run `xmake`. Install only reviewed output into the desktop test setup; keep a manifest/backup for files replaced.
4. Launch through the matched SKSE loader. Require its load log and Acheron's version/load log, with no missing forms/native/package-override dependency errors.
5. In a disposable save, visit `UnownedCell` and check an NPC can navigate and engage another NPC. Record arena acceptance separately from gameplay acceptance. Use a different verified cell if floor/navigation/escape space fails; creating a custom arena is a later conditional task.

**Verification:** `xmake` succeeds; the game loads the newly built DLL; existing NPC defeat/recovery can be exercised. Missing dependencies are infrastructure failures. Do not install the fork into VR during this task.

## Task 2: One-command lifecycle and an API smoke test

**Files:** test quest/assets, controller script, three console files, xmake opt-in targets, `tests/README.md`.

**Controller interface:** `Scriptname AcheronYieldTests extends Quest`; `Function Run(String suite = "quick")`; `Function Stop()`; `Event OnUpdate()`; existing `OnActorDefeated(Actor)` and `OnActorRescued(Actor)` callbacks.

Bind `AcheronMCM Property Config Auto` to the existing `AcheronMain` quest. Use its typed getters/setters for configuration snapshots; keep the fixture list and run state on the test quest. The quest may start with the test plugin but must remain idle until `Run` is called. Its masters are `Skyrim.esm` and `Acheron.esm`; keep the test plugin a normal ESP for the initial desktop/VR path.

1. Create the test-only `AcheronYieldTests` quest with a controller instance. Add a player load-game alias for recovery after loading during a run. Clone suitable nonquest humanoid records into private enemy/civilian/teammate/essential fixtures; never modify a vanilla NPC base. Serialize records into `tests/res/` using the existing Spriggit package/version conventions.
2. Give fixtures fixed level, known health, zero regeneration for damage-measurement cases, no perks or enchanted weapons, and explicit role/Confidence. Disable auto-calculation where necessary and assert the actual spawned values. Do not remove perks or inventory from the user's player; use owned actors and measure actual player damage in later cases.
3. Implement fixture creation via `PlaceAtMe`, store every reference immediately, wait for loaded 3D, and position actors before enabling scenarios. Run from the accepted cell only; do not silently teleport the player or mutate real NPCs.
4. `Run` validates the suite, rejects a concurrent run, snapshots changed settings, registers Acheron events, then schedules `OnUpdate`. Poll at 0.1-second intervals with elapsed-real-time deadlines once the console closes. Track console/pause menu opening and closing through SKSE menu events and exclude paused intervals from scenario timeouts; validate those events in the first smoke run. Use 10-second state/hit deadlines initially; movement cases get 30 seconds. These are harness timeouts, not gameplay timer defaults.
5. First case `api-defeat-rescue`: defeat one fixture through `Acheron.DefeatActor`; require alive + defeated + pacified and one matching event. Rescue with `abRelease=true`; require defeated/pacified cleared and rescue event. Label this API/state coverage, never real-hit integration coverage.
6. `Stop`, timeout, failure, and normal completion unregister events, recover/release owned actors as appropriate, stop their combat, disable/delete them, and restore every setting changed. Cleanup is idempotent. A load during an active run aborts that run and cleans saved owned references; it must not resume stale waits or reroll gameplay outcomes.
7. Add exact batch contents:

   ```text
   ; yield-test.txt
   cqf AcheronYieldTests Run quick
   ```

   ```text
   ; yield-test-stop.txt
   cqf AcheronYieldTests Stop
   ```

   ```text
   ; yield-test-01.txt
   cqf AcheronYieldTests Run api-defeat-rescue
   ```

   Runtime-check `cqf` dispatch and string arguments before declaring the batches usable. User flow: load test save, `bat yield-test`, close console, wait for summary. Batch files belong beside the executable, not inside Data.
8. Print case/status/detail through `Acheron.PrintConsole`. Until Task 3 supplies persistent structured logging, mark the evidence pipeline incomplete. Never report an unknown suite or absent fixture/native as a pass.

**Build contract:** default-off `yield_tests` enables `yield-test-scripts` and `yield-test-plugin`; `yield-test-assets` is an umbrella target depending on these and the ordinary `Acheron`, `papyrus`, and `Acheron.esm` targets. Use the existing Papyrus/Spriggit rules with test-specific source/output roots. Stage test output separately; install scripts/plugin under desktop Data and batches beside the executable.

**Verification:** configure with `--yield_tests=y`, then `xmake build yield-test-assets` succeeds after adding those targets. Run API case twice; verify one actor lifecycle each time, no leftovers, original settings restored. Start while already running, stop twice, and load a test save mid-run; require safe rejection/cleanup. Console left open or reopened mid-case must not cause a false timeout.

## Task 3: Observe real damage and run integration cases

**Files:** `tests/native/Probe.h/.cpp`, probe declarations, controller; gated changes in `src/main.cpp` and `src/Acheron/Hooks/Hooks.cpp`.

**Papyrus bridge, test builds only:**

- `bool Function BeginRun(Actor[] fixtures, String suite) native global`
- `int Function GetHitCount(Actor target, int path) native global`
- `Actor Function GetLastSource(Actor target, int path) native global`
- `float Function GetLastDamage(Actor target, int path) native global`
- `String Function GetLastDecision(Actor target, int path) native global`
- `Function Report(String caseID, String status, String detail) native global`
- `Function EndRun() native global`

Paths: `0` physical, `1` magic-effect application, `2` magic target-admission gate. Counters record hook observations, not unique attack counts. For periodic effects, multiple applications are expected; use case-scoped intervals and identities.

1. Register natives only with `yield_tests` enabled. Validate live owned fixtures from the test plugin; reject arbitrary actor lists, nulls, invalid path/status values, and concurrent sessions. Track actor handles/FormIDs, not retained raw pointers. Protect observation data across hook/VM threads.
2. Record only watched fixture targets during an active run. Ignore the task-queue pre-pass in `ProcessHitData`; observe the execution that actually decides damage. Capture incoming packet damage, computed health damage where available, source/caster, health before, predicted health where computed, decision, and monotonic timestamp. For early immunity/gate rejection, mark uncomputed predicted damage unavailable rather than inventing it. Include enchantment/ongoing-effect attribution where relevant.
3. Preserve original hook control flow. Observation-only calls must neither invoke defeat nor change damage, RNG, settings, or caster attribution. Each observation includes whether damage was allowed, prevented, or an effect rejected/dispelled.
4. Write structured records through the existing release logger, prefixed `[YieldTest]`, with run/case IDs. `Report` logs and prints the summary. Record runtime, fork revision, settings, fixture IDs, event counts and actual health. Archive the log after each session because the existing logger truncates at plugin initialization.
   Summary includes counts for PASS/FAIL/SKIP/UNDECIDED and manual PENDING cases. No skipped required cases may be hidden behind an overall PASS. Keep a real-clock outer watchdog for infrastructure stalls; distinguish deliberate menu pauses from a runner that stopped advancing.
5. Reuse the completed teammate and natural guard-versus-bandit discovery: prove a damaging hit before defeat, then observe native attack activity after pacification. Both desktop fixtures stopped attacking; retain existing Acheron protection without new blocking controls. For later collateral/in-flight immunity checks, require an actual delivered hit; absence of a hit proves attack cessation only when native activity observations support it, not damage immunity.
6. Add a simple test damage spell with no scripts or area, cast with `Spell.Cast(source, target)`. Verify actual caster and magic path before using it for ordinary damage, lethal interception, and downed immunity cases. `RemoteCast`, `DamageAV`, direct hook calls, and animation events alone do not establish normal incoming attack coverage.
7. Prove player-source magic with the player as caster. Separately investigate an actual player melee attack request through existing engine input/attack facilities; accept automation only when the physical hook reports the player and produces the expected real hit. Until proven, player melee cases require a bounded manual prompt and remain manual coverage. Do not advertise the complete suite as fully automatic.
8. Check observation failure handling: wrong attacker/path, no hit, removed actor, session ended, and log write failure. Produce `FAIL` with an infrastructure reason where evidence is missing. EndRun clears observations; game load/revert invalidates old sessions before any actor IDs are reused.

**Verification:** Run normal-damage, API-defeat, delivered downed-hit, rescue, and lethal-hit cases with both physical and magic evidence. Seed a wrong expected caster and a no-hit scenario; both must fail. Compare test-enabled and ordinary builds under the same deterministic lethal settings; diagnostics must not change gameplay results. Ordinary packaging must contain no test ESP, scripts, batches, or native registration.

## Task 4: Fast production-rule checks and feature-linked scenarios

**Files:** `tests/native/RulesTests.cpp`, controller scenarios, xmake `yield-rule-tests` target. Modify gameplay files only through the corresponding feature work.

1. As each gameplay rule is implemented, expose its smallest engine-independent production calculation to the rule-test executable. Link that implementation directly; never duplicate the health ramp in Papyrus and call that proof.
2. Pin entry probabilities to the agreed examples: at T=20, h=21 -> 0, h=20 -> 50, h=10 -> 75, h=5 -> 87.5, h<=0 -> 100. Repeat rescaling at T=25 and T=50. Invalid/zero threshold behavior requires the gameplay decision first. Supply deterministic random draws at the production decision boundary in test mode; do not reseed unrelated game randomness.
3. Extend current observations with actual production injury/deadline/outcome fields when those fields exist. This plan intentionally does not invent their storage/API names ahead of gameplay implementation. Read the production state and log it alongside actual health; forced `0.05` cannot satisfy injury assertions.
4. Add cases with their feature issues: entry/deadlines/automatic outcomes (`skyrim-yek`); physical/magic player finishing, summon attribution and retained existing non-player protection (`skyrim-ise`); native dialogue (`skyrim-8r9`); potion/rescue/peaceful expiry (`skyrim-dre`); dismissal (`skyrim-6a1`); kneeling/prisoner lifecycle (`skyrim-e6q`, `skyrim-hvc`).
5. Optional knockout and identification/audio (`skyrim-tpm`), Plunder alarm (`skyrim-6cl`), Execute and Drain retain separate eligibility/feasibility cases. Unimplemented agreed rules report `SKIP`; undecided gameplay expectations report `UNDECIDED`; neither becomes PASS. Drain remains required where eligible despite being grouped with optional cases in the high-level plan.
6. Test elapsed real time and game-calendar time separately. Existing Acheron recovery uses game-calendar seconds; settle the new production timer clock before exact 15-90-second assertions. Use short explicitly logged settings for quick checks, plus a real-default run. Save/load deadline preservation uses controlled checkpoints and must not discard cleanup state.

**Verification:** `xmake build yield-rule-tests` then `xmake run yield-rule-tests`: assertions pass using production functions. In-game results expose unmet dependencies instead of hiding them. Mortality above/below its unsettled boundary, treatment overrides, Confidence cutoffs, and restraint expiry remain UNDECIDED until the user agrees their rules.

## Task 5: Behavior, persistence, and actual VR acceptance

**Files:** controller/test assets and `tests/README.md`; relevant sections of `test-plan.md` and `test-room.md` after verified delivery.

1. Expand from one actor to enemy/civilian/teammate/essential fixtures. Restore fixture regeneration for healing-specific scenarios. Check health, inventory and potion consumption, combat target, movement, actor life state and applicable dialogue conditions, not just internal flags.
2. Check Rescue during battle and after combat, nonhostility toward a nearby civilian, local wandering, and normal AI restoration only at expiry. Movement acceptance must use agreed distance/tolerance rules. Test civilian quest/escort safety without destructive use of real quest actors.
3. Run ten enemies plus teammates: confirm active-target selection, independent deadlines, early player intervention and eventual cleanup. A synthetic teammate tests the teammate branch; it does not establish NFF compatibility.
4. Add save/load and cell-transition checkpoints around yielding, Rescue, expiry, and restraints. Verify gameplay persistence without rerolls; abort/restart the harness safely around each checkpoint. Check only run-owned references are deleted and unrelated actors/settings remain intact.
5. Keep manual acceptance for visible poses, ordinary Talk/Activate, inventory screens, sound and knockout labels. Calling action code directly tests action logic, not dialogue routing. Record desktop results separately from VR; repeat real PLANCK attacks and actual NFF followers in the user's active VR profile after a reviewed VR test deployment.

**Verification:** a quick run has bounded scenarios, per-case results, one final summary, and clean teardown. A complete acceptance run has no skipped required cases; desktop automation cannot mark headset behavior passed. Measure suite duration before promising a speed target.

## Delivery gates and first useful result

The first useful delivery is Tasks 1-3: `bat yield-test` produces a repeatable baseline run with API defeat/recovery, verified real-hit cases, logs and cleanup. Player melee automation, undecided gameplay and visual acceptance remain explicitly pending where not proven. This interactive milestone does not satisfy the unattended requirement. Task 6 is required before declaring the automated harness ready. Later feature cases attach to that working runner rather than holding the entire foundation hostage to every gameplay decision.

Before calling the harness ready, verify both opt-in and ordinary builds, script/plugin output, runtime dependencies, positive and deliberately failing scenarios, abort/repeat/load cleanup, and that all manual or omitted coverage is visible in the summary. Do not commit or deploy to VR as part of writing this plan.

## Task 6: Host launch, unattended execution and fix/rerun loop

**Files:** `tests/Run-YieldTests.ps1`, `tests/Test-RunYieldTests.ps1`, controller/probe scripts and native bridge, gated bootstrap registration in `src/main.cpp`, `tests/README.md`.

**Host interface:** `Run-YieldTests.ps1 -GameRoot <absolute directory> -Test suite -ResultsRoot <absolute directory>`. Default `suite` runs the eight selectors documented in `tests/README.md`; each is individually selectable. Reject unknown values. Per-case and aggregate results use fresh GUID directories. Exit 0 requires every case to pass with cleanup, graceful shutdown and restored settings; exit 1 indicates failure/incomplete execution. Hello World is removed. Proposed custom bootstrap/protocol steps below remain conditional, as described above.

1. Verify the fixture save, matched SKSE, test-enabled Acheron and test plugin before launch. Refuse an existing Skyrim process; never terminate a user's session. Record environment and expected case inventory before starting. Use a fixture save with a completed character and accepted arena; never rely on navigating character creation. Preserve baseline save files untouched.
2. Pass `ACHERON_YIELD_TEST_RUN_ID` and `ACHERON_YIELD_TEST_SUITE` only to the owned loader process and its descendants. In the test-enabled native bridge, add `Probe::Bootstrap()` after data load: wait for the main-menu-ready event, then queue the engine console command `load YieldHarnessBaseline` once. The fixed save name is validated; do not interpolate untrusted commands. Verify this engine bootstrap experimentally, including missing save and failed load, before counting startup as automated.
3. Add test-native `String Function GetRequestedSuite() native global`, returning empty outside a host-owned run. Once the fixture save finishes loading, the test quest/load alias reads the requested suite and calls `Run` exactly once. No environment request means no automatic test execution. Preserve the host run ID through observation/result records and prevent duplicate OnInit/load callbacks from launching a second suite.
4. Complete real player melee automation from Task 3 through the normal engine attack/input route. Require the player as actual physical-hook attacker; direct damage writes or calling `ProcessHitData` are insufficient. All required automated scenarios must run without prompts. Manual fallback is diagnostic coverage, never unattended acceptance.
5. Emit `[YieldTest]` JSON records with schema version, run ID, case ID, status/detail, evidence and sequence number. Add a final summary containing expected/completed case counts and cleanup outcome. Host filters only its fresh run ID, rejects malformed/stale/duplicate/incomplete results, and archives logs before another session truncates them. Record the actual Skyrim PID/path in the handshake; loader exit alone is not game completion.
6. Bound startup and shutdown to 120 and 30 seconds initially; suite watchdog derives from each selected case's declared timeout plus startup/teardown allowances. Request graceful exit through the test bridge after results and cleanup are flushed. On crash/hang, retain evidence and terminate only a positively identified process owned by this run. Unknown ownership is an infrastructure error, not permission to kill every Skyrim process. Restore any temporary desktop configuration and record restoration failures.
7. `Test-RunYieldTests.ps1` exercises protocol fixtures: successful complete summary -> 0; case failure/skipped required case -> 1; stale run ID, missing summary, malformed output, crash/timeout or cleanup failure -> 2. Test that an existing unrelated Skyrim process is refused and cannot be terminated. Restore settings on every failure path. These tests cover orchestration only, not engine behavior.
8. Prove two unattended runs from the host with no keyboard/mouse use, plus deliberate startup failure and hung-case detection. Then demonstrate a failure -> evidence inspection -> targeted fix -> rebuild -> rerun cycle. The agent diagnoses the root cause and edits agreed implementation/test code; it never changes expectations just to make a failure green. Keep original failed-run artifacts and rerun affected cases before the broader regression suite.

**Verification command, after implementation:**

```powershell
pwsh -NoProfile -File tests/Test-RunYieldTests.ps1
pwsh -NoProfile -File tests/Run-YieldTests.ps1 -GameRoot 'S:\games\The Elder Scrolls V - Skyrim Special Edition' -Suite quick -ResultsRoot 'C:\src\gaming\skyrim-acheron-mod\build\test-results'
```

**Acceptance:** the agent can launch, observe, diagnose and rerun the automated suite without the user operating Skyrim. Graphical rendering may remain necessary. Visual/audio/headset judgments retain separate manual acceptance; their pending status must not contaminate or conceal automated results.

## Sources

- Local source paths in the evidence table are the implementation authority for this fork at upstream `ade7d95` plus the existing dirty NPC-only patch.
- [Acheron author build instructions](https://github.com/KrisV-777/Acheron/blob/master/README.md).
- [SKSE author downloads/runtime compatibility](https://skse.silverlock.org/): latest desktop build targets a newer runtime than this installation; verify an archived match.

This document retains the proposed broader implementation. Current verified
delivery is summarized above and in tests/README.md; remaining steps are not
claims of implemented or passed coverage.
