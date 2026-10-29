class_name LevelUpScreen
extends CanvasLayer
## Pantalla de subida de nivel: tres mejoras de estadística con su rareza (de común a
## legendaria). Funciona con el juego en pausa.
## Level-up screen: three stat upgrades with their rarity (common to legendary).
## Works while the game is paused.

signal chosen(choice: Dictionary)

const RARITY_COLOR: Array[Color] = [Color("bcc0ea"), Color("9be38a"), Color("7fb8ff"), Color("c79bff"), Color("ffc26a")]

var _choices: Array[Dictionary] = []
var _ready_t := 0.4
var _done := false
var _first: Button


func build(choices: Array[Dictionary], level: int) -> void:
	_choices = choices
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.theme = UITheme.build()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(UITheme.INK, 0.8)
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	center.add_child(col)

	var lvl := UITheme.label(tr("HUD_LEVEL") % level, 18, UITheme.GOLD, "caps")
	lvl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(lvl)
	var title := UITheme.label("LEVELUP_TITLE", 72, UITheme.BONE, "display")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := UITheme.label("LEVELUP_SUB", 24, UITheme.ASH, "italic")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size.y = 24
	col.add_child(gap)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 32)
	col.add_child(row)
	for i in choices.size():
		row.add_child(_card(choices[i], i))

	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.3)
	Audio.play("chime", -4.0)
	_first.grab_focus.call_deferred()


func _card(choice: Dictionary, index: int) -> Control:
	var r: int = choice["rarity"]
	var color := RARITY_COLOR[r]
	var id: String = choice["stat"]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(380, 430)
	card.add_theme_stylebox_override("panel", UITheme.glow_box(Color(UITheme.VOID, 0.92), Color(color, 0.7), Color(color, 0.14 + 0.06 * r), 18 + r * 4, 18, 26))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)

	var rarity := UITheme.label("RARITY_" + GameState.RARITIES[r].to_upper(), 15, color, "caps")
	rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(rarity)
	var icon := RarityStar.new()
	icon.color = color
	icon.rarity = r
	icon.custom_minimum_size = Vector2(0, 110)
	v.add_child(icon)
	var name_l := UITheme.label("STAT_NAME_" + id.to_upper(), 32, UITheme.BONE, "display")
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(name_l)
	var value := UITheme.label(GameState.stat_value_text(id, float(choice["value"])), 22, color, "body")
	value.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(value)
	var desc := UITheme.label("STAT_DESC_" + id.to_upper(), 18, UITheme.ASH, "italic")
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(desc)
	var b := Button.new()
	b.text = "LEVELUP_PICK"
	b.custom_minimum_size = Vector2(0, 58)
	b.pressed.connect(_pick.bind(index))
	b.mouse_entered.connect(b.grab_focus)
	v.add_child(b)
	if _first == null:
		_first = b
	return card


func _process(delta: float) -> void:
	_ready_t -= delta


func _pick(index: int) -> void:
	if _done or _ready_t > 0.0:
		return
	_done = true
	Audio.play("pickup", -2.0)
	chosen.emit(_choices[index])
	queue_free()


## Estrella que brilla más cuanto más rara es la mejora / Star that shines brighter the rarer the upgrade
class RarityStar extends Control:
	var color := Color.WHITE
	var rarity := 0
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var pulse := 0.85 + 0.15 * sin(_t * 2.5)
		draw_texture_rect(DreamBackground.soft_texture(), Rect2(c - Vector2(70, 70) * pulse, Vector2(140, 140) * pulse), false, Color(color, 0.25 + 0.08 * rarity))
		# Más rara = más destellos girando alrededor / Rarer = more sparkles circling around
		for i in rarity * 2:
			var a := _t * 0.8 + i * TAU / maxf(1.0, rarity * 2.0)
			DreamBackground.draw_star(self, c + Vector2(cos(a) * 46.0, sin(a) * 30.0), 2.5, Color(color, 0.8))
		var pts := PackedVector2Array()
		var r := 26.0 + rarity * 3.0
		for i in 10:
			var a := -PI / 2.0 + i * PI / 5.0 + sin(_t) * 0.05
			pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
		draw_colored_polygon(pts, color)
		draw_circle(c, 4.0, Color(1, 1, 1, 0.8))
