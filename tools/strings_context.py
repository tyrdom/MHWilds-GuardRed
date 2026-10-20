"""Print the string neighbourhood of a byte pattern inside the game exe.

Fields of one managed type are usually stored contiguously in the metadata, so
the strings around a known field name hint at the declaring class.

Usage: python tools/strings_context.py <pattern> [exe_path] [window]
"""
import re
import sys
import os

PATTERN = sys.argv[1] if len(sys.argv) > 1 else "_SuperArmorTimer"
EXE = sys.argv[2] if len(sys.argv) > 2 else r"C:\Program Files (x86)\Steam\steamapps\common\MonsterHunterWilds\MonsterHunterWilds.exe"
WINDOW = int(sys.argv[3]) if len(sys.argv) > 3 else 40

STR_RE = re.compile(rb"[\x20-\x7e]{4,120}")


def main() -> None:
    needle = PATTERN.encode()
    data = open(EXE, "rb").read()
    print(f"exe={EXE} size={len(data)} pattern={PATTERN!r}")
    start = 0
    hits = 0
    while hits < 3:
        pos = data.find(needle, start)
        if pos < 0:
            break
        hits += 1
        print(f"\n--- occurrence {hits} at offset 0x{pos:X} ---")
        lo = max(0, pos - WINDOW * 32)
        hi = min(len(data), pos + WINDOW * 32)
        chunk = data[lo:hi]
        strings = [m.group().decode("ascii", "ignore") for m in STR_RE.finditer(chunk)]
        for s in strings:
            print(f"  {s}")
        start = pos + 1
    if hits == 0:
        print("not found")


if __name__ == "__main__":
    main()
