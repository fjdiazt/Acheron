"""Stage scoped OAR clips from the user's desktop BSA; no game or VR writes."""
import argparse
import hashlib
import json
import mmap
from pathlib import Path, PurePosixPath
import struct

import lz4.frame

ROOT = Path(__file__).resolve().parents[1]
DRIVER = {"enter": "idlekneelenter.hkx", "loop": "idlekneelidle.hkx", "exit": "idlekneelexit.hkx"}


def read_clips(archive, wanted):
    with archive.open("rb") as stream, mmap.mmap(stream.fileno(), 0, access=mmap.ACCESS_READ) as data:
        magic, version, offset, flags, folders, files, _, names_length, _ = struct.unpack_from("<4s8I", data)
        if magic != b"BSA\0" or version != 105:
            raise ValueError("Expected desktop BSA version 105")
        counts = [struct.unpack_from("<I", data, offset + i * 24 + 8)[0] for i in range(folders)]
        if sum(counts) != files:
            raise ValueError("BSA file count mismatch")
        position = offset + folders * 24
        entries = []
        for count in counts:
            length = data[position]
            position += 1
            folder = data[position:position + length].rstrip(b"\0").decode().lower()
            position += length
            for _ in range(count):
                _, size, file_offset = struct.unpack_from("<QII", data, position)
                position += 16
                entries.append((folder, size, file_offset))
        names = data[position:position + names_length].rstrip(b"\0").split(b"\0")
        if len(names) != files:
            raise ValueError("BSA name count mismatch")
        clips = {}
        for (folder, size, file_offset), name in zip(entries, names):
            base = r"meshes\actors\character\animations"
            if folder != base and not folder.startswith(base + "\\"):
                continue
            name = ((folder[len(base):].strip("\\") + "\\" if folder != base else "") + name.decode()).lower().replace("\\", "/")
            if name not in wanted:
                continue
            payload = bytes(data[file_offset:file_offset + (size & 0x3fffffff)])
            if flags & 0x100:
                payload = payload[1 + payload[0]:]
            if bool(flags & 4) ^ bool(size & 0x40000000):
                length = struct.unpack_from("<I", payload)[0]
                payload = lz4.frame.decompress(payload[4:])
                if len(payload) != length:
                    raise ValueError("BSA decompression length mismatch")
            clips[name] = payload
        if clips.keys() != wanted:
            raise ValueError(f"Missing animation clips: {wanted - clips.keys()}")
        return clips


def stage(game_data):
    families = json.loads((ROOT / "scripts/kneeling-animations.json").read_text())
    if set(families) != {"regular", "blessing", "childSitKneel"}:
        raise ValueError("Expected regular, blessing and childSitKneel families")
    wanted = set()
    for rank, name in enumerate(("regular", "blessing", "childSitKneel")):
        family = families[name]
        if family["rank"] != rank or family["priority"] != 5002 + rank:
            raise ValueError("Family rank/priority must match the managed pose mapping")
        for phase in DRIVER:
            clip = family[phase]
            path = PurePosixPath(clip)
            if path.is_absolute() or ".." in path.parts or ":" in clip or "\\" in clip or not clip.endswith(".hkx"):
                raise ValueError("Clip override must be a relative HKX path within the desktop animation archive")
            wanted.add(clip.lower())
    clips = read_clips(game_data / "Skyrim - Animations.bsa", wanted)
    relative = Path("meshes/actors/character/animations/DynamicAnimationReplacer/_CustomConditions")
    output = ROOT / "build/staging/peaceful"
    manifest = []
    for name, family in families.items():
        folder = output / relative / str(family["priority"])
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "_conditions.txt").write_text(
            f'IsInFaction("Acheron.esm" | 0x00084D)\nFactionRank({family["rank"]}, "Acheron.esm" | 0x00084D)\n', encoding="ascii")
        for phase, target in DRIVER.items():
            payload = clips[family[phase].lower()]
            (folder / target).write_bytes(payload)
            manifest.append({"family": name, "phase": phase, "source": family[phase],
                             "target": str((folder / target).relative_to(output)),
                             "sha256": hashlib.sha256(payload).hexdigest()})
    (ROOT / "build/staging/kneeling-animations.json").write_text(json.dumps(manifest, indent=2))
    print(f"Staged {len(manifest)} scoped kneeling clips; desktop/VR installations unchanged")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game-data", type=Path, default=Path(r"S:\games\The Elder Scrolls V - Skyrim Special Edition\Data"))
    stage(parser.parse_args().game_data)
