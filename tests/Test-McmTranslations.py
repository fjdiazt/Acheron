"""Guard SKSE's UTF-16 translation reader, including its empty-LF EOF behavior."""
from pathlib import Path

root = Path(__file__).resolve().parents[1] / "dist/Interface/Translations"
keys = {
    "Yield", "PostBattle", "Testing", "GodPresetKey", "GodPresetKeyHighlight",
    "PeacefulWanderDuration", "PeacefulWanderDurationHighlight",
    "CommandHoldDuration", "CommandHoldDurationHighlight",
    "FleeDuration", "FleeDurationHighlight", "FleeDistance", "FleeDistanceHighlight",
}
files = list(root.glob("Acheron_*.txt"))
assert files, "No translation catalogs"
for path in files:
    raw = path.read_bytes()
    assert raw.startswith(b"\xff\xfe"), f"Missing UTF-16 LE BOM: {path}"
    text = raw[2:].decode("utf-16-le")
    assert "\n" not in text.replace("\r\n", ""), f"Bare LF can stop SKSE parsing: {path}"
    lines = text.splitlines()
    for key in keys:
        matches = [line for line in lines if line.startswith("$Achr_" + key + "\t")]
        assert len(matches) == 1, f"Missing/duplicate {key}: {path}"
        assert len(matches[0]) < 511 and matches[0].count("\t") == 1, f"Invalid entry: {path}: {key}"
print(f"PASS: {len(files)} UTF-16 LE catalogs, Yield keys and SKSE line endings")
