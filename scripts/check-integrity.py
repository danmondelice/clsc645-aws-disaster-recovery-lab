#!/usr/bin/env python3
"""Offline preservation check; does not read credential files or contact AWS."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / 'baseline/source-sha256.json').read_text())
for name, expected in manifest.items():
    actual = hashlib.sha256((root / 'baseline' / name).read_bytes()).hexdigest()
    if actual != expected:
        raise SystemExit(f'Baseline changed: {name}')
manifest = json.loads((root / 'disaster-recovery/source-sha256.json').read_text())
for name, expected in manifest.items():
    actual = hashlib.sha256((root / 'disaster-recovery' / name).read_bytes()).hexdigest()
    if actual != expected:
        raise SystemExit(f'Instructor script changed: {name}')
print('All imported baseline files and five instructor scripts match original hashes.')
