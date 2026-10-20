"""Second pass: dump type-ish names and health/status/armor related identifiers.

Usage: python tools/strings_scan2.py [exe_path] [out_path]
"""
import re
import sys
import os

EXE = sys.argv[1] if len(sys.argv) > 1 else r"C:\Program Files (x86)\Steam\steamapps\common\MonsterHunterWilds\MonsterHunterWilds.exe"
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), "..", "build", "strings_types.txt")

STR_RE = re.compile(rb"[\x20-\x7e]{4,120}")
# full managed type names: app.X / app.X.Y / System.X
TYPE_RE = re.compile(r"^(app|System|ace|c[A-Z])[\w.`<>+\[\], ]*$")
KEY = re.compile(r"(Health|SuperArmor|HunterStatus|STATUS_FLAG|HitPoint|RedHealth|Guard)", re.I)


def main() -> None:
    os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
    types, keys = set(), set()
    with open(EXE, "rb") as fh:
        while True:
            chunk = fh.read(1 << 24)
            if not chunk:
                break
            for m in STR_RE.finditer(chunk):
                s = m.group().decode("ascii", "ignore")
                if KEY.search(s):
                    keys.add(s)
                if TYPE_RE.match(s) and ("app." in s or s.startswith("c")):
                    types.add(s)
    with open(OUT, "w", encoding="utf-8") as out:
        out.write("=== KEYWORD HITS ===\n")
        out.write("\n".join(sorted(keys)))
        out.write("\n\n=== TYPE-ISH NAMES ===\n")
        out.write("\n".join(sorted(types)))
    print(f"{len(keys)} keyword hits, {len(types)} type-ish names -> {OUT}")


if __name__ == "__main__":
    main()
