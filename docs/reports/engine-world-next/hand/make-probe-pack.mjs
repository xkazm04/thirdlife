// Lane C2 measurement: copies a pack to <out>, adds the probe bot and one ladder cell per hand
// (tests/bot_ladder_<level>_<hand>.gd, the names `tl ladder` reads), and lists them in the copy's pack.json.
// usage: node make-probe-pack.mjs <pack dir> <probe.gd> <level> <out dir> [hands=idle,newcomer,regular,sharp,perfect]
import fs from "node:fs";
import path from "node:path";
const [src, probe, level, out, handsArg] = process.argv.slice(2);
const hands = (handsArg ?? "idle,newcomer,regular,sharp,perfect").split(",");
fs.rmSync(out, { recursive: true, force: true });
fs.cpSync(src, out, { recursive: true, filter: (p) => !p.includes(`${path.sep}.godot`) });
fs.mkdirSync(path.join(out, "tests"), { recursive: true });
const base = path.basename(probe).replace(/\.txt$/, ""); // probes are kept as .gd.txt (no uid outside a pack)
fs.copyFileSync(probe, path.join(out, "tests", base));
const man = JSON.parse(fs.readFileSync(path.join(out, "pack.json"), "utf8"));
for (const h of hands) {
  const name = `bot_ladder_${level}_${h}.gd`;
  fs.writeFileSync(path.join(out, "tests", name), `extends "${base}"\n## Lane C2 probe cell: the ${h} hand.\n\n\nfunc _init() -> void:\n\thand_profile = "${h}"\n`);
  man.tests.push(`tests/${name}`);
}
fs.writeFileSync(path.join(out, "pack.json"), JSON.stringify(man, null, 2) + "\n");
console.log(`probe pack ${out}: ${hands.length} cells`);
