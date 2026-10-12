# Manual starting scenarios

VR is production; desktop is development. Desktop mods use independent copies;
the two shared junctions were removed. Do not recreate links into VR.
The runner rejects VR write destinations and linked configs/ancestors before launch.
See [production isolation](../tests/README.md#production-isolation).

`Install-RescueAnimations.ps1` copies the already installed injury locomotion assets
into a separate desktop rescue override. Run with the matching Acheron build;
it requires desktop Skyrim closed. See [rescue animation qualification](../tests/README.md#rescued-npc-locomotion).

From this checkout:

```powershell
pwsh -NoProfile -File scripts/Setup-OneEnemy.ps1
pwsh -NoProfile -File scripts/Setup-EnemyFollower.ps1
```

Each launches SKSE into a fresh, unsaved `UnownedCell`: 1920x1080 windowed,
first person, FOV 120, freecam off, God mode enabled through one `tgm` command
in the fresh session before actors spawn. It leaves the game open for manual play.
The shared runner enables `bAlwaysActive:General` in memory and verifies it before
setup, so switching windows does not stall DevBench calls. No `saveini` is issued;
desktop INI files and VR settings remain unchanged. The game keeps running while
unfocused for this session.
Wait for `READY` before playing. Spawned actors use temporary `SetGhost(true)`
protection while equipment and starting-state checks run, then normal damage and
AI resume at handoff. Early player attacks cannot invalidate setup.
The runner verifies process parentage at launch; subsequent calls verify PID,
executable path and birth time with `Get-Process`, avoiding slow per-call WMI queries.
One-enemy run `b3e4faf1-0403-4323-a147-04e3bb4e651f` reached `READY` in 12.7 seconds
from run-directory creation, with 153 calls, zero errors and `IsGhost=false` after
handoff. The preceding run `6e8da539-6afc-420c-83a6-1b6232f975d6` took 93 seconds
from first call to shutdown: a recorded player hit defeated the enemy during setup,
so its starting-state check failed and cleanup closed the game.
Inventory setup now uses one native DevBench `inspect kind=inventory` snapshot
per actor in `tests/Npc-Papyrus.ps1`, shared by both setup scripts and automated
fixtures. It supplies item types and counts without per-item Papyrus reads.
Before removal, the helper rejects wrong owners, truncated/incomplete results,
missing fields, invalid counts and duplicate forms. The snapshot limit is 100
distinct items; larger inventories fail rather than silently skip gear.
Shield-slot checks, conditional equipment edits, post-removal/equipped-hand
verification, actor ownership and cleanup remain. Non-gear inventory is preserved.

Batch benchmark (2026-10-12): 20 identical read calls in the same game, three pairs,
averaged 985 ms individually and 688 ms batched (30% faster). Evidence:
`build/test-results/batch-benchmark-dcae829a-6d10-4814-b123-bb1265a88da2/benchmark.json`.
Whole one-enemy setup, measured from run-directory creation, was 12.7 seconds
before batching and 12.9 seconds in clean batched run
`53350b2d-c7ad-4c58-b888-86e5c2870a1d`: no demonstrated overall improvement.
An earlier batched run (`06fdcd03-1277-44ab-944c-0a7adcf5996e`) took 14.5 seconds
including a separate five-second startup inspection timeout. Both reached `READY`.
Inventory snapshot comparison (2026-10-12): fresh batched baseline
`47bf4151-26f9-46ad-982e-8b44eb25cd11` took 13.25 seconds / 103 requests;
snapshot run `f6d29730-f9d7-4d8d-bd44-52210b9e2c6b` took 11.18 seconds / 88
requests. Player equipment setup fell from 3.20 to 1.56 seconds. Both reached
`READY` with zero tool errors. This is one launch pair, not a guaranteed timing;
loading and frame scheduling still vary. Evidence: each run's `tools.jsonl`, plus
`build/test-results/f6d29730-f9d7-4d8d-bd44-52210b9e2c6b/timing-comparison.json`.
Follower setup `c320fe46-bc31-432f-9af9-fa20207350cf` reached `READY` in 11.99
seconds, with 106 requests and zero tool errors; see its `summary.json`,
`tools.jsonl` and `timing.json`. Host inventory and setup checks pass. Full
gameplay regressions were not rerun for this fixture optimization.
Desktop qualification: `2d170bc2-2eae-4752-8f10-d219e0cf4349` reached `READY`
with background execution verified, player sword/shield verified and no tool
errors. Focus/health traces in `build/timeout-probe/fixed-focus.jsonl` show frames
continuing after focus left Skyrim. The preceding unmodified run
`577c0422-983a-41f8-b680-1c38212d0e0d` stopped dispatching calls on focus loss
and failed with 504; its focus trace is `build/timeout-probe/focus.jsonl`.
The player is a female Argonian, with one iron sword (`00012EB7`) and iron shield
(`00012EB6`), and no other armor/clothing or spare weapons. Equipment setup removes
only gear; gold, potions and other inventory remain available for interaction.
Before launch, Skyrim and its SKSE loader from the targeted `GameRoot` are
forcibly closed; unsaved progress is lost. The default target is
`S:\games\The Elder Scrolls V - Skyrim Special Edition`; use `-GameRoot` to select
another desktop installation. Processes from other installations, including VR,
are left running. Automated regressions still refuse an existing desktop session.

Actors are labeled `Test Enemy (Female Forsworn copy)` and, in the second scenario,
`Test Follower (<name> copy)`. Each manual run draws locally from three female
level-one melee Forsworn bases (`00043BE1`, `00043BE0`, `00043BE2`), and the follower
scenario draws from Lydia, Jordis, Iona, Calder or Argis. Repeat choices are allowed.
Followers are disposable combat teammates, not recruited into the normal
follower quest. Original NPCs are untouched. Normal AI and combat are enabled;
setup does not force a hit or defeat. Hunter Pride is active for player attacks.
The enemy uses a female `EncForsworn01Melee1HBretonF01/F02/F03` base, retains
her armor, and carries only one iron sword (`00012EB7`), with no shield or spare
weapons. Setup verifies sex and equipped weapon before enabling combat AI.
Selection adds no MCP/game calls. A fresh-process two-draw benchmark peaked at
47.23 ms; the exact selection block peaked at 7.98 ms across 30 draws
(`build/test-results/random-selection-b5eb5bb9-81b9-4a81-b52f-5e4f4737733a/timing.json`).
`summary.json` records `actorSelectionMilliseconds` and the selected bases.
All 3 enemy / 5 follower choices pass host setup checks; different actor asset
loading times have not been measured in-game.
Automated enemy regressions retain fixed `00043BE1` and equipment setup from
`tests/Npc-Papyrus.ps1`; guards, followers and civilian controls keep their roles.
Desktop one-enemy setup reached `READY` with sex `1`, one equipped iron sword,
empty left hand and no shield; evidence:
`build/test-results/65195741-4b4f-4da7-93fc-c608d2782a6d/summary.json` and `tools.jsonl`.
Setup also adds and verifies Acheron's interaction perk: main-menu `coc` skips
the normal new-game hook that grants it. The perk labels defeated targets Talk;
downed activation opens standard Skyrim dialogue. Rescue and On your knees.
use the same action paths as the automated native-dialogue regression.

These scripts use installed mod files; they do not deploy the staged candidate.
Their hashes, actor IDs and tool calls are recorded under `build/test-results/`.
`READY` means setup completed, not that gameplay passed. Display settings remain
at 1080p windowed after successful setup; the prior INI is archived as
`SkyrimPrefs.ini.before`. Autosave preferences are unchanged. Failed setup cleans
up and closes its owned session, restoring preferences through the normal runner.
Automated regressions retain 800x600, third person and automatic shutdown.

Host checks (no game launch):

```powershell
pwsh -NoProfile -File tests/Test-RunYieldTests.ps1
pwsh -NoProfile -File tests/Test-SetupScenario.ps1
```

## Player appearance

Both scenarios inherit native female Argonian preset 0 from shared bootstrap.
Race selection rebuilds head/mouth; female selection and preset set appearance.
Head-part compatibility is checked before spawning enemies. Restart a scenario
to apply; existing saves are not edited. Requires vanilla character creation UI.
