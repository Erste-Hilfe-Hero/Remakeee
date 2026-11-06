#!/usr/bin/env python3
"""Plan item 3636: a SAVE_VERSION bump must bring a fixture save and a migration test.

For every save version from 3 up to SAVE_VERSION in scripts/core/SaveManager.gd there must be
- a migration step "<n-1>: _migrate_<n-1>_to_<n>" in SaveManager._migrations,
- a fixture tests/fixtures/saves/v<n>_*.json whose "save_version" is n,
- a test function "test_v<n-1>_to_v<n>..." somewhere under tests/.
Versions 0 to 2 are older than this rule and are covered by test_save_migration.gd already.
Usage: python3 tools/save_version_check.py"""
import glob, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIRST_CHECKED = 3

def main():
    src = open(os.path.join(ROOT, "scripts/core/SaveManager.gd"), encoding="utf-8").read()
    m = re.search(r"const SAVE_VERSION: int = (\d+)", src)
    if not m:
        sys.exit("SAVE_VERSION not found in SaveManager.gd")
    version = int(m.group(1))
    tests = ""
    for p in glob.glob(os.path.join(ROOT, "tests/**/*.gd"), recursive=True):
        tests += open(p, encoding="utf-8").read()
    errors = []
    for n in range(1, version + 1):
        if not re.search(r"\b%d: _migrate_%d_to_%d\b" % (n - 1, n - 1, n), src):
            errors.append("SaveManager._migrations has no step %d -> %d" % (n - 1, n))
    for n in range(FIRST_CHECKED, version + 1):
        fixtures = glob.glob(os.path.join(ROOT, "tests/fixtures/saves/v%d_*.json" % n))
        good = [f for f in fixtures if json.load(open(f, encoding="utf-8")).get("save_version") == n]
        if not good:
            errors.append("no fixture tests/fixtures/saves/v%d_<name>.json with \"save_version\": %d" % (n, n))
        if not re.search(r"func test_v%d_to_v%d" % (n - 1, n), tests):
            errors.append("no migration test 'func test_v%d_to_v%d...' under tests/" % (n - 1, n))
    if errors:
        for e in errors:
            print("::error::" + e)
        sys.exit("save version %d: %d problem(s)" % (version, len(errors)))
    print("save version %d: fixtures and migration tests OK" % version)

if __name__ == "__main__":
    main()
