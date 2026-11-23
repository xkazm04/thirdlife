# K3 shell, round 6: thirdjam's figures on the ice

- Every skater is K2's figure (TLRigSkater) driven by thirdjam's pawn (skater_pawn.gd), one a skater, fed its snapshot
  entry each frame in StepOnce's order; team colours from the cartridge, jersey numbers by JerseyNumberFor. The capsules
  stay behind `data/view.json` figures false. The puck is where the sim has it until K2's shown carrier.
- Hit-stop goes to the pawns (BeginHitStop on victim and checker) and to the puck by AJamPuck's own hold (ported).
- Kernel 1.20: `ctx.cores.view_script(id, name)`, because lint N4 lets no pack load under res://cores/.
- The match hash is round 5's (ab881a00fb9af8ef; idle ad03a2add6ce42c1 with figures and with capsules). Export check
  headless PASS (hokej 6e9c32c23eaf3d45 editor = exe).
- Cost: headless pack tick p50 about 2.2 ms with figures against 0.5 ms; in a window (uncapped) 3.57 ms a frame against
  1.30 ms. FINDING: invariants' many-budget fails (p50 2.70 ms over 1.0 ms).
- Looked at (r6_sbs_film_20s.mp4 and sheets): scale right; the boards view brings the eye 0.6-0.9 m over a stopped
  skater's helmet for two seconds (thirdjam's camera, no figure fade in thirdjam); bodies overlap at contact (hits play as
  skating); shadows faint; blank number patches; the carried puck a stick's length off the blade (shown carrier).
