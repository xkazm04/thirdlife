import json, os
v = json.load(open('../engine/boot/village.json'))
for p in v['plots']:
    if p['pack'] == 'ice_hockey_three_against': p['pack'] = 'hockey'
L = {  # name: (start, toward)
 'walker': ((-112, 0, 6), (-114, 0, -20)), 'drive': ((22, 0, 4), (12, 0, -20)), 'wall': ((142, 0, 6), (134, 0, -20)),
 'paddle': ((-118, 0, 2), (-123, 0, 20)), 'kit': ((-14, 0, 2), (-19, 0, 20)), 'car': ((91, 0, 2), (86, 0, 20)),
 'hockey': ((199, 0, 4), (195, 0, 20)), 'parkour': ((-176, 0, 8), (-184, 0, -10)),
 'site_crates': ((246, 0, 6), (241, 0, -20)), 'site_hockey': ((300, 0, 8), (306, 0, 30)),
}
os.makedirs('visits', exist_ok=True)
for n, (a, b) in L.items():
    w = json.loads(json.dumps(v)); w['name'] = 'blend2_' + n; w['ticks'] = 2000
    w['note'] = 'Lane blend round 2: a person at lot ' + n + ' (walk in, along the edge, fly over).'
    w['events'] = []; w['player'] = [[0, list(a)], [60, list(b)]]
    json.dump(w, open('visits/%s.json' % n, 'w'), indent=1)
dev = [[20,"move",0,0],[30,"key","W",1],[120,"shot","1_walk_in",0],[250,"shot","2_at_edge",0],[300,"key","W",0],
       [305,"move",420,0],[320,"key","W",1],[321,"key","Shift",1],[400,"shot","3_along_edge",0],[470,"shot","4_along_edge",0],
       [480,"key","Shift",0],[490,"key","F",1],[492,"key","F",0],[500,"key","Space",1],[560,"shot","5_fly_low",0],[620,"key","Space",0],
       [625,"move",-700,0],[660,"shot","6_fly_30m",0],[700,"key","Space",1],[740,"key","Space",0],[760,"shot","7_fly_high",0],[800,"key","W",0],
       [820,"key","Escape",1],[825,"key","Escape",0]]
json.dump(dev, open('visits/devices.json', 'w'))
print(len(L), 'visits')
