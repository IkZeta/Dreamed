class_name Van
extends Enemy
## Unidad Especial (Acto 4, desde el sueño 16): una furgo blindada que vuela. Llega con la sirena,
## da vueltas alrededor de Kroker y va soltando policías por una cuerda hasta que la derribas.
## No hace daño al tocarla (está en el aire) y no se puede tirar por los agujeros. Al caer,
## se estrella y la explosión daña a los enemigos de alrededor.
## Special Unit (Act 4, from dream 16): an armoured flying van. It arrives with its siren on,
## circles round Kroker and keeps dropping police down a rope until you bring it down. Touching
## it doesn't hurt (it's in the air) and it can't be pushed down holes. When it falls it crashes
## and the blast hurts the enemies around it.

const ORBIT := 380.0
const SPIN := 0.45            # radianes por segundo / radians per second
const DROP_EVERY := 3.4
const MAX_OWN := 4            # policías suyos vivos a la vez / its own police alive at once
const MAX_POLICE := 10
const ALTITUDE := 120.0
const CRASH_RADIUS := 170.0
const CRASH_DAMAGE := 30.0

var style := "brutalist"
var _angle := 0.0
var _drop_t := 2.0
var _own: Array[Node] = []
var _crash := -1.0
var _arrive := 1.0           # entrando desde fuera (1 → 0) / flying in from off screen (1 → 0)


func _init() -> void:
	gait = Gait.FLOAT
	bestiary_id = "van"
	max_hp = 170.0
	hp = max_hp
	contact_damage = 0.0
	radius = 60.0
	speed = 260.0
	mass = 8.0
	aim_height = 40.0
	shards = 10


func _ready() -> void:
	super._ready()
	if run and run.room is Act4Room:
		style = (run.room as Act4Room).style
	if preview:
		_arrive = 0.0
		return
	if run and is_instance_valid(run.player):
		_angle = (global_position - run.player.global_position).angle()
	Audio.play("siren", -8.0)


func is_dangerous() -> bool:
	return false


func can_fall() -> bool:
	return false


func reach_bonus() -> float:
	return 40.0


## Vuela en círculo alrededor de Kroker (los edificios no le estorban) / Circles round Kroker (buildings don't get in its way)
func _move(delta: float) -> void:
	_arrive = maxf(0.0, _arrive - delta * 0.8)
	_angle += SPIN * delta * (0.5 if slow_t > 0.0 else 1.0)
	var target: Vector2 = run.player.global_position + Vector2(cos(_angle) * ORBIT, sin(_angle) * ORBIT * 0.6)
	var to := target - global_position
	position += to.limit_length(speed * delta) + knock * delta * 0.3
	knock = knock.move_toward(Vector2.ZERO, 900.0 * delta)
	external_pull = Vector2.ZERO
	vacuumed = false
	if absf(to.x) > 4.0:
		_facing = signf(to.x)
	var m: Rect2 = run.arena_rect()
	position = Vector2(clampf(position.x, m.position.x, m.end.x), clampf(position.y, m.position.y, m.end.y))


func _act(delta: float) -> void:
	_drop_t -= delta
	if _drop_t > 0.0 or _arrive > 0.3:
		return
	_drop_t = DROP_EVERY
	for i in range(_own.size() - 1, -1, -1):
		if not is_instance_valid(_own[i]) or not (_own[i] as Enemy).is_targetable():
			_own.remove_at(i)
	if _own.size() >= MAX_OWN or run.count_alive(Police) >= MAX_POLICE:
		return
	var at: Vector2 = run.clamp_to_arena(global_position + Vector2(randf_range(-30, 30), 10), 20.0)
	var p := Police.new()
	p.setup(run)
	p.position = at
	p.set("_drop", 1.0)
	run.enemies.add_child(p)
	_own.append(p)
	Audio.play_at("throw", at, -10.0, 0.1)


func die(counted: bool) -> void:
	if state == State.DYING:
		return
	super.die(counted)
	if not counted:
		return
	# Se estrella: explosión que daña a los de alrededor / It crashes: a blast hurting those around
	_crash = 0.0
	run.shake(10.0)
	run.fx.ring(global_position, CRASH_RADIUS, Color("ffb04a"), 0.5, 1.4)
	run.fx.dissipate(global_position + Vector2(0, -40), Color("ffb04a"))
	for e: Node in run.enemies.get_children():
		if e != self and e is Enemy and (e as Enemy).is_targetable() and (e as Node2D).global_position.distance_to(global_position) < CRASH_RADIUS:
			(e as Enemy).hit(CRASH_DAMAGE * GameState.enemy_hp_mult(), ((e as Node2D).global_position - global_position).normalized() * 500.0)
	Audio.play("stove_boom", -4.0)


func _death_sound() -> void:
	Audio.play("crack", -4.0)


func _draw_body(offset: Vector2, tint: Color, a: float) -> void:
	var alt := ALTITUDE + sin(_t * 2.2) * 8.0 + _arrive * 300.0
	if state == State.DYING:
		alt *= _fade
	# En estatua, posada en el pedestal y sin luces / As a statue, resting on the pedestal with no lights
	if statue:
		draw_set_transform(offset + Vector2(0, -6), 0.0, Vector2(_facing, 1.0))
		Sprites.draw(self, "van_" + style, Sprites.flash_color(0.0, a) * tint)
		draw_set_transform(Vector2.ZERO)
		return
	# Sombra en el suelo y luz de los focos / Shadow on the ground and searchlight
	draw_colored_polygon(_ellipse(Vector2.ZERO, Vector2(90, 20)), Color(0.05, 0.02, 0.15, 0.35 * a))
	draw_colored_polygon(PackedVector2Array([Vector2(-20, -alt + 10), Vector2(20, -alt + 10), Vector2(70, 0), Vector2(-70, 0)]), Color(1.0, 0.95, 0.75, 0.08 * a))
	draw_set_transform(offset + Vector2(0, -alt), sin(_t * 1.7) * 0.04, Vector2(_facing, 1.0))
	Sprites.draw(self, "van_" + style, Sprites.flash_color(_flash * 0.6, a) * tint)
	# Luces de la sirena que se alternan / Alternating siren lights
	var blink := fmod(_t * 4.0, 2.0) < 1.0
	draw_circle(Vector2(-29, -100), 9.0, Color("ff3a4a", (0.9 if blink else 0.25) * a))
	draw_circle(Vector2(31, -100), 9.0, Color("3a8aff", (0.25 if blink else 0.9) * a))
	# Llama de las turbinas / Turbine glow
	for x in [-70.0, 70.0]:
		draw_circle(Vector2(x, -4), 8.0 + sin(_t * 20.0 + x) * 2.0, Color("8fe0ff", 0.6 * a))
	draw_set_transform(Vector2.ZERO)


func aim_point() -> Vector2:
	return global_position + Vector2(0, -ALTITUDE - 50.0)


func head_top() -> Vector2:
	return Vector2(0, -ALTITUDE - 110.0)


func _ellipse(c: Vector2, r: Vector2, n := 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts
