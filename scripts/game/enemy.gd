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
var drop_mult := 1.0       # multiplica la probabilidad de soltar objetos / scales the item drop chance
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

## --- Pelusa del oso de peluche / Teddy bear fluff ---------------------------------
## Cada pelusa pegada frena un poco y se cae a los 8 s. Si dos enemigos con pelusa se tocan,
## se quedan pegados y van aún más lentos.
## Each fluff stuck on slows a bit and falls off after 8 s. If two fluffy enemies touch,
## they get stuck together and go even slower.
## Las bolas crecen: cada enemigo con pelusa que toque a una se une. Con 5 se aplastan entre ellos.
## Clumps grow: every fluffy enemy touching one joins it. At 5 they crush each other.
const CLUMP_KILL := 5
const FLUFF_TIME := 8.0
const FLUFF_SLOW := 0.12        # por pelusa / per fluff
const FLUFF_MAX_SLOW := 0.6
const STUCK_SLOW := 0.5         # pegados: la mitad de lo que les quede / stuck: half of what's left
var fluffs: Array[float] = []   # segundos que le quedan a cada pelusa / seconds left on each fluff
var fluff_time := FLUFF_TIME
## Bola de pelusa a la que pertenece (el mismo Array lo comparten todos sus miembros)
## Fluff clump it belongs to (all members share the same Array)
var clump: Array = []
var stuck_bonus := 0.0          # Silly: daño extra mientras está pegado / Silly: extra damage while stuck

## --- Sangrado y quemadura (El Pinche) / Bleeding and burning (The Kitchen Boy) ------------
## Sangrado: daño residual fuerte. Quemadura: daño residual flojo, pero hace menos daño y
## recibe más (le baja el ataque y la defensa).
## Bleed: strong damage over time. Burn: weak damage over time, but it deals less damage and
## takes more (lowers its attack and defence).
var bleed_t := 0.0
var bleed_dps := 0.0
var burn_t := 0.0
var burn_dps := 0.0
var burn_pct := 0.0
var _dot_tick := 0.0

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
	if state == State.ALIVE:
		_update_fluff(delta)
		_update_dots(delta)
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
		vel = _desired_velocity() * (0.5 if slow_t > 0.0 else 1.0) * fluff_speed_mult()
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
	# Pegado a otro por la pelusa: tiran el uno del otro / Stuck to another by fluff: they pull on each other
	# En una bola de pelusa: todos tiran hacia el centro / In a fluff clump: everyone pulls to the middle
	if is_stuck():
		var gap := clump_center() - global_position
		var want := radius * 0.8
		if gap.length() > want:
			vel += gap.normalized() * (gap.length() - want) * 6.0
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


## Jefes: no cuentan para el límite de enemigos ni se borran con la K / Bosses: don't count for the enemy cap and survive the K key
func is_boss() -> bool:
	return false


## Los jefes no se pueden tirar por los agujeros / Bosses can't be thrown down holes
func can_fall() -> bool:
	return true


func _start_fall(to: Vector2) -> void:
	_unstick()
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
	# Tirar enemigos por los agujeros da Realidad Fragmentada / Throwing enemies down holes gives Fragmented Reality
	var chance := GameState.FALL_REALITY_CHANCE_BOSS if run.boss_wave() else GameState.FALL_REALITY_CHANCE
	if randf() < chance:
		run.gain_reality(GameState.REALITY_FALL, _fall_from)


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
		player.take_damage(contact_damage * atk_mult())


## Lo que la quemadura le deja de daño (1 = todo) / What burning leaves of its damage (1 = all of it)
func atk_mult() -> float:
	return 1.0 - burn_pct / 100.0 if burn_t > 0.0 else 1.0


# --- Pelusa / Fluff ---------------------------------------------------------------------

func add_fluff(n := 1, secs := FLUFF_TIME) -> void:
	for i in n:
		fluffs.append(secs)


func fluff_speed_mult() -> float:
	if fluffs.is_empty():
		return 1.0
	var k := 1.0 - minf(FLUFF_MAX_SLOW, FLUFF_SLOW * fluffs.size())
	if is_stuck():
		# Cuanto más grande la bola, más pesa / The bigger the clump, the heavier it is
		k *= STUCK_SLOW * pow(0.85, clump.size() - 2)
	return k


func is_stuck() -> bool:
	return clump.size() >= 2


func clump_center() -> Vector2:
	var c := Vector2.ZERO
	var n := 0
	for m in clump:
		if is_instance_valid(m):
			c += (m as Node2D).global_position
			n += 1
	return c / float(n) if n > 0 else global_position


func _update_fluff(delta: float) -> void:
	if fluffs.is_empty():
		_unstick()
		return
	for i in range(fluffs.size() - 1, -1, -1):
		fluffs[i] -= delta
		if fluffs[i] <= 0.0:
			fluffs.remove_at(i)
	if fluffs.is_empty():
		_unstick()
		return
	# Enemigos con pelusa que se tocan se pegan; las bolas se van uniendo
	# Fluffy enemies that touch stick together; clumps keep merging
	if is_boss():
		return
	for other: Node in run.enemies.get_children():
		if other == self or not other is Enemy:
			continue
		var o := other as Enemy
		if o.fluffs.is_empty() or o.is_boss() or not o.is_targetable():
			continue
		if is_stuck() and clump.has(o):
			continue
		if global_position.distance_to(o.global_position) < radius + o.radius + 12.0:
			_join(o)
			return


## Une las dos bolas (o los dos sueltos) en una / Merges both clumps (or both loose ones) into one
func _join(o: Enemy) -> void:
	var merged: Array = []
	for m in (clump if is_stuck() else [self]) + (o.clump if o.is_stuck() else [o]):
		if is_instance_valid(m) and not merged.has(m):
			merged.append(m)
	for m in merged:
		(m as Enemy).clump = merged
	Audio.play("fluff", -8.0, 0.15)
	run.fx.ring((global_position + o.global_position) / 2.0 + Vector2(0, -20), 18.0 + 6.0 * merged.size(), Color("f4e9da"), 0.4, 2.0)
	if merged.size() >= CLUMP_KILL:
		_crush(merged)


## Una bola de 5: se aplastan entre ellos y mueren todos / A clump of 5: they crush each other and all die
func _crush(members: Array) -> void:
	var c := clump_center()
	for m in members:
		(m as Enemy).clump = []
	Audio.play("pillow", -2.0, 0.1)
	Audio.play("fluff", -2.0)
	run.shake(6.0)
	run.fx.ring(c + Vector2(0, -30), 90.0, Color("f4e9da"), 0.6, 1.6)
	run.fx.dissipate(c + Vector2(0, -30), Color("f4e9da"))
	run.fx.text(c + Vector2(0, -110), tr("FLUFF_CRUSH"), Color("f4e9da"), 26)
	for m in members:
		if is_instance_valid(m) and (m as Enemy).is_targetable():
			(m as Enemy).die(true)


func _unstick() -> void:
	if not is_stuck():
		clump = []
		return
	var shared := clump
	shared.erase(self)
	clump = []
	# Si se queda uno solo, ya no está pegado a nadie / If only one is left, it's no longer stuck to anyone
	if shared.size() == 1 and is_instance_valid(shared[0]):
		(shared[0] as Enemy).clump = []


# --- Sangrado y quemadura / Bleeding and burning -----------------------------------------

func bleed(dps: float, secs: float) -> void:
	bleed_dps = maxf(bleed_dps if bleed_t > 0.0 else 0.0, dps)
	bleed_t = maxf(bleed_t, secs)


func burn(dps: float, secs: float, pct: float) -> void:
	burn_dps = maxf(burn_dps if burn_t > 0.0 else 0.0, dps)
	burn_pct = maxf(burn_pct if burn_t > 0.0 else 0.0, pct)
	burn_t = maxf(burn_t, secs)


## El daño residual entra cada medio segundo / Damage over time ticks every half second
func _update_dots(delta: float) -> void:
	bleed_t = maxf(0.0, bleed_t - delta)
	burn_t = maxf(0.0, burn_t - delta)
	if bleed_t <= 0.0 and burn_t <= 0.0:
		_dot_tick = 0.0
		return
	_dot_tick += delta
	if _dot_tick < 0.5:
		return
	_dot_tick -= 0.5
	var dmg := 0.0
	if bleed_t > 0.0:
		dmg += bleed_dps * 0.5
		if randf() < 0.6:
			run.fx.ring(aim_point() + Vector2(randf_range(-8, 8), 10), 5.0, Color("d8344a"), 0.35, 1.5)
	if burn_t > 0.0:
		dmg += burn_dps * 0.5
		run.fx.ring(aim_point() + Vector2(randf_range(-10, 10), -10), 7.0, Color("ff9a3a"), 0.35, 1.5)
	if dmg > 0.0:
		_dot_hit(dmg)


## Daño residual: no empuja ni hace sonido de golpe / Damage over time: no knockback or hit sound
func _dot_hit(amount: float) -> void:
	if state == State.DYING:
		return
	hp -= amount
	_flash = maxf(_flash, 0.4)
	if Settings.damage_numbers:
		run.fx.text(global_position + Vector2(randf_range(-14, 14), -aim_height - 30), str(snappedf(amount, 0.1)),
			Color("ff7a5a") if burn_t > 0.0 and bleed_t <= 0.0 else Color("ff5a6e"), 16)
	if hp <= 0.0:
		die(true)


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
	# La quemadura le baja la defensa; pegado con el virus de Silly recibe más
	# Burning lowers its defence; stuck with Silly's virus it takes more
	if burn_t > 0.0:
		amount *= 1.0 + burn_pct / 100.0
	if is_stuck() and stuck_bonus > 0.0:
		amount *= 1.0 + stuck_bonus / 100.0
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
	_unstick()
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
	_draw_statuses(bob, a)
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


## Pelusas pegadas, el hilo que une a los pegados, gotas de sangre y llamitas
## Stuck-on fluffs, the strand joining stuck enemies, drops of blood and little flames
func _draw_statuses(bob: float, a: float) -> void:
	if state != State.ALIVE:
		return
	var body_h := aim_height * 2.0
	for i in fluffs.size():
		var ang := float(i) * 2.4 + _phase
		var p := Vector2(cos(ang) * radius * 0.7, -body_h * (0.25 + 0.5 * fmod(float(i) * 0.37 + 0.2, 1.0)) + bob)
		var fade := clampf(fluffs[i] / 1.0, 0.0, 1.0)
		var col := Color("f4e9da", 0.9 * a * fade)
		for k in 4:
			draw_circle(p + Vector2(cos(k * 1.7 + _t) * 4.0, sin(k * 2.3) * 3.0), 4.5, col)
		draw_circle(p + Vector2(-2, -2), 2.0, Color(1, 1, 1, 0.8 * a * fade))
	# Hilo de pelusa hasta el siguiente de la bola / Fluff strand to the next one in the clump
	var idx := clump.find(self) if is_stuck() else -1
	if idx >= 0 and idx + 1 < clump.size() and is_instance_valid(clump[idx + 1]):
		var nxt := clump[idx + 1] as Enemy
		var to := nxt.global_position - global_position + Vector2(0, -nxt.aim_height)
		var from := Vector2(0, -aim_height)
		var pts := PackedVector2Array()
		for k in 9:
			var u := k / 8.0
			pts.append(from.lerp(to, u) + Vector2(0, sin(u * PI) * 10.0 + sin(_t * 6.0 + u * 8.0) * 2.0))
		draw_polyline(pts, Color("f4e9da", 0.85 * a), 5.0)
		draw_polyline(pts, Color(1, 1, 1, 0.6 * a), 1.5)
	if bleed_t > 0.0:
		for k in 2:
			var u := fposmod(_t * 1.3 + k * 0.5, 1.0)
			draw_circle(Vector2(-8 + k * 16, -body_h * 0.4 + u * body_h * 0.4 + bob), 2.5 * (1.0 - u * 0.5), Color("d8344a", 0.9 * a * (1.0 - u)))
	if burn_t > 0.0:
		for k in 3:
			var u := fposmod(_t * 1.8 + k * 0.33, 1.0)
			var p := Vector2(-14 + k * 14 + sin(_t * 7.0 + k) * 3.0, -body_h * 0.2 - u * body_h * 0.7 + bob)
			draw_circle(p, 5.0 * (1.0 - u), Color("ff9a3a", 0.8 * a * (1.0 - u)))
			draw_circle(p, 2.5 * (1.0 - u), Color("ffe08a", 0.9 * a * (1.0 - u)))
