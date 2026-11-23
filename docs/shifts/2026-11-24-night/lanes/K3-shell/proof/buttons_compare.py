#!/usr/bin/env python3
"""K3 round 3: a seeded stream of the five two-role keys (presses, holds, taps inside a frame, releases) under a changing
possession (with the puck / carrying / in reach), fed to thirdjam's own FJamButtonResolver (button_oracle.exe, compiled from
its source) and to the pack's port (buttons_port.gd); every frame's FJamButtonVerbs must be equal.
usage: python buttons_compare.py <button_oracle.exe> <godot> <engine dir> <work dir> [frames] [seed]"""
import random, subprocess, sys, os
exe, godot, engine, work = sys.argv[1:5]
n = int(sys.argv[5]) if len(sys.argv) > 5 else 20000
rng = random.Random(int(sys.argv[6]) if len(sys.argv) > 6 else 7)
down = 0; poss = 0; carrying = 0; reach = 0; rows = []
for f in range(1, n + 1):
    pressed = 0
    for i in range(5):
        bit = 1 << i
        if down & bit:
            if rng.random() < 0.06: down &= ~bit                     # released
        elif rng.random() < 0.03:
            pressed |= bit                                           # a press...
            if rng.random() < 0.85: down |= bit                      # ...held on, or a tap released inside the frame
    if rng.random() < 0.03: poss = 1 - poss                          # the possession changes under the keys
    carrying = poss if rng.random() < 0.8 else 0
    reach = 1 if rng.random() < 0.5 else 0
    rows.append(f"{f} {down} {pressed} {poss} {carrying} {reach} 0 3")   # saucer delay 0 (pass.power on), brace delay 3 (13 - 10)
stream = os.path.join(work, 'buttons_stream.txt'); open(stream, 'w').write("\n".join(rows) + "\n")
ref = subprocess.run([exe], input=open(stream, 'rb').read(), capture_output=True).stdout.decode().split()
port_out = os.path.join(work, 'buttons_port.txt')
subprocess.run([godot, '--headless', '--path', engine, '--script', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'buttons_port.gd'), '--',
                f'--in={stream}', f'--out={port_out}'], capture_output=True)
port = open(port_out).read().split()
ref_l = [ref[i:i + 6] for i in range(0, len(ref), 6)]; port_l = [port[i:i + 6] for i in range(0, len(port), 6)]
diff = [(a, b) for a, b in zip(ref_l, port_l) if a != b]
counts = [sum(int(r[k]) for r in ref_l) for k in range(1, 6)]
ok = len(ref_l) == n and len(port_l) == n and not diff
print(f"{'PASS' if ok else 'FAIL'} buttons: {len(port_l)} of {n} frames, thirdjam's resolver = the port on {n - len(diff)}; "
      f"frames with shootHeld {counts[0]}, passHeld {counts[1]}, check {counts[2]}, lift {counts[3]}, crossHeld {counts[4]}"
      + (f"; first difference {diff[0]}" if diff else ""))
sys.exit(0 if ok else 1)
