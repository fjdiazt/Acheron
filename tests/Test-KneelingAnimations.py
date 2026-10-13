"""Verify BSA extraction and explicit phase overrides without launching Skyrim."""
import json
from pathlib import Path
import runpy
import struct
import tempfile

import lz4.frame

root = Path(__file__).resolve().parents[1]
reader = runpy.run_path(str(root / "scripts/Stage-KneelingAnimations.py"))["read_clips"]
folder = b"meshes\\actors\\character\\animations\0"
names = b"idlekneelidle.hkx\0other.hkx\0"
payload = b"test loop animation"
compressed = struct.pack("<I", len(payload)) + lz4.frame.compress(payload)
embedded = b"\x05test\0" + compressed
file_offset = 36 + 24 + 1 + len(folder) + 32 + len(names)
header = struct.pack("<4s8I", b"BSA\0", 105, 36, 0x100, 1, 2, len(folder), len(names), 0)
directory = struct.pack("<QIIQ", 0, 2, 0, 60)
entries = struct.pack("<QII", 0, 0x40000000 | len(embedded), file_offset)
entries += struct.pack("<QII", 0, 0, file_offset + len(embedded))
archive = header + directory + bytes([len(folder)]) + folder + entries + names + embedded
with tempfile.TemporaryDirectory() as temp:
    path = Path(temp) / "fixture.bsa"
    path.write_bytes(archive)
    assert reader(path, {"idlekneelidle.hkx"}) == {"idlekneelidle.hkx": payload}
    try:
        reader(path, {"missing.hkx"})
    except ValueError:
        pass
    else:
        raise AssertionError("Missing clip accepted")
    assert path.read_bytes() == archive, "Source archive modified"

config = json.loads((root / "scripts/kneeling-animations.json").read_text())
assert config["blessing"]["loop"] == "idleblessingkneel_loop.hkx"
assert config["blessing"]["exit"] == "idlekneelexit.hkx"
manifest = json.loads((root / "build/staging/kneeling-animations.json").read_text())
for clip in manifest:
    import hashlib
    path = root / "build/staging/peaceful" / clip["target"]
    assert hashlib.sha256(path.read_bytes()).hexdigest() == clip["sha256"]
    condition = (path.parent / "_conditions.txt").read_text()
    assert 'IsInFaction("Acheron.esm" | 0x00084D)' in condition
    assert f'FactionRank({config[clip["family"]]["rank"]}, "Acheron.esm" | 0x00084D)' in condition
print("PASS: compressed BSA extraction, explicit phase mapping, scoped staged clip hashes")
