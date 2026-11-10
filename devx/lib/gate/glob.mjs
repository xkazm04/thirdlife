// Tiny glob matcher (no deps) for step `paths`: `**` crosses directories, `*` and `?` stay inside one path segment.
// A trailing `/**` also matches the directory's contents at any depth; `**/` matches zero or more leading directories.
export function globToRegExp(glob) {
  let re = "";
  for (let i = 0; i < glob.length; i++) {
    const c = glob[i];
    if (c === "*") {
      if (glob[i + 1] === "*") {
        i++;
        if (glob[i + 1] === "/") { i++; re += "(?:.*/)?"; } else re += ".*";
      } else re += "[^/]*";
    } else if (c === "?") re += "[^/]";
    else re += c.replace(/[.+^${}()|[\]\\]/g, "\\$&");
  }
  return new RegExp("^" + re + "$");
}
export const matchGlob = (glob, p) => globToRegExp(glob).test(p.replace(/\\/g, "/"));
export const matchAny = (globs, p) => (globs ?? []).some((g) => matchGlob(g, p));
