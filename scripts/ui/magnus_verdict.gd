class_name MagnusVerdict
extends CanvasLayer
## Cierre del trato con Magnus: al acabar el sueño aparece él, dice si has cumplido el objetivo,
## enseña las mejoras que te quedas (o que te quita) y lo que te devuelve. Funciona en pausa.
## Closing the deal with Magnus: when the dream ends he shows up, says whether you met the goal,
## shows the boosts you keep (or that he takes away) and what he pays back. Works while paused.

signal closed

const GiverFigure := preload("res://scripts/ui/astral_plane.gd").GiverFigure
const AURA := Color("4fd39a")

var _done := false
var _ready_t := 0.5


## result: "won" o "lost"; deal: el trato tal como estaba; progress: lo que llevabas del objetivo
## result: "won" or "lost"; deal: the deal as it was; progress: how far into the goal you got
func build(result: String, deal: Dictionary, progress: int) -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var won := result == "won"
	var root := Control.new()
	root.theme = UITheme.build()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(UITheme.INK, 0.82)
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	center.add_child(row)

	var fig := GiverFigure.new()
	fig.who = "magnus"
	fig.highlight = true
	var fig_px := PixelView.wrap(fig, 3)
	fig_px.custom_minimum_size = Vector2(460, 560)
	row.add_child(fig_px)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size.x = 760
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	col.add_child(UITheme.label("INVEST_CLOSE_TITLE", 56, UITheme.BONE, "display"))
	col.add_child(UITheme.label("GIVER_MAGNUS_NAME", 20, AURA, "caps"))
	col.add_child(UITheme.rule(Color(AURA, 0.5)))
	var line := UITheme.label("INVEST_CLOSE_WON" if won else "INVEST_CLOSE_LOST", 26, Color("7fe0d0"), "italic")
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(line)

	# El objetivo y cómo ha ido / The goal and how it went
	var goal_row := HBoxContainer.new()
	goal_row.add_theme_constant_override("separation", 14)
	col.add_child(goal_row)
	var stamp := UITheme.label("INVEST_STAMP_WON" if won else "INVEST_STAMP_LOST", 22, AURA if won else UITheme.EMBER, "caps")
	goal_row.add_child(stamp)
	var hits := String(deal["goal"]) == "hits"
	var goal := UITheme.label("%s  (%d/%d%s)" % [MagnusDeals.deal_goal_text(deal), progress, int(deal["target"]), " " + tr("INVEST_HITS_UNIT") if hits else ""], 22, UITheme.BONE, "body")
	goal.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goal_row.add_child(goal)

	# Las mejoras: te las quedas o te las quita / The boosts: you keep them or he takes them
	col.add_child(UITheme.label("INVEST_KEEP" if won else "INVEST_TAKEN", 18, UITheme.ASH, "caps"))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	col.add_child(flow)
	for b: Dictionary in deal.get("boosts", []):
		flow.add_child(_chip(GameState.stat_value_text(b["stat"], b["value"]), won))

	# El dinero / The money
	var money := HBoxContainer.new()
	money.add_theme_constant_override("separation", 10)
	col.add_child(money)
	var icon := RealityIcon.new()
	icon.custom_minimum_size = Vector2(36, 36)
	money.add_child(icon)
	var m := UITheme.label(tr("INVEST_PAID").format({"n": deal["payout"], "cost": deal["cost"]}) if won else tr("INVEST_KEPT").format({"cost": deal["cost"]}), 24, RealityIcon.COLOR if won else UITheme.EMBER, "display")
	m.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	money.add_child(m)

	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	col.add_child(gap)
	var b2 := Button.new()
	b2.text = "TALK_CONTINUE"
	b2.custom_minimum_size = Vector2(320, 60)
	b2.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b2.pressed.connect(_close)
	b2.mouse_entered.connect(b2.grab_focus)
	col.add_child(b2)
	b2.grab_focus.call_deferred()

	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.3)
	Audio.play("giver_magnus", -4.0)
	Audio.play("deal_won" if won else "deal_lost", -2.0)


## Etiqueta de una mejora: verde si te la quedas, tachada en rojo si te la quita
## Boost tag: green if you keep it, struck through in red if he takes it
func _chip(text: String, kept: bool) -> Control:
	var col := AURA if kept else UITheme.EMBER
	var chip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.15)
	sb.border_color = Color(col, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 3
	sb.content_margin_bottom = 4
	chip.add_theme_stylebox_override("panel", sb)
	var l := Keywords.label(text, 18, col.lightened(0.3), "body")
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	if not kept:
		l.text = "[s]%s[/s]" % l.text
	chip.add_child(l)
	return chip


func _process(delta: float) -> void:
	_ready_t -= delta


func _close() -> void:
	if _done or _ready_t > 0.0:
		return
	_done = true
	closed.emit()
	queue_free()
