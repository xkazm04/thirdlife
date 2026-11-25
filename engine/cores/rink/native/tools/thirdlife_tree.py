#!/usr/bin/env python3
"""Rink core: the source tree of the thirdlife core (the shipped variant; lane K8's lab makes the same tree with lab/thirdlife-tree.sh).
Copies native/thirdjam (thirdjam's files, byte for byte, never edited) to <out>/thirdjam and applies every <patches>/*.patch in name
order with `patch -p1`. A patch that does not apply is an error (exit 1): nothing is built from a half-patched tree. The copy is remade
only when thirdjam's files or the patches changed (a stamp of their hashes), so SCons rebuilds only what a patch touched.
usage: python -I thirdlife_tree.py <native/thirdjam> <patches dir> <out dir>      prints the tree it made, or why not
exit 0 = tree ready, 1 = a patch failed, 2 = no patches (nothing to build)."""
import hashlib, os, shutil, subprocess, sys

src, patches, out = sys.argv[1], sys.argv[2], sys.argv[3]
plist = sorted(p for p in (os.listdir(patches) if os.path.isdir(patches) else []) if p.endswith(".patch"))
if not plist:
    print("NOT BUILT  thirdlife tree: no patches in %s" % patches)
    sys.exit(2)
h = hashlib.sha1()
for root, _, files in sorted(os.walk(src)):
    for f in sorted(files):
        p = os.path.join(root, f)
        h.update(os.path.relpath(p, src).replace("\\", "/").encode())
        h.update(open(p, "rb").read())
for p in plist:
    h.update(p.encode())
    h.update(open(os.path.join(patches, p), "rb").read())
stamp = h.hexdigest()
stamp_file = os.path.join(out, "stamp")
tree = os.path.join(out, "thirdjam")
if os.path.isfile(stamp_file) and open(stamp_file).read().strip() == stamp and os.path.isdir(tree):
    print("PASS  thirdlife tree: up to date (%d patches)" % len(plist))
    sys.exit(0)
patch_exe = shutil.which("patch") or r"C:\Program Files\Git\usr\bin\patch.exe"
if os.path.isdir(tree):
    shutil.rmtree(tree)
os.makedirs(out, exist_ok=True)
shutil.copytree(src, tree)
for p in plist:
    r = subprocess.run([patch_exe, "-p1", "-s", "--no-backup-if-mismatch", "--binary", "-d", out, "-i", os.path.join(patches, p)], capture_output=True, text=True)
    if r.returncode != 0:
        if os.path.isfile(stamp_file):
            os.remove(stamp_file)
        print("FAIL  thirdlife tree: %s does not apply: %s" % (p, (r.stdout + r.stderr).strip().splitlines()[:3]))
        sys.exit(1)
open(stamp_file, "w").write(stamp)
print("PASS  thirdlife tree: %d patches applied to a copy of native/thirdjam (%s)" % (len(plist), tree))
