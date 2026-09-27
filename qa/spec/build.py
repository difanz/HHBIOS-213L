"""Resolve production modules and include paths in source-tree copies."""


def source_file(root, name):
    matches = list(root.rglob(name))
    assert len(matches) == 1, f'Expected one {name} in {root}, found {matches}'
    return matches[0]


def asm_includes(root):
    return [f'-I{path}' for path in [root, *sorted(p for p in root.rglob('*') if p.is_dir())]]
