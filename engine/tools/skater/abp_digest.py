"""Reads an AnimBlueprint exported as T3D text (engine/tools/skater/export_driver_text.py) and writes its animation
graph as a listing:   python abp_digest.py <file.t3d> <out.txt>
- the main AnimGraph as a pose tree from the output pose back to its sources, each node with the settings that matter
  (sequence, blend space, play rate, loop, blend times, bone, slot) and the expressions that feed its pins;
- every state machine: its states (each state's pose tree) and its transitions (from, to, the rule as an expression,
  the cross-fade, the automatic-rule flag, the priority).
A listing, not source: node names are kept so a line can be found in the T3D."""
import re
import sys

src, out_path = sys.argv[1], sys.argv[2]
DEF = re.compile(r'^\s*Begin Object Name="([^"]+)" ExportPath="([^\']+)\'([^\']+)\'"')
nodes = {}        # full path after ':' -> node
by_graph = {}     # graph path -> {name: node}
stack = []
with open(src, encoding="utf-8", errors="replace") as f:
    for line in f:
        m = DEF.match(line)
        if m:
            name, cls, path = m.group(1), m.group(2).rsplit(".", 1)[-1], m.group(3)
            tail = path.split(":", 1)[1] if ":" in path else name
            graph = tail.rsplit(".", 1)[0] if "." in tail else ""
            cur = {"cls": cls, "props": {}, "pins": [], "graph": graph, "name": name, "path": tail}
            nodes[tail] = cur
            by_graph.setdefault(graph, {})[name] = cur
            stack.append(cur)
            continue
        s = line.strip()
        if s == "End Object":
            if stack:
                stack.pop()
            continue
        if s.startswith("Begin Object"):
            stack.append(None)
            continue
        cur = stack[-1] if stack else None
        if cur is None:
            continue
        if s.startswith("CustomProperties Pin ("):
            body = s[len("CustomProperties Pin ("):-1]
            pin = {}
            for key in ("PinId", "PinName", "Direction", "PinType.PinCategory", "DefaultValue", "DefaultObject"):
                mm = re.search(r'(?:^|,)' + re.escape(key) + r'=("(?:[^"\\]|\\.)*"|[^,()]*)', body)
                if mm:
                    pin[key] = mm.group(1).strip('"')
            mm = re.search(r'PinType\.PinSubCategoryObject="?[^,]*?\.([A-Za-z0-9_]+)\'?"?,', body)
            pin["sub"] = mm.group(1) if mm else ""
            mm = re.search(r'LinkedTo=\(([^)]*)\)', body)
            pin["links"] = [tuple(x.split(" ")) for x in mm.group(1).split(",") if x.strip()] if mm else []
            pin["out"] = pin.get("Direction") == "EGPD_Output"
            pin["hidden"] = ",bHidden=True," in body
            pin["pose"] = pin["sub"] in ("PoseLink", "ComponentSpacePoseLink")
            cur["pins"].append(pin)
        elif "=" in s:
            k, v = s.split("=", 1)
            cur["props"][k] = v


def member(node, key):
    m = re.search(r'MemberName="([^"]+)"', node["props"].get(key, ""))
    return m.group(1) if m else ""


def find(graph, name, pin_id):
    n = by_graph.get(graph, {}).get(name)
    if n is None:
        return None, None
    for p in n["pins"]:
        if p.get("PinId") == pin_id:
            return n, p
    return n, None


OPS = {"Add": "+", "Subtract": "-", "Multiply": "*", "Divide": "/", "Less": "<", "Greater": ">", "LessEqual": "<=", "GreaterEqual": ">=",
       "EqualEqual": "==", "NotEqual": "!=", "BooleanAND": "and", "BooleanOR": "or"}


def expr(graph, pin, depth=0):
    if not pin["links"]:
        v = pin.get("DefaultValue")
        if v is None or v == "":
            v = pin.get("DefaultObject") or ""
            if v:
                v = v.rsplit(".", 1)[-1].strip("'")
            else:
                cat = pin.get("PinType.PinCategory", "")
                v = "0" if cat in ("int", "int64", "real", "float", "double", "byte") else "false" if cat == "bool" else "<none>"
        return v
    sn, sp = find(graph, pin["links"][0][0], pin["links"][0][1])
    if sn is None:
        return "?" + pin["links"][0][0]
    if sn["cls"] == "K2Node_VariableGet":
        return member(sn, "VariableReference")
    name = member(sn, "FunctionReference") or sn["cls"].replace("K2Node_", "")
    args = [expr(graph, p, depth + 1) for p in sn["pins"]
            if not p["out"] and p.get("PinType.PinCategory") != "exec" and not ((p.get("PinName") in ("self",) or p["hidden"]) and not p["links"])] if depth < 12 else ["..."]
    op = OPS.get(name.split("_")[0])
    if op and len(args) >= 2:
        return "(" + (" %s " % op).join(args) + ")"
    if name.startswith("Not_PreBool") and len(args) == 1:
        return "(not %s)" % args[0]
    if sn["cls"] == "K2Node_TransitionRuleGetter":
        return "%s(%s)" % (sn["props"].get("GetterType", "getter"), sn["props"].get("AssociatedAnimAssetPlayerNode", "").rsplit(".", 1)[-1].strip("'\""))
    return "%s(%s)" % (name, ", ".join(args))


KEEP = ("Sequence", "BlendSpace", "PlayRate", "bLoopAnimation", "StartPosition", "BlendTime", "BlendType", "bActiveValue", "Alpha", "AlphaScaleBias",
        "BoneToModify", "Rotation", "RotationMode", "RotationSpace", "Translation", "TranslationMode", "SlotName", "LayerSetup", "BlendWeights",
        "bMeshSpaceRotationBlend", "X", "Y", "bResetPlayTimeWhenBlendSpaceChanges", "PlayRateBasis", "CachePoseName", "Name")


def settings(n):
    raw = n["props"].get("Node", "")
    outp = []
    for k in KEEP:
        m = re.search(r'(?:\(|,)' + k + r'=("(?:[^"\\]|\\.)*"|\((?:[^()]|\([^()]*\))*\)|[^,()]*)', raw)
        if m:
            v = m.group(1)
            v = re.sub(r"/Script/[A-Za-z]+\.[A-Za-z0-9_]+'[^']*\.([A-Za-z0-9_]+)'", r"\1", v).strip('"')
            outp.append("%s=%s" % (k, v[:160]))
    return outp


def pose_tree(graph, n, lines, indent, seen):
    pad = "  " * indent
    cls = n["cls"].replace("AnimGraphNode_", "")
    data = []
    for p in n["pins"]:
        if p["out"] or p["pose"] or p.get("PinType.PinCategory") == "exec":
            continue
        if p["links"] or (p.get("DefaultValue") not in (None, "") and not p["hidden"]):
            data.append("%s=%s" % (p.get("PinName"), expr(graph, p)))
    extra = ""
    if n["cls"] == "AnimGraphNode_StateMachine":
        extra = " machine=" + n["props"].get("EditorStateMachineGraph", "").rsplit(".", 1)[-1].strip("'\"")
    if n["cls"] in ("AnimGraphNode_UseCachedPose", "AnimGraphNode_SaveCachedPose"):
        extra = " cache=" + (n["props"].get("CacheName", "") or n["props"].get("SaveCachedPoseNode", "").rsplit(".", 1)[-1]).strip("'\"")
    lines.append("%s%s [%s]%s %s%s" % (pad, cls, n["name"].replace("AnimGraphNode_", ""), extra, "; ".join(settings(n)), ("  <- " + "; ".join(data)) if data else ""))
    if n["path"] in seen:
        lines.append(pad + "  (already listed)")
        return
    seen.add(n["path"])
    for p in n["pins"]:
        if p["out"] or not p["pose"]:
            continue
        if not p["links"]:
            lines.append("%s  %s: (nothing)" % (pad, p.get("PinName")))
            continue
        sn, _ = find(graph, p["links"][0][0], p["links"][0][1])
        lines.append("%s  %s:" % (pad, p.get("PinName")))
        if sn is not None:
            pose_tree(graph, sn, lines, indent + 2, seen)


lines = []
# the main graph and every state graph: start at the node that has pose inputs and no pose output linked
for graph in sorted(by_graph):
    ns = by_graph[graph]
    roots = [n for n in ns.values() if n["cls"] in ("AnimGraphNode_Root", "AnimGraphNode_StateResult", "AnimGraphNode_SaveCachedPose")]
    if not roots:
        continue
    lines.append("")
    lines.append("=== graph %s" % (graph or "(top)"))
    for r in roots:
        pose_tree(graph, r, lines, 1, set())

lines.append("")
lines.append("=== transitions")
for path, n in sorted(nodes.items()):
    if n["cls"] != "AnimStateTransitionNode":
        continue
    graph = n["graph"]
    ends = {}
    for p in n["pins"]:
        for link in p["links"]:
            tn = by_graph.get(graph, {}).get(link[0])
            if tn is not None:
                ends["to" if p["out"] else "from"] = tn["props"].get("BoundGraph", tn["name"]).rsplit("'", 2)[-2] if "BoundGraph" in tn["props"] else tn["name"]
    rule = "?"
    tg = path + ".Transition"
    for rn in by_graph.get(tg, {}).values():
        if rn["cls"] == "AnimGraphNode_TransitionResult":
            for p in rn["pins"]:
                if p.get("PinName") == "bCanEnterTransition":
                    rule = expr(tg, p)
    pr = n["props"]
    lines.append("  %-14s -> %-14s when %s   [crossfade=%s automatic=%s priority=%s mode=%s logic=%s] (%s)" % (
        ends.get("from", "?"), ends.get("to", "?"), rule, pr.get("CrossfadeDuration", "default"),
        pr.get("bAutomaticRuleBasedOnSequencePlayerInState", "False"), pr.get("PriorityOrder", "1"), pr.get("BlendMode", "default"),
        pr.get("LogicType", "default"), n["name"]))

with open(out_path, "w", encoding="utf-8", newline="\n") as f:
    f.write("# animation graph of %s\n" % src.replace("\\", "/").rsplit("/", 1)[-1])
    f.write("\n".join(lines) + "\n")
print("graphs %d, nodes %d, lines %d -> %s" % (len(by_graph), len(nodes), len(lines), out_path))
