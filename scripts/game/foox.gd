class_name Foox
extends Node2D
## Foox: zorro fantasma de la primera oleada. Lento, frágil y de poco daño.
## Foox: the first wave's ghost fox. Slow, fragile and low damage.

const MAX_HP := 16.0
const CONTACT_DAMAGE := 2.0
const RADIUS := 22.0
const EYES := Color("bfe6e2")

enum State { SPAWNING, ALIVE, DYING }

var run: Node  # Run
var hp := MAX_HP
var state := State.SPAWNING
var speed := 95.0
var knock := Vector2.ZERO
var external_pull := Vector2.ZERO  # lo usa la aspiradora / used by the vacuum
var _t := 0.0
var _phase := 0.0
var _flash := 0.0
var _fade := 0.0
var _facing := 1.0

static var _glow: GradientTexture2D


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
			_touch_player()
	queue_redraw()


func _move(delta: float) -> void:
	var player: Node2D = run.player
	var to_player := player.global_position - global_position
	var dir := to_player.normalized()
	# Serpentea un poco, como si flotara / Weaves slightly, as if floating
	var side := Vector2(-dir.y, dir.x) * sin(_t * 2.0 + _phase) * 0.45
	var vel := (dir + side).normalized() * speed
	# Se separa de otros Foox / Keeps apart from other Foox
	for other: Node2D in run.enemies.get_children():
		if other == self:
			continue
		var d := global_position - other.global_position
		var dist := d.length()
		if dist > 0.01 and dist < RADIUS * 2.2:
			vel += d / dist * (RADIUS * 2.2 - dist) * 6.0
	vel += knock + external_pull
	position += vel * delta
	knock = knock.move_toward(Vector2.ZERO, 1400.0 * delta)
	external_pull = Vector2.ZERO
	if absf(vel.x) > 5.0:
		_facing = signf(vel.x)
	position = run.clamp_to_arena(position, RADIUS)


func _touch_player() -> void:
	var player: Node2D = run.player
	if global_position.distance_to(player.global_position + Vector2(0, -45)) < RADIUS + 28.0:
		player.take_damage(CONTACT_DAMAGE)


func is_targetable() -> bool:
	return state != State.DYING


func hit(amount: float, impulse := Vector2.ZERO) -> void:
	if state == State.DYING:
		return
	hp -= amount
	knock += impulse
	_flash = 1.0
	Audio.play("hit", -9.0, 0.15)
	run.fx.text(global_position + Vector2(0, -50), str(roundi(amount)), UITheme.BONE)
	if hp <= 0.0:
		die(true)


func die(counted: bool) -> void:
	if state == State.DYING:
		return
	state = State.DYING
	_fade = 1.0
	run.fx.dissipate(global_position + Vector2(0, -16), Color("dfe3f0"))
	if counted:
		Audio.play("foox_die", -5.0, 0.1)
	if counted:
		run.on_enemy_killed(self)


func _draw() -> void:
	var a := _fade
	var bob := sin(_t * 2.6 + _phase) * 4.0
	var body := Color("dfe3f0").lerp(Color.WHITE, _flash)
	draw_set_transform(Vector2(0, bob), 0.0, Vector2(_facing, 1.0))

	# Resplandor / Glow
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
	draw_set_transform(Vector2.ZERO)
