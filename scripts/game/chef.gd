class_name Chef
extends Enemy
## Jefe del Acto 2 (Sueño 10): El Chef, un Kroker adulto cocinero que sale de la tele.
## Tiene tres ataques, todos avisados antes:
##  - Cuchillos: lanza un abanico de cuchillos; si te da uno, sangras.
##  - Sartenazo: de cerca, un golpe de sartén; si te da, no te puedes mover medio segundo.
##  - Platos: los lanza en arco a puntos marcados; al romperse dejan trozos que hacen daño.
## Con menos de la mitad de vida ataca más a menudo y lanza más cosas.
## Act 2 boss (Dream 10): The Chef, a grown-up Kroker cook who climbs out of the TV.
## He has three attacks, all telegraphed:
##  - Knives: throws a fan of knives; if one hits you, you bleed.
##  - Pan smash: up close, a frying-pan blow; if it hits, you can't move for half a second.
##  - Plates: lobs them at marked spots; when they break they leave shards that hurt.
## Below half health he attacks more often and throws more things.

signal defeated

const HP := 480.0
const WAKE_TIME := 2.6
const PAN_RANGE := 160.0
const PAN_DAMAGE := 4.0
const PAN_ROOT := 0.5
const KNIFE_SPEED := 560.0
const LAND := Vector2(1330, 440)   # donde aterriza al salir de la tele (lienzo del salón) / where he lands (room canvas)

var _wake := WAKE_TIME
var _dying := -1.0
var _walk := 0.0
var _atk := {}
var _atk_cd := 1.6
var _next := 0           # alterna cuchillos y platos / alternates knives and plates
var _angry := false      # segunda fase / second phase
var _arm_front := 0.0    # giro del brazo de la sartén / frying-pan arm angle
var _arm_back := 0.0     # giro del brazo que lanza / throwing arm angle


func _init() -> void:
	bestiary_id = "boss_chef"
	max_hp = HP
	hp = max_hp
	mass = 60.0
	contact_damage = 3.0
	radius = 40.0
	speed = 105.0
	aim_height = 120.0
	shards = 0


func _ready() -> void:
	super._ready()
	speed = 105.0
	state = State.ALIVE
	_fade = 1.0
	if preview:
		_wake = 0.0
		return
	position = run.clamp_to_arena(Bedroom.to_world(LAND), radius)
	Audio.play("boss_wake", -3.0)
	Audio.play("glitch", -4.0)
	run.shake(8.0)


func is_boss() -> bool:
	return true


func reach_bonus() -> float:
	return radius * 0.7


func is_targetable() -> bool:
	return state == State.ALIVE and _wake <= 0.0 and _dying < 0.0


func is_dangerous() -> bool:
	return _wake <= 0.0 and _dying < 0.0


func can_fall() -> bool:
	return false


func start_bounce(_damage: float, _chain: int, _ignore: Array = []) -> void:
	pass


func glitch(stun := 0.0, slow := 0.0, vulnerable := 0.0, mult := 1.5) -> void:
	super.glitch(minf(stun, 0.5), slow, vulnerable, mult)


func aim_point() -> Vector2:
	return global_position + Vector2(0, -aim_height)


func hit(amount: float, impulse := Vector2.ZERO) -> void:
	if not is_targetable():
		return
	super.hit(amount, impulse)
	run.update_boss_hp()
	# Segunda fase: se enfada / Second phase: he gets angry
	if not _angry and hp < max_hp * 0.5 and hp > 0.0:
		_angry = true
		run.shake(10.0)
		Audio.play("boss_wake", -6.0)
		run.fx.text(aim_point() + Vector2(0, -150), tr("CHEF_ANGRY"), UITheme.EMBER, 30)


func die(counted: bool) -> void:
	if not counted:
		super.die(false)
		return
	if _dying >= 0.0:
		return
	_dying = 0.0
	_atk = {}
	run.drop_shards(global_position, roundi(30 * GameState.shard_mult()))
	run.gain_reality(GameState.REALITY_CHEF, global_position)
	Progress.kill(bestiary_id)
	GameState.run_kills += 1
	Progress.add_stat("kills")
	Audio.play("crack", -1.0)
	run.shake(14.0)


func _physics_process(delta: float) -> void:
	if _dying >= 0.0:
		_t += delta
		_dying += delta
		if fmod(_dying, 0.2) < delta:
			run.fx.dissipate(aim_point() + Vector2(randf_range(-50, 50), randf_range(-80, 60)), Color("f4f1fa"))
		if _dying > 1.8:
			state = State.DYING
			defeated.emit()
			queue_free()
		queue_redraw()
		return
	if _wake > 0.0:
		_t += delta
		_wake -= delta
		var lr := run.room as LivingRoom
		if lr:
			lr.tv_burst = 1.0
		if _wake <= 0.0:
			Audio.play("stomp", -3.0)
			run.shake(10.0)
			run.fx.ring(global_position, 60.0, UITheme.BONE, 0.5, 3.0)
		queue_redraw()
		return
	super._physics_process(delta)
	_arm_front = move_toward(_arm_front, 0.0, delta * 3.0) if _atk.is_empty() else _arm_front
	_arm_back = move_toward(_arm_back, 0.0, delta * 3.0) if _atk.is_empty() else _arm_back


func _move(delta: float) -> void:
	external_pull *= 0.15
	var before := position
	super._move(delta)
	_walk += position.distance_to(before) * 0.06


func _desired_velocity() -> Vector2:
	if not _atk.is_empty():
		return Vector2.ZERO
	var to_player: Vector2 = run.player.global_position - global_position
	var d := to_player.length()
	var dir := to_player / maxf(d, 0.01)
	# Se acerca para el sartenazo, pero da rodeos para lanzar / Closes in for the pan, circling to throw
	var side := Vector2(-dir.y, dir.x) * sin(_t * 0.5 + _phase)
	if d > 260.0:
		return (dir + side * 0.4).normalized() * speed
	return (dir * 0.6 + side * 0.6).normalized() * speed * 0.8


func _act(delta: float) -> void:
	var k := (0.5 if slow_t > 0.0 else 1.0)
	if _atk.is_empty():
		_facing = signf(run.player.global_position.x - global_position.x) if absf(run.player.global_position.x - global_position.x) > 6.0 else _facing
		_atk_cd -= delta * k
		if _atk_cd <= 0.0:
			_start_attack()
		return
	_atk["t"] = float(_atk["t"]) + delta * k
	var t: float = _atk["t"]
	match String(_atk["kind"]):
		"pan":
			# Levanta la sartén y la baja de golpe / Raises the pan and brings it down hard
			if t < 0.55:
				_arm_front = lerpf(0.0, 2.5, t / 0.55)
			elif not _atk.has("done"):
				_atk["done"] = true
				_arm_front = -1.3
				_pan_strike()
			elif t > 0.95:
				_end_attack()
		"knives":
			if t < 0.7:
				_arm_back = lerpf(0.0, 2.3, t / 0.7)
			elif not _atk.has("done"):
				_atk["done"] = true
				_arm_back = -1.4
				_throw_knives()
			elif t > 1.0:
				_end_attack()
		"plates":
			var n: int = _atk["n"]
			var each := 0.45
			var i := int(t / each)
			_arm_back = 2.0 if fmod(t, each) < each * 0.6 else -1.2
			if i > int(_atk.get("thrown", -1)) and i < n:
				_atk["thrown"] = i
				_throw_plate(i)
			if t > each * n + 0.3:
				_end_attack()


func _start_attack() -> void:
	var d: float = global_position.distance_to(run.player.global_position)
	if d < PAN_RANGE + 30.0 and randf() < 0.75:
		_atk = {"kind": "pan", "t": 0.0}
		Audio.play("swing", -6.0)
		return
	_next = (_next + 1) % 2
	if _next == 0:
		var count := 5 if _angry else 3
		var base_dir: Vector2 = (run.player.global_position + Vector2(0, -44) - _hand_from()).normalized()
		var dirs: Array[Vector2] = []
		for i in count:
			dirs.append(base_dir.rotated((i - (count - 1) / 2.0) * 0.22))
		_atk = {"kind": "knives", "t": 0.0, "dirs": dirs}
	else:
		_atk = {"kind": "plates", "t": 0.0, "n": 3 if _angry else 2, "targets": _plate_targets(3 if _angry else 2)}


func _end_attack() -> void:
	_atk = {}
	_atk_cd = (1.1 if _angry else 1.6) + randf_range(-0.2, 0.3)


func _plate_targets(n: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var area: Rect2 = run.arena_rect().grow(-40)
	for i in n:
		var p: Vector2 = run.player.global_position + (Vector2.ZERO if i == 0 else Vector2(randf_range(-140, 140), randf_range(-80, 80)))
		out.append(Vector2(clampf(p.x, area.position.x, area.end.x), clampf(p.y, area.position.y, area.end.y)))
	return out


func _hand_from() -> Vector2:
	return global_position + Vector2(-30 * _facing, -150)


func _pan_strike() -> void:
	Audio.play("pan_clang", -2.0, 0.05)
	run.shake(8.0)
	var hit_at := global_position + Vector2(_facing * 70.0, -10)
	run.fx.ring(hit_at, 50.0, UITheme.BONE, 0.35, 3.0)
	var player: Player = run.player
	var d: Vector2 = player.global_position - global_position
	if d.length() < PAN_RANGE and d.x * _facing > -40.0:
		var before := player.hp
		player.take_damage(PAN_DAMAGE * GameState.enemy_dmg_mult() * atk_mult())
		if player.hp < before:
			player.root(PAN_ROOT)


func _throw_knives() -> void:
	Audio.play("knife", -3.0, 0.08)
	for dir: Vector2 in _atk["dirs"]:
		var s := ChefShot.new()
		s.run = run
		s.kind = "knife"
		s.position = _hand_from()
		s.velocity = dir * KNIFE_SPEED
		run.world.add_child(s)


func _throw_plate(i: int) -> void:
	var targets: Array = _atk["targets"]
	var s := ChefShot.new()
	s.run = run
	s.kind = "plate"
	s.position = _hand_from()
	s.target = targets[i]
	run.world.add_child(s)
	Audio.play("throw", -6.0, 0.1)


# --- Dibujo / Drawing -------------------------------------------------------------

func _draw() -> void:
	var a := _fade
	if _dying >= 0.0:
		a = clampf(1.0 - (_dying - 0.6) / 1.2, 0.0, 1.0)
	# Saliendo de la tele: pequeño y con glitch, y luego un salto hasta el suelo
	# Climbing out of the TV: small and glitchy, then a leap down to the floor
	var off := Vector2.ZERO
	var s := 1.0
	if _wake > 0.0 and not preview:
		var k := 1.0 - _wake / WAKE_TIME
		var tv: Vector2 = Bedroom.to_world(LivingRoom.TV_SCREEN.get_center() + Vector2(0, 40)) - global_position
		if k < 0.45:
			off = tv + Vector2(randf_range(-3, 3), 0)
			s = lerpf(0.15, 0.35, k / 0.45)
		else:
			var u := (k - 0.45) / 0.55
			off = tv.lerp(Vector2.ZERO, u) + Vector2(0, -sin(u * PI) * 140.0)
			s = lerpf(0.35, 1.0, u)
	if _wake <= 0.0 or preview:
		draw_colored_polygon(_ellipse(Vector2.ZERO, Vector2(50, 13)), Color(0.05, 0.02, 0.15, 0.4 * a))
		_draw_attack_warnings()
	if glitch_t > 0.0 or (_wake > 0.0 and not preview and fmod(_t, 0.3) < 0.1):
		var j := Vector2(randf_range(-6, 6), randf_range(-2, 2))
		_draw_chef(off + Vector2(-5, 0) + j, s, Color(GLITCH_A, 0.5), a * 0.5)
		_draw_chef(off + Vector2(5, 0) - j, s, Color(GLITCH_B, 0.5), a * 0.5)
	_draw_chef(off, s, Color.WHITE, a)
	draw_set_transform(Vector2.ZERO)
	# Pelusa, sangrado y quemadura también en los jefes / Fluff, bleeding and burning on bosses too
	draw_set_transform(Vector2.ZERO)
	_draw_statuses(0.0, 1.0 if _dying < 0.0 else 0.0)


func _draw_attack_warnings() -> void:
	if _atk.is_empty():
		return
	var t: float = _atk["t"]
	match String(_atk["kind"]):
		"pan":
			if t < 0.55:
				var k := t / 0.55
				var col := Settings.warning_color()
				draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
				var pts := PackedVector2Array([Vector2.ZERO])
				for i in 13:
					var ang := (-PI / 2.0 + PI * i / 12.0) * 1.0
					pts.append(Vector2(cos(ang) * _facing, sin(ang)) * PAN_RANGE)
				draw_colored_polygon(pts, Color(col, 0.12 + 0.2 * k))
				draw_arc(Vector2.ZERO, PAN_RANGE * k, -PI / 2.0 if _facing > 0 else PI / 2.0, PI / 2.0 if _facing > 0 else 3.0 * PI / 2.0, 16, Color(col, 0.7), 3.0)
				draw_set_transform(Vector2.ZERO)
		"knives":
			if t < 0.7:
				var from := _hand_from() - global_position
				for dir: Vector2 in _atk["dirs"]:
					EnemyShot.draw_warning(self, from, dir, EnemyShot.reach(run, _hand_from(), dir, 900.0), 16.0, t / 0.7)


func _draw_chef(offset: Vector2, s: float, tint: Color, a: float) -> void:
	var mod := Sprites.flash_color(_flash * 0.6, a) * tint
	var step := sin(_walk) * 5.0
	var xf := Transform2D(0.0, Vector2(_facing * s, s), 0.0, offset)
	draw_set_transform_matrix(xf)
	# Brazo de atrás (el que lanza) / Back arm (the throwing one)
	_draw_arm(xf, Vector2(-36, -156), _arm_back, mod, false)
	Sprites.draw(self, "chef_leg", mod, Vector2(-14, step))
	Sprites.draw(self, "chef_leg", mod, Vector2(14, -step))
	Sprites.draw(self, "chef_body", mod)
	var breath := sin(_t * 2.0) * 1.5
	Sprites.draw(self, "chef_head", mod, Vector2(0, breath))
	# Ceño fruncido en la segunda fase / Frown in the second phase
	if _angry:
		draw_line(Vector2(-18, -201 + breath), Vector2(-4, -197 + breath), Color("16141f", a), 3.0)
		draw_line(Vector2(18, -201 + breath), Vector2(4, -197 + breath), Color("16141f", a), 3.0)
	# Brazo de delante con la sartén / Front arm with the frying pan
	_draw_arm(xf, Vector2(38, -156), _arm_front, mod, true)
	draw_set_transform(Vector2.ZERO)


func _draw_arm(xf: Transform2D, shoulder: Vector2, rot: float, mod: Color, pan: bool) -> void:
	var arm_xf := xf * Transform2D(rot, shoulder)
	draw_set_transform_matrix(arm_xf)
	Sprites.draw(self, "chef_arm", mod)
	if pan:
		draw_set_transform_matrix(arm_xf * Transform2D(PI, Vector2(0, 58)))
		Sprites.draw(self, "chef_pan", mod)
	elif not _atk.is_empty() and String(_atk["kind"]) == "knives" and not _atk.has("done"):
		draw_set_transform_matrix(arm_xf * Transform2D(PI / 2.0, Vector2(0, 58)))
		Sprites.draw(self, "shot_knife", mod)
	elif not _atk.is_empty() and String(_atk["kind"]) == "plates":
		draw_set_transform_matrix(arm_xf * Transform2D(0.0, Vector2(0, 60)))
		Sprites.draw(self, "shot_plate", mod)
	draw_set_transform_matrix(xf)


func _ellipse(c: Vector2, r: Vector2, n := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var ang := TAU * i / n
		pts.append(c + Vector2(cos(ang) * r.x, sin(ang) * r.y))
	return pts


func head_top() -> Vector2:
	return Vector2(0, -280)
