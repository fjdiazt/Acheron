# Development boundary

Speak like a caveman. Keep technical terms exact.

## Repository ownership

Development lives exclusively in [fjdiazt/Acheron](https://github.com/fjdiazt/Acheron).
All branches, pushes and pull requests target this fork. Never push changes or
open pull requests against `KrisV-777/Acheron`.
`origin` points to our fork; `upstream` is fetch-only, with its push URL disabled.
Keep the GitHub CLI default repository set to `fjdiazt/Acheron`.

VR Mad God installation is production. Treat these paths as read-only:
- `C:\bin\wabbajack\SkyrimVRMods` (active installation)
- `N:\games\systems\pc\mods\wabbajack\SkyrimVRMods` (retained NAS copy)
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

## Issue tracking

Use **bd (Beads)** for all task/issue tracking, including code and documentation.
Shared database: sibling `C:\src\gaming\skyrim`, issue prefix `skyrim`.
Run Beads commands there; do not initialize another database in this repository.

Follow the [shared Beads workflow](../skyrim/AGENTS.md#issue-tracking).

- Run `bd prime` at session start or context recovery. Check `bd ready`, search
  with `bd search "topic"`, then read `bd show <id>` before work.
- Reuse relevant issues; batch related small doc edits under the feature issue.
  Create an issue only for a distinct deliverable without suitable existing
  tracking. Reopen closed issues only for continuation of the same deliverable.
- Record scope, acceptance criteria and links to docs/source. Keep specifications
  in authoritative files, progress and evidence in Beads.
- Mark active work with `bd update <id> --status in_progress`; respect active
  assignments. Use `--append-notes` for progress; `--notes` replaces prior notes.
  Record remaining work and the next step before handoff.
- Add real prerequisites with `bd dep add <blocked-id> <prerequisite-id>`.
- Close with `bd close <id> --reason "Completed scope; validation evidence"`
  only when acceptance criteria pass. Completed FSM/docs do not mean implemented
  gameplay. Keep implementation issues open; distinguish static checks, desktop
  runtime evidence and unverified VR behavior.

Use Beads instead of Markdown task lists or another tracker. Local database has
no sync remote and is excluded from Git; Git commits do not back it up. Preserve
it; never reset or recreate it for routine errors. Closing issues does not
authorize Git commits, pushes or deployment.

## FSM documentation

- `docs/fsm.json` is the authoritative master. Keep `docs/fsm.md` synchronized.
- `docs/fsm-STATE.json` files are generated viewing subsets. Never edit them directly.
- Whenever master changes, run `python docs/split-fsm.py` and include updated views
  in the same change. Regeneration also removes obsolete generated state views.
- Verify with `python docs/split-fsm.py --check` before completing FSM changes.
- Each view keeps its focused state/actions/guards intact; destination nodes are
  placeholders. Open that destination's view or master for its outgoing behavior.
