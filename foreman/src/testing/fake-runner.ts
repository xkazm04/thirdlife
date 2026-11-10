#!/usr/bin/env node
// Executable form of the fake runner. Point TL_GODOT at the compiled file (dist/testing/fake-runner.js):
// the verifier runs a .js or .mjs TL_GODOT with the current Node executable.
// FAKE_RUNNER_DELAY_MS slows every call down (used by the kill-and-resume test).
import { fakeRunner } from "./fake-runner-core.js";

const delay = Number(process.env["FAKE_RUNNER_DELAY_MS"] ?? "0");
const out = fakeRunner(process.argv.slice(2), process.env);
const done = (): void => {
  if (out.hang) {
    setInterval(() => {}, 1 << 30);
    return;
  }
  process.stdout.write(out.stdout, () => process.exit(out.exitCode));
};
if (delay > 0) setTimeout(done, delay);
else done();
