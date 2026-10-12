# Acheron

A SKSE64 Death Alternative Framework for TESV Skyrim, sitting on top of native damage calcuations to create custom and extensible game over events, reducing the need to reload game saves upon losing in combat and adding new ways to interact with NPCs.

For documentation on how to interact with this plugin see the [wiki](https://krisv-777.github.io/Acheron/).  
Alternative download mirror on [Nexus Mods](https://www.nexusmods.com/skyrimspecialedition/mods/108159).

## NPC-only fork

This checkout disables player defeat, player pacification, surrender input, and
player consequence quests. Saved settings and Papyrus calls cannot enable new
player defeat. Player-only controls are hidden in the MCM; its Events page shows
NPC events. Existing player recovery code remains for upstream cosave recovery.
NPC and follower defeat, protection, recovery, and consequence events remain.
General NPC defeat defaults off: player/party Hunter Pride attacks can defeat
eligible enemies, while unrelated NPC fights remain lethal. Hunter Pride is
enabled on new game/load for this policy; its manual toggle remains available.
Direct player physical and damaging spell hits can finish defeated nonessential
NPCs. Other sources retain damage immunity. Native death events clear defeat
and pacification; finishing does not rescue or re-defeat the target.
Downed desktop actors use Skyrim's normal Talk dialogue: Rescue, Plunder,
Execute, conditional vampire Drain, and On your knees. The interaction perk
only labels activation as Talk; it no longer replaces activation or opens a
custom menu. Hunter Pride's attack eligibility remains independent.
Custom-menu SWFs, handlers, option-registration APIs and selection events are
removed. Third-party Hunter Pride menu add-ons need conversion to dialogue.
Old custom-menu cosave records are ignored. Defeated records now preserve the
original Talk/bleedout-dialogue flags; recovery and reset restore them.
Desktop only qualified; VR dialogue support remains unchecked.

## Requirements
* [xmake](https://xmake.io/#/)
	* Add this to your `PATH`
* [PowerShell](https://github.com/PowerShell/PowerShell/releases/latest)
* [Visual Studio Community 2022](https://visualstudio.microsoft.com/)
	* Desktop development with C++
* [Creation Kit](https://store.steampowered.com/app/1946180/Skyrim_Special_Edition_Creation_Kit/)
* [Spriggit CLI](https://github.com/Mutagen-Modding/Spriggit)
* Papyrus Sources
    * SkyUI SDK 5.1: [GitHub][SUI-GitHub]

## Building

### Clone
```
git clone https://github.com/KrisV-777/Acheron.git
cd Acheron
git submodule update --init --recursive
```

### Configure
Before building you must provide the following options: **spriggit_path**, **papyrus_path**, **papyrus_include**, and **papyrus_gamesource**.
These can be provided using either:

1. Environment variables (optionally loaded from `.env`)
   - See `.env.example` for variables/descriptions.
   - Copy to `.env` and edit the values.
   - Run `xmake f -c` after making changes to load the new values.
   - Alternate files can be loaded with `xmake f -c --dotenv=.env.other`

2. Command-line configure
   - Set options when configuring with `xmake f`:
```sh
xmake f -m release \
	--spriggit_path="path\to\Spriggit.CLI" \
	--papyrus_path="path\to\Papyrus Compiler" \
	--papyrus_include="path\to\ModOrganizer\mods" \
	--papyrus_gamesource="path\to\Skyrim Special Edition\Data"
```

### Build

```sh
xmake
```

### Install

If `install_path` and `auto_install` are configured, files will be automatically coppied to `install_path` after a successful build. Otherwise install can be run manually using:
```sh
xmake install -o INSTALLDIR
```

## Packaging
Desktop development: **Acheron MCM → General → God preset key (desktop)**,
default **G**. Press in gameplay to enable God mode and apply level 252,
all 18 skills at 100, and base health/magicka/stamina/carry weight at 100,000.
Higher values survive repeated presses. This is the agreed testing preset,
not an engine maximum. Unbind with Escape; remap through the existing MCM key control.

Unlocks visible playable perks from the loaded plugins, spell-tome/PC-start spells,
reviewed base-game/Dragonborn racial and reward powers/abilities, and all 27 standard
Skyrim/DLC shouts with their words. Perk effects grant their attached abilities normally.
Hidden NPC/test/quest-control spells, diseases and race transformations are excluded.
New mod powers without tomes need catalog review; there is no reliable universal
playable flag for spells/powers. The action does not advance quests or grant items.
Saved character changes persist; disabling the key does not undo the preset.
The action is desktop-only. VR production remains untouched.

Package the project into a `.7z` distribution using:
```
xmake pack
```
The file will be located in `build\xpack\`.

## Papyrus Project Generation

Generate a papyrus project file for IDE integration using:
```sh
xmake papyrus.project papyrus
```
