class_name AlarmClock
extends Enemy
## Despertador (desde el Sueño 9; poco común): corre hacia Kroker a saltitos haciendo tic-tac. No
## hace daño, pero si llega a sonar (se le acaba la cuerda o toca a Kroker) despierta a todos: los
## enemigos van más rápidos un rato. Si lo matas antes, nada. Si lo tiras por un agujero, suena
## desde abajo, amortiguado, y adormece a todos: van más lentos. Enseña que a veces es mejor tirar
## que matar.
## Alarm Clock (from Dream 9; uncommon): hops towards Kroker going tick-tock. It does no damage, but
## if it gets to ring (it runs out of winding or touches Kroker) it wakes everyone up: enemies get
## faster for a while. Kill it first and nothing happens. Throw it down a hole and it rings from
## below, muffled, lulling everyone: they get slower. It teaches that sometimes throwing beats killing.

## Cuerda: segundos hasta que suena / Winding: seconds until it rings
const FUSE := 7.0
## Lo que dura el despertar y lo que acelera / How long the wake-up lasts and how much it speeds up
const HASTE_TIME := 5.0
const HASTE_MULT := 1.3
## Lo que dura el sueño de los de alrededor si cae por un agujero / How long everyone stays drowsy if it falls down a hole
const LULL_TIME := 3.0
const RED := Color("e0505e")

var fuse := FUSE
var _tick := 0.0
var _rang := false


func _init() -> void:
	bestiary_id = "alarm"
	max_hp = 10.0
	hp = max_hp
	contact_damage = 0.0
	radius = 20.0
	speed = 150.0
	mass = 0.7
	aim_height = 26.0
	shards = 2


## Va derecho a por Kroker a saltitos; cuanto menos cuerda le queda, más deprisa
## Goes straight for Kroker in little hops; the less winding it has left, the faster
func _desired_velocity() -> Vector2:
	var dir: Vector2 = (run.player.global_position - global_position).normalized()
	var hurry := 1.0 + 0.5 * (1.0 - fuse / FUSE)
	var hop := 0.5 + 0.5 * absf(sin(_t * 7.0 + _phase))
	return dir * speed * hurry * hop


## Al tocar a Kroker no le pega: suena / Touching Kroker doesn't hurt him: it rings
func _touch_player() -> void:
	var player: Node2D = run.player
	if global_position.distance_to(player.global_position + Vector2(0, -28)) < radius + 26.0:
		_ring()


func _act(delta: float) -> void:
	fuse -= delta * (0.5 if slow_t > 0.0 else 1.0)
	_tick -= delta
	if _tick <= 0.0:
		# Cada vez hace tic-tac más deprisa / It tick-tocks faster and faster
		_tick = lerpf(0.9, 0.25, 1.0 - fuse / FUSE)
		if global_position.distance_squared_to(run.player.global_position) < 1100.0 * 1100.0:
			Audio.play_at("alarm_tick", global_position, -16.0, 0.05, 1.0 + 0.3 * (1.0 - fuse / FUSE))
	if fuse <= 0.0:
		_ring()


## ¡RIIIING! Todos se despiertan y van más deprisa / RIIIING! Everyone wakes up and speeds up
func _ring() -> void:
	if _rang or state != State.ALIVE:
		return
	_rang = true
	Audio.play("alarm_ring", -6.0, 0.05)
	run.shake(4.0)
	run.enemy_haste(HASTE_TIME, HASTE_MULT)
	run.fx.text(global_position + Vector2(0, -aim_height * 3.0 - 20), tr("ALARM_RING"), RED, 26)
	for i in 3:
		run.fx.ring(aim_point(), 30.0 + i * 40.0, Color(RED, 0.8 - i * 0.2), 0.5 + i * 0.15, 3.0)
	Progress.tip("alarm")
	# Se va sin dar trozos: no lo has parado / It leaves without giving shards: you didn't stop it
	shards = 0
	die(false)


## Cae por un agujero: suena desde abajo, amortiguado, y adormece a todos
## Falls down a hole: rings from below, muffled, and lulls everyone
func _start_fall(to: Vector2) -> void:
	super._start_fall(to)
	_rang = true
	get_tree().create_timer(0.45, false).timeout.connect(_ring_below.bind(to))


func _ring_below(at: Vector2) -> void:
	if not is_instance_valid(run) or not run.running:
		return
	Audio.play("alarm_ring", -14.0, 0.05, 0.75)
	run.enemy_lull(LULL_TIME)
	run.fx.text(at + Vector2(0, -60), tr("ALARM_LULL"), UITheme.MIST, 24)
	for i in 3:
		run.fx.ring(at, 40.0 + i * 70.0, Color(UITheme.MIST, 0.6 - i * 0.15), 0.8 + i * 0.2, 2.4)
	Progress.add_stat("alarm_lull")


func _death_sound() -> void:
	Audio.play_at("hit", global_position, -10.0, 0.15)
	Audio.play("yoyo_catch", -14.0, 0.2, 1.4)


func head_top() -> Vector2:
	return Vector2(0, -78)


func _draw_body(offset: Vector2, tint: Color, a: float) -> void:
	var mod := Sprites.flash_color(_flash, a) * tint
	var hurry := 1.0 - fuse / FUSE
	# Tiembla más cuanto menos cuerda le queda / Shakes more the less winding it has left
	var shake := Vector2(sin(_t * 60.0) * 2.5 * hurry * hurry, 0.0) if state == State.ALIVE else Vector2.ZERO
	var hop := -absf(sin(_t * 7.0 + _phase)) * 8.0 if state == State.ALIVE and not statue else 0.0
	# Sombra / Shadow
	draw_set_transform(Vector2(offset.x, 0), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 20.0 - hop * 0.6, Color(0.05, 0.02, 0.15, 0.3 * a))
	# Pies que se turnan / Feet taking turns
	for side: float in [-1.0, 1.0]:
		var lift := maxf(0.0, sin(_t * 7.0 + _phase + (PI if side > 0.0 else 0.0))) * 5.0
		draw_set_transform(offset + Vector2(side * 11.0, hop * 0.4 - lift), 0.0, Vector2(_facing, 1.0))
		Sprites.draw(self, "alarm_foot", mod)
	var tilt := sin(_t * 7.0 + _phase) * 0.12
	draw_set_transform(offset + Vector2(0, hop) + shake, tilt, Vector2(_facing, 1.0))
	Sprites.draw(self, "alarm_body", mod)
	# Agujas: la larga da vueltas cada vez más rápido; la corta avanza / Hands: the long one spins faster and faster; the short one creeps on
	var c := Vector2(0, -32)
	var long := _t * (1.5 + 14.0 * hurry * hurry) + _phase
	var short := _t * 0.4 + _phase * 0.3
	var ink := Color(0.17, 0.16, 0.27, a)
	draw_line(c, c + Vector2(sin(long), -cos(long)) * 12.0, ink, 2.0)
	draw_line(c, c + Vector2(sin(short), -cos(short)) * 7.0, ink, 3.0)
	draw_circle(c, 2.2, Color(RED, a))
	# Cuerda que queda: un arco rojo por dentro de la esfera / Winding left: a red arc inside the dial
	if state == State.ALIVE and not statue:
		draw_arc(c, 18.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(fuse / FUSE, 0.0, 1.0), 24, Color(RED, 0.75 * a), 2.0)
	draw_set_transform(Vector2.ZERO)
