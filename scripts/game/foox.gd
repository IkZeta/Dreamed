class_name Foox
extends Node2D
## Foox: zorro fantasma. Lento, frágil y de poco daño. En sueños más profundos es más duro.
## Foox: a ghost fox. Slow, fragile and low damage. Tougher in deeper dreams.
##
## Estados que le pueden poner las mejoras / States upgrades can apply:
##  aturdido (stun), lento (slow), vulnerable (+50 % de daño), con glitch (efecto visual)
##  y "en rebote": sale despedido y golpea a los Foox con los que choca.

const BASE_HP := 16.0
const CONTACT_DAMAGE := 2.0
const RADIUS := 22.0
const EYES := Color("bfe6e2")
const GLITCH_A := Color("ff5fd2")
const GLITCH_B := Color("5ff2ff")

enum State { SPAWNING, ALIVE, DYING }

var run: Node  # Run
var max_hp := BASE_HP
var hp := BASE_HP
var state := State.SPAWNING
var speed := 95.0
var knock := Vector2.ZERO
var external_pull := Vector2.ZERO  # lo usa la aspiradora / used by the vacuum

var stun_t := 0.0
var slow_t := 0.0
var vuln_t := 0.0
var glitch_t := 0.0
## Rebote / Ricochet: tiempo restante, daño que hace al chocar y cuántos más puede encadenar
var bounce_t := 0.0
var bounce_damage := 0.0
var bounce_chain := 0
var _bounced: Array = []

var _t := 0.0
var _phase := 0.0
var _flash := 0.0
var _fade := 0.0
var _facing := 1.0

static var _glow: GradientTexture2D


func setup(p_run: Node, hp_mult := 1.0, speed_mult := 1.0) -> void:
	run = p_run
	max_hp = BASE_HP * hp_mult
	hp = max_hp
	speed *= speed_mult


func _ready() -> void:
	speed += randf_range(-10, 20)
	_phase = randf() * TAU
	if _glow == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0.8))
		g.set_color(1, Color(1, 1, 1, 0))
		_glow = GradientTexture2D.new()
		_glow.gradient = g
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(0.5, 0.0)


func _physics_process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 5.0)
	for k in ["stun_t", "slow_t", "vuln_t", "glitch_t", "bounce_t"]:
		set(k, maxf(0.0, float(get(k)) - delta))
	match state:
		State.SPAWNING:
			_fade = minf(1.0, _fade + delta / 0.6)
			if _fade >= 1.0:
				state = State.ALIVE
		State.DYING:
			_fade -= delta / 0.35
			if _fade <= 0.0:
				queue_free()
			return
		State.ALIVE:
			_move(delta)
			if bounce_t > 0.0:
				_ricochet()
			if stun_t <= 0.0:
				_touch_player()
	queue_redraw()


func _move(delta: float) -> void:
	var vel := Vector2.ZERO
	if stun_t <= 0.0:
		var player: Node2D = run.player
		var dir := (player.global_position - global_position).normalized()
		# Serpentea un poco, como si flotara / Weaves slightly, as if floating
		var side := Vector2(-dir.y, dir.x) * sin(_t * 2.0 + _phase) * 0.45
		vel = (dir + side).normalized() * speed * (0.5 if slow_t > 0.0 else 1.0)
	# Se separa de otros Foox / Keeps apart from other Foox
	for other: Node2D in run.enemies.get_children():
		if other == self:
			continue
		var d := global_position - other.global_position
		var dist := d.length()
		if dist > 0.01 and dist < RADIUS * 2.2:
			vel += d / dist * (RADIUS * 2.2 - dist) * 6.0
	vel += knock + external_pull
	var before := position
	position += vel * delta
	knock = knock.move_toward(Vector2.ZERO, (500.0 if bounce_t > 0.0 else 1400.0) * delta)
	external_pull = Vector2.ZERO
	if absf(vel.x) > 5.0:
		_facing = signf(vel.x)
	var clamped: Vector2 = run.clamp_to_arena(position, RADIUS)
	# Si sale despedido y choca con una pared, rebota / If flung against a wall, it bounces off
	if bounce_t > 0.0 and clamped != position:
		var n := (clamped - position).normalized()
		if n != Vector2.ZERO:
			knock = knock.bounce(n) * 0.85
		Audio.play("ricochet", -13.0, 0.15)
	position = clamped
	if before == position:
		knock = Vector2.ZERO


## Mientras rebota, golpea a los Foox con los que choca y les pasa el rebote.
## While ricocheting, it hits the Foox it bumps into and passes the bounce on.
func _ricochet() -> void:
	for other: Node2D in run.enemies.get_children():
		if other == self or _bounced.has(other) or not other.is_targetable():
			continue
		if global_position.distance_to(other.global_position) < RADIUS * 2.4:
			_bounced.append(other)
			var dir := (other.global_position - global_position).normalized()
			other.hit(bounce_damage, dir * knock.length() * 0.8)
			run.fx.ring(other.global_position + Vector2(0, -18), 18.0, UITheme.GOLD, 0.3, 2.0)
			Audio.play("ricochet", -10.0, 0.15)
			if bounce_chain > 0:
				other.start_bounce(bounce_damage * 0.9, bounce_chain - 1, [self])


func start_bounce(damage: float, chain: int, ignore: Array = []) -> void:
	bounce_t = 0.7
	bounce_damage = damage
	bounce_chain = chain
	_bounced = ignore.duplicate()


func _touch_player() -> void:
	var player: Node2D = run.player
	if global_position.distance_to(player.global_position + Vector2(0, -45)) < RADIUS + 28.0:
		player.take_damage(CONTACT_DAMAGE)


func is_targetable() -> bool:
	return state != State.DYING


func hit(amount: float, impulse := Vector2.ZERO) -> void:
	if state == State.DYING:
		return
	if vuln_t > 0.0:
		amount *= 1.5
	hp -= amount
	knock += impulse
	_flash = 1.0
	Audio.play("hit", -13.0, 0.1)
	run.fx.text(global_position + Vector2(0, -50), str(roundi(amount)), GLITCH_A if vuln_t > 0.0 else UITheme.BONE)
	if hp <= 0.0:
		die(true)


## Aplica un glitch de Silly / Applies one of Silly's glitches
func glitch(stun := 0.0, slow := 0.0, vulnerable := 0.0) -> void:
	if glitch_t <= 0.0:
		Audio.play("glitch", -12.0, 0.1)
	stun_t = maxf(stun_t, stun)
	slow_t = maxf(slow_t, slow)
	vuln_t = maxf(vuln_t, vulnerable)
	glitch_t = maxf(glitch_t, maxf(stun, maxf(slow, vulnerable)))


func die(counted: bool) -> void:
	if state == State.DYING:
		return
	state = State.DYING
	_fade = 1.0
	run.fx.dissipate(global_position + Vector2(0, -16), Color("dfe3f0"))
	if counted:
		Audio.play("foox_die", -5.0, 0.1)
		run.on_enemy_killed(self)


func _draw() -> void:
	var a := _fade
	var bob := sin(_t * 2.6 + _phase) * 4.0
	if glitch_t > 0.0:
		# Copias desplazadas en rosa y cian, como un vídeo que falla
		# Pink and cyan shifted copies, like a glitching video
		var j := Vector2(randf_range(-6, 6), randf_range(-2, 2))
		_draw_fox(Vector2(-5, bob) + j, Color(GLITCH_A, 0.55), a * 0.7)
		_draw_fox(Vector2(5, bob) - j, Color(GLITCH_B, 0.55), a * 0.7)
	var body := Color("dfe3f0").lerp(Color.WHITE, _flash)
	_draw_fox(Vector2(0, bob), body, a)
	if glitch_t > 0.0:
		# Franjas cortadas / Torn scanlines
		for i in 3:
			var y := randf_range(-50, 6)
			draw_rect(Rect2(randf_range(-40, 10), y, randf_range(20, 50), 3), Color([GLITCH_A, GLITCH_B, Color.WHITE][i], 0.6 * a))
	if stun_t > 0.0:
		# Estrellitas girando sobre la cabeza / Little stars spinning over its head
		for i in 3:
			var ang := _t * 4.0 + i * TAU / 3.0
			DreamBackground.draw_star(self, Vector2(cos(ang) * 18.0, -58 + sin(ang) * 5.0), 2.0, Color(UITheme.GOLD, a))
	draw_set_transform(Vector2.ZERO)


func _draw_fox(offset: Vector2, body: Color, a: float) -> void:
	draw_set_transform(offset, 0.0, Vector2(_facing, 1.0))
	draw_texture_rect(_glow, Rect2(-60, -70, 120, 100), false, Color(UITheme.MIST, 0.22 * a))
	# Cola de humo que ondula / Smoky tail that ripples
	for i in 14:
		var k := i / 13.0
		var p := Vector2(-18 - k * 46.0, -16 - k * 18.0 + sin(_t * 4.0 - k * 4.0 + _phase) * 8.0 * k)
		draw_circle(p, lerpf(10.0, 2.0, k), Color(body, a * lerpf(0.42, 0.04, k)))
	# Cuerpo que se deshace por abajo / Body dissolving at the bottom
	var torso := PackedVector2Array()
	for i in 24:
		var t := TAU * i / 24.0
		torso.append(Vector2(cos(t) * 22.0, -16.0 + sin(t) * 12.0))
	draw_colored_polygon(torso, Color(body, 0.5 * a))
	for i in 4:
		var x := -14.0 + i * 9.0
		var y := -2.0 + fposmod(_t * 14.0 + i * 5.0, 14.0)
		draw_circle(Vector2(x, y), 4.0 * (1.0 - (y + 2.0) / 16.0), Color(body, 0.25 * a))
	# Cabeza con hocico y orejas / Head with snout and ears
	var head := PackedVector2Array([
		Vector2(8, -30), Vector2(13, -46), Vector2(19, -34), Vector2(25, -46), Vector2(29, -30),
		Vector2(44, -22), Vector2(30, -16), Vector2(14, -18),
	])
	draw_colored_polygon(head, Color(body, 0.75 * a))
	draw_polyline(head + PackedVector2Array([head[0]]), Color(1, 1, 1, 0.35 * a), 1.0, true)
	# Ojos rasgados que brillan / Glowing slit eyes
	draw_line(Vector2(22, -27), Vector2(28, -25), Color(EYES, a), 2.2, true)
	draw_circle(Vector2(26, -26), 5.0, Color(EYES, 0.15 * a))
