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


func head_top() -> Vector2:
	return Vector2(0, -50)
