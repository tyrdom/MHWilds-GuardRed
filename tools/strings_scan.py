"""Extract ASCII strings from the game executable and look for API identifiers.

Offline research only: no game launch required. Writes hits to build/strings_hits.txt.
Usage: python tools/strings_scan.py [exe_path] [out_path]
"""
import re
import sys
import os

EXE = sys.argv[1] if len(sys.argv) > 1 else r"C:\Program Files (x86)\Steam\steamapps\common\MonsterHunterWilds\MonsterHunterWilds.exe"
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), "..", "build", "strings_hits.txt")

KEYWORDS = [
    "HunterStatus", "STATUS_FLAG", "Recoverable", "RedHp", "RedHealth", "RedHP",
    "RedPoint", "SuperArmor", "SUPER_ARMOR", "Clash", "CLASH", "HunterCharacter",
    "ACTION_ATTR", "HunterDef", "HitPoint", "DamageInfo", "DamageParam",
    "get_Hp", "get_Health", "get_Red", "set_Red", "HunterParam", "LifeParam",
]

# printable ASCII run
STR_RE = re.compile(rb"[\x20-\x7e]{4,200}")


def main() -> None:
    os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
    hits = []
    seen = set()
    total = 0
    with open(EXE, "rb") as fh:
        while True:
            chunk = fh.read(1 << 24)
            if not chunk:
                break
            total += len(chunk)
            for m in STR_RE.finditer(chunk):
                s = m.group().decode("ascii", "ignore")
                if any(k in s for k in KEYWORDS):
                    # keep short-ish identifiers only; filter obvious noise
                    if len(s) > 160:
                        continue
                    if s in seen:
                        continue
                    seen.add(s)
                    hits.append(s)
    with open(OUT, "w", encoding="utf-8") as out:
        out.write("\n".join(sorted(hits)))
    print(f"scanned {total} bytes, {len(hits)} unique keyword strings -> {OUT}")


if __name__ == "__main__":
    main()
