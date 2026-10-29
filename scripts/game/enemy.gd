class_name Enemy
extends Node2D
## Base de todos los enemigos: movimiento, choques, daño y los estados que ponen las mejoras.
## Base for every enemy: movement, collisions, damage and the states upgrades apply.
##
## Estados / States: aturdido (stun), lento (slow), vulnerable (vuln), glitch (solo visual)
## y "en rebote": sale despedido y golpea a los enemigos con los que choca.
## Para crear un enemigo nuevo: hereda, pon los valores en _init() y dibuja en _draw_body().
## To make a new enemy: inherit, set values in _init() and draw in _draw_body().

const GLITCH_A := Color("ff5fd2")
const GLITCH_B := Color("5ff2ff")

enum State { SPAWNING, ALIVE, DYING }
## Color de cada habilidad del élite: dividirse (naranja), charcos (azul) y rapidez (morado)
## Colour of each elite ability: split (orange), puddles (blue) and haste (purple)
const ELITE_COLORS := {"split": Color("ff8a1f"), "puddle": Color("2fa8ff"), "haste": Color("c44dff")}
const ELITE_TINTS := {"split": Vector3(1.0, 0.55, 0.25), "puddle": Vector3(0.3, 0.55, 1.0), "haste": Vector3(0.75, 0.3, 1.0)}
const ELITE_SHADER := preload("res://assets/shaders/elite.gdshader")

var run: Node  # Run
var max_hp := 16.0
var hp := 16.0
var contact_damage := 2.0
var radius := 22.0
var speed := 95.0
var mass := 1.0            # más masa = menos empuje / more mass = less knockback
var aim_height := 18.0     # a qué altura apuntan las armas / where weapons aim
var shards := 1            # trozos de estrella que suelta / star shards it drops
var bestiary_id := ""      # entrada del bestiario / bestiary entry
## Élite: más grande, brillante, con más vida y una habilidad ("split", "puddle" o "haste")
## Elite: bigger, glowing, with more health and an ability ("split", "puddle" or "haste")
var elite := false
var elite_power := ""
var _puddle_t := 0.0
var preview := false       # solo se dibuja (bestiario) / only drawn (bestiary)
var state := State.SPAWNING
var knock := Vector2.ZERO
var external_pull := Vector2.ZERO  # lo usa la aspiradora / used by the vacuum

var stun_t := 0.0
var slow_t := 0.0
var vuln_t := 0.0
var vuln_mult := 1.5
var glitch_t := 0.0
var bounce_t := 0.0
var bounce_damage := 0.0
var bounce_chain := 0
var _bounced: Array = []

var _fall_t := -1.0          # cayendo por un agujero / falling down a hole
var _fall_from := Vector2.ZERO
var _fall_to := Vector2.ZERO

var _t := 0.0
var _phase := 0.0
var _flash := 0.0
var _fade := 0.0
var _facing := 1.0


func setup(p_run: Node, hp_mult := 1.0, speed_mult := 1.0) -> void:
	run = p_run
	max_hp *= hp_mult
	hp = max_hp
	speed *= speed_mult


func _ready() -> void:
	speed *= randf_range(0.92, 1.12)
	_phase = randf() * TAU
	# Pesadilla: más vida y más daño / Nightmare: more health and damage
	max_hp *= GameState.enemy_hp_mult()
	contact_damage *= GameState.enemy_dmg_mult()
	if elite:
		max_hp *= 3.0
		shards *= 4
		scale = Vector2.ONE * 1.3
		if elite_power == "":
			elite_power = ["split", "puddle", "haste"][randi() % 3]
		# Aspecto demoníaco con el color de su habilidad / Demonic look in its ability's colour
		var m := ShaderMaterial.new()
		m.shader = ELITE_SHADER
		m.set_shader_parameter("outline_color", elite_color())
		m.set_shader_parameter("tint_color", ELITE_TINTS[elite_power])
		material = m
		if elite_power == "haste":
			speed *= 1.5
		if not preview:
			Progress.see("elite")
	hp = max_hp
	if not preview:
		Progress.see(bestiary_id)


func _physics_process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 5.0)
	stun_t = maxf(0.0, stun_t - delta)
	slow_t = maxf(0.0, slow_t - delta)
	vuln_t = maxf(0.0, vuln_t - delta)
	glitch_t = maxf(0.0, glitch_t - delta)
	bounce_t = maxf(0.0, bounce_t - delta)
	match state:
		State.SPAWNING:
			_fade = minf(1.0, _fade + delta / 0.6)
			if _fade >= 1.0:
				state = State.ALIVE
		State.DYING:
			if _fall_t >= 0.0:
				_update_fall(delta)
				return
			_fade -= delta / 0.35
			if _fade <= 0.0:
				queue_free()
			return
		State.ALIVE:
			_move(delta)
			# Élite del charco: deja charcos que frenan / Puddle elite: leaves slowing puddles
			if elite and elite_power == "puddle":
				_puddle_t -= delta
				if _puddle_t <= 0.0:
					_puddle_t = 0.7
					run.spawn_puddle(global_position)
			if bounce_t > 0.0:
				_ricochet()
			if stun_t <= 0.0 and is_dangerous():
				_touch_player()
			if stun_t <= 0.0:
				_act(delta)
	queue_redraw()


## Velocidad que quiere llevar (por defecto, ir a por Kroker) / Desired velocity (by default, chase Kroker)
func _desired_velocity() -> Vector2:
	var to_player: Vector2 = run.player.global_position - global_position
	var dir := to_player.normalized()
	return dir * speed


## Para comportamientos extra, como disparar / For extra behaviour, such as shooting
func _act(_delta: float) -> void:
	pass


## ¿Hace daño al tocar a Kroker? / Does touching Kroker hurt him?
func is_dangerous() -> bool:
	return true


func _move(delta: float) -> void:
	var vel := Vector2.ZERO
	if stun_t <= 0.0:
		vel = _desired_velocity() * (0.5 if slow_t > 0.0 else 1.0)
	# Se separa de los demás enemigos / Keeps apart from other enemies
	for other: Node2D in run.enemies.get_children():
		if other == self:
			continue
		var d := global_position - other.global_position
		var dist := d.length()
		var min_d := radius + float(other.get("radius"))
		if dist > 0.01 and dist < min_d:
			vel += d / dist * (min_d - dist) * 6.0
	vel += knock + external_pull
	position += vel * delta
	# Empujado hacia un agujero: se cae y desaparece / Shoved into a hole: it falls in and is gone
	if can_fall() and (knock.length() > 200.0 or bounce_t > 0.0):
		var to: Vector2 = run.hole_at(position, radius, knock + vel)
		if to != Vector2.INF:
			_start_fall(to)
			return
	knock = knock.move_toward(Vector2.ZERO, (500.0 if bounce_t > 0.0 else 1400.0) * delta)
	external_pull = Vector2.ZERO
	if absf(vel.x) > 5.0:
		_facing = signf(vel.x)
	var clamped: Vector2 = run.clamp_to_arena(position, radius)
	if bounce_t > 0.0 and clamped != position:
		var n := (clamped - position).normalized()
		if n != Vector2.ZERO:
			knock = knock.bounce(n) * 0.85
		Audio.play("ricochet", -14.0, 0.1)
	position = clamped


## Los jefes no se pueden tirar por los agujeros / Bosses can't be thrown down holes
func can_fall() -> bool:
	return true


func _start_fall(to: Vector2) -> void:
	Progress.add_stat("falls")
	_fall_from = run.clamp_to_arena(position, radius)
	position = _fall_from
	_fall_to = to
	_fall_t = 0.0
	state = State.DYING
	_fade = 1.0
	knock = Vector2.ZERO
	run.fx.text(global_position + Vector2(0, -aim_height - 40), tr("ENEMY_FELL"), UITheme.GOLD, 20)
	Audio.play("throw", -6.0, 0.15)
	_death_sound()
	run.on_enemy_killed(self)


func _update_fall(delta: float) -> void:
	_fall_t += delta / 0.55
	var k := minf(_fall_t, 1.0)
	position = _fall_from.lerp(_fall_to, minf(1.0, k * 1.6))
	rotation = k * 2.5 * _facing
	scale = Vector2.ONE * (1.0 - k * 0.85)
	_fade = 1.0 - k
	if k >= 1.0:
		run.fx.ring(_fall_to, 16.0, Color("8d7ff0"), 0.4, 2.0)
		queue_free()
	queue_redraw()


func _ricochet() -> void:
	for other: Node2D in run.enemies.get_children():
		if other == self or _bounced.has(other) or not other.is_targetable():
			continue
		if global_position.distance_to(other.global_position) < radius + float(other.get("radius")) + 8.0:
			_bounced.append(other)
			var dir := (other.global_position - global_position).normalized()
			other.hit(bounce_damage, dir * knock.length() * 0.6)
			run.fx.ring(other.aim_point(), 18.0, UITheme.GOLD, 0.3, 2.0)
			Audio.play("ricochet", -11.0, 0.1)
			if bounce_chain > 0:
				other.start_bounce(bounce_damage, bounce_chain - 1, [self])
			bounce_chain = 0  # solo pasa el rebote una vez / passes the bounce on only once


func start_bounce(damage: float, chain: int, ignore: Array = []) -> void:
	bounce_t = 0.7
	bounce_damage = damage
	bounce_chain = chain
	_bounced = ignore.duplicate()


func _touch_player() -> void:
	var player: Node2D = run.player
	if global_position.distance_to(player.global_position + Vector2(0, -28)) < radius + 22.0:
		player.take_damage(contact_damage)


func is_targetable() -> bool:
	return state != State.DYING


## Cuánto más cerca llegan las armas a un enemigo grande / How much closer weapons reach on a big enemy
func reach_bonus() -> float:
	return 0.0


func aim_point() -> Vector2:
	return global_position + Vector2(0, -aim_height)


func hit(amount: float, impulse := Vector2.ZERO) -> void:
	if state == State.DYING:
		return
	if vuln_t > 0.0:
		amount *= vuln_mult
	hp -= amount
	knock += impulse / mass
	_flash = 1.0
	Audio.play("hit", -13.0, 0.1)
	if Settings.damage_numbers:
		run.fx.text(global_position + Vector2(0, -aim_height - 34), str(roundi(amount)), GLITCH_A if vuln_t > 0.0 else UITheme.BONE)
	if hp <= 0.0:
		die(true)


## Glitch de Silly: congelar, ralentizar o dejar vulnerable / Silly's glitch: freeze, slow or make vulnerable
func glitch(stun := 0.0, slow := 0.0, vulnerable := 0.0, mult := 1.5) -> void:
	if glitch_t <= 0.0:
		Audio.play("glitch", -14.0, 0.05)
	stun_t = maxf(stun_t, stun)
	slow_t = maxf(slow_t, slow)
	if vulnerable > 0.0:
		vuln_t = maxf(vuln_t, vulnerable)
		vuln_mult = mult
	glitch_t = maxf(glitch_t, maxf(stun, maxf(slow, vulnerable)))


func die(counted: bool) -> void:
	if state == State.DYING:
		return
	state = State.DYING
	_fade = 1.0
	run.fx.dissipate(aim_point(), Color("dfe3f0"))
	if counted:
		_death_sound()
		run.on_enemy_killed(self)


func _death_sound() -> void:
	Audio.play("foox_die", -8.0, 0.1)


func _draw() -> void:
	var a := _fade
	var bob := sin(_t * 2.6 + _phase) * 3.0
	if elite:
		# Sombra de su color que late bajo el élite / Pulsing shadow in its colour under the elite
		var pulse := 0.85 + 0.15 * sin(_t * 5.0)
		var r := (radius + 22.0) * pulse
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, r, Color(elite_color().darkened(0.7), 0.45 * a))
		draw_arc(Vector2.ZERO, r, 0, TAU, 28, Color(elite_color(), 0.8 * a), 3.0)
		draw_set_transform(Vector2.ZERO)
	if glitch_t > 0.0:
		var j := Vector2(randf_range(-6, 6), randf_range(-2, 2))
		_draw_body(Vector2(-5, bob) + j, Color(GLITCH_A, 0.5), a * 0.6)
		_draw_body(Vector2(5, bob) - j, Color(GLITCH_B, 0.5), a * 0.6)
	_draw_body(Vector2(0, bob), Color.WHITE, a)
	draw_set_transform(Vector2.ZERO)
	if elite:
		_draw_horns(head_top() + Vector2(0, bob), a)
	if glitch_t > 0.0:
		for i in 3:
			var y := randf_range(-aim_height * 2.5, 6)
			draw_rect(Rect2(randf_range(-40, 10), y, randf_range(20, 50), 3), Color([GLITCH_A, GLITCH_B, Color.WHITE][i], 0.5 * a))
	if stun_t > 0.0:
		for i in 3:
			var ang := _t * 4.0 + i * TAU / 3.0
			DreamBackground.draw_star(self, Vector2(cos(ang) * 18.0, -aim_height * 3.0 + sin(ang) * 5.0), 2.0, Color(UITheme.GOLD, a))


func elite_color() -> Color:
	return ELITE_COLORS.get(elite_power, Color("ff2230"))


## Dónde está lo alto de la cabeza (para los cuernos del élite) / Where the top of the head is (for elite horns)
func head_top() -> Vector2:
	return Vector2(0, -aim_height * 2.2)


## Cuernos de demonio con brillo rojo / Demon horns with a red glow
func _draw_horns(top: Vector2, a: float) -> void:
	for side in [-1.0, 1.0]:
		var base := top + Vector2(side * 9.0 * _facing, 4.0)
		var tip := base + Vector2(side * 9.0, -16.0)
		var pts := PackedVector2Array([base + Vector2(-4, 0), base + Vector2(4, 0), tip])
		draw_colored_polygon(pts, Color(0.2, 0.02, 0.06, a))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(elite_color(), a), 2.0)


## Dibuja el cuerpo. "tint" es blanco normalmente y rosa/cian en las copias del glitch.
## Draws the body. "tint" is white normally and pink/cyan for the glitch copies.
func _draw_body(_offset: Vector2, _tint: Color, _alpha: float) -> void:
	pass
