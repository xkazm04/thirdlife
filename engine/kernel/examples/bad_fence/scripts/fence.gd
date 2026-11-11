class_name BadFenceExample
extends Node
## Every line from "FENCE BEGIN" to "FENCE END" holds exactly one fenced pattern; lint must report each with its line.
## The patterns in this comment (OS.get_name, FileAccess, randf() ) and in the string below must NOT be reported.

const NOT_CODE: String = "OS.execute and FileAccess.open and randi() inside a string are fine"

# FENCE BEGIN
@tool
var a = OS.get_name()
var b = FileAccess.open("x", 1)
var c = DirAccess.open("x")
var d = ResourceSaver.save(null, "x")
var e = ProjectSettings.get_setting("x")
var f = Engine.get_singleton("x")
var g = ClassDB.instantiate("Node")
var h = HTTPRequest.new()
var i = HTTPClient.new()
var j = StreamPeerTCP.new()
var k = TCPServer.new()
var l = UDPServer.new()
var m = PacketPeerUDP.new()
var n = WebSocketPeer.new()
var o = ENetConnection.new()
var p = Thread.new()
var q = Mutex.new()
var r = Semaphore.new()
var s = JavaScriptBridge.eval("1")
var t = Expression.new()
var u = GDScript.new()
var v = str_to_var("1")
var w = bytes_to_var(PackedByteArray())
var x = get_tree().root
var y = get_tree().change_scene_to_file("x")
var z = get_tree().quit()
var aa = Time.get_ticks_msec()
var ab = Time.get_unix_time_from_system()
var ac = randf()
var ad = randi()
var ae = randomize()
var af = load("res://kernel/runner/worker.gd")
var ag = preload("res://kernel/host/host.gd")
var ah = load("user://something.gd")
func _input(_e) -> void: pass
func _unhandled_input(_e) -> void: pass
# FENCE END
var ok1 = load("res://kernel/api/tl_laws.gd")
var ok2 = preload("main.gd")
