class_name PauseSummary
extends PanelContainer
## Resumen de la pausa: estadísticas de Kroker y mejoras del plano astral que lleva.
## Pause summary: Kroker's stats and the astral plane upgrades he carries.


static func make(player: Player) -> PauseSummary:
	var p := PauseSummary.new()
	p._build(player)
	return p


func _build(player: Player) -> void:
	add_theme_stylebox_override("panel", UITheme.glow_box(Color(UITheme.VOID, 0.92), Color(UITheme.LINE, 0.5), Color(UITheme.GOLD, 0.08), 16, 14, 30))
	custom_minimum_size.x = 820
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)

	# Estadísticas / Stats
	v.add_child(UITheme.label("PAUSE_STATS", 24, UITheme.GOLD, "caps"))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	var s := GameState
	var rows := [
		["STAT_NAME_LEVEL", "%d  (%d/%d)" % [s.plevel, s.xp, s.xp_needed()]],
		["STAT_NAME_HP", "%d / %d" % [ceili(player.hp), roundi(player.max_hp)]],
		["STAT_NAME_ATTACK", _pct((player.damage_mult - 1.0) * 100.0)],
		["STAT_NAME_DEFENSE", _num(player.armor)],
		["STAT_NAME_SPEED", _pct((player.speed / float(s.BASE_STATS["speed"]) - 1.0) * 100.0)],
		["STAT_NAME_ATTACK_SPEED", _pct(s.stat("attack_speed"))],
		["STAT_NAME_RANGE", _pct(s.stat("range"))],
		["STAT_NAME_REGEN", tr("STAT_REGEN_VALUE").format({"v": _num(s.stat("regen"))})],
		["STAT_NAME_LIFESTEAL", "%s %%" % _num(s.stat("lifesteal"))],
		["STAT_NAME_LUCK", _num(s.stat("luck"))],
	]
	if s.reality_on():
		rows.append(["REALITY_NAME", "%d ◆" % s.reality])
	for r in rows:
		var name_l := UITheme.label(r[0], 24, UITheme.ASH, "body")
		grid.add_child(name_l)
		var val := UITheme.label(r[1], 24, UITheme.BONE, "body")
		val.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		grid.add_child(val)

	var gap := Control.new()
	gap.custom_minimum_size.y = 14
	v.add_child(gap)

	# Mejoras / Upgrades
	v.add_child(UITheme.label("PAUSE_UPGRADES", 24, UITheme.GOLD, "caps"))
	var any := false
	for weapon in s.weapons():
		for g in s.GIVERS:
			var lvl := s.level(g, weapon)
			if lvl <= 0:
				continue
			any = true
			var parts := [tr("GIVER_%s_NAME" % g.to_upper()), tr("UP_LEVEL") % lvl, tr(s.upgrade_key(g, weapon, "NAME"))]
			# Con dos armas se dice a cuál va cada mejora / With two weapons, say which one each upgrade is for
			if s.weapons().size() > 1:
				parts.append(tr("WEAPON_SHORT_" + weapon.to_upper()))
			var head := UITheme.label("  ·  ".join(PackedStringArray(parts)), 24, UITheme.BONE, "body")
			head.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			v.add_child(head)
			var desc := UITheme.label(s.upgrade_desc(g, weapon, lvl), 24, UITheme.ASH, "italic")
			desc.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc.custom_minimum_size.x = 760
			v.add_child(desc)
	if not any:
		var none := UITheme.label("PAUSE_NO_UPGRADES", 24, UITheme.ASH, "italic")
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(none)


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else str(snappedf(v, 0.1))


static func _pct(v: float) -> String:
	return ("+" if v >= 0.0 else "") + _num(v) + " %"
