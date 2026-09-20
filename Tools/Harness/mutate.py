"""Mutation test for the Config.lua differential harness.

Introduces one deliberate, plausible mistake at a time into Config.lua, runs the
differential harness, and requires it to fail. A differential test that cannot
be made to fail is not testing anything.

Usage: python mutate.py <addon root> <scratchpad>
"""

import io
import os
import subprocess
import sys

ROOT = sys.argv[1]
SP = sys.argv[2]
TARGET = os.path.join(ROOT, "Options", "Kit", "Config.lua")
LUA = r"C:\Program Files (x86)\Lua\5.1\lua.exe"
HARNESS = os.path.join(SP, "config_diff_harness.lua")

MUTATIONS = [
    (
        "hidden stops being inherited",
        "\tdisabled = true,\n\thidden = true\n}",
        "\tdisabled = true\n}",
    ),
    (
        "name treated as never-callable",
        'local allIsLiteral = {\n\ttype = true,',
        'local allIsLiteral = {\n\tname = true,\n\ttype = true,',
    ),
    (
        "desc no longer literal, so a string desc becomes a method call",
        "local stringIsLiteral = {\n\tname = true,\n\tdesc = true,",
        "local stringIsLiteral = {\n\tname = true,",
    ),
    (
        "negative order sorts first instead of last",
        "\tif (orderA < 0) then\n\t\tif (orderB >= 0) then return false end\n\telse\n\t\tif (orderB < 0) then return true end\n\tend",
        "\tif (orderA < 0) then\n\t\tif (orderB >= 0) then return true end\n\telse\n\t\tif (orderB < 0) then return false end\n\tend",
    ),
    (
        "missing order counts as 0 rather than 100",
        "local orderA, orderB = orders[a] or 100, orders[b] or 100",
        "local orderA, orderB = orders[a] or 0, orders[b] or 0",
    ),
    (
        "handler not inherited down the path",
        "\t\thandler = group.handler or handler",
        "\t\thandler = group.handler",
    ),
    (
        "info array omits the path",
        "\t\tinfo[i] = path[i]",
        "\t\tinfo[i] = nil",
    ),
    (
        "dialogHidden short circuit dropped",
        "\tlocal hidden = pickfirstset(option.dialogHidden, option.guiHidden)\n\tif (hidden ~= nil) then\n\t\treturn hidden\n\tend",
        "",
    ),
]


def run_harness():
    proc = subprocess.run(
        [LUA, HARNESS, ROOT, SP],
        capture_output=True, text=True, cwd=ROOT,
    )
    return proc.returncode, (proc.stdout or "") + (proc.stderr or "")


def main():
    with io.open(TARGET, encoding="utf-8", newline="") as fh:
        original = fh.read()

    # Baseline must pass, or nothing below means anything.
    code, out = run_harness()
    if code != 0:
        print("BASELINE FAILS - fix that first")
        print(out[-2000:])
        return 1
    print("baseline: passes\n")

    caught = 0
    for name, find, replace in MUTATIONS:
        if find not in original:
            print("  ?? SKIP   %-58s (pattern not found)" % name)
            continue

        mutated = original.replace(find, replace, 1)
        with io.open(TARGET, "w", encoding="utf-8", newline="") as fh:
            fh.write(mutated)

        code, out = run_harness()
        with io.open(TARGET, "w", encoding="utf-8", newline="") as fh:
            fh.write(original)

        if code != 0:
            caught += 1
            tail = [l for l in out.splitlines() if "failures" in l]
            print("  caught   %-58s %s" % (name, tail[-1].strip() if tail else ""))
        else:
            print("  MISSED   %-58s harness still passed!" % name)

    print("\n%d of %d mutations caught" % (caught, len(MUTATIONS)))

    # Leave the file exactly as found.
    with io.open(TARGET, encoding="utf-8", newline="") as fh:
        assert fh.read() == original, "Config.lua was not restored!"
    print("Config.lua restored byte for byte")

    return 0 if caught == len(MUTATIONS) else 1


if __name__ == "__main__":
    sys.exit(main())
