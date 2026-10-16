"""Restore native functional orb glass; leave themed casings untouched.

python Tools/Repair-ThemeOrbGlass.py --install
Also repairs Druid staging so Build-DruidRuntime.py cannot reintroduce the bug.
Other builders call ThemeOrbGlass.restore_glass when exporting their casings.
"""
from pathlib import Path
import argparse
import hashlib
import json
from PIL import Image
from ThemeOrbGlass import ORBS, restore_glass

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT/'Docs/Research_Assets/OrbGlass-2026-10-16'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def replace_hashes(value, replacements):
    if isinstance(value, dict):
        return {key: replace_hashes(item, replacements) for key, item in value.items()}
    if isinstance(value, list):
        return [replace_hashes(item, replacements) for item in value]
    if isinstance(value, str):
        return replacements.get(value, value)
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install', action='store_true')
    args = parser.parse_args()
    folders = [(ROOT/'Assets'/theme, ROOT/'Assets'/theme/'manifest.json')
               for theme in ('Hunter', 'Mage', 'Paladin', 'Druid')]
    stage = ROOT/'Docs/Research_Assets/Druid/HD'
    if (stage/'Export').is_dir():
        folders.append((stage/'Export', stage/'manifest.json'))
    WORK.mkdir(parents=True, exist_ok=True)
    for folder, manifest_path in folders:
        replacements = {}
        for name in ORBS:
            target = folder/(name+'.tga')
            before = Image.open(target).convert('RGBA')
            after = restore_glass(before, ROOT, name)
            if before.tobytes() == after.tobytes():
                continue
            print(target.relative_to(ROOT))
            if args.install:
                backup = WORK/(folder.parent.name+'-'+folder.name+'-'+target.name)
                if not backup.exists():
                    backup.write_bytes(target.read_bytes())
                old = sha(target)
                after.save(target, compression=None)
                replacements[old] = sha(target)
                if target.with_suffix('.png').exists():
                    after.save(target.with_suffix('.png'))
        if args.install and manifest_path.exists():
            data = replace_hashes(json.loads(manifest_path.read_text(encoding='utf-8')), replacements)
            current_sizes = {sha(folder/(name+'.tga')):(folder/(name+'.tga')).stat().st_size for name in ORBS}
            current_paths = {(folder/(name+'.tga')).relative_to(ROOT).as_posix():sha(folder/(name+'.tga')) for name in ORBS}
            def refresh_sizes(value):
                if isinstance(value, dict):
                    recorded_path = str(value.get('path', '')).replace(chr(92), '/')
                    if recorded_path in current_paths:
                        value['sha256'] = current_paths[recorded_path]
                    if value.get('sha256') in current_sizes and 'bytes' in value:
                        value['bytes'] = current_sizes[value['sha256']]
                    for item in value.values(): refresh_sizes(item)
                elif isinstance(value, list):
                    for item in value: refresh_sizes(item)
            refresh_sizes(data)
            manifest_path.write_text(json.dumps(data, indent=2)+'\n', encoding='utf-8')
    print('Installed native glass.' if args.install else 'Dry run; use --install to repair.')


if __name__ == '__main__':
    main()
