#!/usr/bin/env python3
"""Generate small, deterministic per-directory title indexes from the catalogue."""
import argparse
import json
from pathlib import Path
import unicodedata


def encode_title(title):
    text = unicodedata.normalize('NFKD', title).encode('ascii', 'ignore').decode().upper()
    text = ' '.join(text.split())
    if not text or len(text) > 116 or any(not 32 <= ord(c) < 127 for c in text):
        raise ValueError('Title cannot be represented in 116 printable characters: '+title)
    return text.encode('ascii')


def record(filename, title):
    p = Path(filename)
    stem, ext = p.stem.upper(), p.suffix[1:].upper()
    assert 1 <= len(stem) <= 8 and len(ext) <= 3
    return (stem.ljust(8)+ext.ljust(3)).encode('ascii')+encode_title(title).ljust(117, b'\0')


def generate(root):
    report = json.loads((root/'CATALOG.JSN').read_text())
    groups = {}
    for row in report['files']:
        path = Path(row['destination'])
        title = row['title']
        if any(ord(c) < 32 or c == '\ufffd' for c in title):
            title = next((s['title'] for s in row['sources'] if s.get('title') and
                          all(ord(c) >= 32 and c != '\ufffd' for c in s['title'])), path.stem)
        groups.setdefault(path.parent, []).append((path.name, title))
    result = {}
    for folder, items in groups.items():
        assert len(items) <= 128
        data = b''.join(record(name, title) for name, title in sorted(items))
        target = root/folder/'TITLES.IDX'
        target.write_bytes(data)
        result[str(target.relative_to(root))] = len(items)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    args = parser.parse_args()
    print(json.dumps(generate(args.root), indent=2))
