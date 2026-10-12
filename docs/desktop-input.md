# Desktop keyboard input

Installed 2026-10-12: Media Keys Fix SKSE v1.0.1, the author's GitHub release
compatible with desktop Skyrim 1.6.1170. Requires installed SKSE and Address Library.

- [Release archive](https://github.com/epinter/MediaKeysFix/releases/tag/v1.0.1)
- [Author configuration documentation](https://github.com/epinter/MediaKeysFix)
- [Nexus](https://www.nexusmods.com/skyrimspecialedition/mods/92948)

Desktop files:

```text
S:\games\The Elder Scrolls V - Skyrim Special Edition\Data\SKSE\Plugins\MediaKeysFix.dll
S:\games\The Elder Scrolls V - Skyrim Special Edition\Data\SKSE\Plugins\MediaKeysFix.ini
```

Only configuration change: `[General] DisableDeadKeys = true`, allowing direct
quote entry on keyboard layouts with dead keys. Defaults retained:
`DisableWindowsKey = true`, `BackgroundAccess = false`.
The Windows key remains disabled; unfocused windows do not send keyboard input
to Skyrim. The test runner's `bAlwaysActive` setting controls simulation while
unfocused separately.

Game was closed during deployment. Installed hashes match staged files;
SKSE and the 1.6.1170 Address Library were present. Alt+F4 and console quote
entry have not been tested in-game. Load through `skse64_loader.exe` next launch.
VR installation was not changed.

Archive, original configuration, installation manifest and rollback evidence:
`build/media-keys-fix-20261012-025922/`. Neither target file existed before install.
Rollback: with desktop Skyrim closed, validate both paths using
`Assert-DesktopWritePath` from `tests/Desktop-Isolation.ps1`, then remove only
the two listed desktop files. No save, plugin load order or game INI change
needs reversal.

Archive SHA256:
`2AB31C13C8BF4B0E1A4647CAACCD64D70A60429C3AE740AA8C12C57690499A1D`.
Installed DLL SHA256:
`AF2E0797CC46DECD19C69A3019A5C061C0F8932C40BCDED0E2E965D863730E5E`.
Installed INI SHA256:
`F22C004FD7E1B26297619EDA4ECCE071F1D5BE0C078565316E7B1301058CA934`.
