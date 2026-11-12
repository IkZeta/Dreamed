class_name WeaponYoyo
extends Weapon
## Yoyó (alcance medio): Kroker lo lanza al enemigo más cercano y vuelve a su mano por la cuerda.
## Cada YANK_EVERY lanzamientos, el yoyó se engancha y, al recoger la cuerda, arrastra al enemigo
## hacia Kroker con tanta fuerza que pasa de largo: así se tiran enemigos por los agujeros que
## Kroker tiene detrás. A los jefes solo les hace daño.
## Yo-yo (medium reach): Kroker throws it at the nearest enemy and it comes back to his hand along
## the string. Every YANK_EVERY throws the yo-yo hooks on and, as the string is reeled in, drags the
## enemy towards Kroker so hard it flies past him: that's how you send enemies down the holes behind
## Kroker. Bosses only take damage.
##
## Mejoras (valores por nivel en GameState.UPGRADE_VALUES) / Upgrades (per-level values there):
##  Svinho — Vuelta al mundo: rebota en "extra" enemigos más con "pct" % del daño.
##  Stolk  — Yoyó de acero: +"pct" % de daño.
##  Silly  — Cuerda con bug: "chance" % de congelar "secs" segundos.
##  Doc    — vida máxima a cambio de +"pct" % de recarga.

const RANGE := 240.0
const DAMAGE := 9.0
const KNOCKBACK := 130.0
const COOLDOWN := 0.65
const YANK_EVERY := 3
## Hasta dónde busca un agujero detrás de Kroker / How far behind Kroker it looks for a hole
const YANK_HOLE := 340.0
const SPEED := 1100.0
const BOUNCE_RANGE := 200.0
const PINK := Color("e85d75")

var _shot: Node2D
var _throws := 0


func _init() -> void:
	cooldown = COOLDOWN


func _ready() -> void:
	cooldown = COOLDOWN * (1.0 + uv("doc", "pct") / 100.0)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	KrokerArt.yoyo_out = is_instance_valid(_shot)


func attack() -> bool:
	if is_instance_valid(_shot):
		return false
	var target := nearest(RANGE * range_mult())
	if target == null:
		return false
	var y := YoyoShot.new()
	y.weapon = self
	y.target = target
	y.damage = DAMAGE * (1.0 + uv("stolk", "pct") / 100.0)
	y.bounces = int(uv("svinho", "extra"))
	y.yank = _throws >= YANK_EVERY - 1
	y.position = hand_pos()
	run.world.add_child(y)
	_shot = y
	swung()
	Audio.play("yoyo_throw", -8.0, 0.1)
	return true


## Dónde tiene Kroker la mano del yoyó (en el mundo) / Where Kroker's yo-yo hand is (in the world)
func hand_pos() -> Vector2:
	var side := 1.0 if hand() == "r" else -1.0
	return player.global_position + Vector2(20.0 * side * player._facing, -40.0)


## El tirón: el enemigo sale disparado hacia Kroker y pasa de largo; puede caer por un agujero
## The yank: the enemy shoots towards Kroker and flies past him; it can fall down a hole
func yank(e: Enemy) -> void:
	if e.is_boss() or not e.can_fall():
		return
	_throws = 0
	var from := e.global_position
	var me := player.global_position
	var dir := (me - from).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(player._facing, 0.0)
	# Pegado a Kroker: lo voltea alrededor, hacia el agujero más cercano que haya
	# Right next to Kroker: swings it round, towards the nearest hole there is
	var close := from.distance_to(me) < 90.0
	# Si hay un agujero detrás de Kroker (en la misma dirección, no muy lejos), apunta ahí y llega
	# justo; si no, pasa de largo ~160 px / If there's a hole behind Kroker (same direction, not too
	# far), it aims there and gets just far enough; otherwise it flies ~160 px past him
	var goal := me + dir * 160.0
	var best := YANK_HOLE
	for c in _holes_near(me):
		var to_c := c - me
		var dist := to_c.length()
		if dist < best and dist > 1.0 and (close or to_c.normalized().dot(dir) > 0.55):
			best = dist
			goal = c + to_c.normalized() * 30.0
	var path := goal - from
	# Frena a ~850 px/s² mientras dura el golpe fuerte / Brakes at ~850 px/s² while the heavy hit lasts
	var v := sqrt(2.0 * 850.0 * path.length())
	e.knock = path.normalized() * v
	e.heavy_t = 1.0
	e.stun_t = maxf(e.stun_t, 0.7)   # pasa a tu lado sin morderte / flies past without biting you
	run.fx.text(e.global_position + Vector2(0, -e.aim_height * 2.0 - 30), tr("YOYO_YANK"), PINK, 22)
	Audio.play("swing", -4.0, 0.1)
	run.shake(2.0)
	Progress.add_stat("yoyo_yank")
	Progress.tip("yoyo")
	# Dúo Svinho y Lil Key: arrastra también a los de al lado, que se quedan bailando
	# Svinho & Lil Key duo: also drags the ones beside it, who are left dancing
	if GameState.has_duo("svinho_lilkey") and primary:
		var near: Array = []
		for n: Node in run.foes():
			if n != e and is_instance_valid(n) and n is Enemy and (n as Enemy).is_targetable() and not (n as Enemy).is_boss() \
					and (n as Node2D).global_position.distance_to(e.global_position) < 170.0:
				near.append(n)
		near.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.global_position.distance_squared_to(e.global_position) < b.global_position.distance_squared_to(e.global_position))
		for i in mini(near.size(), int(GameState.duo_value("svinho_lilkey", "extra"))):
			var o := near[i] as Enemy
			o.knock = e.knock * 0.9
			o.heavy_t = 0.9
			o.dance_t = maxf(o.dance_t, GameState.duo_value("svinho_lilkey", "secs"))
			run.fx.bolt(PackedVector2Array([e.aim_point(), o.aim_point()]), PINK)


## Centros de los agujeros libres cerca de Kroker (los del suelo y los Bostezos)
## Centres of the free holes near Kroker (floor ones and Yawns)
func _holes_near(at: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var list: Array = run.room.holes_list()
	for i in run.room.hole_count():
		var rc := Bedroom.rect_world(list[i])
		if not run.hole_covered(rc) and rc.get_center().distance_to(at) < YANK_HOLE:
			out.append(rc.get_center())
	if is_instance_valid(run.yawns):
		for c in run.yawns.open_centers():
			if c.distance_to(at) < YANK_HOLE:
				out.append(c)
	return out


func on_yoyo_hit(e: Enemy) -> void:
	# Cuenta los golpes que llegan (los que fallan o dan a un jefe no gastan el tirón)
	# Counts the hits that land (misses or hits on a boss don't spend the yank)
	if _throws < YANK_EVERY - 1:
		_throws += 1
	if lv("silly") > 0 and randf() * 100.0 < uv("silly", "chance"):
		e.glitch(uv("silly", "secs"))


func charge_bars() -> Array:
	# Con el yoyó fuera, el anillo espera; el rosa cuenta para el tirón
	# With the yo-yo out, the ring waits; the pink one counts towards the yank
	var yank_k := float(_throws) / (YANK_EVERY - 1)
	if is_instance_valid(_shot):
		return [[0.0, UITheme.BONE], [yank_k, PINK]]
	return [super.charge_bars()[0], [yank_k, PINK]]


func _exit_tree() -> void:
	KrokerArt.yoyo_out = false


class YoyoShot extends Node2D:
	var weapon: WeaponYoyo
	var target: Node2D
	var damage := 7.0
	var bounces := 0
	var yank := false
	var _hit: Array = []
	var _returning := false
	var _spin := 0.0
	var _life := 2.5

	func _ready() -> void:
		z_index = 40

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(weapon) or not is_instance_valid(weapon.player):
			queue_free()
			return
		_life -= delta
		_spin += delta * 30.0
		if not _returning and (not is_instance_valid(target) or not target.is_targetable() or _life < 1.2):
			_returning = true
		var goal: Vector2 = weapon.hand_pos() if _returning else (target as Enemy).aim_point()
		var dir := (goal - global_position).normalized()
		global_position += dir * WeaponYoyo.SPEED * (1.15 if _returning else 1.0) * delta
		if _returning:
			if global_position.distance_to(goal) < 22.0 or _life <= 0.0:
				# La recarga empieza al volver a la mano / The cooldown starts when it's back in the hand
				weapon._timer = weapon.cooldown
				Audio.play("yoyo_catch", -12.0, 0.1)
				queue_free()
				return
		elif global_position.distance_to(goal) < 22.0:
			var e := target as Enemy
			_hit.append(e)
			weapon.deal(e, damage, dir * WeaponYoyo.KNOCKBACK)
			weapon.on_yoyo_hit(e)
			weapon.run.fx.ring(goal, 18.0, WeaponYoyo.PINK, 0.25, 2.0)
			Audio.play("hit", -10.0, 0.1)
			if yank and _hit.size() == 1 and e.state == Enemy.State.ALIVE:
				weapon.yank(e)
				_returning = true
			elif bounces > 0:
				bounces -= 1
				damage *= weapon.uv("svinho", "pct") / 100.0 if weapon.lv("svinho") > 0 else 0.8
				target = weapon.nearest(WeaponYoyo.BOUNCE_RANGE * weapon.range_mult(), global_position, _hit)
				if target == null:
					_returning = true
				else:
					Audio.play("ricochet", -12.0, 0.1)
			else:
				_returning = true
		queue_redraw()

	func _draw() -> void:
		# Cuerda hasta la mano de Kroker / String back to Kroker's hand
		var hand := weapon.hand_pos() - global_position
		draw_line(Vector2.ZERO, hand, Color(0.98, 0.95, 0.9, 0.85), 1.5)
		draw_circle(Vector2(0, 30), 7.0, Color(0.05, 0.02, 0.15, 0.25))
		# Gira de canto: se estrecha y se ensancha / Spins edge-on: it narrows and widens
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(Player.ART_SCALE * (0.55 + 0.45 * absf(cos(_spin))), Player.ART_SCALE))
		Sprites.draw(self, "weapon_yoyo")
		draw_set_transform(Vector2.ZERO)
		if yank and not _returning:
			draw_arc(Vector2.ZERO, 14.0, _spin, _spin + 4.0, 12, Color(WeaponYoyo.PINK, 0.8), 2.0)
