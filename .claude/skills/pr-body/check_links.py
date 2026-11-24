"""Check that relative markdown links in the given files point at existing files.

Usage: python3 .claude/skills/pr-body/check_links.py FILE...
Prints one summary line, lists broken links, exits 1 if any are broken.
Skips http(s)/mailto links, fenced code blocks and non-.md arguments.
Anchors (#...) are not checked.
"""

import re
import sys
from pathlib import Path

LINK = re.compile(r"\]\(([^)#\s]+)(?:#[^)]*)?\)")


def links_in(text: str) -> list[str]:
    out, in_fence = [], False
    for line in text.splitlines():
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if not in_fence:
            out += [m.group(1) for m in LINK.finditer(line)]
    return [t for t in out if not t.startswith(("http://", "https://", "mailto:"))]


def main(paths: list[str]) -> int:
    files = [Path(p) for p in paths if p.endswith(".md") and Path(p).is_file()]
    total, broken = 0, []
    for f in files:
        for target in links_in(f.read_text(encoding="utf-8")):
            total += 1
            if not (f.parent / target).exists():
                broken.append(f"{f} -> {target}")
    print(f"files={len(files)} links={total} broken={len(broken)} (anchors not checked)")
    for b in broken:
        print(f"BROKEN {b}")
    return 1 if broken else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
