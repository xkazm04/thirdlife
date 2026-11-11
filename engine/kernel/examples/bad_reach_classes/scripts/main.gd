extends Node
## N4 hole: engine classes that read or write files, open the network or reach past the kernel, and that the
## contract's list did not name. Every line from "FENCE BEGIN" to "FENCE END" holds exactly one of them.

var img: Image
var sound: AudioStreamWAV


func _pack_setup(_ctx) -> void:
	pass


func _pack_start() -> void:
	pass


func reach() -> void:
# FENCE BEGIN
	var a = ResourceLoader.exists("x")
	var b = ConfigFile.new()
	var c = ZIPReader.new()
	var d = ZIPPacker.new()
	var e = PCKPacker.new()
	var f = XMLParser.new()
	var g = Image.load_from_file("x")
	img.save_png("x")
	var i = MultiplayerAPI.create_default_interface()
	var j = ENetMultiplayerPeer.new()
	var k = WebRTCPeerConnection.new()
	var l = Crypto.new()
	var m = DisplayServer.window_get_size()
	var n = RenderingServer.get_video_adapter_name()
	var o = PhysicsServer3D.get_process_info(0)
	var p = AudioServer.get_output_device_list()
	var q = Performance.get_monitor(0)
	var r = Input.is_anything_pressed()
	var s = Engine.get_main_loop()
	var t = Time.get_datetime_dict_from_system()
	var u = PackedScene.new()
	var v = Marshalls.base64_to_variant("x", true)
	var w = InputMap.get_actions()
	var x = RenderingDevice.new()
	var y = IP.resolve_hostname("x")
	var z = CameraServer.feeds()
	var aa = AudioStreamMicrophone.new()
	var ab = GDExtensionManager.get_loaded_extensions()
	var ac = GLTFDocument.new()
	var ad = FontFile.new().load_dynamic_font("x")
	var ae = WebSocketMultiplayerPeer.new()
	var af = ENetPacketPeer.new()
	var ag = UPNP.new()
	var ah = JavaClassWrapper.wrap("x")
	var ai = EngineDebugger.is_active()
	var aj = FileDialog.new()
	var ak = LinkButton.new()
	var al = HashingContext.new()
	var am = multiplayer.get_unique_id()
	rpc("x")
	sound.save_to_wav("x")
# FENCE END
	var fine = Image.create(4, 4, false, Image.FORMAT_RGB8)
