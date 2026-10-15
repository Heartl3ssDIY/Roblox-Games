import json
from pathlib import Path

from PackageUpgradeSupport import read, verify_embedded, verify_upgrade_contract


root = Path(__file__).resolve().parent
package = read(root / 'InstallMovementRewards.luau')
manifest = json.loads(read(root / 'movement-package-manifest.json'))
checks = verify_embedded(package, manifest)
verify_upgrade_contract(package)
assert 'saveGui(britishBulldogHUD)\nsaveGui(shell)' in package
assert 'saveSource(bootstrap)' in package
assert 'copy.Enabled=false' in package and 'object.Disabled=true' in package
assert 'geometryPreserved=true' in package
assert 'Install Playground Expansion before this upgrade' in package
assert 'Instance.new("Part")' not in package[:package.index('local sources={')]
print(json.dumps({
    'embedded_files_verified': checks,
    'bytes': manifest['package']['bytes'],
    'restricted_permissions': True,
    'authored_layout_preservation': True,
    'first_run_backups': True,
    'prior_expansion_required': True,
    'package_sha256': manifest['package']['sha256'],
    'icon_assets': manifest['package']['icon_assets'],
    'support_svg_files_verified': len(manifest['package'].get('support_files', {})),
    'animation_scripts': manifest['package']['animation_scripts'],
}))
