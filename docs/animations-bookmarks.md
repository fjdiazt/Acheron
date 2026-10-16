# Animation bookmarks

Selected clips and groups from SSE Animation Previewer screenshots, 2026-10-12.
Clip order matches screenshots. Related event-name catalog: [animations.md](animations.md).

## Clip bookmarks

| # | Clip filename | Family |
| --- | --- | --- |
| 1 | `aoboundkneesidle.hkx` | Bound kneeling |
| 2 | `aoboundkneesenter.hkx` | Bound kneeling |
| 3 | `idleblessingkneel_enter.hkx` | Blessing kneeling |
| 4 | `idleblessingkneel_loop.hkx` | Blessing kneeling |
| 5 | `special_childsitkneelidle.hkx` | Child sit/kneel |
| 6 | `mt_wounded_01.hkx` | Wounded |
| 7 | `mt_wounded_02.hkx` | Wounded |
| 8 | `mt_wounded_03.hkx` | Wounded |
| 9 | `idlesit_crosslegged.hkx` | Cross-legged sitting |
| 10 | `idlesit_crosslegged_exit.hkx` | Cross-legged sitting |
| 11 | `bedroll_frontsleep.hkx` | Bedroll front sleeping |
| 12 | `sneak1hm_idle.hkx` | Sneak idle |
| 13 | `sneakmtidle.hkx` | Sneak idle |
| 14 | `mt_wounded_02.hkx` | Wounded variant; source group/path not shown |
| 15 | `BillyyLay693mt_5_0.hkx` | BillyyLay693mt |
| 16 | `BillyyLay693mt_2_0.hkx` | BillyyLay693mt |
| 17 | `idlewarmhands_crouched.hkx` | Crouched warm hands |
| 18 | `idleblessingkneel_exit.hkx` | Blessing kneeling |
| 19 | `idlekneelenter.hkx` | Kneeling |
| 20 | `idlekneelexit.hkx` | Kneeling |
| 21 | `idlekneelidle.hkx` | Kneeling |
| 22 | `special_childsitkneelenter.hkx` | Child sit/kneel |
| 23 | `special_childsitkneelexit.hkx` | Child sit/kneel |

Clips 15-16 source: `Billyy's animations for Ostim Standalone`, verified folder
`meshes\actors\character\Animations\BillyysHuman\fmPos\BillyyLay693mt`.

Clip 17 appears in three screenshots. Source groups/paths not shown; whether
these selections represent distinct variants remains unverified.

## Group bookmarks

Bookmark entire group, including its clips and variants.

| Group | Priority |
| --- | --- |
| NPC - Injured | `6001935` |
| NPC - Fatigued Stage 2 | `6001926` |
| NPC - Headache | `6001921` |
| NPC - Fatigued Stage 1 | `6001908` |
| n cough mtidle w conditions | `1007975` |
| after combat idle var 4 health or stamina damaged condition | `1897` |
| Take a Seat 3 | `60003` |

## Folder bookmarks

Mod: `Billyy's animations for Ostim Standalone`. Bookmark entire folders,
including their clips and variants. Relative paths verified in installed mod.

- `meshes\actors\character\Animations\BillyysHuman\fmPos\BillyyCglay`
- `meshes\actors\character\Animations\BillyysHuman\fmPos\BillyyHj3lay`

## Commanded sitting selections (2026-10-15)

User-selected candidate pools for planned `Sitting` and `SittingWounded`.
Deduplicate by source/group + priority + clip, not filename alone: Take a Seat
replacements with the same filename may contain different poses. Repeated
Take a Seat 4 cross-legged screenshots represent one selection. Ungrouped
cross-legged screenshots and the bare `idlesit_crosslegged` reference are recorded
together provisionally; source paths/hashes must establish whether they differ.
Only the selected clips below are included, not entire replacement groups.

### Sitting

| Source shown | Priority | Selected clip(s) |
| --- | --- | --- |
| Ungrouped/base cross-legged; exact source not shown | — | `idlesit_crosslegged.hkx`; matching `idlesit_crosslegged_enter.hkx` and `idlesit_crosslegged_exit.hkx` shown |
| Ungrouped ledge; exact source not shown | — | `idlesitledge.hkx` |
| Take a Seat 1 | `60001` | `idlesit_crosslegged.hkx` |
| Take a Seat 2 | `60002` | `idlesit_crosslegged.hkx` |
| Take a Seat 3 | `60003` | `idlesitledge.hkx`, `idlesit_crosslegged.hkx` |
| Take a Seat 4 | `60004` | `idlesit_crosslegged.hkx` |
| Take a Seat 5 | `60005` | `idlesit_crosslegged.hkx` |
| Take a Seat 6 | `60006` | `idlesitledge.hkx` |
| Take a Seat 7 | `60007` | `idlesit_crosslegged.hkx` |

### SittingWounded

| Source shown | Priority | Selected clip | Actor restriction |
| --- | --- | --- | --- |
| Native beggar family | — | `mt_beggarsit.hkx` | No sex restriction requested |
| Female Laydown | `800001` | `idlelaydown.hkx` | Female NPCs only |
| Female Laydown Mirrored | `800002` | `idlelaydown.hkx` | Female NPCs only; shown alongside normal Laydown |
| Wounded 01; exact replacement source not shown | — | `mt_wounded_01.hkx` | No sex restriction requested |
| Wounded 02; exact replacement source not shown | — | `mt_wounded_02.hkx` | No sex restriction requested |
| Wounded 03; exact replacement source not shown | — | `mt_wounded_03.hkx` | No sex restriction requested |

Native beggar assets were found in the desktop BSA and behavior graph:
`mt_beggarsit.hkx` (expected entry), `mt_beggaridle.hkx` (expected held idle),
`mt_beggarstand.hkx` (exit). Native entry/held-loop mapping passed desktop qualification;
visual geometry remains separate.
Do not use the entry clip as the held loop merely because its name says "sit".

The wounded pool intentionally includes female lying poses; it is a visual
injury/risk cue, not proof of unconsciousness or death. Actual posture, matching
enter/idle/exit, sustained hold, dialogue and sex compatibility require probes.
File names alone do not establish that Wounded 01-03 are seated poses.

Requested routing: Sit at health zero chooses `SittingWounded`; positive health
chooses `Sitting`. The cue must preserve untreated wound/death risk rather than
silently cure the NPC. Acheron currently clamps defeated actor health to `0.05`
in `src/Acheron/Defeat.cpp`; the defeat record captures its exact damage modifier as the zero-injury baseline.
The controller tracks repaired damage, not temporary maximum-health buffs.
Defeated cosave v3 preserves the baseline; only old-save migration estimates the floor.
Heal is shown only in `SittingWounded` at zero injury health; successful healing
above zero, from any source, automatically selects `Sitting` and preserves remaining
hold and peaceful budget. Failed/cancelled healing keeps the wounded pose.
The transition declares skipped source exit and destination enter through the
shared animation-phase pipeline policy. Swap held idle directly, without standing
up or sitting down again; no healing-specific bypass or assumed interpolation.
Native compatibility has desktop regression coverage; visual result needs user confirmation.
Kneeling -> KneelingBound is included in that same shared phase-policy scope:
skip kneeling exit and bound enter, directly select bound held idle; Bind still
restarts the command hold. Direct child Bind run `df6ad484` retained the occupied marker,
native sitting status and health; no kneeling exit/bound enter clips occurred.
Sitting states, native Heal/Test topics and shared phase policy are implemented in
this desktop candidate. Mortality scheduling remains planned. Functional qualification
is separate from visual pose/swap review and VR verification.

### Sitting asset staging

`scripts/sitting-animations.json` explicitly selects all 16 enter/loop/exit triples.
Normal variants 0-9; wounded 10-15. Hidden pose ranks 3-18 use scoped OAR priorities
5005-5020 for enter/exit on persistent kneeling geometry; idle-only interruptible
submods use priorities5105-5120. Keeping enter/exit non-interruptible prevents a
lingering exit clip from restarting when the destination rank changes. `AcheronManagedPhase` (0x850, rank=phase)
controls native dialogue independently of physical packages. Take a Seat 7 retains
its source female restriction; Laydown/Mirrored are female-only. Same-basename
Take a Seat files have distinct SHA256 hashes and remain separate choices.

Run `python scripts/Stage-SittingAnimations.py`; sources are the desktop animation
BSA and read-only active VR pack copies. Only staging is written; source HKX files
are excluded from Git. The manifest records source paths and hashes. Native cross-legged
enter/exit are explicit overrides for variants lacking a selected enter/exit. Beggar
and both female Laydown variants now enter with native `idleblessingkneel_enter.hkx`.
Beggar retains `mt_beggaridle.hkx` / `mt_beggarstand.hkx`; Laydown retains its selected
female loop and now exits with native `idlekneelexit.hkx`. User rejected the relaxed
hands-behind-head laydown transitions; both entry and exit are now overridden. Bedroll alternatives were
rejected as long and side-lying. Retain `mt_getupfromback.hkx` / `mt_getupfromfront.hkx`
as candidate exits for flat back/front poses; neither is configured yet.
Updated entry qualification passed `65a1d519-d9d4-418a-be6f-708da2972c97`:
all16 female Test poses reached their scoped enter/held idle, repeated their loop,
preserved health/native sitting and released on hold expiry. The new entry assertion
was replayed against all16 captured clips. Beggar and both laydown entries matched
the native blessing-enter bytes; only those three installed assets changed.
Candidate retained with130 source/deployment hashes verified in receipt
`build/pacification-backups/b7003b13-9c88-42b1-ad73-eb6559cbcac4/manifest.json`.
Visual entry-to-loop fit still needs review; no male/VR rerun. Subsequent laydown
exit override to `idlekneelexit.hkx` is asset/hash-verified only, without a new runtime pass.
Both former laydown-exit uses are replaced; no active pipeline references remain.
Exit deployment backup: `build/pacification-backups/07169fd9-bdb0-44a6-9565-ad7a997dca89/manifest.json`;
both copied exits and all130 current source/deployment files match their staged bytes.
Wounded 01-03 remain visually unqualified as seated
poses even after graph/loop qualification; filename does not prove posture.

Probe `04bf6cdb` showed why a generic kneeling instant event cannot drive healing:
it selected the new clip but cleared native sitting state. The adapter now changes
only scoped selection; OAR interruptible idle submods reevaluate without waiting
for a full loop (female laydown loops last47.916668 seconds). Enter/exit stay outside
those submods. Probe `ec11f1d1` showed why marking all three phases interruptible
was unsafe: changing rank restarted a lingering exit, preventing the next native entry.
Native potion healing remains exactly 25 points, with one consumed item. Visual
continuity still requires user review; no seamless blend is claimed.

Desktop asset qualification passed `e560ab49-72d1-4686-8945-dd2d83854497`
(female, all16 families) and `186f2737-b9ef-4d14-9219-5eb71e59402c`
(male,13 eligible families). Each native Test choice used an independent disposable
actor and required its exact scoped idle, repeat loop, native sitting ownership,
unchanged engine health and eventual hold release. Female-only choices were absent
for the male actor. These are playback checks, not visual pose approval.

Long one-actor sweep `6c16058d-f80c-472c-8c4c-a1e13c171055` passed nine families
then stalled entering the tenth. That same family passed alone in `9b94874b`.
Repeated native marker-entry stress remains unresolved in `skyrim-emh`; the fresh-actor
asset checks do not establish a fix or prove a geometric cause.

Direct kneeling -> bound regressions passed all three families: regular
`8d297cb7-12eb-44f0-b69f-ff13e404f63a` through native Test selection, blessing
`41a9015b-5415-47e8-a4a2-5a15b10eb8dc` and child
`76dbfbae-d138-415e-8b32-c0e73960d089` through ordinary Bind. All retained the
occupied marker/native sitting, skipped enter/exit clips, reset hold to1800,
preserved health/pacification and passed Talk/default-exit/scope controls.

Final core sitting run `7f6938bd-25ff-44b9-b892-b2f09caa8f0e` passed yielding
and sitting save/load, exact zero-injury routing, failed no-potion Heal, one consumed
potion/+25 health, direct healed swap, resumed rescued locomotion, default posture
commands/Bind and external healing. Direct swaps retained marker, sitting and timers.
Real player-hit defeat regression `fdaa3914-a1b1-4fa1-a8a1-5beacd912090` passed.
The qualified desktop candidate remains installed;130 file receipts match current
source in `build/pacification-backups/0c3bd37c-2a80-4727-bcf8-141741b5eb73/manifest.json`.
Desktop closed; owned saves cleaned and test INI/Prefs/config snapshots restored.
VR was not modified. Mortality scheduling, visual swaps and the repeated-entry
stress case remain outside this functional qualification.

## Playback notes

### Resting variants

Surrendered enemies choose standing Wandering or automatic Resting once peace
begins. Resting randomly selects a compatible bookmarked sitting family;
previously agreed unbound kneeling/crouched families remain candidates.

| Family/source | Candidate coverage | Qualification pending |
| --- | --- | --- |
| Cross-legged sitting | `idlesit_crosslegged.hkx`, `idlesit_crosslegged_exit.hkx` | Entry clip/event and playback mapping |
| Take a Seat 3 | All compatible sitting variants in bookmarked group, priority `60003` | Enumerate clips and matching entry/idle/exit |
| Unbound kneeling | Blessing, regular kneeling, child sit/kneel triples below | Playback mapping and actor compatibility |
| Crouched warm hands | `idlewarmhands_crouched.hkx` and compatible variants | Matching entry/exit and source variants |
| Other bookmarked clips/groups/folders | Any verified compatible sitting family | Confirm actual pose, independent NPC playback and matching sequence |

Choose one family, then use its matching enter/idle/exit; save `selectedPose`.
Bookmarks record candidates, not a verified enabled pool. Keep bound poses,
sleeping and unrelated animations out of this unbound sitting/resting pool.
No eligible family or failed entry falls back to standing Wandering without
resetting the peaceful budget. Resting's chance and saved selection rules live
in [FSM documentation](fsm.md#surrender-random-resting-or-standing-wandering).

### Commanded Kneeling variants

Implemented desktop three-family pool for **On your knees.** entering unbound Kneeling.
FSM entry action chooses a family; this catalog records its matching clips.
Bound kneeling uses its separate pose. Child clips qualified on adult female
and male Forsworn; wider actors/races and VR remain unverified.
Desktop uses persistent native KneelingMarker (`0xE8E4E`) for all three enabled families.
OAR replaces its enter/idle/exit clips only for our hidden `AcheronKneelingPose`
faction (`0x84D`, rank 0 regular, rank 1 blessing, rank 2 child sit/kneel). Native BlessingKneelMarker
plays its exit after one loop even while the command hold remains active; it is
not used for new entries. Child sit/kneel is enabled. Bound pose stays separate.

| Variant ID | Enter | Idle/loop | Exit |
| --- | --- | --- | --- |
| blessing | `idleblessingkneel_enter.hkx` | `idleblessingkneel_loop.hkx` | `idlekneelexit.hkx` (explicit override) |
| kneeling | `idlekneelenter.hkx` | `idlekneelidle.hkx` | `idlekneelexit.hkx` |
| childSitKneel | `byoh/special_childsitkneelenter.hkx` | `byoh/special_childsitkneelidle.hkx` | `byoh/special_childsitkneelexit.hkx` |

Explicit phase overrides live in `scripts/kneeling-animations.json`; no filename
suffix inference. Edit enter/loop/exit independently using a relative HKX path within the
desktop animation archive, then run `python scripts/Stage-KneelingAnimations.py`.
The script extracts independent clips into candidate staging, not the game or VR.
The persistent graph slots remain `idlekneelenter`, `idlekneelidle`, `idlekneelexit`;
replacement content follows the selected family. Source HKX assets are not stored
in Git. OAR remains required for the family-specific visuals.

Desktop qualification: baseline `24d1c149-7c66-4f4a-acf1-bb17ecadec22` failed when
native blessing exited three seconds after loop start with 1788 seconds of hold
remaining, without an FSM exit request. Fixed run
`3d798e2d-524c-42b5-8d04-4b8e62c15207` passed a 12-second hold with repeated
loop events, three native Talk interactions, requested regular exit, actor invariant
checks, marker cleanup and original-clip control outside commanded Kneeling.
Run `8934b36f-2518-483d-9816-b77e5384afff` passed both families, save/load without
reroll, both On your feet destinations, exit before Bind, restarted hold, bound
dialogue and hold expiry. Candidate installed on desktop; VR unchanged.
Earlier `72989f68-f72f-41e6-a9c7-1fe94ef5c0b5` stopped on a REST socket error;
candidate restored, then retry passed. Old native blessing-marker saves and VR
remain unqualified. Silent-opening promotion remains separate.

Child integration qualified on adult male Forsworn (`0x43BDD`, sex 0, DefaultMale)
and the default adult female Forsworn. Male probe `010da013-4422-4daa-88bb-879ba37a4404`
also received visual review without obvious pose distortion. Integrated rank-2
runs `28904db0-16ee-4c2b-8be6-ed595a5087e7` (male) and
`ecfddef7-bc3b-4b80-a8c6-9004eab5c759` (female) passed sustained hold, repeated
Talk, child exit, unowned-animation control and child-to-Bind handoff.
Three-family run `30e6235a-9fb9-485e-840a-52761eb8af2e` passed random coverage,
explicit child save/load without reroll/timer reset, both On your feet destinations,
Bind and ordered hold expiry. All 34 installed candidate hashes matched deployment
receipt `build/pacification-backups/f4092851-f227-412f-aa80-094ffc6c5785/manifest.json`.
Earlier runs `7f8564d4` and `897d0d57` failed while issuing the next activation or
direct kneel before the previous Talk UI finished closing; candidate restored.
The harness now waits for both dialogue-manager and UI closure before repeating.
These results do not qualify broader races, VR, forced fallback or old-marker saves.

The broader `peaceful-test-dialogue` run `f86d2721-b5ae-4690-b1a0-b4b3250cc855`
passed regular -> blessing -> child -> bound -> regular and the later engine
destinations, but failed waiting for AvoidingCombat -> Wandering after combat
fixture teardown. Diagnostic retries `71e8167d` and `3fc29002` did not resolve it;
the latter confirmed all four owned NPCs and the player were out of combat while
the managed actor remained ready in AvoidingCombat. No cause is established.
Temporary teardown probes were removed; their script is archived locally at
`build/test-dialogue-investigation/With-CombatDiagnostics.ps1`. Track further
investigation in Beads `skyrim-1ir`; the complete Test-tree gate is not passing.

Many animation families have **start/enter**, **idle/loop**, and/or **exit** clips.
Check related clips together when selecting behavior; one bookmarked clip may be
only part of the sequence. Other missing sibling filenames remain unrecorded.

Screenshots now record full clip sequences for **Blessing kneeling**
(enter -> loop -> exit), **Kneeling** and **Child sit/kneel** (enter -> idle -> exit).
Existing blessing enter/loop bookmarks retained without duplicates.

These are `.hkx` clip filenames, not verified `playidle` EditorIDs or `sae` event
names. Gameplay entry, exit, looping, interruption and actor compatibility remain
untested for this bookmark set.
