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

Intended three-family pool for **On your knees.** entering unbound Kneeling.
FSM entry action chooses a family; this catalog records its matching clips.
Bound kneeling uses its separate pose. Families still need verified playback
events/forms and actor compatibility, including adult use of Child sit/kneel.
Desktop uses persistent native KneelingMarker (`0xE8E4E`) for both enabled families.
OAR replaces its enter/idle/exit clips only for our hidden `AcheronKneelingPose`
faction (`0x84D`, rank 0 regular, rank 1 blessing). Native BlessingKneelMarker
plays its exit after one loop even while the command hold remains active; it is
not used for new entries. Child sit/kneel remains disabled. Bound pose stays separate.

| Variant ID | Enter | Idle/loop | Exit |
| --- | --- | --- | --- |
| blessing | `idleblessingkneel_enter.hkx` | `idleblessingkneel_loop.hkx` | `idlekneelexit.hkx` (explicit override) |
| kneeling | `idlekneelenter.hkx` | `idlekneelidle.hkx` | `idlekneelexit.hkx` |
| childSitKneel | `special_childsitkneelenter.hkx` | `special_childsitkneelidle.hkx` | `special_childsitkneelexit.hkx` |

Explicit phase overrides live in `scripts/kneeling-animations.json`; no filename
suffix inference. Edit enter/loop/exit independently using an HKX basename from the
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
candidate restored, then retry passed. Old native blessing-marker saves, child
pose and VR remain unqualified. Silent-opening promotion remains separate.

Many animation families have **start/enter**, **idle/loop**, and/or **exit** clips.
Check related clips together when selecting behavior; one bookmarked clip may be
only part of the sequence. Other missing sibling filenames remain unrecorded.

Screenshots now record full clip sequences for **Blessing kneeling**
(enter -> loop -> exit), **Kneeling** and **Child sit/kneel** (enter -> idle -> exit).
Existing blessing enter/loop bookmarks retained without duplicates.

These are `.hkx` clip filenames, not verified `playidle` EditorIDs or `sae` event
names. Gameplay entry, exit, looping, interruption and actor compatibility remain
untested for this bookmark set.
