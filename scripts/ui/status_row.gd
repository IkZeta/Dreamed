class_name StatusRow
extends Control
## Fila de estados alterados bajo la vida: un icono por estado con un anillo que se vacía según
## le queda. Al pasar el ratón por encima sale la tarjeta que lo explica.
## Row of status effects under the health bar: one icon per state with a ring that empties as
## it wears off. Hovering one shows the card that explains it.

const CHIP := 38.0
const GAP := 8.0
const COLORS := {"bleed": Color("e8455a"), "rooted": Color("f6d24a"),
	"slow": Color("6fa8ff"), "stench": Color("8fd14f"), "hack": Color("ff5fd2")}

var player: Player
var _chips: Array[Dictionary] = []     # {"id", "k" (0..1 que queda), "label"}
var _max := {}                          # duración más alta vista de cada estado / longest duration seen for each state
var _hover := ""
var _t := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(0, CHIP)


func _process(delta: float) -> void:
	_t += delta
	_chips.clear()
	if is_instance_valid(player):
		# Paralizado (descarga) e inmovilizado (sartenazo) son el mismo estado / Paralysed (zap) and rooted (pan) are the same state
		_add("rooted", player.root_t)
		_add("bleed", player.bleed_t)
		_add("slow", player.slow_t)
		if player.stench_t > 0.0 and player.stench_weapon:
			_add("stench", player.stench_t, tr("WEAPON_SHORT_" + player.stench_weapon.id.to_upper()))
		else:
			_max.erase("stench")
		for h: Dictionary in GameState.hacks.values():
			_chips.append({"id": "hack", "k": 1.0, "label": ""})   # la estadística ya sale debajo / the stat is already listed below
	var labelled := false
	for c in _chips:
		labelled = labelled or c["label"] != ""
	custom_minimum_size = Vector2(maxf(0.0, _chips.size() * (CHIP + GAP) - GAP), CHIP + (16.0 if labelled else 0.0))
	visible = not _chips.is_empty()
	if _hover != "" and not visible:
		_hover = ""
		Keywords.hide_tip()
	queue_redraw()


func _add(id: String, t: float, label := "") -> void:
	if t <= 0.0:
		_max.erase(id)
		return
	if not _max.has(id) or t > float(_max[id]):
		_max[id] = t
	_chips.append({"id": id, "k": t / float(_max[id]), "label": label})


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var i := int((event as InputEventMouseMotion).position.x / (CHIP + GAP))
		var id := ""
		if i >= 0 and i < _chips.size():
			id = _chips[i]["id"]
		if id != _hover:
			_hover = id
			if id == "":
				Keywords.hide_tip()
			else:
				Keywords.show_tip(self, id)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != "":
		_hover = ""
		Keywords.hide_tip()


func _draw() -> void:
	for i in _chips.size():
		var c := _chips[i]
		var id: String = c["id"]
		var col: Color = COLORS[id]
		var r := Rect2(Vector2(i * (CHIP + GAP), 0), Vector2(CHIP, CHIP))
		var center := r.get_center()
		draw_rect(r, Color(0.06, 0.04, 0.14, 0.85))
		draw_rect(r, Color(col, 0.9), false, 2.0)
		# Anillo de lo que le queda / Ring showing what's left
		var k: float = c["k"]
		if k < 1.0:
			draw_arc(center, CHIP * 0.42, -PI / 2.0, -PI / 2.0 + TAU * k, 24, Color(col, 0.5), 3.0)
		_icon(id, center, col)
		if c["label"] != "":
			var f := UITheme.font("caps")
			draw_string(f, Vector2(r.position.x, r.end.y + 14), String(c["label"]).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, CHIP, 12, col)


## Iconos sencillos en pixel art / Simple pixel-art icons
func _icon(id: String, c: Vector2, col: Color) -> void:
	match id:
		"bleed":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -11), c + Vector2(7, 2), c + Vector2(0, 9), c + Vector2(-7, 2)]), col)
			draw_rect(Rect2(c + Vector2(-3, -1), Vector2(3, 3)), Color(1, 1, 1, 0.7))
		"rooted":
			for i in 3:
				var a := _t * 4.0 + i * TAU / 3.0
				DreamBackground.draw_star(self, c + Vector2(cos(a) * 9.0, sin(a) * 5.0), 4.0, col)
		"slow":
			draw_arc(c + Vector2(2, 0), 7.0, 0, TAU, 16, col, 3.0)
			draw_rect(Rect2(c + Vector2(-11, 5), Vector2(16, 4)), col)
		"stench":
			for i in 3:
				var pts := PackedVector2Array()
				for kk in 5:
					pts.append(c + Vector2(-8 + i * 8 + sin(_t * 6.0 + kk + i) * 2.5, 10 - kk * 5))
				draw_polyline(pts, col, 2.5)
		"hack":
			draw_rect(Rect2(c + Vector2(-10, -7), Vector2(20, 14)), col, false, 2.0)
			if fmod(_t, 0.6) < 0.3:
				draw_rect(Rect2(c + Vector2(-6, -2), Vector2(8, 3)), col)
			draw_rect(Rect2(c + Vector2(4, -2), Vector2(3, 3)), Color(1, 1, 1, 0.8))
