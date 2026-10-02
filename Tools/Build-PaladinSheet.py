"""Publish the complete original-versus-Paladin comparison as the main sheet."""
from pathlib import Path
import runpy
import shutil

root = Path(__file__).resolve().parent.parent
runpy.run_path(str(root/'Tools/Build-PaladinFullComparison.py'))
source = root/'Docs/Research_Assets/Paladin/Revision5'
target = root/'Docs/Research_Assets/Paladin/Production'
for extension in ('png', 'jpg'):
    shutil.copy2(source/('Paladin-Full-Comparison.'+extension), target/('Paladin-Production-Asset-Sheet.'+extension))
print(target/'Paladin-Production-Asset-Sheet.png')
