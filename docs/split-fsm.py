"""Generate lightweight per-state diagrams from the authoritative fsm.json."""

import argparse
import json
import re
from pathlib import Path


def build_views(master):
    states = master["states"]
    views = {}
    for name, state in states.items():
        if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", name):
            raise ValueError(f"Unsafe state filename: {name!r}")
        nodes = {name: state}
        for edges in state.get("on", {}).values():
            for edge in edges:
                target = edge["target"]
                if target not in states:
                    raise ValueError(f"Unknown target {target!r} from {name}")
                if target in nodes:
                    continue
                stub = {}
                destination = states[target]
                if "type" in destination:
                    stub["type"] = destination["type"]
                status = destination.get("meta", {}).get("status")
                if status:
                    stub["meta"] = {"status": status}
                nodes[target] = stub
        views[f"fsm-{name}.json"] = {
            "id": f"{master['id']}-{name}",
            "initial": name,
            "states": nodes,
            "meta": {"generatedFrom": "fsm.json", "focus": name},
        }
    return views


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Report drift without writing files")
    args = parser.parse_args()
    docs = Path(__file__).resolve().parent
    views = build_views(json.loads((docs / "fsm.json").read_text(encoding="utf-8")))
    existing = {}
    for path in docs.glob("fsm-*.json"):
        content = json.loads(path.read_text(encoding="utf-8"))
        if content.get("meta", {}).get("generatedFrom") != "fsm.json":
            raise ValueError(f"Refusing to overwrite ungenerated view: {path.name}")
        existing[path.name] = content
    stale = set(existing) - set(views)
    changed = [name for name, view in views.items() if existing.get(name) != view]
    if args.check:
        for name in sorted(stale):
            print(f"Obsolete: {name}")
        for name in changed:
            print(f"Missing or stale: {name}")
        if stale or changed:
            return 1
        print(f"PASS: {len(views)} state views match fsm.json")
        return 0
    for name in changed:
        (docs / name).write_text(json.dumps(views[name], indent=4, ensure_ascii=False) + "\n", encoding="utf-8")
    for name in stale:
        (docs / name).unlink()
    print(f"Synced {len(views)} state views; updated {len(changed)}, removed {len(stale)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
