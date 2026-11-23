#!/usr/bin/env python3
"""K3 round 5: thirdjam's own FJamButtonResolver (button_oracle.exe, compiled from its source) against K1's core glue on the
same seeded key stream in a real match (buttons_glue.gd). The glue's bCrossHold is crossHeld while not carrying (ApplyButtons,
InputMapping.cpp:501), so the oracle's crossHeld is compared through that rule.
usage: python buttons_vs_glue.py <button_oracle.exe> <godot> <engine dir> <work dir> [frames] [seed]"""
import subprocess, sys, os
exe, godot, engine, work = sys.argv[1:5]
n = sys.argv[5] if len(sys.argv) > 5 else "6000"; seed = sys.argv[6] if len(sys.argv) > 6 else "7"
here = os.path.dirname(os.path.abspath(__file__))
inp = os.path.join(work, "glue_in.txt"); outp = os.path.join(work, "glue_out.txt")
subprocess.run([godot, "--headless", "--path", engine, "--script", os.path.join(here, "buttons_glue.gd"), "--", f"--frames={n}", f"--seed={seed}",
                f"--in={inp}", f"--out={outp}"], capture_output=True)
rows = open(inp).read().split("\n"); rows = [r for r in rows if r]
ref = subprocess.run([exe], input=("\n".join(rows) + "\n").encode(), capture_output=True).stdout.decode().split("\n")
ref = [r.split() for r in ref if r]
glue = [r.split() for r in open(outp).read().split("\n") if r]
diff = []
counts = [0] * 5
for row, a, b in zip(rows, ref, glue):
    carrying = row.split()[4] == "1"
    want = [a[1], a[2], a[3], a[4], "1" if (a[5] == "1" and not carrying) else "0"]
    got = b[1:6]
    for k in range(5): counts[k] += int(got[k])
    if want != got: diff.append((a[0], want, got))
ok = len(rows) > 0 and len(ref) == len(glue) == len(rows) and not diff
print(f"{'PASS' if ok else 'FAIL'} buttons vs glue: {len(rows)} frames of a real match, thirdjam's resolver = K1's glue on {len(rows) - len(diff)}; "
      f"glue frames with shootHeld {counts[0]}, passHeld {counts[1]}, check {counts[2]}, lift {counts[3]}, crossHold {counts[4]}"
      + (f"; first difference frame {diff[0][0]}: thirdjam {diff[0][1]} glue {diff[0][2]} ({len(diff)} frames differ)" if diff else ""))
sys.exit(0 if ok else 1)
