# Native defeated dialogue

Desktop replaces Hunter Pride's custom menu with normal Skyrim Talk dialogue.
The interaction perk only supplies the Talk label; no activation replacement,
menu SWFs, option-registration APIs or custom selection events remain.
Hunter Pride's combat eligibility and attack toggle remain separate.

Defeated actors temporarily permit PC/bleedout dialogue and suppress aggression.
Stopping combat alone did not permit native dialogue on the Forsworn fixture.
Recovery restores prior dialogue flags and removes the owned aggression modifier;
subsequent peaceful states acquire their own ownership. Defeated cosave version 2
stores this state; version 1 still loads. Obsolete menu records are ignored.

Native choices reuse existing action logic: Rescue, Plunder, Execute and Drain.
Execute/Drain are hidden for essential actors; Drain requires a vampire player
and a living, non-undead target. On your knees. enters owned Kneeling without
healing; Bind remains available from Kneeling.

## Desktop evidence

- `build/test-results/9f5f0f07-84e1-4070-b142-82df55c1b121/summary.json`:
  real player lethal hit; downed crosshair acquired; E opened native dialogue;
  selected On your knees. INFO; native kneeling occupancy, held pose and Talk;
  native Bind selection/clip, timer restart; original aggression restored;
  native Rescue selection, one potion consumed, 25-point healing, peaceful Wander.
- `build/test-results/2ea50d6b-0d0c-40f3-af49-90805ee46a83/summary.json`:
  enemy/civilian standing crosshair Talk, selectable Continue., preserved
  peaceful ownership and deferred expiry passed.
- C++/Papyrus/plugin builds passed. Dialogue-evidence, manual setup fixture and
  desktop-isolation host checks passed. No routine screenshots.

## Deployment and rollback

Qualified desktop candidate installed by `tests/Invoke-PacificationTests.ps1`.
Backup: `build/pacification-backups/ab2c62da-2017-40bf-a101-4674dcae75fc`.
Its `manifest.json` lists original/candidate hashes and all original files,
including retired SWFs and the interaction perk fragment PEX. With desktop
closed, restore exactly those files from backup through Desktop-Isolation guards.
Restore an older test save/cosave when reverting to a build predating version 2.
Source deletions backed up under `build/retired-hunter-menu-20261012-030934`.

VR production untouched. VR, creature/custom-voice dialogue, old-save migration,
and native Plunder/Execute/Drain selection remain unchecked. Third-party custom
Hunter Pride menu add-ons need conversion to dialogue; removed menu APIs are
intentionally incompatible. Newly added topics currently use English labels.
