#!/usr/bin/env python3
"""Fetch the pinned Core ML model and tokenizer; publish files only after verifying them."""
import concurrent.futures
import hashlib
import os
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
target = Path(sys.argv[1])
def digest(path, expected):
    size = path.stat().st_size
    h = hashlib.sha256() if len(expected) == 64 else hashlib.sha1(f"blob {size}\0".encode())
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()

def fetch(entry):
    name, size, expected, url = entry.split("\t")
    dest = target / name
    if dest.is_file() and dest.stat().st_size == int(size) and digest(dest, expected) == expected:
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=dest.parent, delete=False) as tmp:
        path = Path(tmp.name)
    try:
        subprocess.run(["curl", "-fsSL", "--retry", "4", "--connect-timeout", "15", "--max-time", "1200",
                        "-o", str(path), url], check=True)
        if path.stat().st_size != int(size) or digest(path, expected) != expected:
            raise ValueError(f"Integrity check failed for {name}")
        os.replace(path, dest)
    finally:
        path.unlink(missing_ok=True)

with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
    list(pool.map(fetch, (root / "Resources/model-files.tsv").read_text().splitlines()))
