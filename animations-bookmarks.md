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

Many animation families have **start/enter**, **idle/loop**, and/or **exit** clips.
Check related clips together when selecting behavior; one bookmarked clip may be
only part of the sequence. Missing sibling filenames are not yet recorded.

These are `.hkx` clip filenames, not verified `playidle` EditorIDs or `sae` event
names. Gameplay entry, exit, looping, interruption and actor compatibility remain
untested for this bookmark set.
