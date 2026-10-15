import json
import sys
from pathlib import Path

root = Path(__file__).resolve().parent
sys.path.insert(0, str(root.parent / 'BritishBulldogMovement20261003'))
from PackageUpgradeSupport import verify_embedded, verify_upgrade_contract

package = (root / 'InstallPlaygroundExpansion.luau').read_text(encoding='utf-8')
manifest = json.loads((root / 'expansion-package-manifest.json').read_text(encoding='utf-8'))
checks = verify_embedded(package, manifest)
verify_upgrade_contract(package)
assert 'if not StarterGui:FindFirstChild("BritishBulldogHUD") then buildBritishBulldogHUD() end' in package
assert 'oldSpawn.Enabled=false' in package
assert 'saveGui(StarterGui:FindFirstChild(name))' in package
assert 'copy.Enabled=false' in package
print(json.dumps({'embedded_files_verified': checks, 'bytes': len(package.encode()),
                  'restricted_permissions': True, 'authored_layout_preservation': True,
                  'first_run_backups': True, 'icon_assets': manifest['package']['icon_assets'],
                  'support_svg_files_verified': len(manifest['package'].get('support_files', {})),
                  'animation_scripts': manifest['package']['animation_scripts'],
                  'package_sha256': manifest['package']['sha256']}))
