// `tl hook install|remove|status`: the pre-push hook that runs the gate. Works in a worktree (hooks live in the common git dir).
import fs from "node:fs";
import path from "node:path";
import { run as sh, REPO } from "../ctx.mjs";

export const summary = "install/remove/status of the pre-push hook that runs `tl check`";
export const MARKER = "# tl-devx-managed-hook v1 (written by `tl hook install`; remove with `tl hook remove`)";

export const HOOK_SCRIPT = `#!/bin/sh
${MARKER}
# Runs the gate before a push; a FAIL stops the push. TL_PUSH_TIER=full for the full tier (default fast). git push --no-verify skips it.
ROOT="$(git rev-parse --show-toplevel)" || exit 0
TL="$ROOT/devx/bin/tl.mjs"
if [ ! -f "$TL" ]; then echo "tl pre-push: $TL not found in this checkout; not gating"; exit 0; fi
TIER="\${TL_PUSH_TIER:-fast}"
echo "tl pre-push: node devx/bin/tl.mjs check --tier $TIER"
node "$TL" check --tier "$TIER" || { echo "tl pre-push: gate FAILED, push stopped (override once: git push --no-verify)"; exit 1; }
`;

export function hookPath(repo) {
  const r = sh("git", ["rev-parse", "--git-path", "hooks"], { cwd: repo });
  if (r.code !== 0) throw new Error(`not a git repository: ${repo}`);
  return path.join(path.resolve(repo, r.stdout.trim()), "pre-push");
}

/** -> {ok, message, path}; actions: install | remove | status */
export function hookAction(action, repo = REPO) {
  let file;
  try { file = hookPath(repo); } catch (e) { return { ok: false, message: e.message }; }
  const exists = fs.existsSync(file);
  const ours = exists && fs.readFileSync(file, "utf8").includes("tl-devx-managed-hook");
  if (action === "status") return { ok: true, path: file, message: !exists ? `not installed (${file})` : ours ? `installed (${file})` : `a foreign pre-push hook is present (${file}); tl will not touch it` };
  if (action === "install") {
    if (exists && !ours) return { ok: false, path: file, message: `refusing to overwrite a pre-push hook tl did not write: ${file}` };
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, HOOK_SCRIPT, { mode: 0o755 });
    try { fs.chmodSync(file, 0o755); } catch { /* windows */ }
    return { ok: true, path: file, message: `installed ${file}` };
  }
  if (action === "remove") {
    if (!exists) return { ok: true, path: file, message: "nothing to remove" };
    if (!ours) return { ok: false, path: file, message: `refusing to remove a pre-push hook tl did not write: ${file}` };
    fs.rmSync(file);
    return { ok: true, path: file, message: `removed ${file}` };
  }
  return { ok: false, message: "usage: tl hook install|remove|status" };
}

export async function run(args) {
  const r = hookAction(args[0] ?? "");
  (r.ok ? console.log : console.error)(r.message);
  return r.ok ? 0 : (["install", "remove", "status"].includes(args[0]) ? 1 : 2);
}
