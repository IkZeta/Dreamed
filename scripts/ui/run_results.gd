class_name RunResults
extends PanelContainer
## Tarjeta de resultados al acabar la partida, junto al diario: daño de cada arma en barras, la
## mejor caída en cadena y los récords (marcados si son nuevos).
## Results card when the run ends, next to the diary: each weapon's damage as bars, the best fall
## chain and the records (marked when they're new).

const W := 440.0


static func make() -> RunResults:
	var r := RunResults.new()
	r._build()
	return r


func _build() -> void:
	add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.SLATE, 0.55), Color(UITheme.LINE, 0.5), 2, 12, 18))
	custom_minimum_size = Vector2(W, 0)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	v.add_child(UITheme.label("RESULTS_TITLE", 28, UITheme.GOLD, "display"))
	# Sueño del día y fiebre / Daily dream and fever
	if GameState.daily != "":
		var dl := UITheme.label("", 18, UITheme.MIST, "caps")
		dl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		dl.text = tr("RESULTS_DAILY") % [GameState.daily, Progress.daily_best(GameState.daily)]
		v.add_child(dl)
	if GameState.fever() > 0:
		var fl := UITheme.label("", 18, UITheme.EMBER, "caps")
		fl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		fl.text = tr("RESULTS_FEVER") % [FeverDaily.fever_temp(), roundi(GameState.FEVER_SHARDS * 100.0 * GameState.fever())]
		v.add_child(fl)

	# Daño por arma / Damage per weapon
	var dmg: Dictionary = GameState.run_dmg
	if not dmg.is_empty():
		v.add_child(UITheme.label("RESULTS_DAMAGE", 18, UITheme.ASH, "caps"))
		var top := 1.0
		for k: String in dmg:
			top = maxf(top, float(dmg[k]))
		var ids := dmg.keys()
		ids.sort_custom(func(a: String, b: String) -> bool: return float(dmg[a]) > float(dmg[b]))
		for id: String in ids:
			v.add_child(_bar(tr("WEAPON_SHORT_" + id.to_upper()), float(dmg[id]), float(dmg[id]) / top))
	v.add_child(_gap(4))

	# Récords / Records
	v.add_child(UITheme.label("RESULTS_RECORDS", 18, UITheme.ASH, "caps"))
	var before: Dictionary = GameState.records_before
	var rows := [
		["RESULTS_DEPTH", GameState.dream_depth, "best_depth"],
		["RESULTS_KILLS", GameState.run_kills, "best_kills"],
		["RESULTS_LEVEL", GameState.plevel, "best_level"],
		["RESULTS_CHAIN", GameState.run_best_chain, "fall_chain"],
	]
	for row: Array in rows:
		var val: int = row[1]
		var is_new: bool = not GameState.god_mode and val > int(before.get(row[2], 0)) and val > 0
		v.add_child(_record(tr(row[0]), val, is_new))
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5).set_delay(0.3)


func _bar(name: String, value: float, k: float) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var h := HBoxContainer.new()
	var l := UITheme.label(name, 20, UITheme.BONE)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var n := UITheme.label(str(roundi(value)), 20, UITheme.GOLD)
	n.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	h.add_child(n)
	box.add_child(h)
	var track := Control.new()
	track.custom_minimum_size = Vector2(W - 44.0, 12)
	track.draw.connect(func() -> void:
		track.draw_rect(Rect2(Vector2.ZERO, track.size), Color(UITheme.SLATE, 0.8))
		track.draw_rect(Rect2(Vector2.ZERO, Vector2(track.size.x * clampf(k, 0.02, 1.0), track.size.y)), UITheme.GOLD)
		track.draw_rect(Rect2(Vector2.ZERO, Vector2(track.size.x * clampf(k, 0.02, 1.0), 3)), Color(1, 1, 1, 0.35)))
	box.add_child(track)
	return box


func _record(name: String, value: int, is_new: bool) -> Control:
	var h := HBoxContainer.new()
	var l := UITheme.label(name, 20, UITheme.BONE)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	if is_new:
		var tag := UITheme.label("RESULTS_NEW", 16, UITheme.INK, "caps")
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UITheme.box(UITheme.GOLD, Color.TRANSPARENT, 0, 6, 4))
		p.add_child(tag)
		h.add_child(p)
	var n := UITheme.label(str(value), 22, UITheme.GOLD if is_new else UITheme.BONE)
	n.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	n.custom_minimum_size.x = 56
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(n)
	return h


func _gap(px: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = px
	return c
