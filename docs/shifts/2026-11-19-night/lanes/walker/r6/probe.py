"""Run the r3 terrain tools from the worktree root, with all captures under r6/raw."""
from pathlib import Path
import sys
import types

HERE = Path(__file__).resolve().parent
R3 = HERE.parent / "r3" / "terrain"
RAW = HERE / "raw"
OLD = "c8b88fc683b057c5523c883efd07ffc84c95ae2e"


def run(tool, *, module="__main__", candidate="after"):
    path = R3 / (tool + ".py")
    source = path.read_text()
    # The original tools use their own directory for both inputs and output.
    # Redirect only the immutable inputs and make the historical HEAD explicit.
    for name in ("sample.gd.txt", "r3-before.gdshader.txt", "r3b-reviewed.gdshader.txt"):
        source = source.replace(f'here / "{name}"', f'Path({str(R3 / name)!r})')
    source = source.replace("here.parent.as_posix()", repr(R3.parent.as_posix()))
    source = source.replace("HEAD:engine", OLD + ":engine").replace('"HEAD:"+source_file', repr(OLD + ":") + "+source_file")
    if tool == "capture":
        source = source.replace('if stage not in ("head", "before", "r3b", "after"):', 'if not stage.isidentifier():')
    if tool in ("strong", "verify"):
        # The middle comparison is r6's starting shader. Compare the candidate
        # to the very same strong mask, plane and geometry as the original tools.
        source = source.replace('"r3b"', '"baseline"').replace('"after"', repr(candidate))
        if tool == "verify":
            source = source.replace('p/"r3b-reviewed.gdshader.txt"', f'Path({str(RAW / "baseline.gdshader.txt")!r})')
            if candidate != "after":
                source = source.replace("Path(source_file).read_text()", f"Path({str(RAW / (candidate + '.gdshader.txt'))!r}).read_text()")
    obj = types.ModuleType(module)
    obj.__file__ = str(RAW / path.name)
    sys.modules[module] = obj
    exec(compile(source, str(path), "exec"), obj.__dict__)


if __name__ == "__main__":
    RAW.mkdir(exist_ok=True)
    tool = sys.argv.pop(1)
    candidate = sys.argv[1] if len(sys.argv) > 1 else "after"
    if tool == "band":
        run("measure", module="measure")
    elif tool in ("strong", "verify"):
        sys.argv[1:] = ["head" if tool == "strong" else candidate]
        run("measure", module="measure")
    run(tool, candidate=candidate)
