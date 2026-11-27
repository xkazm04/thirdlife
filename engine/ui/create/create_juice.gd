extends RefCounted
## S2-juice arm B (juice day, 27 Nov 2026): the two "make it juicy" controls of Create's done screen, drawn on the page
## (create_build.gd calls these; kept here so the page stays under its size budget). The Foreman runs the standard juice
## pass only on a change whose words say "make it juicy" (foreman/src/juicepass.ts, JUICE_MODE "choice").

const Model = preload("res://ui/create/create_model.gd")
const Kit = preload("res://ui/create/create_kit.gd")


## The one-click follow-up beside Play: the person's last change added a move that was built plain (the Foreman's
## "juice pass offered" note); one click sends "Make it juicy: the move I just added (...)".
static func follow_up(page: Control, job: Dictionary, at: Vector2, h: float) -> void:
	var jf: Button = page.call("_button", "JuicyFollowUp", "Juice that move", "power", Kit.ORANGE, at, Vector2(320, h), 26)
	jf.tooltip_text = "Give the move you just added a tell, an impact word, a camera kick and a slow beat"
	jf.pressed.connect(func() -> void: page.call("_send", Model.juicy_follow_up(job)))
	(page.get("_body") as Control).add_child(jf)


## The card on the change row: off until picked; picked, the next change ends "Make it juicy." (send_change).
static func card(page: Control, at: Vector2) -> void:
	var on: bool = bool(page.get("juicy"))
	var jc: Button = page.call("_button", "JuicyCard", "Make it juicy", "check" if on else "power", Kit.HONEY_LIGHT if on else Kit.CREAM, at + Vector2(505, 0), Vector2(240, 80), 22)
	jc.tooltip_text = "A tell that grows, an impact word, a camera kick, a slow beat on the big moment"
	jc.pressed.connect(func() -> void:
		page.set("juicy", not bool(page.get("juicy")))
		page.call("_rebuild"))
	(page.get("_body") as Control).add_child(jc)
	if on:
		page.call("_place", page.call("_label", "Juicy: a tell that grows, an impact word mid-screen, hit-stop and a camera kick, a slow beat on the big moment", 17, 650, Kit.HONEY_LIGHT, Kit.W, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 666))
