class_name Boss
extends Enemy
## Jefe del Acto 1: la habitación cobra vida. A la cama, el escritorio y la estantería les
## salen brazos mecánicos y atacan por turnos, en orden aleatorio. Solo se le puede dar
## al mueble que está despierto. La vida es compartida.
##  - Cama: aplastones con daño en área (avisa con un círculo).
##  - Estantería: lanza libros.
##  - Escritorio: se estira para alcanzarte cuerpo a cuerpo (avisa con una línea).
## Act 1 boss: the bedroom comes alive. The bed, the desk and the bookshelf sprout
## mechanical arms and attack in turns, in random order. Only the awake piece can be hit.
## Health is shared.

signal defeated

const TURN_TIME := 8.0
const WAKE_TIME := 1.4
const METAL := Color("8f8fb8")
const METAL_DARK := Color("4f4f78")
const EYE := Color("ff8fa8")

## Datos de cada mueble en el lienzo de la habitación / Each piece's data on the room canvas
const PARTS := {
	"bed": {"anchor": Vector2(250, 505), "rect": Rect2(150, 236, 200, 262), "name": "BOSS_PART_BED"},
	"desk": {"anchor": Vector2(1620, 345), "rect": Rect2(1470, 226, 300, 104), "name": "BOSS_PART_DESK"},
	"shelf": {"anchor": Vector2(1321, 300), "rect": Rect2(1236, 70, 170, 226), "name": "BOSS_PART_SHELF"},
}

var active := ""
var _turn_t := 0.0
var _wake_t := 0.0
var _attack_t := 0.0
var _last := ""
var _dead_anim := -1.0
## Ataque en curso / Current attack: {kind, t, dur, target, from}
var _atk := {}


func _init() -> void:
	max_hp = 520.0
	hp = max_hp
	contact_damage = 0.0
	radius = 60.0
	speed = 0.0
	mass = 1000.0
	aim_height = 40.0


func _ready() -> void:
	super._ready()
	state = State.ALIVE
	_fade = 1.0
	_next_part()


func is_dangerous() -> bool:
	return false


func is_targetable() -> bool:
	return state == State.ALIVE and _wake_t <= 0.0 and _dead_anim < 0.0


func aim_point() -> Vector2:
	var r: Rect2 = Bedroom.rect_world(PARTS[active]["rect"])
	return Vector2(r.get_center().x, r.end.y - 30.0)


## No se mueve: siempre está delante del mueble despierto / Doesn't move: always in front of the awake piece
func _move(_delta: float) -> void:
	position = Bedroom.to_world(PARTS[active]["anchor"])
	knock = Vector2.ZERO


func start_bounce(_damage: float, _chain: int, _ignore: Array = []) -> void:
	pass


func glitch(stun := 0.0, slow := 0.0, vulnerable := 0.0, mult := 1.5) -> void:
	super.glitch(minf(stun, 0.4), slow, vulnerable, mult)


func hit(amount: float, _impulse := Vector2.ZERO) -> void:
	if not is_targetable():
		return
	if vuln_t > 0.0:
		amount *= vuln_mult
	hp -= amount
	_flash = 1.0
	Audio.play("hit", -12.0, 0.1)
	run.fx.text(aim_point() + Vector2(randf_range(-30, 30), -30), str(roundi(amount)), GLITCH_A if vuln_t > 0.0 else UITheme.BONE)
	run.hud.set_boss_hp(hp, max_hp)
	if hp <= 0.0:
		_start_death()


func die(counted: bool) -> void:
	if counted:
		_start_death()


func _start_death() -> void:
	if _dead_anim >= 0.0:
		return
	_dead_anim = 0.0
	_atk = {}
	Audio.play("boss_wake", -2.0)
	Audio.play("crack", 0.0)
	run.shake(16.0)


func _physics_process(delta: float) -> void:
	if _dead_anim >= 0.0:
		_dead_anim += delta
		_t += delta
		if fmod(_dead_anim, 0.4) < delta:
			var key: String = PARTS.keys()[int(_dead_anim / 0.4) % 3]
			run.fx.dissipate(Bedroom.rect_world(PARTS[key]["rect"]).get_center(), EYE)
			run.shake(6.0)
		if _dead_anim > 2.4:
			state = State.DYING
			defeated.emit()
			queue_free()
		queue_redraw()
		return
	super._physics_process(delta)


func _act(delta: float) -> void:
	if not run.running:
		return
	if _wake_t > 0.0:
		_wake_t -= delta
		if _wake_t <= 0.0:
			_attack_t = 0.4
		return
	_turn_t -= delta
	if _turn_t <= 0.0 and _atk.is_empty():
		_next_part()
		return
	if not _atk.is_empty():
		_update_attack(delta)
		return
	_attack_t -= delta * (0.5 if slow_t > 0.0 else 1.0)
	if _attack_t <= 0.0:
		_begin_attack()


func _next_part() -> void:
	var options: Array = PARTS.keys().filter(func(k: String) -> bool: return k != _last)
	active = options[randi() % options.size()]
	_last = active
	_turn_t = TURN_TIME
	_wake_t = WAKE_TIME
	_atk = {}
	position = Bedroom.to_world(PARTS[active]["anchor"])
	Audio.play("boss_wake", -6.0, 0.05)
	run.shake(5.0)
	run.hud.set_boss_part(PARTS[active]["name"])


func _begin_attack() -> void:
	var p: Vector2 = run.player.global_position
	match active:
		"bed":
			_atk = {"kind": "slam", "t": 0.0, "dur": 1.1, "target": p}
			_attack_t = 1.4
		"shelf":
			_atk = {"kind": "books", "t": 0.0, "dur": 0.45, "target": p, "n": 3 if randf() < 0.35 else 1}
			_attack_t = 1.0
		"desk":
			_atk = {"kind": "reach", "t": 0.0, "dur": 0.9, "target": p, "from": aim_point()}
			_attack_t = 1.3


func _update_attack(delta: float) -> void:
	_atk["t"] = float(_atk["t"]) + delta
	var t := float(_atk["t"])
	var dur := float(_atk["dur"])
	if t < dur:
		return
	var target: Vector2 = _atk["target"]
	var player: Player = run.player
	match _atk["kind"]:
		"slam":
			Audio.play("stomp", -2.0, 0.05)
			run.shake(12.0)
			run.fx.ring(target, 120.0, EYE, 0.5, 1.3)
			run.fx.dissipate(target, Color("cfc6e8"))
			if player.global_position.distance_to(target) < 120.0:
				player.take_damage(5.0)
		"books":
			var n := int(_atk.get("n", 1))
			for i in n:
				var shot := EnemyShot.new()
				shot.run = run
				shot.kind = "book"
				shot.radius = 16.0
				shot.damage = 3.0
				shot.position = aim_point() + Vector2(0, -80)
				var dir := (player.global_position + Vector2(0, -70) - shot.position).normalized()
				shot.velocity = dir.rotated((i - (n - 1) / 2.0) * 0.28) * 460.0
				run.add_child(shot)
			Audio.play("throw", -4.0, 0.1)
		"reach":
			Audio.play("kick", -2.0, 0.05)
			run.shake(8.0)
			var from: Vector2 = _atk["from"]
			var closest := Geometry2D.get_closest_point_to_segment(player.global_position + Vector2(0, -40), from, target)
			if closest.distance_to(player.global_position + Vector2(0, -40)) < 46.0:
				player.take_damage(5.0)
			_atk = {"kind": "retract", "t": 0.0, "dur": 0.35, "target": target, "from": from}
			return
	_atk = {}


# --- Dibujo / Drawing -----------------------------------------------------------

func _draw() -> void:
	draw_set_transform(Vector2.ZERO)
	if _dead_anim >= 0.0:
		for key: String in PARTS:
			_draw_eyes(key, maxf(0.0, 1.0 - _dead_anim / 2.4), true)
		return
	for key: String in PARTS:
		var awake := key == active
		var wake_k := 1.0 - clampf(_wake_t / WAKE_TIME, 0.0, 1.0) if awake else 0.0
		_draw_eyes(key, wake_k if awake else 0.25, false)
		if awake:
			_draw_glow(key, wake_k)
			_draw_arms(key, wake_k)
	_draw_attack()


## Ojos que se abren en el mueble / Eyes opening on the furniture
func _draw_eyes(key: String, open: float, dying: bool) -> void:
	var r: Rect2 = Bedroom.rect_world(PARTS[key]["rect"])
	var c := to_local(Vector2(r.get_center().x, r.position.y + r.size.y * (0.62 if key == "bed" else 0.45)))
	var shake := Vector2(randf_range(-2, 2), 0) * (1.0 if dying else 0.0)
	for side in [-1.0, 1.0]:
		var p := c + Vector2(side * 22.0, 0) + shake
		draw_colored_polygon(_ellipse(p, Vector2(11, 7 * open + 1)), Color(0.05, 0.02, 0.12, 0.9))
		if open > 0.3:
			draw_circle(p + Vector2(0, 1), 4.0 * open, Color(EYE, 0.9))
			draw_circle(p, 12.0, Color(EYE, 0.12 * open))


func _draw_glow(key: String, k: float) -> void:
	var r: Rect2 = Bedroom.rect_world(PARTS[key]["rect"])
	var local := Rect2(to_local(r.position), r.size)
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	draw_rect(local.grow(6), Color(EYE, (0.25 + 0.25 * pulse) * k), false, 3.0)
	if _flash > 0.0:
		draw_rect(local, Color(1, 1, 1, 0.25 * _flash))


## Brazos mecánicos que salen de los lados del mueble / Mechanical arms coming out of the piece's sides
func _draw_arms(key: String, k: float) -> void:
	var r: Rect2 = Bedroom.rect_world(PARTS[key]["rect"])
	for side in [-1.0, 1.0]:
		var base := Vector2(r.position.x if side < 0 else r.end.x, r.position.y + r.size.y * 0.5)
		var sway := sin(_t * 3.0 + side) * 10.0
		var elbow := base + Vector2(side * 46.0 * k, -30.0 * k + sway)
		var hand := elbow + Vector2(side * 30.0 * k, 34.0 * k - sway * 0.5)
		if key == active and not _atk.is_empty() and side > 0:
			hand = _attack_hand(hand)
		_segment(to_local(base), to_local(elbow), 9.0)
		_segment(to_local(elbow), to_local(hand), 7.0)
		draw_circle(to_local(elbow), 7.0, METAL_DARK)
		_claw(to_local(hand), (hand - elbow).angle())


func _attack_hand(rest: Vector2) -> Vector2:
	var t := float(_atk["t"]) / float(_atk["dur"])
	var target: Vector2 = _atk["target"]
	match _atk["kind"]:
		"slam":
			# Sube el puño y lo deja caer / Raises the fist then drops it
			var up := target + Vector2(0, -220)
			return rest.lerp(up, minf(1.0, t * 1.6)) if t < 0.8 else up.lerp(target, (t - 0.8) / 0.2)
		"books":
			return rest + Vector2(0, -40 * sin(t * PI))
		"reach":
			return rest.lerp(rest + (target - rest) * 0.15, t)
		"retract":
			return target.lerp(rest, t)
	return rest


func _draw_attack() -> void:
	if _atk.is_empty():
		return
	var t := float(_atk["t"]) / float(_atk["dur"])
	var target: Vector2 = _atk["target"]
	match _atk["kind"]:
		"slam":
			# Aviso: círculo que se cierra donde va a caer / Warning: a closing circle where it will land
			var lt := to_local(target)
			draw_colored_polygon(_ellipse(lt, Vector2(120, 52)), Color(EYE, 0.10 + 0.15 * t))
			draw_arc(lt, 120.0 * (1.0 - t) + 10.0, 0, TAU, 40, Color(EYE, 0.8), 2.0, true)
			draw_set_transform(lt, 0.0, Vector2(1.0, 0.43))
			draw_arc(Vector2.ZERO, 120.0, 0, TAU, 48, Color(EYE, 0.6), 2.0, true)
			draw_set_transform(Vector2.ZERO)
		"reach", "retract":
			var from: Vector2 = _atk["from"]
			var reach_k := t if _atk["kind"] == "reach" else 1.0 - t
			if _atk["kind"] == "reach":
				# Aviso: línea punteada hacia donde va a golpear / Warning: dotted line to where it will strike
				var a := to_local(from)
				var b := to_local(target)
				var n := 14
				for i in n:
					if i % 2 == 0:
						draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), Color(EYE, 0.4 + 0.5 * t), 3.0)
			if _atk["kind"] == "retract" or t > 0.85:
				# El escritorio se estira: cajones encadenados / The desk stretches: chained drawers
				var k := 1.0 if _atk["kind"] == "reach" else reach_k
				var tip := from.lerp(target, k)
				var segs := 6
				for i in segs:
					var p := to_local(from.lerp(tip, float(i) / segs))
					draw_rect(Rect2(p - Vector2(18, 12), Vector2(36, 24)), Color("8a7fc4"))
					draw_rect(Rect2(p - Vector2(18, 12), Vector2(36, 24)), Color("4a4592"), false, 2.0)
				_claw(to_local(tip), (tip - from).angle())


func _segment(a: Vector2, b: Vector2, w: float) -> void:
	draw_line(a, b, METAL_DARK, w + 3.0, true)
	draw_line(a, b, METAL, w, true)
	draw_line(a, b, Color(1, 1, 1, 0.25), 1.5, true)


func _claw(p: Vector2, ang: float) -> void:
	draw_circle(p, 9.0, METAL_DARK)
	for off in [-0.6, 0.0, 0.6]:
		var tip := p + Vector2.from_angle(ang + off) * 16.0
		draw_line(p, tip, METAL, 4.0, true)


func _ellipse(c: Vector2, r: Vector2, n := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts
