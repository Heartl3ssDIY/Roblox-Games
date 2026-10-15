from pathlib import Path
root = Path(__file__).resolve().parent
checks = (root / 'CatalogChecks.luau').read_text(encoding='utf-8')
after = (root / 'After/PlaygroundCatalog.luau').read_text(encoding='utf-8')
start = checks.index('local current = (function()\n') + len('local current = (function()\n')
end = checks.index('\nend)()\nlocal function equal',start)
checks = checks[:start] + after + checks[end:]
checks = checks.replace('and item.toyActionPending)', 'and item.cosmeticOnly and not item.toyActionPending)')
(root / 'CatalogFinalChecks.luau').write_text(checks,encoding='utf-8')
