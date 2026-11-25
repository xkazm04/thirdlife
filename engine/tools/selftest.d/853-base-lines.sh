# A pack started from a base counts only its own game lines against lint's 6,000 (lane E3g, 25 Nov; E5c's real job 3:
# the rink_game base alone is 5,943 of the 6,000, so its `banks` script package overflowed and asked the person whether
# the limit may be raised). A pack declares its base in pack.json ("base": "rink_game", a directory of engine/templates/);
# a line the base's file at the same path holds is the base's (kernel/runner/lint_base.gd). One copy of the base, changed
# between the cases:
#   base.lines_own_500      the base + 500 lines of its own in two new scripts: lint.size ok, the detail says 500 own
#   base.lines_undeclared   the same files without "base": 6,443 game lines, lint.size fails (the rule before E3g)
#   base.lines_own_6001     the base + 6,001 own lines: lint.size fails and says "6001 lines of game GDScript of its own"
#   base.lines_edited       the base + 5,995 own lines passes; 10 lines changed in the base's scripts/main.gd fail it
#   base.lines_unknown      "base": "no_such_base" is a layout error
bl_t="$HERE/../templates/rink_game"
bl_o="$OUT/base_lines/pack"
bl_cases="base.lines_own_500 base.lines_undeclared base.lines_own_6001 base.lines_edited base.lines_unknown"
bl_want=0; for c in $bl_cases; do if [ -z "$FILTER" ] || [[ "$c" == *"$FILTER"* ]]; then bl_want=1; fi; done
if [ "$bl_want" = 1 ]; then
  rm -rf "$OUT/base_lines"; mkdir -p "$OUT/base_lines"; cp -r "$bl_t" "$bl_o"; find "$bl_o" -name "*.uid" -delete
  bl_n="$bl_o"; if command -v cygpath >/dev/null 2>&1; then bl_n="$(cygpath -m "$bl_n")"; fi
  # bl_set <base or ""> : pack.json with (or without) the base key
  bl_set() { node -e 'const fs=require("fs"),f=process.argv[1]+"/pack.json",m=JSON.parse(fs.readFileSync(f,"utf8"));if(process.argv[2])m.base=process.argv[2];else delete m.base;fs.writeFileSync(f,JSON.stringify(m,null,2)+"\n")' "$bl_n" "$1"; }
  # bl_own <total> : that many own comment lines in new scripts/own_<k>.gd files of at most 550 lines each
  bl_own() { rm -f "$bl_o"/scripts/own_*.gd; node -e 'const fs=require("fs");let n=+process.argv[2],k=0;while(n>0){const c=Math.min(550,n);let s="extends RefCounted\n";for(let i=1;i<c;i++)s+="# own line "+k+"."+i+"\n";fs.writeFileSync(process.argv[1]+"/scripts/own_"+k+".gd",s);n-=c;k++}' "$bl_n" "$1"; }
  bl_set rink_game; bl_own 500
  check base.lines_own_500 0 lint "--pack=$bl_n" -- '"id":"lint.size","ok":true,"detail":"[0-9]+ lines of GDScript \(500 game lines of its own over the base rink_game\)'
  bl_set ""
  check base.lines_undeclared 1 lint "--pack=$bl_n" -- '"id":"lint.size","ok":false' '"message":"6443 lines of game GDScript \(scripts/, gen/; at most 6000\)'
  bl_set rink_game; bl_own 6001
  check base.lines_own_6001 1 lint "--pack=$bl_n" -- '"id":"lint.size","ok":false' '"message":"6001 lines of game GDScript of its own \(scripts/, gen/; at most 6000; 5943 more are the base templates/rink_game/ unchanged, not counted\)'
  if [ -z "$FILTER" ] || [[ "base.lines_edited" == *"$FILTER"* ]]; then
    bl_own 5995
    check base.lines_edited_before 0 lint "--pack=$bl_n" -- '"id":"lint.size","ok":true' '5995 game lines of its own'
    # ten lines of the base's main.gd changed in place (a comment tag on each of its first ten "var " lines)
    node -e 'const fs=require("fs"),f=process.argv[1]+"/scripts/main.gd";let k=0;fs.writeFileSync(f,fs.readFileSync(f,"utf8").replace(/\r\n/g,"\n").split("\n").map(l=>(k<10&&/^var /.test(l))?(k++,l+"  # edited"):l).join("\n"))' "$bl_n"
    check base.lines_edited 1 lint "--pack=$bl_n" -- '"id":"lint.size","ok":false' '"message":"6005 lines of game GDScript of its own'
    cp "$bl_t/scripts/main.gd" "$bl_o/scripts/main.gd"
  fi
  bl_set no_such_base; bl_own 10
  check base.lines_unknown 1 lint "--pack=$bl_n" -- '"id":"lint.layout","ok":false' '"kind":"layout","file":"pack.json","message":"declares the base .no_such_base., but the engine has no templates/no_such_base/'
fi
