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
## Forma de andar: a pasos (con saltito, aplastamiento y balanceo), pisando fuerte (los grandes),
## flotando (fantasmas, bichos y cosas que vuelan) o nada (los que llevan su propia animación)
## Gait: stepping (with a hop, squash and sway), stomping (the big ones), floating (ghosts, bugs and
## flying things) or none (those with their own animation)
enum Gait { WALK, STOMP, FLOAT, NONE }
var gait := Gait.WALK

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
var statue := false        # estatua del museo: sin aura ni ascuas / museum statue: no aura or embers
var state := State.SPAWNING
var knock := Vector2.ZERO
var external_pull := Vector2.ZERO  # lo usa la aspiradora / used by the vacuum
## Lo está aspirando la aspiradora este fotograma. Si está débil (la mitad de vida o menos) y lo
## arrastra por encima de un agujero, se cae: así no se vacía la sala de enemigos sanos.
## The vacuum is sucking it this frame. If it's weak (half health or less) and gets dragged over
## a hole, it falls in: that way healthy enemies can't just be hoovered away.
var vacuumed := false

var stun_t := 0.0
## Bailando con Lil Key: quieto y sin hacer daño / Dancing to Lil Key: still and harmless
var dance_t := 0.0
## Actuando para D. Lynx: lucha contra los demás enemigos y las armas no le apuntan
## Acting for D. Lynx: it fights the other enemies and the weapons don't aim at it
var actor_t := 0.0
var actor_dmg := 0.0
var _actor_tick := 0.0
const ACTOR_REACH := 16.0
const ACTOR_EVERY := 0.55
var _detour := Vector2.ZERO
## Escudo de un antidisturbios (mientras ese siga en pie) / A riot officer's shield (while that one stands)
var shield_by: Node = null
var _detour_t := 0.0
var slow_t := 0.0
## Golpe fuerte: sale despedido y frena despacio / Heavy hit: sent flying, slowing down gently
const HEAVY_TIME := 0.6
var heavy_t := 0.0
## Sale corriendo de una puerta (timbre del colegio): aparece rápido y se aleja de la puerta
## Rushes out of a door (school bell): appears quickly and runs away from the door
var rush_t := 0.0
var rush_dir := Vector2.ZERO
var spawn_time := 0.6
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
var _hit_squash := 0.0
## Luna: flotando sin gravedad (no muerde ni ataca); al acabar cae donde esté, también a un agujero
## Luna: floating weightless (it neither bites nor attacks); when it ends it drops where it is, also into a hole
var float_t := 0.0
var _float_total := 1.0
const FLOAT_KNOCK := 1.6
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
	if not is_boss():
		max_hp *= GameState.late_hp_mult()
		# Fiebre: enemigos más rápidos / Fever: faster enemies
		if GameState.pact("swift"):
			speed *= 1.18
	elif GameState.pact("titans"):
		max_hp *= 1.35
	contact_damage *= GameState.enemy_dmg_mult()
	if elite:
		max_hp *= 3.0
		shards *= 4
		# Sin agrandarlo: escalar el pixel art a tamaños raros lo deforma; se distingue por el
		# contorno, los cuernos y el aura / Not enlarged: scaling pixel art by odd amounts warps it;
		# it stands out through the outline, the horns and the aura
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
			Progress.tip("elite")
	hp = max_hp
	if not preview:
		Progress.see(bestiary_id)


func _physics_process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 5.0)
	stun_t = maxf(0.0, stun_t - delta)
	# El escudo se rompe cuando cae su antidisturbios / The shield breaks when its riot officer falls
	if shield_by != null and not shielded():
		shield_by = null
		if state == State.ALIVE:
			run.fx.ring(aim_point(), 34.0, Color("8fd8ff"), 0.35, 2.2)
			run.fx.dissipate(aim_point(), Color("bfe8ff"))
	if dance_t > 0.0:
		dance_t = maxf(0.0, dance_t - delta)
		stun_t = maxf(stun_t, minf(dance_t, 0.1))
	if actor_t > 0.0:
		actor_t = maxf(0.0, actor_t - delta)
		if actor_t <= 0.0 and state == State.ALIVE:
			# "¡Corten!": hace una reverencia y vuelve a ser malo / "Cut!": takes a bow and turns bad again
			stun_t = maxf(stun_t, 0.8)
			run.fx.text(global_position + Vector2(0, -aim_height * 3.0 - 20.0), tr("LYNX_CUT"), Color("ffb0b0"), 18)
	slow_t = maxf(0.0, slow_t - delta)
	if float_t > 0.0 and state == State.ALIVE:
		float_t -= delta
		stun_t = maxf(stun_t, minf(float_t, 0.1))
		rotation = sin(_t * 3.0 + _phase) * 0.3 * minf(1.0, float_t * 3.0)
		if float_t <= 0.0:
			rotation = 0.0
			_land_float()
			if state != State.ALIVE:
				return
	if state == State.ALIVE:
		rush_t = maxf(0.0, rush_t - delta)
	vuln_t = maxf(0.0, vuln_t - delta)
	glitch_t = maxf(0.0, glitch_t - delta)
	bounce_t = maxf(0.0, bounce_t - delta)
	if state == State.ALIVE:
		_update_fluff(delta)
		_update_dots(delta)
	match state:
		State.SPAWNING:
			_fade = minf(1.0, _fade + delta / spawn_time)
			# Aún no camina, pero la aspiradora, el muñeco o un golpe sí lo mueven poco a poco
			# (si no, el tirón se acumulaba y al acabar de aparecer daba un salto de golpe)
			# It doesn't walk yet, but the vacuum, the dummy or a hit do move it bit by bit
			# (otherwise the pull built up and it jumped all at once when it finished appearing)
			if knock != Vector2.ZERO or external_pull != Vector2.ZERO:
				position = run.clamp_to_arena(position + (knock + external_pull) * delta, radius)
				knock = knock.move_toward(Vector2.ZERO, 1400.0 * delta)
			external_pull = Vector2.ZERO
			vacuumed = false
			# Brota del suelo del sueño: sale aplastado y se estira / Sprouts from the dream floor: comes out squashed and stretches up
			if sprouts():
				var f := _fade
				var spring := sin(f * PI) * 0.12
				scale = Vector2(1.0 + 0.3 * (1.0 - f) - spring, 0.35 + 0.65 * f + spring)
			if _fade >= 1.0:
				state = State.ALIVE
				if not is_boss():
					scale = Vector2.ONE
		State.DYING:
			if _fall_t >= 0.0:
				_update_fall(delta)
				return
			_fade -= delta / 0.35
			if _fade <= 0.0:
				queue_free()
				return
			# Se deshace hacia arriba como humo y sigue el impulso del último golpe
			# Melts upwards like smoke and carries the last hit's momentum
			if not is_boss() and not statue:
				var g := 1.0 - _fade
				scale = Vector2(1.0 - 0.45 * g, 1.0 + 0.6 * g * g)
				if knock != Vector2.ZERO:
					position = run.clamp_to_arena(position + knock * delta * 0.6, radius)
					knock = knock.move_toward(Vector2.ZERO, 2200.0 * delta)
			return
		State.ALIVE:
			_move(delta)
			_animate_motion(delta)
			# Élite del charco: deja charcos que frenan / Puddle elite: leaves slowing puddles
			if elite and elite_power == "puddle":
				_puddle_t -= delta
				if _puddle_t <= 0.0:
					_puddle_t = 0.7
					run.spawn_puddle(global_position)
			if bounce_t > 0.0:
				_ricochet()
			if actor_t > 0.0:
				_actor_strike(delta)
			else:
				# Kroker en sigilo (pantera): no le encuentran / Kroker in stealth (panther): they can't find him
				var lost := lost_track()
				if stun_t <= 0.0 and is_dangerous() and not lost:
					_touch_player()
				if stun_t <= 0.0 and not lost:
					_act(delta)
	queue_redraw()


# --- Movimiento animado / Animated motion ---
var _walk_vel := Vector2.ZERO
var _turn_t := 0.0
var _step_ph := 0.0
var _gait_k := 0.0
## Altura del saltito del paso (la usa _draw) / Height of the step hop (used by _draw)
var _step_hop := 0.0
var _anim_last := Vector2.INF


## Para todos los enemigos que andan: se inclinan hacia donde van (y hacia atrás si los empujan),
## rebotan un poco a cada paso y se estrechan un instante al darse la vuelta. Los jefes y las
## estatuas llevan su propia animación.
## For every walking enemy: they lean into where they're going (and backwards when shoved), bounce
## a little with each step and narrow for an instant when turning round. Bosses and statues have
## their own animation.
func _animate_motion(delta: float) -> void:
	if is_boss() or statue or speed <= 0.0:
		return
	if _anim_last == Vector2.INF:
		_anim_last = position
	var moved := (position - _anim_last) / maxf(delta, 0.0001)
	_anim_last = position
	var k := clampf(_walk_vel.length() / maxf(speed, 60.0), 0.0, 1.0) if stun_t <= 0.0 and heavy_t <= 0.0 and knock.length() < 200.0 else 0.0
	_gait_k = move_toward(_gait_k, k, delta * 6.0)
	k = _gait_k
	# Con la velocidad con la que anda, no con la de los empujones: si no, al salir lanzado el paso
	# giraba a toda velocidad / From its walking speed, not from shoves: otherwise, when launched,
	# the step spun at full speed
	_step_ph += minf(_walk_vel.length(), moved.length()) * delta * (0.065 if gait == Gait.STOMP else 0.085)
	var lean := clampf(_walk_vel.x / 900.0, -0.14, 0.14) - clampf(knock.x / 1600.0, -0.3, 0.3)
	_turn_t = maxf(0.0, _turn_t - delta * 6.0)
	# Cada paso: sube un poco, se estira en el aire y se aplasta al apoyar; se balancea de un pie al otro
	# Every step: rises a little, stretches in the air and squashes on landing; sways from foot to foot
	var s := absf(sin(_step_ph))
	var contact := pow(1.0 - s, 3.0)
	var air := s * s
	var sq := 0.0
	var sway := 0.0
	_step_hop = 0.0
	match gait:
		Gait.WALK:
			sq = 0.07 * k
			_step_hop = 5.0 * s * k
			sway = 0.05 * sin(_step_ph) * k
		Gait.STOMP:
			# Pesados: apenas despegan, pero aplastan más al pisar / Heavy: barely leave the ground, but squash harder on landing
			sq = 0.1 * k
			_step_hop = 2.5 * s * k
			sway = 0.035 * sin(_step_ph) * k
		Gait.FLOAT:
			# Flotan: sin pasos, un vaivén suave que se inclina con el viaje / Float: no steps, a gentle drift leaning with the travel
			contact = 0.0
			air = 0.0
			sway = 0.06 * sin(_t * 2.2 + _phase) * (0.4 + 0.6 * k)
	skew = lerpf(skew, lean + sway, minf(1.0, delta * 10.0))
	# Al recibir un golpe se aplasta y rebota (un muelle que se apaga) / When hit it squashes and springs back (a dying spring)
	_hit_squash = maxf(0.0, _hit_squash - delta * 4.0)
	var hit := _hit_squash * _hit_squash * cos((1.0 - _hit_squash) * 9.0)
	var sx := 1.0 + sq * contact - sq * 0.5 * air + 0.16 * hit
	var sy := 1.0 - sq * contact + sq * 0.6 * air - 0.14 * hit
	scale = Vector2(sx * (1.0 - 0.3 * sin(_turn_t * PI)), sy)


## Velocidad que quiere llevar (por defecto, ir a por Kroker) / Desired velocity (by default, chase Kroker)
func _desired_velocity() -> Vector2:
	var to_player: Vector2 = run.player.global_position - global_position
	var dir := to_player.normalized()
	return dir * speed


## ¿Ha perdido de vista a Kroker? (sigilo de la pantera; los jefes no se dejan engañar)
## Has it lost sight of Kroker? (panther stealth; bosses aren't fooled)
func lost_track() -> bool:
	return not is_boss() and run.player is Player and (run.player as Player).stealth_t > 0.0


## Husmea despacio dando vueltas, sin rumbo / Sniffs about slowly in circles, aimlessly
func _sniff() -> Vector2:
	return Vector2.from_angle(_t * 0.9 + float(get_instance_id() % 97)) * speed * 0.3


## Para comportamientos extra, como disparar / For extra behaviour, such as shooting
func _act(_delta: float) -> void:
	pass


## ¿Hace daño al tocar a Kroker? / Does touching Kroker hurt him?
func is_dangerous() -> bool:
	return true


func _move(delta: float) -> void:
	var vel := Vector2.ZERO
	if stun_t <= 0.0:
		var want := _actor_velocity() if actor_t > 0.0 else (_sniff() if lost_track() else _desired_velocity())
		# Saliendo en estampida de la puerta: corre hacia el pasillo / Stampeding out of the door: runs into the hall
		if rush_t > 0.0:
			want = rush_dir * maxf(speed, 95.0) * 2.2
		vel = want * (0.5 if slow_t > 0.0 else 1.0) * fluff_speed_mult()
		# El Despertador ha sonado: todos van más deprisa / The Alarm Clock went off: everyone's faster
		if run.haste_t > 0.0 and not is_boss():
			vel *= run.haste_mult
	# Se separa de los demás enemigos / Keeps apart from other enemies
	var here := global_position
	for n: Node in run.foes():
		if n == self or not is_instance_valid(n):
			continue
		var other := n as Enemy
		var d := here - other.global_position
		var min_d := radius + other.radius
		var d2 := d.length_squared()
		if d2 > 0.0001 and d2 < min_d * min_d:
			var dist := sqrt(d2)
			vel += d / dist * (min_d - dist) * 6.0
	# Rodeando un edificio de la ciudad / Going round a city building
	if _detour_t > 0.0:
		_detour_t -= delta
		vel = vel * 0.25 + _detour * speed * fluff_speed_mult()
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
	var sucked_in := vacuumed and hp <= max_hp * 0.35
	heavy_t = maxf(0.0, heavy_t - delta)
	if can_fall() and (knock.length() > 200.0 or bounce_t > 0.0 or heavy_t > 0.0 or sucked_in):
		var to: Vector2 = run.hole_at(position, radius, knock + vel if not sucked_in else external_pull * 2.0)
		if to != Vector2.INF:
			_start_fall(to)
			return
	vacuumed = false
	knock = knock.move_toward(Vector2.ZERO, (500.0 if bounce_t > 0.0 or heavy_t > 0.0 else 1400.0) * delta)
	external_pull = Vector2.ZERO
	_walk_vel = vel
	if absf(vel.x) > 5.0:
		if signf(vel.x) != _facing:
			_turn_t = 1.0
		_facing = signf(vel.x)
	var clamped: Vector2 = run.clamp_to_arena(position, radius)
	# En la ciudad, si un obstáculo le corta el paso, lo rodea por el lado que da a Kroker
	# In the city, if an obstacle blocks its way, it goes round on Kroker's side
	if run.room.open_map() and _detour_t <= 0.0 and clamped.distance_to(position) > 0.5:
		var side: Vector2 = (clamped - position).normalized().orthogonal()
		if side.dot(run.player.global_position - global_position) < 0.0:
			side = -side
		_detour = side
		_detour_t = 0.7
	if bounce_t > 0.0 and clamped != position:
		var n := (clamped - position).normalized()
		if n != Vector2.ZERO:
			knock = knock.bounce(n) * 0.85
		Audio.play("ricochet", -14.0, 0.1)
	position = clamped


## Jefes: no cuentan para el límite de enemigos ni se borran con la K / Bosses: don't count for the enemy cap and survive the K key
## ¿Brota del suelo al aparecer? (no los que vuelan o llegan por su cuenta) / Does it sprout from the floor when appearing? (not flyers or those that arrive on their own)
func sprouts() -> bool:
	return not is_boss() and not statue and not bestiary_id in ["van", "mosquito", "exam"]


func is_boss() -> bool:
	return false


## Los jefes no se pueden tirar por los agujeros / Bosses can't be thrown down holes
func can_fall() -> bool:
	return true


func _start_fall(to: Vector2) -> void:
	_unstick()
	skew = 0.0
	Progress.add_stat("falls")
	if is_instance_valid(run.yawns) and run.yawns.owns(to):
		Progress.add_stat("yawn_falls")
	GameState.run_falls += 1
	Progress.tip("hole")
	_fall_from = run.clamp_to_arena(position, radius)
	position = _fall_from
	_fall_to = to
	_fall_t = 0.0
	state = State.DYING
	_fade = 1.0
	knock = Vector2.ZERO
	run.fx.text(global_position + Vector2(0, -aim_height - 40), tr("ENEMY_FELL"), UITheme.GOLD, 20, true)
	run.fx.vortex(to)
	run.fx.flash(to, 50.0, Color("b48cff", 0.8), 0.25)
	run.punch(0.03)
	Audio.play("hole_fall", -7.0, 0.08)
	Audio.play("vortex", -12.0, 0.08)
	# Que se note: un instante parado y una sacudida, más fuerte cuanto más pesa
	# Make it land: a frozen instant and a shake, stronger the heavier it is
	run.hit_stop(0.045 + 0.02 * minf(2.0, mass - 1.0))
	run.shake(3.0 + 2.0 * minf(2.0, mass - 1.0))
	Settings.rumble(0.35, 0.1, 0.12)
	if run.get("trinkets"):
		run.trinkets.on_fall(self)
	if run.has_method("on_fall_chain"):
		run.on_fall_chain(self, _fall_from)
	if run.has_method("hole_bonus"):
		run.hole_bonus(to)
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
		run.fx.ring(_fall_to, 30.0, Color("8d7ff0", 0.5), 0.6, 1.4)
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
			# Dúo Svinho y Silly: lo que toca el rebote se queda congelado y vulnerable
			# Svinho & Silly duo: whatever the bounce touches freezes and turns vulnerable
			if GameState.has_duo("svinho_silly") and not other.is_boss():
				other.glitch(GameState.duo_value("svinho_silly", "secs"), 0.0, 3.0, 1.0 + GameState.duo_value("svinho_silly", "pct") / 100.0)
			Audio.play("ricochet", -11.0, 0.1)
			if bounce_chain > 0:
				other.start_bounce(bounce_damage, bounce_chain - 1, [self])
			bounce_chain = 0  # solo pasa el rebote una vez / passes the bounce on only once


func start_bounce(damage: float, chain: int, ignore: Array = []) -> void:
	bounce_t = 0.7
	bounce_damage = damage
	bounce_chain = chain
	if GameState.has_duo("svinho_silly") and ignore.is_empty():
		bounce_chain += int(GameState.duo_value("svinho_silly", "extra"))
		glitch_t = maxf(glitch_t, 0.7)
	_bounced = ignore.duplicate()


func _touch_player() -> void:
	var player: Node2D = run.player
	if global_position.distance_to(player.global_position + Vector2(0, -28)) < radius + 22.0:
		player.take_damage(contact_damage * atk_mult(), self)


## Luna lo deja flotando "secs" segundos / Luna leaves it floating for "secs" seconds
func float_up(secs: float) -> void:
	if is_boss() or not can_fall() or state != State.ALIVE:
		return
	if float_t <= 0.0:
		run.fx.ring(global_position, radius + 10.0, Color("c9d4ff"), 0.4, 2.0)
	float_t = maxf(float_t, secs)
	_float_total = float_t


## Vuelve al suelo: si debajo hay un agujero, se cae / Back to the floor: if there's a hole below, it falls in
func _land_float() -> void:
	var to: Vector2 = run.hole_at(position, radius, Vector2.ZERO)
	if to != Vector2.INF:
		_start_fall(to)
		run.fx.text(global_position + Vector2(0, -aim_height * 2.0 - 40), tr("LUNA_DROP"), Color("c9d4ff"), 20)
	else:
		run.fx.ring(global_position, radius + 6.0, Color(1, 1, 1, 0.5), 0.25, 1.5)


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


## Indefenso (para el Abusón de Stolk): aturdido, congelado, glitcheado, frenado, flotando, bailando,
## pegado o volando por un golpe fuerte / Defenceless (for Stolk's Bully): stunned, frozen, glitched,
## slowed, floating, dancing, stuck or flying from a heavy hit
func defenceless() -> bool:
	return stun_t > 0.0 or glitch_t > 0.0 or slow_t > 0.0 or float_t > 0.0 or dance_t > 0.0 or heavy_t > 0.0 \
		or is_stuck() or fluffs.size() >= 2


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

## Defensa que le queda al que sangra (también a Kroker) / Defence left to whoever bleeds (Kroker too)
const BLEED_DEFENSE := 0.75


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


func shielded() -> bool:
	return shield_by != null and is_instance_valid(shield_by) and (shield_by as Enemy).is_targetable()


func is_targetable() -> bool:
	return state != State.DYING and actor_t <= 0.0


## ¿Puede D. Lynx ponerlo a actuar? Los jefes y los que no persiguen (nidos, furgonetas,
## antidisturbios, el zorro dorado, el muñeco) no / Can D. Lynx make it act? Bosses and the ones that
## don't chase (nests, vans, riot officers, the golden fox, the dummy) can't
func can_act() -> bool:
	return state == State.ALIVE and actor_t <= 0.0 and not is_boss() and not (self is Nest or self is Van or self is Riot or self is GoldenFoox or self is TrainingDummy or self is BotcherTurret)


## Se pone a actuar para D. Lynx durante "secs" / Starts acting for D. Lynx for "secs"
func start_acting(secs: float, dmg: float) -> void:
	actor_t = secs
	actor_dmg = dmg
	_actor_tick = 0.2
	dance_t = 0.0
	shield_by = null


func _actor_target() -> Enemy:
	var best: Enemy = null
	var best_d := INF
	for o: Node in run.enemies.get_children():
		if o == self or not o is Enemy or not (o as Enemy).is_targetable():
			continue
		var d := global_position.distance_squared_to((o as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = o
	return best


## Actuando: va a por el enemigo más cercano; si no hay, se queda junto a Kroker
## Acting: goes for the nearest enemy; if there's none, stays by Kroker
func _actor_velocity() -> Vector2:
	var foe := _actor_target()
	var to: Vector2 = (foe.global_position if foe else run.player.global_position + Vector2(_facing * 60.0, 20.0)) - global_position
	if to.length() < radius + 6.0:
		return Vector2.ZERO
	return to.normalized() * maxf(speed, 110.0) * 1.15


func _actor_strike(delta: float) -> void:
	_actor_tick -= delta
	if _actor_tick > 0.0:
		return
	_actor_tick = ACTOR_EVERY
	for o: Node in run.enemies.get_children():
		if o == self or not o is Enemy or not (o as Enemy).is_targetable():
			continue
		var e := o as Enemy
		var d := e.global_position - global_position
		if d.length() < radius + e.radius + ACTOR_REACH:
			e.hit(actor_dmg * run.player.damage_mult, d.normalized() * 260.0 / maxf(0.5, e.mass))
			run.fx.ring(e.aim_point(), 18.0, Color("ff6a6a"), 0.25, 2.0)
			_facing = signf(d.x) if absf(d.x) > 1.0 else _facing


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
	# Sangrando, su defensa baja al 75 %: recibe un tercio más / Bleeding, its defence drops to 75%: takes a third more
	if bleed_t > 0.0:
		amount /= BLEED_DEFENSE
	if is_stuck() and stuck_bonus > 0.0:
		amount *= 1.0 + stuck_bonus / 100.0
	# Escudo de antidisturbios: casi no le hace nada / Riot shield: barely anything gets through
	if shielded():
		amount *= Riot.SHIELD_PASS
		impulse *= Riot.SHIELD_PASS
		run.fx.ring(aim_point(), 22.0, Color("8fd8ff"), 0.25, 1.8)
	hp -= amount
	# Flotando (Luna): sin peso, sale despedido más lejos / Floating (Luna): weightless, it flies further
	if float_t > 0.0:
		impulse *= FLOAT_KNOCK
	knock += impulse / mass
	_flash = 1.0
	_hit_squash = 1.0
	Audio.play("hit", -13.0, 0.1)
	if Settings.damage_numbers:
		# Los golpes gordos salen más grandes y dorados / Big hits come out larger and golden
		var heavy_num := amount >= max_hp * 0.35 and amount >= 8.0
		run.fx.text(global_position + Vector2(0, -aim_height - 34), str(roundi(amount)),
			GLITCH_A if vuln_t > 0.0 else (UITheme.GOLD if heavy_num else UITheme.BONE), 28, heavy_num)
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
		var big := elite or (max_hp >= 60.0 and not is_boss())
		run.fx.burst(aim_point(), FX.DEATH_COLORS.get(bestiary_id, Color("dfe3f0")), big)
		_death_sound()
		# Los grandes caen con peso / The big ones go down with weight
		if elite or (max_hp >= 60.0 and not is_boss()):
			run.hit_stop(0.05)
			run.shake(3.0)
		if burn_t > 0.0 and GameState.has_duo("pinche_magnus"):
			_franchise()
		run.on_enemy_killed(self)


## Dúo del Pinche y Magnus: quien muere quemado a veces suelta Realidad Fragmentada y le pasa
## el fuego a los de al lado / Kitchen Boy & Magnus duo: whoever dies burning sometimes drops
## Fragmented Reality and passes the fire on to its neighbours
func _franchise() -> void:
	if randf() * 100.0 < GameState.duo_value("pinche_magnus", "chance") and GameState.reality_on():
		GameState.add_reality(1)
		run.hud.set_reality()
		run.fx.text(global_position + Vector2(0, -aim_height * 3.0), "+1 ◆", Color("4fd39a"), 20)
		Audio.play("reality", -10.0, 0.1)
	var near: Array = []
	for o: Node in run.enemies.get_children():
		if o != self and o is Enemy and (o as Enemy).is_targetable() and (o as Node2D).global_position.distance_to(global_position) < 220.0:
			near.append(o)
	near.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position))
	for i in mini(near.size(), int(GameState.duo_value("pinche_magnus", "spread"))):
		var e := near[i] as Enemy
		e.burn(burn_dps, maxf(burn_t, 2.0), burn_pct)
		run.fx.ring(e.aim_point(), 16.0, Color("ff9a3a"), 0.3, 2.0)


func _death_sound() -> void:
	Audio.play("foox_die", -8.0, 0.1)


func _draw() -> void:
	var a := _fade
	var bob := sin(_t * 2.6 + _phase) * 3.0 - _step_hop
	# Flotando: sube un palmo, sombra pequeña y burbuja de ingravidez / Floating: rises a hand's breadth, small shadow and a zero-g bubble
	if float_t > 0.0 and state == State.ALIVE:
		var up := minf(1.0, (_float_total - float_t) * 5.0) * minf(1.0, float_t * 4.0)
		bob -= 34.0 * up
		draw_set_transform(Vector2.ZERO, -rotation, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, radius * (1.0 - 0.4 * up), Color(0.05, 0.02, 0.15, 0.25 * a))
		draw_set_transform(Vector2.ZERO)
		for i in 4:
			var ang := _t * 2.0 + i * TAU / 4.0
			draw_circle(Vector2(cos(ang) * (radius + 10.0), bob - aim_height + sin(ang) * 8.0), 2.0, Color(0.79, 0.83, 1.0, 0.8 * a))
	# Remolino de bruma a sus pies mientras aparece / A swirl of mist at its feet while it appears
	if state == State.SPAWNING and sprouts() and not preview:
		var k := 1.0 - _fade
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 / maxf(scale.x, 0.01), 0.4 / maxf(scale.y, 0.01)))
		for i in 3:
			var r := radius + 10.0 + i * 9.0
			var st := _t * (5.0 - i) + i * 2.0
			draw_arc(Vector2.ZERO, r, st, st + 2.2, 14, Color(UITheme.MIST, 0.55 * k), 2.0)
		draw_set_transform(Vector2.ZERO)
	if elite and not statue:
		# Sombra de su color que late bajo el élite / Pulsing shadow in its colour under the elite
		var pulse := 0.85 + 0.15 * sin(_t * 5.0)
		var r := (radius + 22.0) * pulse
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, r, Color(elite_color().darkened(0.7), 0.45 * a))
		draw_arc(Vector2.ZERO, r, 0, TAU, 28, Color(elite_color(), 0.8 * a), 3.0)
		draw_set_transform(Vector2.ZERO)
		# Ascuas de su color que suben alrededor / Embers in its colour rising around it
		for i in 6:
			var ph := fposmod(_t * 0.7 + i * 0.167 + _phase, 1.0)
			var x := sin(i * 2.4 + _phase) * (radius + 8.0)
			var y := -ph * aim_height * 3.0
			var s := 4.0 if i % 2 == 0 else 2.0
			draw_rect(Rect2(Vector2(x, y) - Vector2(s, s) / 2.0, Vector2(s, s)), Color(elite_color(), (1.0 - ph) * 0.9 * a))
	if glitch_t > 0.0:
		var j := Vector2(randf_range(-6, 6), randf_range(-2, 2))
		_draw_body(Vector2(-5, bob) + j, Color(GLITCH_A, 0.5), a * 0.6)
		_draw_body(Vector2(5, bob) - j, Color(GLITCH_B, 0.5), a * 0.6)
	# Bailando: se balancea y da saltitos al ritmo, con notas encima / Dancing: sways and hops to the beat, with notes above
	if dance_t > 0.0:
		var beat := _t * 8.4 + _phase
		bob += -absf(sin(beat * 0.5)) * 10.0
		_draw_body(Vector2(sin(beat * 0.5) * 9.0, bob), Color.WHITE, a)
		var nc := Color(["ff6a8a", "8fe0ff", "f6d993"][int(_phase * 10.0) % 3], 0.8 * a)
		var np := head_top() + Vector2(sin(beat * 0.25) * 14.0, -12.0 - fposmod(_t * 30.0, 18.0))
		draw_circle(np, 4.0, nc)
		draw_line(np + Vector2(3.5, 0), np + Vector2(3.5, -12), nc, 2.0)
	else:
		_draw_body(Vector2(0, bob), Color.WHITE, a)
	draw_set_transform(Vector2.ZERO)
	if elite:
		_draw_horns(head_top() + Vector2(0, bob), a)
		if Settings.colorblind:
			_draw_elite_symbol(head_top() + Vector2(0, bob - 34), a)
	# Burbuja del escudo de antidisturbios / Riot shield bubble
	if shielded():
		var top := head_top()
		var c := Vector2(0, top.y * 0.5)
		var rr := Vector2(radius + 22.0, -top.y * 0.5 + 12.0)
		var pts := PackedVector2Array()
		for i in 25:
			var ang := TAU * i / 24.0
			pts.append(c + Vector2(cos(ang) * rr.x, sin(ang) * rr.y))
		draw_colored_polygon(pts, Color("8fd8ff", 0.12 * a))
		draw_polyline(pts, Color("bfe8ff", (0.45 + 0.2 * sin(_t * 4.0)) * a), 2.0)
	# Sonámbulos: zetas que suben de la cabeza / Sleepwalkers: z's rising from the head
	if run and run.event == "sleepy" and not is_boss() and state == State.ALIVE:
		for i in 2:
			var ph := fposmod(_t * 0.6 + _phase + i * 0.5, 1.0)
			var zp := head_top() + Vector2(8 + ph * 14.0, -6 - ph * 26.0)
			var zs := 4.0 + i * 2.0
			draw_polyline(PackedVector2Array([zp + Vector2(-zs, -zs), zp + Vector2(zs, -zs), zp + Vector2(-zs, zs), zp + Vector2(zs, zs)]),
				Color(UITheme.MIST, (1.0 - ph) * 0.85 * a), 2.0)
	if glitch_t > 0.0:
		for i in 3:
			var y := randf_range(-aim_height * 2.5, 6)
			draw_rect(Rect2(randf_range(-40, 10), y, randf_range(20, 50), 3), Color([GLITCH_A, GLITCH_B, Color.WHITE][i], 0.5 * a))
	# Lanzado por un golpe fuerte: estelas de viento detrás, para que se lea hacia dónde vuela (y si va al agujero)
	# Launched by a heavy hit: wind streaks behind it, so you can read where it's flying (and whether it's going down the hole)
	if state == State.ALIVE and heavy_t > 0.0 and knock.length() > 250.0 and not statue:
		var back := -knock.normalized()
		var side := back.orthogonal()
		var k := clampf((knock.length() - 250.0) / 500.0, 0.2, 1.0)
		for i in 3:
			var o := side * (i - 1) * radius * 0.7 + Vector2(0, -aim_height * (0.6 + 0.4 * i))
			var len := (26.0 + 14.0 * i) * k
			draw_line(o + back * (radius * 0.6), o + back * (radius * 0.6 + len), Color(1, 1, 1, 0.55 * k * a), 2.0)
	# Despiertos por el Despertador: rayitas de prisa detrás / Woken by the Alarm Clock: little hurry lines behind
	if run and state == State.ALIVE and not is_boss() and float(run.get("haste_t")) > 0.0:
		for i in 3:
			var y := -aim_height * (0.6 + i * 0.6) + bob
			var x0 := -_facing * (radius + 4.0 + fposmod(_t * 90.0 + i * 13.0, 14.0))
			draw_line(Vector2(x0, y), Vector2(x0 - _facing * 12.0, y), Color("ff8a96", 0.7 * a), 2.0)
	_draw_statuses(bob, a)
	if actor_t > 0.0 and state == State.ALIVE:
		_draw_actor_mark(a)
	if stun_t > 0.0:
		for i in 3:
			var ang := _t * 4.0 + i * TAU / 3.0
			DreamBackground.draw_star(self, Vector2(cos(ang) * 18.0, -aim_height * 3.0 + sin(ang) * 5.0), 2.0, Color(UITheme.GOLD, a))


## Actuando para D. Lynx: una claqueta encima y un foco a sus pies / Acting for D. Lynx: a clapperboard above and a spotlight at its feet
func _draw_actor_mark(a: float) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, radius + 14.0, Color(1.0, 0.95, 0.8, 0.16 * a))
	draw_arc(Vector2.ZERO, radius + 14.0, 0.0, TAU, 24, Color("e0303a", 0.7 * a), 3.0)
	draw_set_transform(Vector2.ZERO)
	var c := (head_top() + Vector2(0, -16.0 + sin(_t * 3.0) * 2.0)).round()
	Sprites.draw(self, "fx_clapper", Color(1, 1, 1, a), c)


## Modo daltónico: un símbolo para cada habilidad del élite, además del color
## Colourblind mode: a symbol for each elite ability, on top of the colour
## (flechas que se separan, gota o rayo / arrows pulling apart, a drop or a lightning bolt)
func _draw_elite_symbol(c: Vector2, a: float) -> void:
	Sprites.draw(self, "elite_sym_" + elite_power, Color(1, 1, 1, a), c.round())


func elite_color() -> Color:
	return ELITE_COLORS.get(elite_power, Color("ff2230"))


## Dónde está lo alto de la cabeza (para los cuernos del élite) / Where the top of the head is (for elite horns)
func head_top() -> Vector2:
	return Vector2(0, -aim_height * 2.2)


## Cuernos de demonio en pixel art, con la punta brillando en el color del élite
## Pixel-art demon horns, with the tip glowing in the elite's colour
func _draw_horns(top: Vector2, a: float) -> void:
	var glow := Color(elite_color(), (0.7 + 0.3 * sin(_t * 5.0)) * a)
	for side: float in [-1.0, 1.0]:
		var base := top + Vector2(side * 10.0, 6.0)
		draw_set_transform(base, 0.0, Vector2(-side, 1.0))
		Sprites.draw(self, "elite_horn", Color(1, 1, 1, a))
		draw_rect(Rect2(Vector2(-22, -24), Vector2(4, 4)), glow)
	draw_set_transform(Vector2.ZERO)


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
