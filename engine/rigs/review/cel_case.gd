extends "res://rigs/review/clay_case.gd"
## Exercise the real dispatcher, including a style switch with a biped in the build queue.


func _run() -> void:
	var crisp := "res://style/style_crisp.json"
	var params := {"backpack":false}
	_expect(TLStyle.load_style(TLStyle.DEFAULT_PATH).is_empty(),"classic load")
	var classic := TLRigs.build("biped",params) as TLRigNode
	var baseline := _mesh(classic).get_meta(&"tl_hash") as String
	var names := (classic.get_node("Model/Skeleton3D") as Skeleton3D).get_concatenated_bone_names()
	var clips := classic.clips()
	classic.free()
	var classic_key := TLRigs._rig_ahead("biped",params)
	_expect(TLStyle.load_style(crisp).is_empty(),"crisp load")
	var cel := TLRigs.build("biped",params) as TLRigNode
	var red := _mesh(cel).get_meta(&"tl_hash") as String
	_expect(cel.get_script() == preload("res://rigs/biped/cel_rig.gd"),"queued classic used for cel")
	_expect(red != baseline and _has_coat(cel),"distinct walking coat")
	cel.set_param("colors",{"top":"car_blue"})
	_expect(_mesh(cel).get_meta(&"tl_hash") != red,"blue team colour")
	cel.set_param("colors",{})
	_expect(_mesh(cel).get_meta(&"tl_hash") == red,"restore red")
	root.add_child(cel)
	var bar := _grip_error(cel,&"swing",Vector3(0,2.2,0))
	var stick := _stick_error(cel)
	_expect(bar < .012 and stick < .025,"hand targets")
	cel.free()
	var min_tris := 12000
	var max_tris := 0
	var count := 0
	for mode: String in ["walk","skate"]:
		for pack: bool in [false,true]:
			for head: String in ["auto","helmet","none"]:
				var rig := TLRigs.build("biped",{"mode":mode,"backpack":pack,"headgear":head}) as TLRigNode
				var metrics := rig.metrics()
				var skin := rig.get_node("Model/Skeleton3D") as Skeleton3D
				var tris := _drawn_tris(rig)
				_expect(skin.get_bone_count()==29 and skin.get_concatenated_bone_names()==names,"bone names")
				_expect(rig.clips()==clips and metrics.height==2.0 and metrics.radius==.3,"clips and size")
				for socket: String in ["hand_l","hand_r","head","back"]:
					_expect(rig.socket(socket)!=null,"socket "+socket)
				_expect(tris > 0 and tris==metrics.triangles and tris<=12000,"wardrobe triangles")
				_expect(_has_coat(rig)==(mode=="walk"),"team uniform")
				min_tris = mini(min_tris,tris)
				max_tris = maxi(max_tris,tris)
				count += 1
				rig.free()
	var cel_key := TLRigs._rig_ahead("biped",params)
	TLStyle.load_style(TLStyle.DEFAULT_PATH)
	classic = TLRigs.build("biped",params)
	_expect(_mesh(classic).get_meta(&"tl_hash")==baseline,"classic restored")
	_expect(not TLRigs._drop_rig(classic_key) and TLRigs._drop_rig(cel_key),"build queue isolation")
	classic.free()
	print("CEL_FIGURE ok=%s wardrobes=%d tris=%d..%d bones=29 clips=%d height=2.0 radius=0.3 grip_m=%.5f/%.5f errors=%s" %
		[failures.is_empty(),count,min_tris,max_tris,clips.size(),bar,stick,failures])
	quit(0 if failures.is_empty() else 1)
