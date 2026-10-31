"""Basic geometry/coverage gate; does not establish visual or live acceptance."""
import argparse
import importlib.util
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder', type=Path)
    parser.add_argument('--shared', type=Path, help='JSON object: casing name -> reason')
    parser.add_argument('--geometry-only', action='store_true', help='Diagnostic only; never authorizes installation')
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    if not (root/'Docs').is_dir() and (root.parent/'Docs').is_dir():
        root = root.parent
    folder = args.folder.resolve()
    if not folder.is_dir() or not list(folder.glob('*.tga')):
        parser.exit(1, 'FAIL: missing or empty theme folder\n')
    spec = importlib.util.spec_from_file_location('style', root/'Tools/Check-ThemeAssetStyle.py')
    style = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(style)
    shared = json.loads(args.shared.read_text(encoding='utf-8')) if args.shared else {}
    if not isinstance(shared, dict) or any(
        name not in style.SPEC or not isinstance(reason, str) or not reason.strip()
        for name, reason in shared.items()
    ):
        parser.exit(1, 'FAIL: shared inventory must name measured casings with reasons\n')
    errors = []
    if not args.geometry_only:
        import sys
        sys.path.insert(0, str(root/'Tools'))
        from ThemeSourceIntegrity import verify_pack
        try:
            verify_pack(folder, root)
        except (ValueError, KeyError, OSError) as error:
            errors.append('source integrity: '+str(error))
    for name in style.SPEC:
        if not (folder/(name+'.tga')).is_file() and name not in shared:
            errors.append('missing casing/disposition: '+name)
    for file in sorted(folder.glob('*.tga')):
        failures, notes = style.check(file)
        errors.extend(file.name+': '+failure for failure in failures)
        for note in notes:
            print('look:', file.name, note)
    for error in errors:
        print('FAIL:', error)
    print(f'{len(errors)} errors; '+('GEOMETRY-ONLY DIAGNOSTIC; ' if args.geometry_only else 'source/geometry gate; ')+'endcap/visual/live checks remain separate')
    return 1 if errors else 0


if __name__ == '__main__':
    raise SystemExit(main())
