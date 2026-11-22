"""Rename locale keys everywhere at once: the code, the harnesses and all ten Locale/*.lua files.

Usage: python Tools/Rename-LocaleKeys.py <renames.json> [--dry-run]

renames.json is a list of objects:
  { "old": "Old English key", "new": "New English key",
    "values": { "deDE": "...", ... },       # optional: new translations, all nine or none
    "lOnly": true }                          # optional: in code, rename only L["..."], not plain
                                             # strings (page keys equal their English labels)

{ "add": "New English key", "values": { ... } } appends a new key (all nine translations) to the
end of every locale file; nothing in the code changes.

Without "values" every locale keeps its translation (a typo fix in the English key). With
"values" each locale gets the given text. When "new" already exists in a locale, the old line
is dropped and the existing translation of "new" is kept (two keys merged into one); give
"values" to replace that translation too.

Keys are matched as Lua string literals: L["..."] and plain "..." in code (the harnesses name
labels as plain strings), `L["..."] = ` lines in the locales. Line endings are preserved.
Docs/Options Navigation Review - 2026-11-22.md, plan steps 1, 2 and 6.
"""
import io, json, os, re, subprocess, sys

LOCALES = ["enUS", "deDE", "esES", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW"]
SKIP = ("Libs/", "Locale/", ".research/", "Docs/")


def lua_str(text):
    out = text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    return '"' + out + '"'


def read(path):
    with io.open(path, encoding="utf-8", newline="") as handle:
        return handle.read()


def write(path, text):
    with io.open(path, "w", encoding="utf-8", newline="") as handle:
        handle.write(text)


def find_line(text, key):
    needle = "L[" + lua_str(key) + "] = "
    hits = [m.start() for m in re.finditer(re.escape(needle), text)]
    if not hits:
        return None
    if len(hits) > 1:
        raise SystemExit("key defined twice: %r" % key)
    start = hits[0]
    end = text.find("\n", start)
    end = len(text) if end < 0 else end + 1
    return start, end, len(needle)


def main():
    root = os.getcwd()
    renames = json.load(io.open(sys.argv[1], encoding="utf-8"))
    dry = "--dry-run" in sys.argv
    for item in renames:
        if "add" in item:
            if sorted(item.get("values") or {}) != sorted(LOCALES[1:]):
                raise SystemExit("an added key needs all nine translations: %r" % item["add"])
            continue
        if item["old"] == item["new"] and not item.get("values"):
            raise SystemExit("nothing to do: %r" % item["old"])
        values = item.get("values")
        if values and sorted(values) != sorted(LOCALES[1:]):
            raise SystemExit("values must cover all nine locales: %r" % item["new"])

    for code in LOCALES:
        path = os.path.join(root, "Locale", code + ".lua")
        text = read(path)
        for item in renames:
            if "add" in item:
                if find_line(text, item["add"]) is not None:
                    raise SystemExit("%s: key already exists %r" % (code, item["add"]))
                eol = "\r\n" if "\r\n" in text else "\n"
                value = "true" if code == "enUS" else lua_str(item["values"][code])
                if not text.endswith("\n"):
                    text += eol
                text += "L[" + lua_str(item["add"]) + "] = " + value + eol
                continue
            old, new, values = item["old"], item["new"], item.get("values")
            hit = find_line(text, old)
            if hit is None:
                raise SystemExit("%s: missing key %r" % (code, old))
            start, end, head = hit
            line = text[start:end]
            eol = "\r\n" if line.endswith("\r\n") else ("\n" if line.endswith("\n") else "")
            value = line[head:len(line) - len(eol)]
            if values:
                value = "true" if code == "enUS" else lua_str(values[code])
            if new != old and find_line(text, new) is not None:
                # Merged into an existing key: drop this line, update the survivor if asked.
                text = text[:start] + text[end:]
                if values:
                    s2, e2, h2 = find_line(text, new)
                    line2 = text[s2:e2]
                    eol2 = "\r\n" if line2.endswith("\r\n") else ("\n" if line2.endswith("\n") else "")
                    text = text[:s2] + "L[" + lua_str(new) + "] = " + value + eol2 + text[e2:]
            else:
                text = text[:start] + "L[" + lua_str(new) + "] = " + value + eol + text[end:]
        if not dry:
            write(path, text)

    listing = subprocess.check_output(["git", "-C", root, "ls-files", "--cached", "--others",
                                       "--exclude-standard", "--", "*.lua"], text=True).split()
    touched = []
    for rel in listing:
        if rel.startswith(SKIP) or rel == "Tools/Rename-LocaleKeys.py":
            continue
        path = os.path.join(root, rel)
        if not os.path.exists(path):
            continue
        text = read(path)
        changed = text
        for item in renames:
            if "add" in item or item["old"] == item["new"]:
                continue
            if item.get("lOnly"):
                changed = re.sub(r"(?<!\w)L\[\s*" + re.escape(lua_str(item["old"])) + r"\s*\]",
                                 lambda m: "L[" + lua_str(item["new"]) + "]", changed)
            else:
                changed = changed.replace(lua_str(item["old"]), lua_str(item["new"]))
        if changed != text:
            touched.append(rel)
            if not dry:
                write(path, changed)
    print("%d renames; code files: %s" % (len(renames), ", ".join(touched) or "none"))


if __name__ == "__main__":
    main()
