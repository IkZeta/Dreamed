class_name DruidArt
extends RefCounted
## Kroker convertido en el animal del collar de druida: oso, pantera o buitre, a su tamaño, en
## piezas (tools/make_sprites.py, druid_forms) que se animan aquí: andar, respirar, atacar, rugir,
## saltar y batir las alas. Todos llevan sus gafas y su mechón. Unidades del mundo, pies en (0, 0),
## mirando a +x (facing da la vuelta).
## Kroker turned into the druid collar's animal: bear, panther or vulture, at his size, in pieces
## (tools/make_sprites.py, druid_forms) animated here: walking, breathing, attacking, roaring,
## leaping and flapping. They all wear his glasses and his tuft. World units, feet at (0, 0),
## facing +x (facing flips it).

static var _ci: CanvasItem
static var _base: Transform2D
static var _mod := Color.WHITE

## Dónde flota la segunda arma encima de cada animal / Where the second weapon floats above each animal
const HELD_AT := {"bear": Vector2(-8, -126), "panther": Vector2(-12, -96), "vulture": Vector2(-24, -132)}
## Dónde van los anillos de carga del collar (en la grupa) / Where the collar's charge rings go (on the rump)
const RING_AT := {"bear": Vector2(-62, -96), "panther": Vector2(-62, -78), "vulture": Vector2(-58, -96)}


## opts: facing, walk (fase del paso), moving (0..1), attack (1→0), roar (1→0), pounce (1→0),
## flash (0..1), alpha, ghost (bool: buitre fantasma de la rapiña)
## opts: facing, walk (step phase), moving (0..1), attack (1→0), roar (1→0), pounce (1→0),
## flash (0..1), alpha, ghost (bool: the snatch's ghost vulture)
static func draw(ci: CanvasItem, at: Vector2, form: String, t: float, opts := {}) -> void:
	_ci = ci
	var facing: float = opts.get("facing", 1.0)
	var sc: float = opts.get("scale", 1.0)
	# Al darse la vuelta se estrecha un instante, como si girara / When turning round it narrows for an instant, as if rotating
	var turn: float = opts.get("turn", 0.0)
	var tw := 1.0 - 0.55 * sin(turn * PI)
	_base = Transform2D(0.0, Vector2(facing * sc * tw, sc), 0.0, at)
	_mod = Sprites.flash_color(float(opts.get("flash", 0.0)), float(opts.get("alpha", 1.0)))
	if opts.get("ghost", false):
		_mod = Color(0.75, 1.0, 0.95, 0.55 * float(opts.get("alpha", 1.0)))
	match form:
		"bear": _bear(t, opts)
		"panther": _panther(t, opts)
		_: _vulture(t, opts)
	_ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func _put(sprite: String, local: Transform2D) -> void:
	_ci.draw_set_transform_matrix(_base * local)
	Sprites.draw(_ci, sprite, _mod)


## Pieza que gira sobre su articulación en "joint" / A piece rotating on its joint at "joint"
static func _limb(sprite: String, joint: Vector2, rot: float, body: Transform2D) -> void:
	_put(sprite, body * Transform2D(rot, joint))


static func _shadow(c: Vector2, r: Vector2, a: float) -> void:
	_ci.draw_set_transform_matrix(_base)
	var pts := PackedVector2Array()
	for i in 20:
		var ang := TAU * i / 20.0
		pts.append(c + Vector2(cos(ang) * r.x, sin(ang) * r.y))
	_ci.draw_colored_polygon(pts, Color(0.05, 0.02, 0.15, 0.3 * a * _mod.a))


## Una pata en su fase del paso: se balancea y, al ir hacia delante, se levanta del suelo
## A leg at its step phase: it swings and, while moving forward, lifts off the ground
static func _step(sprite: String, joint: Vector2, phase: float, amp: float, lift: float, extra: float, body: Transform2D) -> void:
	var rot := sin(phase) * amp + extra
	var up := maxf(0.0, cos(phase)) * lift
	_put(sprite, body * Transform2D(rot, joint + Vector2(0, -up)))


# --- Oso: pesado; paso cruzado con las patas que se levantan, cuerpo que rueda de lado a lado,
# --- cabeza que cabecea a contratiempo; olfatea quieto; zarpazo y rugido de pie ---
# --- Bear: heavy; cross-gait with lifting paws, a body that rolls side to side, a head nodding
# --- off-beat; sniffs when still; swipe and a rearing roar ---

static func _bear(t: float, o: Dictionary) -> void:
	var w: float = o.get("walk", 0.0)
	var m: float = o.get("moving", 0.0)
	var atk: float = o.get("attack", 0.0)
	var roar: float = o.get("roar", 0.0)
	var swipe := sin((1.0 - atk) * PI) if atk > 0.0 else 0.0
	var rear := sin((1.0 - roar) * PI) if roar > 0.0 else 0.0
	_shadow(Vector2(-6, 0), Vector2(64 - 4.0 * m, 9), 1.0)
	var bob := -absf(sin(w)) * 4.0 * m + sin(t * 1.8) * 0.8 * (1.0 - m)
	var roll := sin(w) * 0.035 * m
	var breathe := 1.0 + sin(t * 1.8) * 0.012 * (1.0 - m)
	var body := Transform2D(-0.16 * rear - 0.04 * swipe, Vector2(-40, 0)) * Transform2D(roll, Vector2(1.0, breathe), 0.0, Vector2(40, bob))
	var hips := Transform2D(roll * 0.5, Vector2(0, bob * 0.6))
	var amp := 0.5 * m
	var lift := 6.0 * m
	_step("druidf_bear_leg_far", Vector2(-34, -46), w + PI, amp, lift, 0.0, hips)
	_step("druidf_bear_leg_far", Vector2(30, -46), w, amp, lift, -0.3 * rear, body)
	_step("druidf_bear_leg", Vector2(-44, -46), w, amp, lift, 0.0, hips)
	if swipe <= 0.0:
		_step("druidf_bear_leg", Vector2(20, -46), w + PI, amp, lift, -0.5 * rear, body)
	_put("druidf_bear_body", body)
	# Quieto, de vez en cuando levanta el hocico a olfatear / Standing still, now and then it lifts its snout to sniff
	var sniff := (1.0 - m) * maxf(0.0, sin(t * 0.9)) ** 6 * (0.18 + 0.04 * sin(t * 18.0))
	var head_rot := -0.4 * rear + sin(w * 2.0 + 0.8) * 0.05 * m - 0.1 * swipe - sniff + sin(t * 1.6) * 0.02
	var head := body * Transform2D(0.0, Vector2(0, sin(w * 2.0 + 0.8) * 1.5 * m))
	_limb("druidf_bear_head_roar" if rear > 0.25 else "druidf_bear_head", Vector2(44, -70), head_rot, head)
	if swipe > 0.0:
		_limb("druidf_bear_leg", Vector2(20, -46), -1.7 * swipe, body)


# --- Pantera: zancadas largas que doblan la espalda (se estira y se encoge), cola que sigue el
# --- movimiento con retraso, cabeza estable; quieta, mueve la punta de la cola ---
# --- Panther: long strides that flex the spine (it stretches and bunches), a tail following the
# --- motion with a lag, a steady head; standing still, it flicks the tip of its tail ---

static func _panther(t: float, o: Dictionary) -> void:
	var w: float = o.get("walk", 0.0)
	var m: float = o.get("moving", 0.0)
	var atk: float = o.get("attack", 0.0)
	var pounce: float = o.get("pounce", 0.0)
	var swipe := sin((1.0 - atk) * PI) if atk > 0.0 else 0.0
	var leap := sin((1.0 - pounce) * PI) if pounce > 0.0 else 0.0
	_shadow(Vector2(-4, 0), Vector2(58, 7), 1.0 - 0.4 * leap)
	var flex := sin(w) * 0.07 * m
	var bob := -absf(sin(w)) * 3.0 * m + sin(t * 2.2) * 0.6 * (1.0 - m) - 12.0 * leap
	var pitch := sin(w + 0.5) * 0.04 * m
	# La espalda se estira y se encoge con cada zancada / The spine stretches and bunches with each stride
	var body := Transform2D(pitch, Vector2(1.0 + flex + 0.18 * leap + 0.05 * swipe, 1.0 - flex * 0.6 - 0.08 * leap), 0.0, Vector2(4.0 * swipe, bob))
	var amp := 0.7 * m
	var lift := 5.0 * m
	var flick := (1.0 - m) * maxf(0.0, sin(t * 1.3)) ** 8 * 0.4
	var tail := sin(w - 1.4) * 0.3 * m + sin(t * 2.0) * 0.12 * (1.0 - m) - flick - 0.5 * leap
	_limb("druidf_panther_tail", Vector2(-60, -54), tail, body)
	_step("druidf_panther_hind_far", Vector2(-40, -42), w + PI * 0.9, amp, lift, 0.8 * leap, body)
	_step("druidf_panther_leg_far", Vector2(38, -38), w + 0.2, amp, lift, -0.9 * leap, body)
	_step("druidf_panther_hind", Vector2(-48, -42), w - PI * 0.1, amp, lift, 0.9 * leap, body)
	if swipe <= 0.0:
		_step("druidf_panther_leg", Vector2(30, -38), w + PI + 0.2, amp, lift, -1.0 * leap, body)
	_put("druidf_panther_body", body)
	# La cabeza no se mueve con el cuerpo: mira fija a la presa / The head doesn't move with the body: it stays locked on the prey
	var head_rot := -pitch * 1.4 + sin(t * 1.9) * 0.03 * (1.0 - m) - 0.12 * swipe + 0.1 * leap
	_limb("druidf_panther_head", Vector2(46, -62), head_rot, body)
	if swipe > 0.0:
		_limb("druidf_panther_leg", Vector2(30, -38), -1.5 * swipe, body)


# --- Buitre: aletea más rápido y se inclina hacia delante al moverse; quieto, planea a ratos con
# --- las alas abiertas y mira a los lados; picotea estirando el cuello ---
# --- Vulture: flaps faster and leans forward when moving; still, it glides now and then with
# --- open wings and looks around; pecks by stretching its neck ---

static func _vulture(t: float, o: Dictionary) -> void:
	var atk: float = o.get("attack", 0.0)
	var peck := sin((1.0 - atk) * PI) if atk > 0.0 else 0.0
	var m: float = o.get("moving", 0.0)
	# Planea un rato cada pocos segundos cuando está quieto / Glides for a while every few seconds when still
	var glide := (1.0 - m) * clampf(sin(t * 0.55) * 3.0 - 1.5, 0.0, 1.0)
	var freq := 6.0 + 4.0 * m
	var flap := sin(t * freq) * (1.0 - glide)
	_shadow(Vector2(-4, 0), Vector2(40, 6), 0.7)
	var bob := -flap * (4.0 + 2.0 * m) - 4.0 + sin(t * 1.1) * 2.0 * glide
	var lean := 0.16 * m + 0.12 * peck
	var body := Transform2D(lean, Vector2(0, -66)) * Transform2D(0.0, Vector2(0, 66 + bob))
	var wing := lerpf(-0.15 + flap * (0.55 + 0.15 * m), -0.35, glide)
	var squash := 0.8 + 0.2 * flap
	_put("druidf_vulture_wing_far", body * Transform2D(wing * 0.9, Vector2(1.0, squash + 0.05), 0.0, Vector2(2, -86)))
	_put("druidf_vulture_body", body)
	var look := sin(t * 0.8) * 0.12 * (1.0 - m)
	_limb("druidf_vulture_head", Vector2(34, -82), 0.45 * peck + look - lean * 0.6, Transform2D(0.0, Vector2(4.0 * peck, 0)) * body)
	_put("druidf_vulture_wing", body * Transform2D(wing, Vector2(1.0, squash), 0.0, Vector2(8, -80)))
