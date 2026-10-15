"""Publish the complete original-versus-Paladin comparison as the main sheet."""
from pathlib import Path
import runpy
import shutil
import sys

root = Path(__file__).resolve().parent.parent
if (root/'Docs/Research_Assets/Paladin/Rebuild-2026-10-14/layouts.json').exists():
    runpy.run_path(str(root/'Tools/Build-PaladinDropInReview.py'), run_name='__main__')
    sys.exit(0)
runpy.run_path(str(root/'Tools/Build-PaladinFullComparison.py'))
source = root/'Docs/Research_Assets/Paladin/Revision5'
target = root/'Docs/Research_Assets/Paladin/Production'
for extension in ('png', 'jpg'):
    shutil.copy2(source/('Paladin-Full-Comparison.'+extension), target/('Paladin-Production-Asset-Sheet.'+extension))
print(target/'Paladin-Production-Asset-Sheet.png')
