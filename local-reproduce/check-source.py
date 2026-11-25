#!/usr/bin/env python3
"""Check the complete committed upstream tree while allowing reproduction files."""
import pathlib
import subprocess
import sys

UPSTREAM_TREE = "a36ade652af3a438ecfa227a79240b7480b00ed4"
repo = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else __file__).resolve()
if len(sys.argv) <= 1:
    repo = repo.parent.parent

def git(*args, data=None):
    return subprocess.run(
        ["git", "-C", str(repo), *args], input=data,
        stdout=subprocess.PIPE, check=True,
    ).stdout

entries = git("ls-tree", "-z", "HEAD").split(b"\0")
upstream = b"\0".join(
    entry for entry in entries
    if entry and entry.split(b"\t", 1)[1] != b"local-reproduce"
) + b"\0"
actual = git("mktree", "-z", data=upstream).decode().strip()
if actual != UPSTREAM_TREE:
    raise SystemExit(f"Upstream source tree changed: {actual}; expected {UPSTREAM_TREE}")
print(f"COMMITTED_UPSTREAM_TREE=PASS {actual}")
print("Working-tree source and binaries are checked separately by prepare-view.sh.")
