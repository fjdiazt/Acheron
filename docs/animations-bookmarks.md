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
`mt_beggarstand.hkx` (expected exit). This phase mapping is not live-qualified.
Do not use the entry clip as the held loop merely because its name says "sit".

The wounded pool intentionally includes female lying poses; it is a visual
injury/risk cue, not proof of unconsciousness or death. Actual posture, matching
enter/idle/exit, sustained hold, dialogue and sex compatibility require probes.
File names alone do not establish that Wounded 01-03 are seated poses.

Requested routing: Sit at health zero chooses `SittingWounded`; positive health
chooses `Sitting`. The cue must preserve untreated wound/death risk rather than
silently cure the NPC. Acheron currently clamps defeated actor health to `0.05`
in `src/Acheron/Defeat.cpp`; injury-health tracking still needs implementation.
Heal is shown only in `SittingWounded` at zero injury health; successful healing
above zero, from any source, automatically selects `Sitting` and preserves remaining
hold and peaceful budget. Failed/cancelled healing keeps the wounded pose.
The transition declares skipped source exit and destination enter through the
shared animation-phase pipeline policy. Swap held idle directly, without standing
up or sitting down again; no healing-specific bypass or assumed interpolation.
Native compatibility and the visual result need testing and user confirmation.
Kneeling -> KneelingBound is included in that same shared phase-policy scope:
skip kneeling exit and bound enter, directly select bound held idle; Bind still
restarts the command hold. Existing qualified Bind runs played kneeling exit
before bound idle and do not qualify the proposed direct handoff.
Both sitting states, their health routing, Heal and animation-phase policy are
planned in the [FSM](fsm.md#commanded-sitting), not enabled gameplay.

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
