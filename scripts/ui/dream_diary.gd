class_name DreamDiary
extends PanelContainer
## El diario de Kroker al acabar una partida (al despertar, gane o pierda): una hoja de libreta
## con lo que ha soñado, lo que le tumbó, las mejoras que llevaba y una frase de quien más le ayudó.
## Kroker's diary at the end of a run (on waking, win or lose): a notebook page with what he
## dreamed, what knocked him out, the upgrades he had and a line from whoever helped him most.

const PAPER := Color("efe6cf")
const INK := Color("2a2440")
const RED := Color("c8404a")
const BLUE_LINE := Color(0.35, 0.5, 0.85, 0.22)


static func make(won: bool) -> DreamDiary:
	var d := DreamDiary.new()
	d._build(won)
	return d


func _build(won: bool) -> void:
	var st := StyleBoxFlat.new()
	st.bg_color = PAPER
	st.shadow_color = Color(0, 0, 0, 0.5)
	st.shadow_size = 0
	st.shadow_offset = Vector2(10, 10)
	add_theme_stylebox_override("panel", st)
	custom_minimum_size = Vector2(800, 0)
	rotation = -0.012
	var paper := Lines.new()
	add_child(paper)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 96)
	m.add_theme_constant_override("margin_right", 40)
	m.add_theme_constant_override("margin_top", 26)
	m.add_theme_constant_override("margin_bottom", 30)
	add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	m.add_child(v)

	var s := GameState
	v.add_child(_line(tr("DIARY_TITLE"), 34, RED, "display"))
	var outfit := tr("CHAR_%s_NAME" % s.selected_character.to_upper())
	v.add_child(_line(tr("DIARY_SUB").format({"outfit": outfit, "diff": tr("DIFF_" + s.difficulty.to_upper())}), 18, Color(INK, 0.7), "caps"))
	v.add_child(_gap(6))

	var m_ := int(s.run_time) / 60
	var sec := int(s.run_time) % 60
	var dreams := s.dream_depth if won else s.dream_depth - 1
	var key := "DIARY_WON" if won else "DIARY_LOST"
	v.add_child(_text(tr(key).format({"n": maxi(0, dreams), "depth": s.dream_depth, "time": "%d:%02d" % [m_, sec]})))
	var tot := maxf(1.0, s.run_time + s.choose_time)
	v.add_child(_text(tr("DIARY_PACE").format({"fight": "%d:%02d" % [int(s.run_time) / 60, int(s.run_time) % 60],
		"choose": "%d:%02d" % [int(s.choose_time) / 60, int(s.choose_time) % 60], "pct": roundi(100.0 * s.run_time / tot)})))
	v.add_child(_text(tr("DIARY_COUNT").format({"kills": s.run_kills, "elites": s.run_elites, "falls": s.run_falls, "hits": s.run_hits})))
	if not won:
		v.add_child(_text(tr("DIARY_KILLER").format({"who": _killer_name()})))
	v.add_child(_gap(8))

	# Mejoras, dúos y combos / Upgrades, duos and combos
	var ups := PackedStringArray()
	for w in s.weapons():
		for g in s.GIVERS:
			var lvl := s.level(g, w)
			if lvl > 0:
				ups.append("%s (%s%s)" % [tr(s.upgrade_key(g, w, "NAME")), tr("GIVER_%s_NAME" % g.to_upper()), ", " + tr("UP_LEGEND").to_lower() if lvl >= s.LEGEND_LEVEL else ""])
	for id: String in s.duos:
		ups.append("%s (%s)" % [tr("DUO_%s_NAME" % id.to_upper()), tr("DUO_ROLE")])
	v.add_child(_text("[b]%s[/b] %s" % [tr("DIARY_GIFTS"), ", ".join(ups) + "." if not ups.is_empty() else tr("DIARY_NO_GIFTS")]))
	var combos := s.active_combos()
	if not combos.is_empty():
		var names := PackedStringArray()
		for id in combos:
			names.append(tr("COMBO_%s_NAME" % id.to_upper()))
		v.add_child(_text("[b]%s[/b] %s." % [tr("PAUSE_COMBOS") + ":", ", ".join(names)]))
	v.add_child(_gap(8))

	# Pegatinas nuevas para el álbum / New stickers for the album
	if not s.new_stickers.is_empty():
		var st_names := PackedStringArray()
		for stk: Array in s.new_stickers:
			st_names.append(StickerAlbum.sticker_name(stk[0], stk[1]))
		v.add_child(_text("[b]%s[/b] %s." % [tr("DIARY_STICKERS"), ", ".join(st_names)]))
	# Quien más le ayudó, con su frase / Whoever helped most, with their line
	var best := _best_helper()
	if best != "":
		v.add_child(_text(tr("DIARY_HELPER").format({"who": tr("GIVER_%s_NAME" % best.to_upper())})))
		var quote := _line(tr("GIVER_%s_LINE" % best.to_upper()), 20, Color(INK, 0.8), "italic")
		quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(quote)
	v.add_child(_gap(6))
	var bye := _line(tr("DIARY_BYE_WON" if won else "DIARY_BYE_LOST"), 20, RED, "italic")
	bye.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(bye)


func _killer_name() -> String:
	var id := GameState.last_hit
	if id == "bleed":
		return tr("DIARY_BY_BLEED")
	if id == "":
		return tr("DIARY_BY_UNKNOWN")
	var key := "BEST_%s_NAME" % id.to_upper()
	return tr(key) if tr(key) != key else tr("DIARY_BY_UNKNOWN")


## El personaje con más niveles en la partida / The giver with the most levels this run
func _best_helper() -> String:
	var best := ""
	var best_n := 0
	for g in GameState.GIVERS:
		var n := 0
		for w in GameState.weapons():
			n += GameState.level(g, w)
		if n > best_n:
			best_n = n
			best = g
	return best


func _line(text: String, size: int, color: Color, role: String) -> Label:
	var l := UITheme.label(text, size, color, role)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return l


func _text(bb: String) -> RichTextLabel:
	var r := Keywords.label(bb, 21, INK, "body")
	r.custom_minimum_size.x = 640
	return r


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


## Rayas de libreta y el margen rojo, con unas estrellitas pintadas a boli
## Notebook lines and the red margin, with a few little stars doodled in pen
class Lines extends Control:
	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := 64.0
		while y < size.y - 8.0:
			draw_line(Vector2(8, y), Vector2(size.x - 8, y), DreamDiary.BLUE_LINE, 2.0)
			y += 30.0
		draw_line(Vector2(76, 0), Vector2(76, size.y), Color(DreamDiary.RED, 0.5), 2.0)
		draw_line(Vector2(80, 0), Vector2(80, size.y), Color(DreamDiary.RED, 0.3), 1.0)
		# Agujeros de la anilla / Ring-binder holes
		for i in 4:
			draw_circle(Vector2(36, 70 + i * (size.y - 140) / 3.0), 9.0, Color("cfc4a8"))
		# Garabatos de estrellas / Star doodles
		for p in [Vector2(size.x - 70, 40), Vector2(size.x - 110, 70), Vector2(size.x - 40, 100)]:
			var pts := PackedVector2Array()
			for k in 11:
				var a := -PI / 2.0 + k * TAU / 10.0
				pts.append(p + Vector2(cos(a), sin(a)) * (12.0 if k % 2 == 0 else 5.0))
			draw_polyline(pts, Color(DreamDiary.INK, 0.55), 1.5)
