class_name TrainingDummy
extends Enemy
## Muñeco de pruebas del tatami de entrenamiento: no se mueve, no hace daño y no se rompe nunca
## (se vuelve a rellenar). Se tambalea con cada golpe y enseña el daño por segundo.
## Practice dummy on the training mat: it doesn't move, doesn't hurt and never breaks (it
## refills). It wobbles with every hit and shows the damage per second.

const WINDOW := 3.0          # segundos para el daño por segundo / seconds for the damage per second
var _wobble := 0.0
var _wobble_v := 0.0
var _hits: Array[Vector2] = []    # (momento, daño) / (time, damage)
var _clock := 0.0
var _total := 0.0


func _init() -> void:
	max_hp = 100000.0
	contact_damage = 0.0
	speed = 0.0
	mass = 8.0
	radius = 30.0
	aim_height = 44.0
	shards = 0
	drop_mult = 0.0


func is_dangerous() -> bool:
	return false


func can_fall() -> bool:
	return false


func _move(delta: float) -> void:
	# Plantado: el empujón solo lo hace tambalearse / Planted: a shove only makes it wobble
	if knock != Vector2.ZERO:
		_wobble_v += knock.x * 0.004
		knock = Vector2.ZERO
	external_pull = Vector2.ZERO
	vacuumed = false
	_wobble_v += (-_wobble * 60.0 - _wobble_v * 7.0) * delta
	_wobble = clampf(_wobble + _wobble_v * delta, -0.5, 0.5)


func _physics_process(delta: float) -> void:
	_clock += delta
	super(delta)
	# Nunca se rompe: se vuelve a rellenar / It never breaks: it refills
	if hp < max_hp * 0.5:
		hp = max_hp
	while not _hits.is_empty() and _clock - _hits[0].x > WINDOW:
		_hits.pop_front()


func hit(amount: float, impulse := Vector2.ZERO) -> void:
	super(amount, impulse)
	_hits.append(Vector2(_clock, amount))
	_total += amount
	_wobble_v += signf(impulse.x if impulse.x != 0.0 else 1.0) * 1.2


func dps() -> float:
	var sum := 0.0
	for h in _hits:
		sum += h.y
	return sum / WINDOW


func die(_counted: bool) -> void:
	hp = max_hp


func _draw_body(offset: Vector2, tint: Color, alpha: float) -> void:
	draw_set_transform(Vector2(offset.x, 0), _wobble, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([Vector2(-36, 0), Vector2(36, 0), Vector2(30, 6), Vector2(-30, 6)]), Color(0.03, 0.02, 0.1, 0.3 * alpha))
	Sprites.draw(self, "dummy", Sprites.flash_color(_flash, alpha) * tint)
	draw_set_transform(Vector2.ZERO)
	# Daño por segundo encima / Damage per second on top
	var font := UITheme.font("caps")
	var size := UITheme.pixel_size(14)
	var text := TranslationServer.translate("TRAINING_DPS") % snappedf(dps(), 0.1)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, Vector2(-w / 2.0, -196), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(UITheme.GOLD, alpha))
