# Skyrim test room

Notes for testing the NPC behavior specified in [yield.md](yield.md).

## Enter the developer test room

Load a separate test save. Open Skyrim's console with the keyboard's `~` key,
enter the command, and press Enter:

```text
coc qasmoke
```

This teleports the player to the vanilla developer test room, which contains
item containers and crafting facilities. Close the console to resume play.

## Other test rooms

Enter one command at a time. Cell names contain no spaces: use
`coc WarehouseAmbushes`, not `coc Warehouse Ambushes`.

| Exact console command | Room / purpose |
| --- | --- |
| `coc qasmoke` | Developer item room with containers and crafting facilities; user found it crowded. |
| `coc UnownedCell` | Small stone room with one chest; preferred candidate for less clutter. |
| `coc WarehouseAmbushes` | Enemy ambush setups; not an empty arena. |
| `coc WarehouseFurniture` | Furniture testing. |
| `coc WarehouseCrafting` | Crafting testing. |
| `coc XTestGrantInt` | Magic Visuals Test Hall. |
| `coc MainMenuCell` | Empty black area; screenshot candidate, not a verified combat arena. |

These are existing game cells; no additional room mod is required. UnownedCell
is the current preferred candidate, not yet an accepted integration-test arena.
Verify floor space, NPC navigation, combat, and local avoidance/fleeing before
choosing the final room. Teleporting successfully does not establish AI suitability.

References: [test-cell list](https://elderscrolls.fandom.com/wiki/Test_Cells_%28Skyrim%29),
[Unowned Cell](https://elderscrolls.fandom.com/wiki/Unowned_Cell), and
[debug/unused-room guide](https://steamcommunity.com/sharedfiles/filedetails/?id=136149109).

## Leave for Riverwood

Open the console and enter:

```text
coc Riverwood
```

This sends the player to Riverwood, not necessarily the location they occupied
before entering the test room. Reload the earlier save to return to that state.

## Play an NPC animation

Target a nearby, loaded NPC by its reference ID. In VR, use `prid` rather than
relying on mouse selection. This must be the placed actor's RefID, not its NPC
BaseID:

```text
prid <NPCRefID>
playidle IdleWave
```

Replace the placeholder, enter each command separately, then close the console
to see the animation. `playidle` takes an idle record's EditorID. General form:

```text
playidle <IdleEditorID>
```

For animation graph events, use `sae` (short for `SendAnimEvent`) instead:

```text
sae <AnimationEventName>
```

On the same selected NPC, request a return to the default animation state:

```text
sae IdleForceDefaultState
```

For an ordinary test NPC, the bleedout animation events used by Acheron are:

```text
sae BleedoutStart
```

Then request its exit with:

```text
sae BleedoutStop
```

Animations alone do not create Acheron's defeat, protection, restraint, or
knockout states. Do not use these exit/reset commands to recover an actor still
registered as defeated by Acheron; use the mod's recovery action.

`IdleWave`, `IdleSurrender`, `IdleKneeling`, and `IdleForceDefaultState` names
were found in the installed `Skyrim.esm`. Wave is the simple playback example;
the exact kneeling/bound poses remain to be checked. Idle EditorIDs and animation
event names are different identifiers even when some names match. Use Creation
Kit's idle record to identify the associated event; these commands do not accept
a raw `.hkx` filename.

AI, combat, furniture, or animation conditions can interrupt or reject playback.
The reset event is a request, not a guaranteed exit from every animation.
Playback and poses have not been tested in the headset.

## Toggle AI during tests

With no actor selected in the console, toggle AI globally:

```text
tai
```

Run it again with no actor selected to restore the previous setting. Global AI
off is useful for animation experiments: actors stop choosing normal actions,
but idle animations can still run. Select the test NPC afterward with `prid`
and use the animation commands above.

With an actor selected, `tai` toggles that actor's AI instead. This can freeze
its animation too, so it is not the preferred way to test animation playback.
Keep the same targeting scope when toggling back.

To stop combat AI while keeping ordinary NPC behavior, use:

```text
tcai
```

Run `tcai` again to restore combat AI. Neither command is a permanent pacification
or Rescue implementation. Restore AI before testing defeat, recovery, combat
avoidance, or dialogue behavior. These toggles have not been tested in this VR
profile.

## Maxed test character

Desktop shortcut: **G**, configurable in **Acheron MCM → General → God preset key
(desktop)**. Approved preset: level 252, all 18 skills 100, base health/magicka/
stamina/carry weight 100,000, God mode enabled. Higher values are preserved.
Grants playable visible perks, learnable tome/start spells, reviewed racial/reward
powers/abilities and 27 standard shouts with unlocked words. Mod powers without
tomes need review. Does not grant hidden/NPC/quest-control/transformation abilities.
Saving makes character grants permanent. The manual commands below remain available.

Target: playable perks, spells, and powers only. Exclude hidden NPC, quest,
and test abilities. The active Mad God Overhaul NSFW profile uses Adamant,
Hand to Hand, Mysticism, and additional spell packs; vanilla-only unlock lists
will not cover this profile.

### Level and attributes

Use these on the separate test character:

```text
player.setlevel 252
player.setav health 9999
player.setav magicka 9999
player.setav stamina 9999
player.restoreav health 9999
player.restoreav magicka 9999
player.restoreav stamina 9999
```

These are practical test values, not the engine's numeric maximum. Level 252
is a chosen test level, not a level cap. Setting level does not grant perks,
skill XP, or the normal level-up attribute increases. Setting attributes changes
their base values; equipment and other modifiers can change the displayed totals.

God mode is already part of this setup. `tgm` toggles it: running it again can
turn it off. Keep it outside any repeatable character setup batch.

### All eighteen skills at 100

```text
player.setav onehanded 100
player.setav twohanded 100
player.setav marksman 100
player.setav block 100
player.setav smithing 100
player.setav heavyarmor 100
player.setav lightarmor 100
player.setav pickpocket 100
player.setav lockpicking 100
player.setav sneak 100
player.setav alchemy 100
player.setav speechcraft 100
player.setav alteration 100
player.setav conjuration 100
player.setav destruction 100
player.setav illusion 100
player.setav restoration 100
player.setav enchanting 100
```

Use the engine names even when menus rename skills. Hand to Hand uses
`lockpicking`; the merged Security tree uses `pickpocket`. Setting skills does
not purchase their perks.

### Perks, spells, powers, and shouts

There is no single vanilla console command that grants every playable perk and
spell while filtering out hidden records. Use one command per actual FormID:

```text
player.addperk <PerkID>
player.addspell <SpellOrPowerID>
player.addshout <ShoutID>
player.teachword <WordID>
player.unlockword <WordID>
```

Replace each placeholder before running. For ranked perks, include each required
rank's record. For shouts, teach and unlock each word belonging to that shout.
Adding spells also handles ordinary playable powers; it does not safely reproduce
every quest reward or transformation's scripted setup.

Find installed records by name:

```text
help "perk name" 4
help "spell name" 4
```

Choose the matching `PERK` or `SPEL` result, respectively. Use IDs from the current
load order, including light-plugin IDs; do not paste another profile's prefixes.

For a complete unlock, collect the active skill trees' perk ranks and the installed
player-learnable spells, powers, and shout words into a console batch. Exclude
NPC-only perks, hidden abilities, diseases, and quest-control spells. Merely
collecting every `PERK` or `SPEL` record would not meet the playable-only requirement.
That profile-specific ID list has not been generated; the commands above are
syntax, not a finished all-perks/all-spells unlock.

Avoid `psb` for this setup: it broadly populates the spellbook rather than selecting
only playable spells, and can add unwanted abilities or cause problems.

### Reusable console batch

Save the stat and skill commands in a plain-text file named `max-test.txt` in the
Skyrim VR game directory, beside `SkyrimVR.exe`, then run:

```text
bat max-test
```

Current game directory: `S:\SteamLibrary\steamapps\common\SkyrimVR`.
Add the reviewed perk/spell/word commands to that file when the profile-specific
list is available. No batch file has been installed or executed by these notes.

### Check values

```text
player.getlevel
player.getbaseav health
player.getbaseav magicka
player.getbaseav stamina
player.getbaseav lockpicking
player.hasperk <PerkID>
player.hasspell <SpellOrPowerID>
```

Check the skill and magic menus too. A high level and skills at 100 alone do not
prove that perks, spells, or shout words are unlocked.

## Test save

Keep test saves separate from the main playthrough. Use them for spawned NPCs
and experimental defeat, recovery, dialogue, animation, and damage behavior.

Commands are documented; operation in the active Mad God Overhaul VR profile
has not been verified in-game.

## References

[Skyrim VR console command reference](https://synergyvr.org/synergy/reference/console-commands/).

[Creation Kit: SetLevel](https://ck.uesp.net/wiki/SetLevel).

[Hand to Hand: skill names and console actor values](https://www.nexusmods.com/skyrimspecialedition/mods/59790).

[Reported spellbook crash after psb](https://forums.nexusmods.com/topic/8637828-crash-after-added-spells-with-psb/).

[FNIS author: idle records versus animation events](https://forums.nexusmods.com/topic/853462-idle-animation-question/).

[FNIS author: IdleForceDefaultState reset event](https://forums.nexusmods.com/topic/5147210-animation-problems/).

Local animation references: `Skyrim.esm` in the game directory and Acheron's
[`src/Acheron/Defeat.cpp`](src/Acheron/Defeat.cpp).

[Skyrim screenshot testing: global tai and idle animations](https://www.gamesas.com/show-your-character-t244842.html).
