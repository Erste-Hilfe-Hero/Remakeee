#!/usr/bin/env python3
"""Plan item 3736: sets the game version everywhere in one step.

  python3 tools/bump_version.py                 # next build: version code + 1, same name
  python3 tools/bump_version.py --name 0.2.0    # new version name, version code + 1
  python3 tools/bump_version.py --name 1.0.0 --code 10
  python3 tools/bump_version.py --check         # only checks that all places agree

Places: export_presets.cfg (Android version/code + version/name in every Android preset, iOS
application/short_version + application/version) and Online.CLIENT_VERSION (= version code; the
server sends builds below server_config.min_version to the store).
The store builds in lifekit add their own build number on top (docs/RELEASE.md)."""
import argparse, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PRESETS = os.path.join(ROOT, "export_presets.cfg")
ONLINE = os.path.join(ROOT, "scripts/online/Online.gd")
NAME_RE = re.compile(r"^\d+\.\d+\.\d+$")


def read_state():
    presets = open(PRESETS, encoding="utf-8").read()
    online = open(ONLINE, encoding="utf-8").read()
    codes = set(re.findall(r'^version/code=(\d+)$', presets, re.M))
    codes |= set(re.findall(r'^application/version="(\d+)"$', presets, re.M))
    names = set(re.findall(r'^version/name="([^"]*)"$', presets, re.M))
    names |= set(re.findall(r'^application/short_version="([^"]*)"$', presets, re.M))
    client = re.findall(r"^const CLIENT_VERSION: int = (\d+)$", online, re.M)
    codes |= set(client)
    names |= set(re.findall(r'^const CLIENT_VERSION_NAME: String = "([^"]*)"$', online, re.M))
    return presets, online, codes, names


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--name")
    ap.add_argument("--code", type=int)
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    presets, online, codes, names = read_state()
    if len(codes) != 1 or len(names) != 1:
        msg = "version places disagree: codes %s, names %s" % (sorted(codes), sorted(names))
        if a.check:
            sys.exit(msg)
        print("warning: " + msg + " (setting all of them now)")
    if a.check:
        print("version %s (%s) everywhere" % (next(iter(names)), next(iter(codes))))
        return
    code = a.code if a.code is not None else max(int(c) for c in codes) + 1
    name = a.name or sorted(names)[-1]
    if not NAME_RE.match(name):
        sys.exit("version name must look like 1.2.3, got %r" % name)
    if code <= 0:
        sys.exit("version code must be positive")
    presets = re.sub(r'^version/code=\d+$', "version/code=%d" % code, presets, flags=re.M)
    presets = re.sub(r'^application/version="\d+"$', 'application/version="%d"' % code, presets, flags=re.M)
    presets = re.sub(r'^version/name="[^"]*"$', 'version/name="%s"' % name, presets, flags=re.M)
    presets = re.sub(r'^application/short_version="[^"]*"$', 'application/short_version="%s"' % name, presets, flags=re.M)
    online = re.sub(r"^const CLIENT_VERSION: int = \d+$", "const CLIENT_VERSION: int = %d" % code, online, flags=re.M)
    online = re.sub(r'^const CLIENT_VERSION_NAME: String = "[^"]*"$', 'const CLIENT_VERSION_NAME: String = "%s"' % name, online, flags=re.M)
    open(PRESETS, "w", encoding="utf-8").write(presets)
    open(ONLINE, "w", encoding="utf-8").write(online)
    print("version %s (%d) set in export_presets.cfg and Online.gd" % (name, code))
    print("Raise server_config.min_version only once this build is live in both stores.")


if __name__ == "__main__":
    main()
