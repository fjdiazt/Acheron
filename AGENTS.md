# Development boundary

Speak like a caveman. Keep technical terms exact.

VR Mad God installation is production. Treat these paths as read-only:
- `C:\bin\wabbajack\SkyrimVRMods`
- `S:\SteamLibrary\steamapps\common\SkyrimVR`
- Documents `My Games\Skyrim VR`

Desktop development target: `S:\games\The Elder Scrolls V - Skyrim Special Edition`.
Keep desktop configs, saves, load order and candidate builds separate. Never edit
through shared mod junctions/symlinks/hardlinks or close VR for desktop tests.
Use independent desktop mod copies, never shared links into VR. VR assets are read-only
copy sources.
Use `Assert-DesktopWritePath` from `tests/Desktop-Isolation.ps1` before deployment
or test config writes, including restoration. It rejects linked ancestors and files.
Future VR deployment needs explicit user authorization.

Track issues with `bd` in sibling `C:\src\gaming\skyrim`; run `bd prime` there.
