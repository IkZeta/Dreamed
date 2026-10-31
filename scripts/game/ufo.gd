class_name Ufo
extends Enemy
## Jefe del Acto 3 (Sueño 15): el Ovni. Pasa por el pasillo dando tumbos y lo destroza: quema las
## paredes, abre agujeros en el suelo con su rayo, deja caer enemigos y dispara láseres. Mientras
## vuela no se le puede dar; cada cierto tiempo se estrella contra el suelo y ahí sí, hasta que
## vuelve a despegar.
## Act 3 boss (Dream 15): the UFO. It lurches down the hallway and wrecks it: scorches the walls,
## blasts holes in the floor with its beam, drops enemies and fires lasers. It can't be hit while
## flying; every so often it crashes into the floor and then it can, until it takes off again.

signal defeated

const HP := 480.0
const SIZE := 1.6                # el platillo se dibuja más grande / the saucer is drawn bigger
const ALTITUDE := 230.0          # altura a la que vuela / flying height
const FLY_TIME := 9.0           # tiempo volando antes de estrellarse / flying time before crashing
const GROUND_TIME := 8.0         # tiempo en el suelo, vulnerable / time on the ground, vulnerable
const FALL_TIME := 0.7
const RISE_TIME := 1.0
const LASER_EVERY := 2.3
const LASER_DAMAGE := 3.0
const LASER_SPEED := 620.0
const RAY_EVERY := 5.5
const RAY_WARN := 1.1
const RAY_RADIUS := 80.0
const RAY_DAMAGE := 5.0
const DROP_EVERY := 7.0
const SCORCH_EVERY := 1.6
const DROP_KINDS: Array[String] = ["foox", "foox", "puppet", "thug", "skeleton"]
const LIGHTS := [Color("ff5f7a"), Color("f6d24a"), Color("5ff2ff"), Color("7fd65a")]

var phase := "fly"               # "fly", "fall", "ground", "rise"
var _phase_t := 0.0
var _alt := ALTITUDE
var _laser_cd := 2.0
var _ray_cd := 3.5
var _drop_cd := 4.0
var _scorch_cd := 0.5
var _ray := {}                   # rayo en curso: {"pos", "t"} / beam under way
var _beam := 0.0                 # rayo tractor al soltar enemigos / tractor beam when dropping enemies
var _target := Vector2.ZERO
var _wobble := 0.0
var _dying := -1.0


func _init() -> void:
	bestiary_id = "boss_ufo"
	max_hp = HP
	hp = max_hp
	mass = 80.0
	contact_damage = 3.0
	radius = 60.0
	speed = 230.0
	aim_height = 40.0
	shards = 0


func _ready() -> void:
	super._ready()
	state = State.ALIVE
	_fade = 1.0
	if preview:
		_alt = 0.0
		return
	position = run.player.position + Vector2(-500, -60)
	position = run.clamp_to_arena(position, radius)
	_target = position
	Audio.play("boss_wake", -3.0)
	run.shake(8.0)


func is_boss() -> bool:
	return true


func is_targetable() -> bool:
	return state == State.ALIVE and phase == "ground" and _dying < 0.0


func is_dangerous() -> bool:
	return phase == "ground" and _dying < 0.0


func can_fall() -> bool:
	return false


func start_bounce(_damage: float, _chain: int, _ignore: Array = []) -> void:
	pass


func glitch(stun := 0.0, slow := 0.0, vulnerable := 0.0, mult := 1.5) -> void:
	super.glitch(0.0, slow, vulnerable, mult)


func aim_point() -> Vector2:
	return global_position + Vector2(0, -aim_height - _alt)


func reach_bonus() -> float:
	return radius * 0.8


func hit(amount: float, impulse := Vector2.ZERO) -> void:
	if not is_targetable():
		return
	super.hit(amount, Vector2.ZERO)
	run.update_boss_hp()


func die(counted: bool) -> void:
	if not counted:
		super.die(false)
		return
	if _dying >= 0.0:
		return
	_dying = 0.0
	_ray = {}
	run.drop_shards(global_position, roundi(40 * GameState.shard_mult()))
	run.gain_reality(GameState.REALITY_CHEF, global_position)
	Progress.kill(bestiary_id)
	GameState.run_kills += 1
	Progress.add_stat("kills")
	Audio.play("crack", -1.0)
	run.shake(16.0)


func _physics_process(delta: float) -> void:
	_t += delta
	if preview:
		queue_redraw()
		return
	if _dying >= 0.0:
		_dying += delta
		if fmod(_dying, 0.15) < delta:
			run.fx.dissipate(global_position + Vector2(randf_range(-90, 90), randf_range(-60, 10)), Color("ffd27a"))
			run.fx.ring(global_position + Vector2(randf_range(-80, 80), -20), 30.0, UITheme.EMBER, 0.4, 2.4)
		if _dying > 2.0:
			state = State.DYING
			defeated.emit()
			queue_free()
		queue_redraw()
		return
	_flash = maxf(0.0, _flash - delta * 4.0)
	if not run.running:
		queue_redraw()
		return
	_phase_t += delta
	match phase:
		"fly":
			_fly(delta)
			if _phase_t > FLY_TIME:
				_set_phase("fall")
				Audio.play("glitch", -4.0)
		"fall":
			_alt = lerpf(ALTITUDE, 0.0, minf(1.0, _phase_t / FALL_TIME) ** 2)
			_wobble = sin(_t * 30.0) * 0.3 * (1.0 - _phase_t / FALL_TIME)
			if _phase_t >= FALL_TIME:
				_alt = 0.0
				_set_phase("ground")
				_crash()
		"ground":
			_wobble = 0.18 + sin(_t * 2.0) * 0.02
			if fmod(_t, 0.25) < delta:
				run.fx.dissipate(global_position + Vector2(randf_range(-60, 60), -30), Color("6a6a7a"))
			if _phase_t > GROUND_TIME:
				_set_phase("rise")
				Audio.play("dash", -4.0)
		"rise":
			_alt = lerpf(0.0, ALTITUDE, minf(1.0, _phase_t / RISE_TIME))
			_wobble = lerpf(0.18, 0.0, minf(1.0, _phase_t / RISE_TIME))
			if _phase_t >= RISE_TIME:
				_set_phase("fly")
	_update_ray(delta)
	_beam = maxf(0.0, _beam - delta)
	queue_redraw()


func _set_phase(p: String) -> void:
	phase = p
	_phase_t = 0.0


## Vuelo a tumbos alrededor de Kroker, atacando y destrozando el pasillo
## Lurching flight around Kroker, attacking and wrecking the hallway
func _fly(delta: float) -> void:
	var player: Player = run.player
	if position.distance_to(_target) < 40.0 or fmod(_t, 2.6) < delta:
		var side := -1.0 if randf() < 0.5 else 1.0
		_target = run.clamp_to_arena(player.position + Vector2(side * randf_range(220, 520), randf_range(-160, 160)), radius)
	var to := _target - position
	var jolt := Vector2(sin(_t * 3.1) * 90.0, cos(_t * 2.3) * 50.0)
	position += (to.normalized() * speed + jolt) * delta * (1.0 if to.length() > 10.0 else 0.0)
	position = run.clamp_to_arena(position, radius)
	_wobble = sin(_t * 2.7) * 0.18 + sin(_t * 7.0) * 0.05
	_alt = ALTITUDE + sin(_t * 1.8) * 18.0
	_facing = signf(to.x) if absf(to.x) > 20.0 else _facing
	# Láseres / Lasers
	_laser_cd -= delta
	if _laser_cd <= 0.0:
		_laser_cd = LASER_EVERY + randf_range(-0.3, 0.4)
		_fire_lasers()
	# Rayo que rompe el suelo / Beam that breaks the floor
	_ray_cd -= delta
	if _ray_cd <= 0.0 and _ray.is_empty():
		_ray_cd = RAY_EVERY + randf_range(-0.5, 0.8)
		var at: Vector2 = player.position + Vector2(randf_range(-90, 90), randf_range(-40, 40))
		_ray = {"pos": run.clamp_to_arena(at, 40.0), "t": 0.0}
		Audio.play("zap", -8.0, 0.1)
	# Suelta enemigos / Drops enemies
	_drop_cd -= delta
	if _drop_cd <= 0.0:
		_drop_cd = DROP_EVERY + randf_range(-1.0, 1.0)
		_drop_enemies()
	# Se va cargando las paredes al pasar / Wrecks the walls as it goes by
	_scorch_cd -= delta
	if _scorch_cd <= 0.0 and run.room is Act3Room:
		_scorch_cd = SCORCH_EVERY + randf_range(-0.4, 0.6)
		var cx := (global_position.x - Bedroom.OFFSET.x) / Bedroom.S + randf_range(-120, 120)
		(run.room as Act3Room).add_scorch(cx)
		run.fx.ring(Bedroom.to_world(Vector2(cx, 180)), 26.0, UITheme.EMBER, 0.4, 2.0)
		Audio.play("crack", -14.0, 0.1)


func _saucer() -> Vector2:
	return global_position + Vector2(0, -_alt)


func _fire_lasers() -> void:
	var from := _saucer() + Vector2(0, 24)
	var dir: Vector2 = (run.player.global_position + Vector2(0, -40) - from).normalized()
	for i in 3:
		var s := EnemyShot.new()
		s.run = run
		s.kind = "laser"
		s.position = from
		s.velocity = dir.rotated((i - 1) * 0.18) * LASER_SPEED
		s.damage = LASER_DAMAGE * atk_mult()
		s.radius = 9.0
		s.life = 2.4
		run.world.add_child(s)
	Audio.play("laser", -6.0, 0.1)


## El rayo avisa con un círculo, baja, hace daño y abre un agujero en el suelo
## The beam warns with a circle, comes down, deals damage and opens a hole in the floor
func _update_ray(delta: float) -> void:
	if _ray.is_empty():
		return
	_ray["t"] = float(_ray["t"]) + delta
	if float(_ray["t"]) >= RAY_WARN and not _ray.has("done"):
		_ray["done"] = true
		var at: Vector2 = _ray["pos"]
		run.shake(7.0)
		Audio.play("crack", -2.0)
		run.fx.ring(at, RAY_RADIUS, Color("ff5f7a"), 0.5, 1.6)
		run.fx.dissipate(at, Color("ffd27a"))
		var player: Player = run.player
		if player.global_position.distance_to(at) < RAY_RADIUS:
			player.take_damage(RAY_DAMAGE * GameState.enemy_dmg_mult() * atk_mult())
		if run.room is Act3Room:
			(run.room as Act3Room).add_crater((at - Bedroom.OFFSET) / Bedroom.S)
	if float(_ray["t"]) >= RAY_WARN + 0.45:
		_ray = {}


func _drop_enemies() -> void:
	_beam = 1.2
	Audio.play("spawn", -6.0, 0.1)
	for i in randi_range(1, 2):
		var p: Vector2 = run.clamp_to_arena(global_position + Vector2(randf_range(-80, 80), randf_range(-30, 30)), 30.0)
		run.fx.telegraph(p + Vector2(0, -16), 0.7)
		run.spawn_enemy_soon(DROP_KINDS[randi() % DROP_KINDS.size()], p, 0.7)


## Se estrella: temblor, polvo y grietas / It crashes: shaking, dust and cracks
func _crash() -> void:
	run.shake(14.0)
	Audio.play("stomp", 0.0)
	Audio.play("crack", -2.0)
	run.fx.ring(global_position, 90.0, UITheme.BONE, 0.6, 2.4)
	for i in 3:
		run.fx.dissipate(global_position + Vector2(randf_range(-80, 80), -10), Color("cfc6b0"))
	var player: Player = run.player
	if player.global_position.distance_to(global_position) < radius + 40.0:
		player.take_damage(RAY_DAMAGE * GameState.enemy_dmg_mult())
	run.fx.text(global_position + Vector2(0, -120), tr("UFO_DOWN"), UITheme.GOLD, 26)


func _draw() -> void:
	if not preview and state == State.ALIVE and not _ray.is_empty():
		var at: Vector2 = _ray["pos"] - global_position
		var k: float = minf(1.0, float(_ray["t"]) / RAY_WARN)
		# Aviso en el suelo / Floor warning
		draw_colored_polygon(_ellipse(at, Vector2(RAY_RADIUS, RAY_RADIUS * 0.45)), Color(Settings.warning_color(), 0.15 + 0.25 * k))
		draw_arc(at, RAY_RADIUS * k, 0, TAU, 32, Color(Settings.warning_color(), 0.8), 3.0)
		if _ray.has("done"):
			var top := Vector2(0, -_alt + 20)
			draw_colored_polygon(PackedVector2Array([top + Vector2(-20, 0), top + Vector2(20, 0), at + Vector2(RAY_RADIUS * 0.7, 0), at + Vector2(-RAY_RADIUS * 0.7, 0)]), Color("ff5f7a", 0.55))
			draw_colored_polygon(PackedVector2Array([top + Vector2(-8, 0), top + Vector2(8, 0), at + Vector2(RAY_RADIUS * 0.3, 0), at + Vector2(-RAY_RADIUS * 0.3, 0)]), Color(1, 1, 1, 0.7))
	super._draw()


func _draw_body(offset: Vector2, tint: Color, a: float) -> void:
	var mod := Sprites.flash_color(_flash * 0.6, a) * tint
	# Sombra en el suelo (más pequeña cuanto más alto) / Shadow on the floor (smaller the higher it is)
	var sk := 1.0 - 0.5 * _alt / ALTITUDE
	draw_colored_polygon(_ellipse(offset, Vector2(110, 22) * sk * SIZE), Color(0.05, 0.02, 0.15, 0.45 * a))
	# Rayo tractor al soltar enemigos / Tractor beam when dropping enemies
	if _beam > 0.0 and _alt > 20.0:
		var top := offset + Vector2(0, -_alt + 24)
		draw_colored_polygon(PackedVector2Array([top + Vector2(-22, 0), top + Vector2(22, 0), offset + Vector2(80, 0), offset + Vector2(-80, 0)]), Color("9fe0ea", 0.3 * minf(1.0, _beam)))
	var bob := sin(_t * 3.0) * 4.0 if phase == "fly" else 0.0
	draw_set_transform(offset + Vector2(0, -_alt - 40 + bob), _wobble, Vector2.ONE * SIZE)
	Sprites.draw(self, "ufo_body", mod)
	# Luces del borde que van rotando / Rim lights chasing round
	for i in 7:
		var x := -96.0 + i * 32.0
		var on := int(_t * 8.0 + i) % 4
		draw_rect(Rect2(x - 4, 8, 8, 6), Color(LIGHTS[on], a if phase != "ground" or fmod(_t, 0.5) < 0.25 else 0.3 * a))
	if phase == "ground":
		# Chispas de avería / Fault sparks
		for s in 3:
			var p := Vector2(randf_range(-100, 100), randf_range(-30, 10))
			draw_line(p, p + Vector2(randf_range(-12, 12), randf_range(-12, 12)), Color("ffd27a", a), 2.0)
	draw_set_transform(Vector2.ZERO)


func _ellipse(c: Vector2, r: Vector2, n := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var ang := TAU * i / n
		pts.append(c + Vector2(cos(ang) * r.x, sin(ang) * r.y))
	return pts


func head_top() -> Vector2:
	return Vector2(0, -_alt - 110)
