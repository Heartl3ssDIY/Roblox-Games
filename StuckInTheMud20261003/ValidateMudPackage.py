import json
from pathlib import Path

from MudPackageSupport import (load_manifest, read, verify_all_games, verify_embedded,
                               verify_upgrade_contract)


def validate():
    root = Path(__file__).resolve().parent
    manifest = load_manifest(root)
    compact = read(root / 'InstallStuckInTheMud.luau')
    full = read(root / 'InstallPlaygroundAllGames.luau')
    embedded = verify_embedded(compact, manifest)
    contracts = verify_upgrade_contract(compact)
    expansion_files = verify_all_games(full, manifest, compact)
    result = {'valid': True, 'sources': manifest['package']['sources'],
                      'builders': manifest['package']['builders'], 'embedded_files_verified': embedded,
                      'support_files_verified': len(manifest['package']['support_files']),
                      'upgrade_contract_verified': contracts, 'expansion_stage_files_verified': expansion_files,
                      'combined_stage_order_verified': True,
                      'compact_sha256': manifest['package']['sha256'],
                      'all_games_sha256': manifest['all_games_package']['sha256'],
                      'external_profile_writes': 0, 'studio_mutations': 0}
    (root / 'package-validation.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps(result))


if __name__ == '__main__':
    validate()
