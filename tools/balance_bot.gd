extends Node
## Bot de equilibrio (solo para pruebas): juega partidas enteras con cada pijama, acelerado,
## y escribe un informe con cómo acaba cada sueño. Se activa como autoload temporal:
##   B="*res://tools/balance_bot.gd"   (en [autoload] de project.godot, sin commitear)
## y se lanza con:  godot --headless --path . -- --bot-runs=2
## Balance bot (testing only): plays whole runs with every pajama, sped up, and writes a
## report of how each dream ends. Enable it as a temporary autoload (see above).
##
## El bot no es un jugador experto: esquiva lo que tiene cerca, se acerca o se aleja según su
## arma, recoge estrellas y elige las mejoras al azar. Sirve para comparar, no para medir.
## The bot isn't an expert player: it dodges what's near, keeps a distance that suits its weapon,
## picks up stars and chooses upgrades at random. It's for comparing, not for exact numbers.

const WEAPONS: Array[String] = ["bat", "shield", "book", "vacuum", "finger", "teddy"]
const OUT := "user://balance_report.json"
const SPEED := 6.0

var runs_per_weapon := 2
var _queue: Array[String] = []
var _results: Array = []
var _cur: Dictionary = {}
var _t := 0.0
var _astral_t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bot-runs="):
			runs_per_weapon = int(a.split("=")[1])
	_rng.seed = 7
	Engine.time_scale = SPEED
	Engine.max_physics_steps_per_frame = 16
	Progress.stats["charo_met"] = 1
	for w in WEAPONS:
		for i in runs_per_weapon:
			_queue.append(w)
	await get_tree().process_frame
	_next_run()


func _next_run() -> void:
	if _queue.is_empty():
		_finish()
		return
	var w: String = _queue.pop_front()
	GameState.god_mode = false
	GameState.difficulty = "normal"
	GameState.selected_character = w
	GameState.start_run()
	_cur = {"weapon": w, "dreams": [], "died_at": 0}
	print("[bot] start ", w)
	GameState.change_scene("res://scenes/run.tscn")


func _finish() -> void:
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(_results, "  "))
	f.close()
	print("[bot] report: ", ProjectSettings.globalize_path(OUT))
	GameState.clear_saved_run()
	get_tree().quit()


func _physics_process(delta: float) -> void:
	_t += delta
	var sc := get_tree().current_scene
	if sc == null:
		return
	if sc is Run:
		_drive(sc as Run)
	elif sc.name == "AstralPlane":
		_astral(sc, delta)


# --- Plano astral / Astral plane ----------------------------------------------------

func _astral(ap: Node, delta: float) -> void:
	_astral_t += delta
	if _astral_t < 1.0:
		return
	_astral_t = -1000.0
	var offer: Array = ap.get("_offer")
	if offer.is_empty():
		ap.call("_leave")
		return
	# Elige con algo de sentido: nada de Stolk con poca vida; Doc si la vida es baja
	# Picks sensibly: no Stolk with low health; Doc when health is low
	var g: String = offer[_rng.randi_range(0, offer.size() - 1)]
	var max_hp := float(GameState.stats_for(GameState.selected_character)["max_hp"])
	if g == "stolk" and max_hp - GameState.STOLK_HP_COST < 18.0 and offer.size() > 1:
		g = offer[1] if offer[0] == "stolk" else offer[0]
	if "doc" in offer and max_hp < 22.0:
		g = "doc"
	var targets: Dictionary = ap.get("_target")
	var ws := GameState.weapons()
	var options := []
	for w in ws:
		if GameState.level(g, w) < GameState.MAX_UPGRADE_LEVEL:
			options.append(w)
	if not options.is_empty():
		targets[g] = options[_rng.randi_range(0, options.size() - 1)]
	ap.call("_choose", g)
	get_tree().create_timer(0.8).timeout.connect(func() -> void:
		if is_instance_valid(ap):
			ap.call("_leave")
		_astral_t = 0.0)


# --- Partida / Run ------------------------------------------------------------------

var _last_depth := -1
var _hooked: Run


func _drive(run: Run) -> void:
	if _hooked != run:
		_hooked = run
		run.dream_finished.connect(dream_done.bind(run))
	_release()
	if GameState.dream_depth != _last_depth and run.running:
		_last_depth = GameState.dream_depth
	_handle_modals(run)
	if not run.running or run.player == null or not run.player.alive:
		return
	var p := run.player
	var pos := p.global_position
	var force := Vector2.ZERO
	var melee := GameState.selected_character in GameState.MELEE
	var keep := 95.0 if melee else 290.0
	var danger_r := 150.0 if melee else 230.0
	var nearest: Node2D = null
	var nearest_d := INF
	var boss_t: Node2D = null
	for e: Node in run.enemies.get_children():
		if not e is Enemy or not e.is_targetable():
			continue
		var en := e as Enemy
		var d := pos - en.global_position
		var dist := d.length()
		var danger := en.is_dangerous() and not en is Nest
		# Con arma cuerpo a cuerpo, el jefe es el objetivo y no se huye de él (salvo en los saltos de la cama)
		# With a melee weapon the boss is the target and isn't avoided (except for the bed's jumps)
		if melee and en.is_boss():
			danger = en.get("_hop") != null and float(en.get("_hop")) > 10.0
			boss_t = en
		if dist < nearest_d and not en is Nest:
			nearest_d = dist
			nearest = en
		if danger and dist < danger_r:
			var w := (danger_r - dist) / danger_r * (2.5 if en.is_boss() else (1.6 if en is Thug else 1.0))
			force += d.normalized() * w
			# De lado, para no quedar acorralado / Sideways, so as not to get cornered
			force += d.normalized().orthogonal() * w * 0.5
	if boss_t:
		nearest = boss_t
		nearest_d = pos.distance_to(boss_t.global_position)
	# Distancia que le va bien a su arma / Distance that suits its weapon
	if nearest:
		var to_e := nearest.global_position - pos
		if nearest_d > keep + 40.0:
			force += to_e.normalized() * 0.6
		elif nearest_d < keep - 30.0 and not melee:
			force -= to_e.normalized() * 0.8
	# Proyectiles, platos y trozos / Projectiles, plates and shards
	for n: Node in run.world.get_children():
		if n is EnemyShot or (n is ChefShot and n.kind == "knife"):
			var v: Vector2 = n.get("velocity")
			var rel: Vector2 = pos + Vector2(0, -44) - n.global_position
			if v.dot(rel) > 0.0 and rel.length() < 300.0:
				var side := v.normalized().orthogonal()
				force += side * signf(side.dot(rel)) * 1.5
		elif n is ChefShot:
			var tgt: Vector2 = n.get("target")
			if pos.distance_to(tgt) < 110.0:
				force += (pos - tgt).normalized() * 2.0
		elif n is PlateShards or n is Puddle:
			if pos.distance_to(n.global_position) < 80.0:
				force += (pos - n.global_position).normalized() * 1.5
		elif n is StarShard and pos.distance_to(n.global_position) < 220.0:
			force += (n.global_position - pos).normalized() * 0.25
	# Lejos de las paredes y de la chimenea / Away from the walls and the fireplace
	var area := run.arena_rect().grow(-60)
	var c := area.get_center()
	if not area.has_point(pos):
		force += (c - pos).normalized() * 1.2
	force += (c - pos) / 2000.0
	if run.room is LivingRoom and Bedroom.rect_world(LivingRoom.HEARTH_ZONE).grow(30).has_point(pos):
		force += Vector2(0, 1.5)
	if force.length() > 0.05:
		var dir := force.normalized()
		_press("move_right", maxf(0.0, dir.x))
		_press("move_left", maxf(0.0, -dir.x))
		_press("move_down", maxf(0.0, dir.y))
		_press("move_up", maxf(0.0, -dir.y))


func _press(action: String, k: float) -> void:
	if k > 0.05:
		Input.action_press(action, clampf(k, 0.0, 1.0))


func _release() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)


func _handle_modals(run: Run) -> void:
	var ls = run.get("_level_screen")
	if ls and is_instance_valid(ls) and float(ls.get("_ready_t")) <= 0.0:
		var choices: Array = ls.get("_choices")
		var best := 0
		for i in choices.size():
			var r: int = choices[i]["rarity"]
			var useful: bool = choices[i]["stat"] in ["attack", "attack_speed", "regen", "defense"]
			var rb: int = choices[best]["rarity"]
			if r > rb or (r == rb and useful):
				best = i
		ls.call("_pick", best)
	var m = run.get("_modal")
	if m and is_instance_valid(m):
		if m is CharoShop:
			m.set("_ready_t", 0.0)
			for w in m.get("_wares"):
				m.set("_ready_t", 0.0)
				m.call("_buy", w)
			m.set("_ready_t", 0.0)
			m.call("_close")
		elif m is SacrificeScreen:
			m.set("_ready_t", 0.0)
			m.call("_cancel")
		elif m is WeaponChoiceScreen:
			m.set("_ready_t", 0.0)
			var opts := GameState.other_weapons()
			m.call("_pick", opts[_rng.randi_range(0, opts.size() - 1)])
		elif m is CharoDialogue:
			m.call("_next")
	var ov = run.get("_overlay")
	if ov and is_instance_valid(ov) and not _cur.is_empty() and not _cur.has("done"):
		_cur["done"] = true
		_record_end(run)


## Al acabar la partida (muerte o victoria) / When the run ends (death or victory)
func _record_end(run: Run) -> void:
	var won := run.player.alive
	_cur["won"] = won
	_cur["died_at"] = 0 if won else GameState.dream_depth
	_cur["level"] = GameState.plevel
	_cur["time"] = int(GameState.run_time)
	_cur["upgrades"] = GameState.upgrades.duplicate()
	_cur["upgrades2"] = GameState.upgrades2.duplicate()
	_cur["second"] = GameState.second_weapon
	_cur["reality"] = GameState.reality
	print("[bot] end ", _cur["weapon"], " won=", won, " died_at=", _cur["died_at"], " lvl=", GameState.plevel)
	_results.append(_cur)
	_cur = {}
	_last_depth = -1
	get_tree().create_timer(1.0).timeout.connect(_next_run)


## Lo llama la partida al acabar cada sueño / Called by the run when each dream ends
func dream_done(run: Run) -> void:
	if not is_instance_valid(run):
		return
	if _cur.is_empty():
		return
	_cur["dreams"].append({"depth": GameState.dream_depth, "hp": snappedf(run.player.hp, 0.1), "max_hp": run.player.max_hp,
		"level": GameState.plevel, "reality": GameState.reality, "time": int(GameState.run_time), "hits": GameState.run_hits})
