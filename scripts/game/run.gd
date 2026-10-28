class_name Run
extends Node2D
## Una partida: el escenario, la oleada actual, Kroker, los enemigos y las pantallas
## de pausa, victoria y derrota. El Sueño 1 ocurre en la habitación de Kroker y
## empieza con él levantándose de la cama.
## One run: the stage, the current wave, Kroker, the enemies and the pause, win and
## lose screens. Dream 1 takes place in Kroker's bedroom and starts with him
## getting out of bed.

const MAIN_MENU := "res://scenes/main_menu.tscn"
const SETTINGS_SCENE := preload("res://scenes/settings_menu.tscn")
const WAKE_POINT := Vector2(500, 600)     # donde se pone de pie / where he stands up
const START_POINT := Vector2(860, 680)    # donde empieza a jugar / where play begins

var running := false
var player: Player
var enemies: Node2D
var fx: FX
var hud: HUD
var room: Bedroom

var _wave: Dictionary
var _time_left := 0.0
var _spawn_timer := 1.2
var _kills := 0
var _camera: Camera2D
var _shake := 0.0
var _overlay: DreamOverlay


func _ready() -> void:
	var depth := GameState.dream_depth
	_wave = GameState.WAVES[clampi(depth - 1, 0, GameState.WAVES.size() - 1)]
	_time_left = _wave["duration"]

	room = Bedroom.new()
	room.outfit = GameState.selected_character
	add_child(room)

	_camera = Camera2D.new()
	_camera.position = Vector2(960, 540)
	add_child(_camera)
	_camera.make_current()

	# Actores ordenados por altura / Actors sorted by height
	var actors := Node2D.new()
	actors.y_sort_enabled = true
	add_child(actors)
	enemies = Node2D.new()
	enemies.y_sort_enabled = true
	actors.add_child(enemies)
	player = Player.new()
	player.position = WAKE_POINT
	player.visible = false
	actors.add_child(player)
	player.setup(self, GameState.selected_character)

	fx = FX.new()
	add_child(fx)

	hud = HUD.new()
	add_child(hud)
	hud.visible = false
	hud.set_hp(player.hp, player.max_hp)
	hud.set_time(_time_left)
	_play_wake_up(depth)


## Intro: Kroker duerme, se revuelve, se incorpora, se estira, se pone las gafas,
## sale de la cama, va a por su arma y empieza el sueño.
## Intro: Kroker sleeps, tosses, sits up, stretches, puts on his glasses, gets out
## of bed, goes to fetch his weapon and the dream begins.
func _play_wake_up(depth: int) -> void:
	var outfit := GameState.selected_character
	var pickup: Vector2 = Bedroom.PICKUP.get(outfit, START_POINT)
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(room, "stir", 1.0, 0.9)
	tw.tween_callback(func() -> void: room.bed_state = "sitting")
	tw.tween_property(room, "sit", 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(room, "stretch", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.45)
	tw.tween_property(room, "stretch", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.2)
	tw.tween_callback(func() -> void:
		room.glasses_on_stand = false
		fx.dissipate(Bedroom.NIGHTSTAND.position + Vector2(30, 64), UITheme.GOLD))
	tw.tween_interval(0.5)
	tw.tween_callback(func() -> void:
		room.bed_state = "empty"
		player.armed = false
		player.position = WAKE_POINT
		player.visible = true)
	tw.tween_interval(0.25)
	tw.tween_property(player, "position", pickup, _walk_time(WAKE_POINT, pickup))
	tw.tween_callback(func() -> void:
		room.weapon_taken = true
		player.armed = true
		player.attack_anim = 1.0
		player.cast_anim = 1.0
		fx.dissipate(pickup + Vector2(0, -80), UITheme.GOLD)
		fx.ring(pickup + Vector2(0, -80), 30.0, UITheme.GOLD, 0.5, 2.0))
	tw.tween_interval(0.6)
	tw.tween_property(player, "position", START_POINT, _walk_time(pickup, START_POINT))
	tw.tween_callback(func() -> void:
		hud.visible = true
		hud.start(depth)
		running = true)


func _walk_time(a: Vector2, b: Vector2) -> float:
	return maxf(0.3, a.distance_to(b) / 280.0)


func _physics_process(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta * 30.0)
	_camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake if Settings.screen_shake else Vector2.ZERO
	if not running:
		return
	_time_left -= delta
	hud.set_time(_time_left)
	if _time_left <= 0.0:
		_on_wave_cleared()
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = _wave["spawn_every"]
		_spawn_group()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and running and _overlay == null:
		get_viewport().set_input_as_handled()
		_open_pause()


# --- Oleada / Wave ----------------------------------------------------------

func _spawn_group() -> void:
	var alive := enemies.get_child_count()
	var group: Array = _wave["group"]
	var count := mini(randi_range(group[0], group[1]), int(_wave["max_alive"]) - alive)
	for i in count:
		var pos := _spawn_point()
		fx.telegraph(pos + Vector2(0, -16), 0.8)
		get_tree().create_timer(0.8, false).timeout.connect(_spawn_foox.bind(pos))


func _spawn_point() -> Vector2:
	var area := Bedroom.WALKABLE.grow(-40)
	for attempt in 30:
		var p := Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
		if p.distance_to(player.position) > 360.0 and not _blocked(p, 40.0):
			return p
	return Vector2(area.end.x - 40, area.end.y - 40)


func _spawn_foox(pos: Vector2) -> void:
	if not running:
		return
	var f := Foox.new()
	f.run = self
	f.position = pos
	enemies.add_child(f)


func _blocked(p: Vector2, margin: float) -> bool:
	for r in Bedroom.OBSTACLES:
		if r.grow(margin).has_point(p):
			return true
	return false


## Mantiene a alguien dentro del suelo y fuera de los muebles.
## Keeps someone on the floor and out of the furniture.
func clamp_to_arena(p: Vector2, margin: float) -> Vector2:
	var r := Bedroom.WALKABLE.grow(-margin * 0.5)
	p = Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	for o in Bedroom.OBSTACLES:
		var g := o.grow(margin * 0.6)
		if g.has_point(p):
			# Empuja hacia el borde más cercano / Push out through the nearest edge
			var d_left := p.x - g.position.x
			var d_right := g.end.x - p.x
			var d_bottom := g.end.y - p.y
			var m := minf(d_left, minf(d_right, d_bottom))
			if m == d_bottom:
				p.y = g.end.y
			elif m == d_left:
				p.x = g.position.x
			else:
				p.x = g.end.x
	return p


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


# --- Eventos / Events -------------------------------------------------------

func on_enemy_killed(_e: Node) -> void:
	_kills += 1


func on_player_hit(_dmg: float) -> void:
	hud.set_hp(player.hp, player.max_hp)
	shake(10.0)


func on_player_died() -> void:
	running = false
	shake(18.0)
	fx.dissipate(player.position + Vector2(0, -40), UITheme.BONE)
	get_tree().create_timer(1.3, false).timeout.connect(func() -> void:
		_show_end("LOSE_TITLE", "", [["BTN_DREAM_AGAIN", _restart], ["BTN_MAIN_MENU", _to_menu]]))


func _on_wave_cleared() -> void:
	running = false
	hud.set_time(0.0)
	for e: Node in enemies.get_children():
		e.die(false)
	get_tree().create_timer(1.4, false).timeout.connect(func() -> void:
		_show_end("WIN_TITLE", "WIN_NEXT_HINT", [["BTN_DREAM_AGAIN", _restart], ["BTN_MAIN_MENU", _to_menu]]))


# --- Pantallas / Screens ----------------------------------------------------

func _show_end(title: String, subtitle: String, buttons: Array) -> void:
	get_tree().paused = true
	_overlay = DreamOverlay.new()
	add_child(_overlay)
	_overlay.build(title, subtitle, buttons)


func _open_pause() -> void:
	get_tree().paused = true
	_overlay = DreamOverlay.new()
	add_child(_overlay)
	_overlay.on_cancel = _resume
	_overlay.build("PAUSE_TITLE", "", [
		["PAUSE_RESUME", _resume],
		["MENU_SETTINGS", _open_settings],
		["PAUSE_QUIT_RUN", _to_menu],
	])


func _resume() -> void:
	if _overlay:
		_overlay.close()
		_overlay = null
	get_tree().paused = false


func _open_settings() -> void:
	var menu := SETTINGS_SCENE.instantiate()
	_overlay.add_child(menu)
	menu.closed.connect(_overlay.refocus)


func _restart() -> void:
	GameState.change_scene("res://scenes/run.tscn")


func _to_menu() -> void:
	GameState.change_scene(MAIN_MENU)
