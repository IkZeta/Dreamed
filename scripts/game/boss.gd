class_name BossPiece
extends Enemy
## Jefe del Acto 1: los muebles de la habitación cobran vida, de uno en uno.
## Primero la cama, luego la estantería y por último el baúl de juguetes. Cada uno tiene
## la vida de 5 matones, se mueve por la habitación y ataca a su manera:
##  - Cama: camina hacia ti y salta; al caer hace un sismo (daño en área y una onda).
##  - Estantería: se mantiene a distancia y te lanza ráfagas de libros.
##  - Baúl: no hace daño al tocarlo, huye de ti y saca enemigos de dentro.
## Act 1 boss: the bedroom furniture comes alive, one piece at a time: first the bed,
## then the bookshelf and finally the toy chest. Each has the health of 5 thugs, moves
## around the room and attacks in its own way:
##  - Bed: walks toward you and jumps; landing causes a quake (area damage and a wave).
##  - Bookshelf: keeps its distance and throws volleys of books at you.
##  - Chest: harmless to touch, runs away from you and lets enemies out.

signal defeated

const ORDER: Array[String] = ["bed", "shelf", "chest"]
const HP_PER_PIECE := 225.0   # 5 matones de 45 / 5 thugs of 45
const WAKE_TIME := 1.8
const QUAKE_RADIUS := 105.0   # daño al caer la cama / damage where the bed lands
const WAVE_REACH := 290.0     # hasta dónde llega la onda del sismo / how far the quake wave travels
const METAL := Color("8f8fb8")
const METAL_DARK := Color("4f4f78")
const EYE := Color("ff8fa8")

## Datos de cada mueble. "anchor" es dónde está en la habitación (lienzo de la habitación).
## Data for each piece. "anchor" is where it sits in the room (room canvas).
const PARTS := {
	"bed": {"anchor": Vector2(250, 520), "name": "BOSS_PART_BED"},
	"shelf": {"anchor": Vector2(1321, 400), "name": "BOSS_PART_SHELF"},
	"chest": {"anchor": Vector2(575, 400), "name": "BOSS_PART_CHEST"},
}

var kind := "bed"
var _wake := WAKE_TIME
var _dying := -1.0
var _walk := 0.0
var _hop := 0.0          # altura del salto en píxeles / jump height in pixels
var _squash := 0.0       # agacharse antes de saltar / crouch before jumping
## Ataque en curso / Current attack: {kind, t, ...}
var _atk := {}
var _atk_cd := 2.0
var _volleys := 0
var _waves: Array[Dictionary] = []   # ondas del sismo / quake shockwaves


func _init() -> void:
	max_hp = HP_PER_PIECE
	hp = max_hp
	mass = 40.0
	contact_damage = 3.0


func setup_piece(p_run: Node, p_kind: String) -> void:
	kind = p_kind
	setup(p_run)
	match kind:
		"bed":
			radius = 70.0
			speed = 70.0
			aim_height = 60.0
			_atk_cd = 2.5
		"shelf":
			radius = 52.0
			speed = 95.0
			aim_height = 85.0
			_atk_cd = 1.6
		"chest":
			radius = 50.0
			speed = 150.0
			aim_height = 40.0
			contact_damage = 0.0
			_atk_cd = 1.5
	position = p_run.clamp_to_arena(Bedroom.to_world(PARTS[kind]["anchor"]), radius)


func _ready() -> void:
	var base_speed := speed
	super._ready()
	speed = base_speed  # sin variación aleatoria / no random variation
	state = State.ALIVE
	_fade = 1.0
	Audio.play("boss_wake", -3.0)
	run.shake(8.0)


## Las armas alcanzan antes a un mueble grande / Weapons reach a big piece of furniture sooner
func reach_bonus() -> float:
	return radius * 0.7


func is_targetable() -> bool:
	return state == State.ALIVE and _wake <= 0.0 and _dying < 0.0


func is_dangerous() -> bool:
	return kind != "chest" and _wake <= 0.0 and _hop < 10.0


func aim_point() -> Vector2:
	return global_position + Vector2(0, -aim_height - _hop)


func can_fall() -> bool:
	return false


func start_bounce(_damage: float, _chain: int, _ignore: Array = []) -> void:
	pass


func glitch(stun := 0.0, slow := 0.0, vulnerable := 0.0, mult := 1.5) -> void:
	super.glitch(minf(stun, 0.5), slow, vulnerable, mult)


func hit(amount: float, impulse := Vector2.ZERO) -> void:
	if not is_targetable():
		return
	super.hit(amount, impulse)
	run.hud.set_boss_hp(maxf(hp, 0.0), max_hp)


func die(counted: bool) -> void:
	if not counted:
		super.die(false)
		return
	if _dying >= 0.0:
		return
	_dying = 0.0
	_atk = {}
	run.drop_shards(global_position, 12)
	Audio.play("crack", -1.0)
	Audio.play("stomp", -4.0)
	run.shake(14.0)


func _physics_process(delta: float) -> void:
	if _dying >= 0.0:
		_t += delta
		_dying += delta
		if fmod(_dying, 0.25) < delta:
			run.fx.dissipate(aim_point() + Vector2(randf_range(-50, 50), randf_range(-40, 40)), EYE)
		if _dying > 1.6:
			state = State.DYING
			run.fx.dissipate(aim_point(), Color("cfc6e8"))
			defeated.emit()
			queue_free()
		queue_redraw()
		return
	if _wake > 0.0:
		_t += delta
		_wake -= delta
		if fmod(_wake, 0.3) < delta:
			run.shake(3.0)
		queue_redraw()
		return
	_update_waves(delta)
	super._physics_process(delta)


func _move(delta: float) -> void:
	external_pull *= 0.15   # la aspiradora apenas lo mueve / the vacuum barely moves it
	if not _atk.is_empty() and _atk["kind"] == "jump":
		external_pull = Vector2.ZERO
		knock = Vector2.ZERO
		return  # el salto mueve la cama él solo / the jump moves the bed by itself
	var before := position
	super._move(delta)
	_walk += position.distance_to(before) * 0.06


func _desired_velocity() -> Vector2:
	if not _atk.is_empty():
		return Vector2.ZERO
	var to_player: Vector2 = run.player.global_position - global_position
	var d := to_player.length()
	var dir := to_player / maxf(d, 0.01)
	match kind:
		"bed":
			return dir * speed
		"shelf":
			# Se queda a media distancia y se va moviendo de lado / Keeps mid range, strafing
			var side := Vector2(-dir.y, dir.x) * (1.0 if sin(_t * 0.4) > 0.0 else -1.0)
			if d < 340.0:
				return (-dir * 0.8 + side * 0.5).normalized() * speed
			if d > 520.0:
				return (dir + side * 0.3).normalized() * speed
			return side * speed * 0.7
		"chest":
			# Huye; si está contra una pared, se escurre de lado / Runs away; slides sideways along walls
			var away := -dir
			var r: Rect2 = run.arena_rect().grow(-radius - 40.0)
			var p := global_position
			if p.x < r.position.x or p.x > r.end.x:
				away.x *= -0.2
				away.y += signf(away.y if away.y != 0.0 else 1.0)
			if p.y < r.position.y or p.y > r.end.y:
				away.y *= -0.2
				away.x += signf(away.x if away.x != 0.0 else 1.0)
			return away.normalized() * speed * (1.0 if d < 600.0 else 0.4)
	return Vector2.ZERO


# --- Ataques / Attacks ------------------------------------------------------------

func _act(delta: float) -> void:
	if not run.running:
		return
	if not _atk.is_empty():
		_update_attack(delta)
		return
	_atk_cd -= delta * (0.5 if slow_t > 0.0 else 1.0)
	if _atk_cd <= 0.0:
		_begin_attack()


func _begin_attack() -> void:
	var p: Vector2 = run.player.global_position
	match kind:
		"bed":
			var target: Vector2 = run.clamp_to_arena(p, radius)
			_atk = {"kind": "crouch", "t": 0.0, "dur": 0.6, "target": target}
		"shelf":
			_volleys += 1
			_atk = {"kind": "aim", "t": 0.0, "dur": 0.55, "n": 5 if _volleys % 3 == 0 else 3}
		"chest":
			_atk = {"kind": "open", "t": 0.0, "dur": 0.8}


## Barra de carga del próximo ataque / Charge bar for the next attack
func charge() -> float:
	var full := {"bed": 2.8, "shelf": 1.9, "chest": 2.8}[kind] as float
	if not _atk.is_empty():
		return 1.0
	return 1.0 - clampf(_atk_cd / full, 0.0, 1.0)


func _update_attack(delta: float) -> void:
	_atk["t"] = float(_atk["t"]) + delta
	var t := float(_atk["t"])
	var dur := float(_atk["dur"])
	match _atk["kind"]:
		"crouch":
			_squash = t / dur
			if t >= dur:
				_squash = 0.0
				Audio.play("throw", -4.0, 0.05)
				_atk = {"kind": "jump", "t": 0.0, "dur": 0.85, "from": global_position, "target": _atk["target"]}
		"jump":
			var k := t / dur
			global_position = (_atk["from"] as Vector2).lerp(_atk["target"], k)
			_hop = sin(k * PI) * 160.0
			if t >= dur:
				_hop = 0.0
				_land()
				_atk = {}
				_atk_cd = 2.8
		"aim":
			if t >= dur:
				_throw_books(int(_atk["n"]))
				_atk = {}
				_atk_cd = 1.9
		"open":
			if t >= dur:
				_release_enemies()
				_atk = {"kind": "close", "t": 0.0, "dur": 0.4}
		"close":
			if t >= dur:
				_atk = {}
				_atk_cd = 2.8


## La cama cae: sismo con daño en área y una onda que se expande / The bed lands: area quake and an expanding wave
func _land() -> void:
	Audio.play("stomp", -1.0, 0.05)
	run.shake(16.0)
	run.fx.dissipate(global_position, Color("cfc6e8"))
	var player: Player = run.player
	if player.global_position.distance_to(global_position) < QUAKE_RADIUS:
		player.take_damage(5.0)
	_waves.append({"r": 40.0, "hit": false})


func _update_waves(delta: float) -> void:
	var player: Player = run.player
	for i in range(_waves.size() - 1, -1, -1):
		var w := _waves[i]
		w["r"] = float(w["r"]) + 380.0 * delta
		var r := float(w["r"])
		# Una onda achatada (perspectiva del suelo) / A flattened wave (floor perspective)
		var d := player.global_position - global_position
		var dist := Vector2(d.x, d.y / 0.45).length()
		if not w["hit"] and absf(dist - r) < 26.0 and r > QUAKE_RADIUS:
			w["hit"] = true
			player.take_damage(3.0)
		if r > WAVE_REACH:
			_waves.remove_at(i)


func _throw_books(n: int) -> void:
	var player: Player = run.player
	var from := aim_point() + Vector2(0, -40)
	var dir := (player.global_position + Vector2(0, -44) - from).normalized()
	for i in n:
		var shot := EnemyShot.new()
		shot.run = run
		shot.kind = "book"
		shot.radius = 16.0
		shot.damage = 3.0
		shot.position = from
		shot.velocity = dir.rotated((i - (n - 1) / 2.0) * 0.22) * 470.0
		run.world.add_child(shot)
	Audio.play("throw", -3.0, 0.1)


## El baúl abre la tapa y saca enemigos del acto / The chest opens its lid and lets out act enemies
func _release_enemies() -> void:
	var alive := 0
	for e in run.enemies.get_children():
		if not e is BossPiece and e.is_targetable():
			alive += 1
	var kinds := ["foox", "foox", "thug", "sling", "skeleton"]
	for i in mini(randi_range(3, 4), 12 - alive):
		var p: Vector2 = run.clamp_to_arena(global_position + Vector2.from_angle(randf() * TAU) * randf_range(80, 130), 24.0)
		run.fx.telegraph(p + Vector2(0, -16), 0.5)
		run.spawn_enemy_soon(kinds[randi() % kinds.size()], p, 0.5)
	Audio.play("revive", -6.0, 0.1)


# --- Dibujo / Drawing --------------------------------------------------------------

func _draw() -> void:
	var wake_k := 1.0 - clampf(_wake / WAKE_TIME, 0.0, 1.0)
	var a := 1.0
	var scale_k := 1.0
	if _dying >= 0.0:
		a = maxf(0.0, 1.0 - _dying / 1.6)
		scale_k = 1.0 - 0.3 * _dying / 1.6
	_draw_waves()
	_draw_warning()
	# Sombra (se queda en el suelo al saltar) / Shadow (stays on the floor while jumping)
	var shadow_r := radius * (1.0 - _hop / 600.0)
	draw_colored_polygon(_ellipse(Vector2.ZERO, Vector2(shadow_r, shadow_r * 0.3)), Color(0.05, 0.02, 0.15, 0.35 * a))
	var shake := Vector2(randf_range(-3, 3), 0) if (_wake > 0.0 or _dying >= 0.0) else Vector2.ZERO
	var sq := 1.0 - 0.18 * _squash
	draw_set_transform(Vector2(0, -_hop) + shake, 0.0, Vector2((2.0 - sq) * scale_k, sq * scale_k))
	var flash := Color(1, 1, 1, 0.35 * _flash)
	match kind:
		"bed": _draw_bed(wake_k, a, flash)
		"shelf": _draw_shelf(wake_k, a, flash)
		"chest": _draw_chest(wake_k, a, flash)
	draw_set_transform(Vector2.ZERO)
	if is_targetable():
		# Barra de carga del ataque / Attack charge bar
		var top := {"bed": 250.0, "shelf": 230.0, "chest": 120.0}[kind] as float
		var r := Rect2(-40, -top - _hop, 80, 5)
		draw_rect(r.grow(1.5), Color(0.05, 0.03, 0.18, 0.55))
		draw_rect(Rect2(r.position, Vector2(r.size.x * charge(), r.size.y)), Color(EYE, 0.85))


func _draw_warning() -> void:
	if _atk.is_empty():
		return
	if _atk["kind"] in ["crouch", "jump"]:
		# Dónde va a caer la cama / Where the bed will land
		var lt := to_local(_atk["target"])
		var k := float(_atk["t"]) / float(_atk["dur"])
		if _atk["kind"] == "jump":
			k = 0.5 + 0.5 * k
		else:
			k *= 0.5
		draw_colored_polygon(_ellipse(lt, Vector2(QUAKE_RADIUS, QUAKE_RADIUS * 0.44)), Color(EYE, 0.08 + 0.18 * k))
		draw_set_transform(lt, 0.0, Vector2(1.0, 0.44))
		draw_arc(Vector2.ZERO, QUAKE_RADIUS, 0, TAU, 48, Color(EYE, 0.7), 2.5, true)
		draw_arc(Vector2.ZERO, QUAKE_RADIUS * (1.0 - k) + 8.0, 0, TAU, 40, Color(EYE, 0.9), 2.0, true)
		draw_set_transform(Vector2.ZERO)


func _draw_waves() -> void:
	for w in _waves:
		var r := float(w["r"])
		var a := clampf(1.0 - r / WAVE_REACH, 0.0, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
		draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(EYE, 0.7 * a), 10.0, true)
		draw_arc(Vector2.ZERO, r - 14.0, 0, TAU, 64, Color("cfc6e8", 0.4 * a), 4.0, true)
		draw_set_transform(Vector2.ZERO)


## Patas mecánicas que andan / Walking mechanical legs
func _legs(xs: Array, top_y: float, length: float, k: float) -> void:
	for i in xs.size():
		var x: float = xs[i]
		var ph := _walk + (PI if i % 2 else 0.0)
		var lift := maxf(0.0, sin(ph)) * 10.0 * k
		var hip := Vector2(x, top_y)
		var foot := Vector2(x + cos(ph) * 10.0 * k, top_y + length * k - lift)
		var knee := hip.lerp(foot, 0.5) + Vector2(signf(x) * 12.0 * k, -4.0)
		_segment(hip, knee, 6.0)
		_segment(knee, foot, 5.0)
		draw_circle(knee, 5.0, METAL_DARK)
		draw_colored_polygon(_ellipse(foot, Vector2(9, 4)), METAL_DARK)


func _eyes(c: Vector2, open: float, a: float) -> void:
	for side in [-1.0, 1.0]:
		var p := c + Vector2(side * 22.0, 0)
		draw_colored_polygon(_ellipse(p, Vector2(11, 7 * open + 1)), Color(0.05, 0.02, 0.12, 0.9 * a))
		if open > 0.3:
			draw_circle(p + Vector2(0, 1), 4.0 * open, Color(EYE, 0.95 * a))
			draw_circle(p, 13.0, Color(EYE, 0.14 * open * a))


func _draw_bed(k: float, a: float, _flash_c: Color) -> void:
	var w := 140.0
	var h := 150.0
	var lift := 28.0 * k    # se levanta sobre sus patas / rises on its legs
	_legs([-w * 0.42, -w * 0.15, w * 0.15, w * 0.42], -lift - 4.0, lift + 4.0, k)
	var base := -lift
	Sprites.draw(self, "boss_bed", _mod(a), Vector2(0, base))
	_eyes(Vector2(0, base - h + 30), k, a)


func _draw_shelf(k: float, a: float, _flash_c: Color) -> void:
	var w := 120.0
	var h := 170.0
	var lift := 34.0 * k
	_legs([-w * 0.3, w * 0.3], -lift - 4.0, lift + 4.0, k)
	var base := -lift
	# Los libros tiemblan cuando apunta / The books tremble while it aims
	var tremble := 2.0 if (not _atk.is_empty() and _atk["kind"] == "aim") else 0.0
	Sprites.draw(self, "boss_shelf", _mod(a), Vector2(randf_range(-tremble, tremble), base))
	# Brazos para lanzar / Throwing arms
	var throw_k := 0.0
	if not _atk.is_empty() and _atk["kind"] == "aim":
		throw_k = float(_atk["t"]) / float(_atk["dur"])
	for side in [-1.0, 1.0]:
		var sh := Vector2(side * w / 2, base - h * 0.6)
		var elbow := sh + Vector2(side * 30.0 * k, -10.0 - 30.0 * throw_k)
		var hand := elbow + Vector2(side * 10.0 * k, -30.0 * k - 20.0 * throw_k)
		_segment(sh, elbow, 6.0)
		_segment(elbow, hand, 5.0)
		draw_circle(hand, 7.0, METAL_DARK)
	_eyes(Vector2(0, base - h + 26), k, a)


func _draw_chest(k: float, a: float, _flash_c: Color) -> void:
	var w := 120.0
	var h := 66.0
	var lift := 20.0 * k
	_legs([-w * 0.38, -w * 0.12, w * 0.12, w * 0.38], -lift - 2.0, lift + 2.0, k)
	var base := -lift
	var open := 0.0
	if not _atk.is_empty():
		var t := float(_atk["t"]) / float(_atk["dur"])
		open = t if _atk["kind"] == "open" else 1.0 - t
	# Interior oscuro con brillos / Dark inside with glints
	var r := Rect2(-w / 2, base - h, w, h)
	if open > 0.0:
		draw_colored_polygon(_ellipse(Vector2(0, base - h), Vector2(w / 2 - 6, 10 + 16 * open)), Color(Color("1b1640"), a))
		for i in 3:
			draw_circle(Vector2(-30 + i * 30, base - h - 4), 3.0, Color(EYE, 0.8 * open * a))
	Sprites.draw(self, "boss_chest_box", _mod(a), Vector2(0, base))
	# Tapa que se abre como una boca / Lid that opens like a mouth
	Sprites.draw(self, "boss_chest_lid", _mod(a), Vector2(0, base - h - 40.0 * open))
	_eyes(Vector2(0, base - h * 0.72), k, a)


## Color del sprite: destello al recibir un golpe / Sprite colour: flash when hit
func _mod(a: float) -> Color:
	return Sprites.flash_color(_flash * 0.5, a)


func _segment(p1: Vector2, p2: Vector2, w: float) -> void:
	draw_line(p1, p2, METAL_DARK, w + 3.0, true)
	draw_line(p1, p2, METAL, w, true)


func _star(c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var ang := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(ang), sin(ang)) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, color)


func _ellipse(c: Vector2, r: Vector2, n := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var ang := TAU * i / n
		pts.append(c + Vector2(cos(ang) * r.x, sin(ang) * r.y))
	return pts
