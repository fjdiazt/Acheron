"""Stage independently copied, state-scoped sitting clips; production sources are read-only."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("kneeling", ROOT / "scripts/Stage-KneelingAnimations.py")
kneeling = importlib.util.module_from_spec(spec)
spec.loader.exec_module(kneeling)


def stage(game_data, mods):
    poses = json.loads((ROOT / "scripts/sitting-animations.json").read_text())
    if len(poses) != 16 or [p["rank"] for p in poses] != list(range(3, 19)):
        raise ValueError("Sitting ranks must match SittingPose.h")
    wanted = {value for pose in poses for phase in kneeling.DRIVER
              if not (value := pose[phase]).startswith("mod:")}
    clips = kneeling.read_clips(game_data / "Skyrim - Animations.bsa", wanted)
    output = ROOT / "build/staging/peaceful"
    manifest = []
    for pose in poses:
        folder = output / "meshes/actors/character/animations/DynamicAnimationReplacer/_CustomConditions" / str(5002 + pose["rank"])
        loop_folder = folder.with_name(str(5102 + pose["rank"]))
        for target in (folder, loop_folder):
            target.mkdir(parents=True, exist_ok=True)
        conditions = f'IsInFaction("Acheron.esm" | 0x00084D)\nFactionRank({pose["rank"]}, "Acheron.esm" | 0x00084D)\n'
        if pose.get("femaleOnly"):
            conditions += "IsFemale()\n"
        for target in (folder, loop_folder):
            (target / "_conditions.txt").write_text(conditions, encoding="ascii")
        # Retire only our previous staging layout; installations are managed by the deployment receipt.
        (folder / "user.json").unlink(missing_ok=True)
        (folder / "idlekneelidle.hkx").unlink(missing_ok=True)
        faction = {"pluginName": "Acheron.esm", "formID": "84D"}
        filters = [{"condition": "IsInFaction", "requiredVersion": "1.0.0.0", "Faction": faction},
                   {"condition": "FactionRank", "requiredVersion": "1.0.0.0", "Faction": faction,
                    "Comparison": "==", "Numeric value": {"value": pose["rank"]}}]
        if pose.get("femaleOnly"):
            filters.append({"condition": "IsFemale", "requiredVersion": "1.0.0.0"})
        # OAR's legacy-folder user config permits prompt held-idle swaps without replaying a native enter event.
        (loop_folder / "user.json").write_text(json.dumps({"name": pose["name"], "priority": 5102 + pose["rank"],
            "interruptible": True, "conditions": filters}, indent=2))
        for phase, target in kneeling.DRIVER.items():
            source = pose[phase]
            if source.startswith("mod:"):
                path = (mods / source[4:]).resolve()
                if not path.is_relative_to(mods.resolve()):
                    raise ValueError("Source escapes mods root")
                payload = path.read_bytes()
            else:
                payload = clips[source]
            destination = (loop_folder if phase == "loop" else folder) / target
            destination.write_bytes(payload)
            manifest.append({"pose": pose["name"], "phase": phase, "source": source,
                             "target": str(destination.relative_to(output)),
                             "sha256": hashlib.sha256(payload).hexdigest()})
    (ROOT / "build/staging/sitting-animations.json").write_text(json.dumps(manifest, indent=2))
    print(f"Staged {len(manifest)} sitting clips; game and VR sources unchanged")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game-data", type=Path, default=Path(r"S:\games\The Elder Scrolls V - Skyrim Special Edition\Data"))
    parser.add_argument("--mods", type=Path, default=Path(r"C:\bin\wabbajack\SkyrimVRMods\mods"))
    args = parser.parse_args()
    stage(args.game_data, args.mods)
