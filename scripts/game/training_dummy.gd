class_name TrainingDummy
extends Enemy
## Muñeco de pruebas del tatami de entrenamiento: no anda, no hace daño y no se rompe nunca (se
## vuelve a rellenar). Los empujones lo arrastran por el tatami; uno muy fuerte lo tumba y, si
## lo sacas por el borde, cae al vacío. Al segundo vuelve a su sitio. Enseña el daño por segundo.
## Practice dummy on the training mat: it doesn't walk, doesn't hurt and never breaks (it
## refills). Shoves drag it across the mat; a very hard one knocks it over and, if you push it
## off the edge, it drops into the void. A second later it's back in its spot. Shows the damage
## per second.

const WINDOW := 3.0          # segundos para el daño por segundo / seconds for the damage per second
var _wobble := 0.0
var _wobble_v := 0.0
var _hits: Array[Vector2] = []    # (momento, daño) / (time, damage)
var _clock := 0.0
var _total := 0.0
const TOPPLE := 450.0        # empujón de un solo golpe que lo tumba / single-hit shove that knocks it over
const EDGE := 200.0          # empujón que, contra el borde, lo tira al vacío / shove that, against the edge, throws it off
const BACK := 1.0            # segundos hasta que vuelve / seconds until it's back
var _down := -1.0            # tiempo tumbado o cayendo (−1 = de pie) / time down or falling (−1 = standing)
var _fell := false           # cayó al vacío (si no, tumbado) / fell into the void (otherwise toppled)
var _side := 1.0
var _rise := 1.0             # aparece de nuevo (0 → 1) / reappears (0 → 1)


func _init() -> void:
	max_hp = 100000.0
	contact_damage = 0.0
	speed = 0.0
	mass = 1.2
	radius = 30.0
	aim_height = 44.0
	shards = 0
	drop_mult = 0.0


func is_dangerous() -> bool:
	return false


func can_fall() -> bool:
	return false


func _move(delta: float) -> void:
	external_pull = external_pull if _down < 0.0 else Vector2.ZERO
	vacuumed = false
	_wobble_v += (-_wobble * 60.0 - _wobble_v * 7.0) * delta
	_wobble = clampf(_wobble + _wobble_v * delta, -0.5, 0.5)
	if _down >= 0.0:
		knock = Vector2.ZERO
		return
	# Lo arrastra el empujón (no anda solo) / The shove drags it (it doesn't walk by itself)
	var push := knock + external_pull
	external_pull = Vector2.ZERO
	var to := position + push * delta
	var clamped: Vector2 = run.clamp_to_arena(to, radius)
	if clamped.distance_to(to) > 0.5 and knock.length() > EDGE:
		# Se sale del tatami: al vacío / Off the mat: into the void
		position = to
		_knock_down(true, push)
		return
	position = clamped
	knock = knock.move_toward(Vector2.ZERO, 1100.0 * delta)


func _knock_down(off_edge: bool, push: Vector2) -> void:
	_down = 0.0
	_fell = off_edge
	_side = signf(push.x) if absf(push.x) > 1.0 else 1.0
	knock = push.normalized() * 220.0 if off_edge else Vector2.ZERO
	Audio.play("throw" if off_edge else "hit", -8.0, 0.1)
	run.fx.text(global_position + Vector2(0, -aim_height - 40), tr("ENEMY_FELL") if off_edge else tr("TRAINING_DOWN"), UITheme.GOLD, 20)


func _stand_up() -> void:
	_down = -1.0
	_fell = false
	_rise = 0.0
	knock = Vector2.ZERO
	_wobble = 0.0
	_wobble_v = 0.0
	position = Bedroom.to_world(TrainingRoom.DUMMY_AT)
	run.fx.ring(position, 46.0, UITheme.GOLD, 0.5, 1.8)


func _physics_process(delta: float) -> void:
	_clock += delta
	_rise = minf(1.0, _rise + delta * 3.0)
	if _down >= 0.0:
		_down += delta
		# Cayendo: sigue el empujón un poco mientras se hunde / Falling: carries on with the shove a bit as it sinks
		if _fell:
			position += knock * delta
			knock = knock.move_toward(Vector2.ZERO, 400.0 * delta)
		if _down >= BACK:
			_stand_up()
	super(delta)
	# Nunca se rompe: se vuelve a rellenar / It never breaks: it refills
	if hp < max_hp * 0.5:
		hp = max_hp
	while not _hits.is_empty() and _clock - _hits[0].x > WINDOW:
		_hits.pop_front()


func hit(amount: float, impulse := Vector2.ZERO) -> void:
	if _down >= 0.0:
		return
	super(amount, impulse)
	# Un golpe muy fuerte lo tumba (el escudo, el giro de las botas...) / A very hard hit knocks it over (the shield, the boots' spin...)
	if impulse.length() / mass > TOPPLE:
		_knock_down(false, knock)
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
	var rot := _wobble
	var drop := 0.0
	var a := alpha * _rise
	var sc := Vector2.ONE * (0.6 + 0.4 * _rise)
	if _down >= 0.0:
		if _fell:
			# Se hunde en el vacío y se desvanece / Sinks into the void and fades
			var k := minf(1.0, _down / 0.6)
			drop = k * k * 160.0
			rot = _side * k * 1.4
			a *= 1.0 - k
			sc *= 1.0 - 0.4 * k
		else:
			# Tumbado con un botecito; al final se desvanece para volver a su sitio
			# Knocked over with a little bounce; at the end it fades to go back to its spot
			var k := minf(1.0, _down / 0.25)
			var bounce := absf(sin(minf(_down, 0.5) * TAU)) * maxf(0.0, 1.0 - _down * 2.0) * 0.12
			rot = _side * (k * k * (PI / 2.0 - 0.08) - bounce)
			a *= clampf((BACK - _down) / 0.25, 0.0, 1.0)
	if _down < 0.0 or not _fell:
		draw_colored_polygon(PackedVector2Array([Vector2(-36, 0), Vector2(36, 0), Vector2(30, 6), Vector2(-30, 6)]), Color(0.03, 0.02, 0.1, 0.3 * a))
	draw_set_transform(Vector2(offset.x, drop), rot, sc)
	Sprites.draw(self, "dummy", Sprites.flash_color(_flash, a) * tint)
	draw_set_transform(Vector2.ZERO)
	# Daño por segundo encima / Damage per second on top
	var font := UITheme.font("caps")
	var size := UITheme.pixel_size(14)
	var text := TranslationServer.translate("TRAINING_DPS") % snappedf(dps(), 0.1)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, Vector2(-w / 2.0, -196), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(UITheme.GOLD, alpha))
