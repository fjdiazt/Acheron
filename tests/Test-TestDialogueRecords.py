"""Check compiled ESM, including INFO fields Spriggit can silently discard."""
from pathlib import Path
import struct
import sys
import zlib

data = Path(sys.argv[1] if len(sys.argv) > 1 else "build/staging/peaceful/Acheron.esm").read_bytes()
records = {}


def walk(start, end):
    while start < end:
        tag = data[start:start + 4]
        size, flags, form = struct.unpack_from("<III", data, start + 4)
        if tag == b"GRUP":
            walk(start + 24, start + size)
            start += size
            continue
        if not 0x835 <= form & 0xFFFFFF <= 0x849:
            start += 24 + size
            continue
        body = data[start + 24:start + 24 + size]
        if flags & 0x40000:
            body = zlib.decompress(body[4:])
        fields = []
        offset = 0
        while offset < len(body):
            key, length = struct.unpack_from("<4sH", body, offset)
            if key == b"XXXX":
                length = struct.unpack_from("<I", body, offset + 6)[0]
                offset += 10
                key = body[offset:offset + 4]
            fields.append((key, body[offset + 6:offset + 6 + length]))
            offset += 6 + length
        records[form & 0xFFFFFF] = (tag, fields)
        start += 24 + size


walk(0, len(data))
expected = [0x838 + 2 * i for i in range(9)]
for form in (0x836, 0x837):
    tag, fields = records[form]
    links = [struct.unpack("<I", value)[0] & 0xFFFFFF for key, value in fields if key == b"TCLT"]
    assert tag == b"INFO" and links == expected, f"Test root {form:X} lost native choice links"
    assert sum(key == b"DNAM" for key, _ in fields) == 1, "Test root lost spoken response"
    assert sum(key == b"CTDA" for key, _ in fields) == 2, "Test root lost actor/death restrictions"
    assert not (dict(fields)[b"ENAM"][0] & 1), "Test root must continue to choices"
for form in expected:
    assert records[form][0] == b"DIAL", "Linked Test topic missing"
    tag, fields = records[form + 1]
    assert tag == b"INFO" and dict(fields)[b"ENAM"][0] & 1, "Test action must end dialogue"
    assert sum(key == b"DNAM" for key, _ in fields) == 1, "Test action lost response"
print("PASS: compiled Test roots, nine native topic links, responses and action INFOs")
