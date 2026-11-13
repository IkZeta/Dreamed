class_name Riot
extends Enemy
## Antidisturbios (Acto 4, desde el sueño 17): salen de las alcantarillas abiertas. No persiguen a
## Kroker ni atacan: se quedan detrás de los demás y les ponen escudos. Un enemigo con escudo
## apenas recibe daño ni empujones, y el escudo solo desaparece cuando cae el antidisturbios que
## lo puso. Salen pocos. Se les puede tirar por los agujeros.
## Riot police (Act 4, from dream 17): they climb out of open manholes. They don't chase Kroker or
## attack: they stay behind the others and shield them. A shielded enemy barely takes damage or
## knockback, and the shield only goes away when the riot officer who put it up goes down. Few
## of them turn up. They can be pushed down holes.

const SHIELD_EVERY := 3.0
const SHIELD_RANGE := 430.0
const MAX_SHIELDS := 5
const KEEP_AWAY := 380.0
## Daño que deja pasar el escudo / Damage the shield lets through
const SHIELD_PASS := 0.2

var style := "brutalist"
var rise := 0.0             # saliendo de la alcantarilla (1 → 0) / climbing out of the manhole (1 → 0)
var _shield_t := 1.5
var _given: Array[Node] = []
var _beam := 0.0


func _init() -> void:
	bestiary_id = "riot"
	max_hp = 70.0
	hp = max_hp
	contact_damage = 0.0
	radius = 26.0
	speed = 55.0
	mass = 3.0
	aim_height = 64.0
	shards = 5


func _ready() -> void:
	super._ready()
	if run and run.room is Act4Room:
		style = (run.room as Act4Room).style


func is_dangerous() -> bool:
	return false


## Se queda lejos de Kroker, junto a los suyos / Stays away from Kroker, near its own side
func _desired_velocity() -> Vector2:
	if rise > 0.0:
		return Vector2.ZERO
	var away: Vector2 = global_position - run.player.global_position
	if away.length() < KEEP_AWAY:
		return away.normalized() * speed
	# Hacia el grupo de los que protege / Towards the group it protects
	var c := Vector2.ZERO
	var n := 0
	for e in _given:
		if is_instance_valid(e):
			c += (e as Node2D).global_position
			n += 1
	if n > 0 and global_position.distance_to(c / n) > 220.0:
		return (c / n - global_position).normalized() * speed * 0.6
	return Vector2.ZERO


func _physics_process(delta: float) -> void:
	rise = maxf(0.0, rise - delta * 0.8)
	_beam = maxf(0.0, _beam - delta * 2.0)
	super._physics_process(delta)


func _act(delta: float) -> void:
	if rise > 0.0:
		return
	_facing = signf(run.player.global_position.x - global_position.x) if absf(run.player.global_position.x - global_position.x) > 4.0 else _facing
	_shield_t -= delta
	if _shield_t > 0.0:
		return
	_shield_t = SHIELD_EVERY
	for i in range(_given.size() - 1, -1, -1):
		if not is_instance_valid(_given[i]) or not (_given[i] as Enemy).is_targetable():
			_given.remove_at(i)
	if _given.size() >= MAX_SHIELDS:
		return
	# Los más cercanos sin escudo / The nearest ones without a shield
	var best: Array = []
	for e: Node in run.enemies.get_children():
		if e == self or not e is Enemy or e is Riot or e is Van or (e as Enemy).is_boss():
			continue
		var en := e as Enemy
		if not en.is_targetable() or en.shielded():
			continue
		var d := en.global_position.distance_to(global_position)
		if d < SHIELD_RANGE:
			best.append([d, en])
	best.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for k in mini(2, best.size()):
		var en: Enemy = best[k][1]
		en.shield_by = self
		Progress.tip("riot")
		_given.append(en)
		run.fx.ring(en.global_position + Vector2(0, -40), 40.0, Color("8fd8ff"), 0.4, 1.6)
	if not best.is_empty():
		_beam = 1.0
		Audio.play_at("pillow", global_position, -8.0, 0.1)


func _death_sound() -> void:
	Audio.play("pan_clang", -6.0, 0.1)


func _draw_body(offset: Vector2, tint: Color, a: float) -> void:
	# Saliendo de la alcantarilla: sube desde abajo / Climbing out of the manhole: rises from below
	var sink := rise * 150.0
	draw_colored_polygon(_ellipse(Vector2.ZERO, Vector2(30, 8)), Color(0.05, 0.02, 0.15, 0.4 * a))
	draw_set_transform(offset + Vector2(0, sink), 0.0, Vector2(_facing, 1.0))
	var mod := Sprites.flash_color(_flash * 0.6, a) * tint
	if rise > 0.0:
		mod.a *= 1.0 - rise * 0.6
	Sprites.draw(self, "riot_" + style, mod)
	# La luz azul del casco cuando reparte escudos / The helmet's blue light when handing out shields
	draw_circle(Vector2(0, -160), 4.0 + _beam * 4.0, Color("8fd8ff", (0.4 + 0.6 * _beam) * a))
	draw_set_transform(Vector2.ZERO)
	# Hilos de luz hacia los que protege / Threads of light to the ones it protects
	for e in _given:
		if is_instance_valid(e) and (e as Enemy).is_targetable():
			var to: Vector2 = (e as Node2D).global_position + Vector2(0, -40) - global_position
			draw_line(Vector2(0, -150), to, Color("8fd8ff", 0.18 * a), 2.0)


func head_top() -> Vector2:
	return Vector2(0, -170)


func _ellipse(c: Vector2, r: Vector2, n := 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts
