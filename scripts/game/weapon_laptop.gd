class_name WeaponLaptop
extends Weapon
## Portátil (a distancia): Kroker teclea y pone torretas en el suelo, a su lado. Salen muy de
## tarde en tarde (dependen de la velocidad de ataque, que empieza muy baja), duran un rato y
## disparan solas al enemigo más cercano.
## Laptop (ranged): Kroker types and places turrets on the floor beside him. They come out very
## rarely (they depend on attack speed, which starts very low), last a while and shoot the
## nearest enemy by themselves.
##
## Nivel de las torretas: sube con el ataque de Kroker, hasta 4. Cada nivel añade un efecto:
## 2 quema, 3 empuja, 4 hace sangrar.
## Turret level: goes up with Kroker's attack, up to 4. Each level adds an effect:
## 2 burns, 3 pushes, 4 makes bleed.
##
## Mejoras (valores por nivel en GameState.UPGRADE_VALUES) / Upgrades (per-level values there):
##  Svinho — Wifi compartido: cada disparo salta a "extra" enemigos más.
##  Stolk  — Overclock: +"pct" % de daño de las torretas.
##  Silly  — Exploit: "chance" % de congelar "secs" s.
##  Doc    — vida máxima y una torreta curativa, a cambio de +"pct" % de recarga y −"dmg" % de daño.

const COOLDOWN := 4.5
const PLACE_RANGE := 420.0      # solo pone torretas si hay enemigos cerca / only places turrets with enemies near
const MAX_TURRETS := 3
## Ataque de Kroker (en %) que hace falta para cada nivel de torreta / Kroker's attack (in %) needed for each turret level
const LEVEL_ATTACK: Array[float] = [0.0, 10.0, 25.0, 45.0]

var _turrets: Array[Node2D] = []
var _healer: Node2D


func _init() -> void:
	cooldown = COOLDOWN


func _ready() -> void:
	cooldown = COOLDOWN * (1.0 + uv("doc", "pct") / 100.0)


## Nivel de las torretas según el ataque / Turret level from attack
static func turret_level() -> int:
	var atk := GameState.stat("attack")
	var lvl := 1
	for i in LEVEL_ATTACK.size():
		if atk >= LEVEL_ATTACK[i]:
			lvl = i + 1
	return lvl


func attack() -> bool:
	if nearest(PLACE_RANGE * range_mult()) == null:
		return false
	_turrets = _turrets.filter(func(t: Node2D) -> bool: return is_instance_valid(t))
	# Si ya hay muchas, la más vieja se apaga / If there are too many, the oldest shuts down
	while _turrets.size() >= MAX_TURRETS:
		_turrets.pop_front().shut_down()
	var t := _place(false)
	_turrets.append(t)
	# Doc: además, una torreta curativa (solo una a la vez) / Doc: also a healing turret (one at a time)
	if lv("doc") > 0 and not is_instance_valid(_healer):
		_healer = _place(true)
	swung(true)
	Audio.play("hack", -10.0, 0.15)
	return true


func _place(healer: bool) -> Node2D:
	var t := Turret.new()
	t.weapon = self
	t.healer = healer
	t.level = turret_level()
	var side := Vector2.from_angle(randf() * TAU) * randf_range(50.0, 90.0)
	t.position = run.clamp_to_arena(player.global_position + side * Vector2(1.0, 0.6), 20.0)
	run.world.add_child(t)
	run.fx.ring(t.position, 26.0, Color("5ff2ff") if not healer else Color("9be38a"), 0.35, 2.0)
	return t


## Daño de cada disparo / Damage of each shot
func shot_damage() -> float:
	return Turret.DAMAGE * (1.0 + uv("stolk", "pct") / 100.0) * (1.0 - uv("doc", "dmg") / 100.0)


## Lo que pasa al acertar: los efectos de nivel y Silly / What happens on a hit: level effects and Silly
func on_turret_hit(e: Node2D, dir: Vector2, level: int) -> void:
	var push := dir * (Turret.PUSH if level >= 3 else 60.0)
	deal(e, shot_damage(), push)
	if not is_instance_valid(e) or not e is Enemy or not e.is_targetable():
		return
	var en := e as Enemy
	if level >= 2:
		en.burn(1.0, 3.0, 10.0)
	if level >= 4:
		en.bleed(2.0, 3.0)
	if lv("silly") > 0 and randf() * 100.0 < uv("silly", "chance"):
		en.glitch(uv("silly", "secs"))


class Turret extends Node2D:
	const LIFE := 15.0
	const RANGE := 300.0
	const FIRE_EVERY := 0.8
	const DAMAGE := 4.0
	const PUSH := 300.0
	const JUMP := 220.0
	const HEAL_RADIUS := 170.0
	const HEAL_EVERY := 4.0
	## Color de cada nivel / Colour of each level
	const SIZE := 1.3          # escala del dibujo / drawing scale
	const LEVEL_COLOR: Array[Color] = [Color("5ff2ff"), Color("ffb06a"), Color("b9a2ff"), Color("ff5f7a")]

	var weapon: WeaponLaptop
	var healer := false
	var level := 1
	var _life := LIFE
	var _fire := 0.4
	var _beams: Array = []    # [[desde, hasta, tiempo], ...] / [[from, to, time], ...]
	var _t := 0.0
	var _pop := 0.0
	var _aim := Vector2(1, 0)
	var _off := false

	func _ready() -> void:
		z_index = 5
		add_to_group("turrets")

	func shut_down() -> void:
		_life = minf(_life, 0.3)

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(weapon) or not is_instance_valid(weapon.player):
			queue_free()
			return
		_t += delta
		_pop = minf(1.0, _pop + delta * 5.0)
		for b: Array in _beams:
			b[2] = float(b[2]) - delta
		_beams = _beams.filter(func(b: Array) -> bool: return float(b[2]) > 0.0)
		queue_redraw()
		if not weapon.run.running:
			return
		_life -= delta
		if _life <= 0.0:
			queue_free()
			return
		_fire -= delta * weapon.speed_mult()
		if _fire > 0.0:
			return
		if healer:
			_fire = HEAL_EVERY
			var p: Player = weapon.player
			if p.global_position.distance_to(global_position) < HEAL_RADIUS and p.hp < p.max_hp:
				p.heal(weapon.uv("doc", "heal"))
				weapon.run.fx.ring(p.global_position + Vector2(0, -40), 30.0, Color("9be38a"), 0.4, 2.0)
				Audio.play("pickup", -16.0, 0.2)
			return
		var target := weapon.nearest(RANGE * weapon.range_mult(), global_position + Vector2(0, -24))
		if target == null:
			_fire = 0.15
			return
		_fire = FIRE_EVERY
		var from := global_position + Vector2(0, -27 * SIZE)
		var hit: Array = []
		var jumps := 1 + int(weapon.uv("svinho", "extra"))
		var cur := target
		while cur != null and jumps > 0:
			var to: Vector2 = cur.aim_point()
			_aim = (to - global_position).normalized()
			_beams.append([from - global_position, to - global_position, 0.1])
			weapon.on_turret_hit(cur, (to - from).normalized(), level)
			hit.append(cur)
			jumps -= 1
			from = to
			cur = weapon.nearest(JUMP * weapon.range_mult(), from, hit) if jumps > 0 else null
		Audio.play("laser", -18.0, 0.15)

	func _draw() -> void:
		var col: Color = Color("9be38a") if healer else LEVEL_COLOR[clampi(level, 1, 4) - 1]
		var fade := clampf(_life / 0.5, 0.0, 1.0)
		var s := (0.6 + 0.4 * _pop) * fade * SIZE
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
		draw_circle(Vector2(0, 2), 14.0, Color(0.05, 0.02, 0.15, 0.3))
		Sprites.draw(self, "turret_heal" if healer else "turret", Color(1, 1, 1, fade))
		# Luz del nivel y la pantalla / Level light and screen
		var blink := 0.6 + 0.4 * sin(_t * 6.0)
		draw_rect(Rect2(-7, -31, 14, 8), Color(col, 0.55 * blink * fade))
		for i in level if not healer else 0:
			draw_rect(Rect2(-7 + i * 4, -18, 2, 2), Color(col, fade))
		if healer:
			var r := 18.0 + fmod(_t * 20.0, 30.0)
			draw_arc(Vector2(0, -6), r, 0, TAU, 24, Color(col, 0.35 * (1.0 - (r - 18.0) / 30.0) * fade), 1.5)
		# Cuánto le queda / How long it has left
		draw_arc(Vector2(0, 6), 12.0, -PI / 2, -PI / 2 + TAU * clampf(_life / LIFE, 0.0, 1.0), 20, Color(col, 0.5 * fade), 1.5)
		draw_set_transform(Vector2.ZERO)
		for b: Array in _beams:
			var k := float(b[2]) / 0.1
			draw_line(b[0], b[1], Color(col, 0.9 * k), 3.0)
			draw_line(b[0], b[1], Color(1, 1, 1, 0.8 * k), 1.0)
