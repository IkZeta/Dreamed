class_name Nest
extends Enemy
## Nido de mosquitos (salón, desde el Sueño 6): no se mueve ni hace daño, pero va soltando
## mosquitos mientras no lo rompas. No se puede empujar ni tirar por los agujeros.
## Mosquito nest (living room, from Dream 6): it doesn't move or hurt, but keeps releasing
## mosquitoes until you break it. It can't be shoved or thrown down holes.

const SPAWN_EVERY := 1.6      # segundos entre mosquito y mosquito / seconds between mosquitoes
const MAX_OUT := 7            # mosquitos vivos por nido / live mosquitoes per nest

var _spawn_t := 1.0
var _pulse := 0.0
var _out: Array[Node] = []


func _init() -> void:
	bestiary_id = "nest"
	max_hp = 34.0
	hp = max_hp
	contact_damage = 0.0
	radius = 34.0
	speed = 0.0
	mass = 1000.0
	aim_height = 20.0
	shards = 4


func is_dangerous() -> bool:
	return false


func can_fall() -> bool:
	return false


## Clavado en el suelo: ni se empuja ni lo atrae la aspiradora / Stuck to the floor: no shoving, no vacuum pull
func _move(_delta: float) -> void:
	knock = Vector2.ZERO
	external_pull = Vector2.ZERO
	position = run.clamp_to_arena(position, radius)


func _act(delta: float) -> void:
	_pulse = maxf(0.0, _pulse - delta * 3.0)
	_spawn_t -= delta
	if _spawn_t > 0.0:
		return
	_spawn_t = SPAWN_EVERY * randf_range(0.8, 1.2)
	var still: Array[Node] = []
	for m in _out:
		if is_instance_valid(m) and m.is_targetable():
			still.append(m)
	_out = still
	if _out.size() >= MAX_OUT or not run.running:
		return
	var m := Mosquito.new()
	m.setup(run)
	m.nest = self
	m.position = global_position + Vector2(randf_range(-20, 20), -4)
	run.enemies.add_child(m)
	_out.append(m)
	_pulse = 1.0
	Audio.play("spawn", -22.0, 0.2)


func _death_sound() -> void:
	Audio.play("crack", -8.0, 0.1)


func _draw_body(offset: Vector2, tint: Color, a: float) -> void:
	var mod := Sprites.flash_color(_flash, a) * tint
	# Se hincha un poco al soltar un mosquito / Swells a little when it lets out a mosquito
	var s := 1.0 + 0.08 * _pulse + 0.02 * sin(_t * 3.0 + _phase)
	draw_set_transform(Vector2(offset.x, 0), 0.0, Vector2(s, s))
	Sprites.draw(self, "nest_body", mod)
	draw_set_transform(Vector2.ZERO)
	# Unos mosquitos zumbando alrededor de las bocas del nido / A few mosquitoes buzzing around the nest's holes
	if state == State.ALIVE and not statue:
		for i in 3:
			var ph := _t * (2.2 + i * 0.7) + _phase + i * 2.1
			var p := offset + Vector2(cos(ph) * (26.0 + i * 6.0), -30.0 + sin(ph * 1.7) * 9.0 - i * 6.0)
			p += Vector2(randf_range(-1, 1), randf_range(-1, 1))
			var wing := Color(0.87, 0.9, 1.0, 0.5 * a)
			draw_line(p + Vector2(-2, -2), p + Vector2(-4, -5 + absf(sin(_t * 40.0 + i)) * 3.0), wing, 1.5)
			draw_line(p + Vector2(1, -2), p + Vector2(3, -5 + absf(cos(_t * 40.0 + i)) * 3.0), wing, 1.5)
			draw_rect(Rect2(p - Vector2(2, 1), Vector2(4, 3)), Color(0.12, 0.09, 0.2, a))


func head_top() -> Vector2:
	return Vector2(0, -50)
