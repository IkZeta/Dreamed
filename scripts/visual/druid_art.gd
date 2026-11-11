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
	_base = Transform2D(0.0, Vector2(facing * sc, sc), 0.0, at)
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


# --- Oso: pesado, se balancea al andar; zarpazo con la pata delantera y rugido de pie ---
# --- Bear: heavy, sways as it walks; swipe with the front paw and a rearing roar ---

static func _bear(t: float, o: Dictionary) -> void:
	var w: float = o.get("walk", 0.0)
	var m: float = o.get("moving", 0.0)
	var atk: float = o.get("attack", 0.0)
	var roar: float = o.get("roar", 0.0)
	var swipe := sin((1.0 - atk) * PI) if atk > 0.0 else 0.0
	var rear := sin((1.0 - roar) * PI) if roar > 0.0 else 0.0
	_shadow(Vector2(-6, 0), Vector2(64, 9), 1.0)
	# Se levanta un poco sobre las patas traseras al rugir; respira y se balancea al andar
	# Rears up a little on its hind legs when roaring; breathes and sways when walking
	var bob := -absf(sin(w)) * 3.0 * m + sin(t * 1.8) * 0.8
	var body := Transform2D(-0.16 * rear - 0.04 * swipe, Vector2(-40, 0)) * Transform2D(0.0, Vector2(40, bob))
	var amp := 0.42 * m
	_limb("druidf_bear_leg_far", Vector2(-34, -46), sin(w + PI) * amp, Transform2D(0.0, Vector2(0, bob * 0.5)))
	_limb("druidf_bear_leg_far", Vector2(30, -46), sin(w) * amp - 0.3 * rear, body)
	_limb("druidf_bear_leg", Vector2(-44, -46), sin(w) * amp, Transform2D(0.0, Vector2(0, bob * 0.5)))
	if swipe <= 0.0:
		_limb("druidf_bear_leg", Vector2(20, -46), sin(w + PI) * amp - 0.5 * rear, body)
	_put("druidf_bear_body", body)
	var head_rot := -0.4 * rear + sin(t * 1.6) * 0.03 + sin(w * 2.0) * 0.03 * m - 0.1 * swipe
	_limb("druidf_bear_head_roar" if rear > 0.25 else "druidf_bear_head", Vector2(44, -70), head_rot, body)
	# El zarpazo, por delante del cuerpo / The swipe, in front of the body
	if swipe > 0.0:
		_limb("druidf_bear_leg", Vector2(20, -46), -1.7 * swipe, body)


# --- Pantera: ágil y baja; la cola ondea; zarpazo rápido y salto estirada ---
# --- Panther: lithe and low; the tail ripples; a quick swipe and a stretched-out leap ---

static func _panther(t: float, o: Dictionary) -> void:
	var w: float = o.get("walk", 0.0)
	var m: float = o.get("moving", 0.0)
	var atk: float = o.get("attack", 0.0)
	var pounce: float = o.get("pounce", 0.0)
	var swipe := sin((1.0 - atk) * PI) if atk > 0.0 else 0.0
	var leap := sin((1.0 - pounce) * PI) if pounce > 0.0 else 0.0
	_shadow(Vector2(-4, 0), Vector2(58, 7), 1.0 - 0.4 * leap)
	var bob := -absf(sin(w)) * 2.0 * m + sin(t * 2.2) * 0.6 - 16.0 * leap
	# Al saltar se estira hacia delante / When leaping it stretches forward
	var body := Transform2D(0.0, Vector2(1.0 + 0.18 * leap, 1.0 - 0.08 * leap), 0.0, Vector2(4.0 * swipe, bob))
	var amp := 0.55 * m
	var tail := sin(t * 2.4) * 0.18 + sin(w) * 0.12 * m - 0.5 * leap
	_limb("druidf_panther_tail", Vector2(-60, -54), tail, body)
	_limb("druidf_panther_hind_far", Vector2(-40, -42), sin(w + PI) * amp + 0.8 * leap, body)
	_limb("druidf_panther_leg_far", Vector2(38, -38), sin(w) * amp - 0.9 * leap, body)
	_limb("druidf_panther_hind", Vector2(-48, -42), sin(w) * amp + 0.9 * leap, body)
	if swipe <= 0.0:
		_limb("druidf_panther_leg", Vector2(30, -38), sin(w + PI) * amp - 1.0 * leap, body)
	_put("druidf_panther_body", body)
	_limb("druidf_panther_head", Vector2(46, -62), sin(t * 1.9) * 0.03 - 0.12 * swipe + 0.1 * leap, body)
	if swipe > 0.0:
		_limb("druidf_panther_leg", Vector2(30, -38), -1.5 * swipe, body)


# --- Buitre: vuela bajito, batiendo las alas; picotea estirando el cuello ---
# --- Vulture: flies low, flapping; pecks by stretching its neck ---

static func _vulture(t: float, o: Dictionary) -> void:
	var atk: float = o.get("attack", 0.0)
	var peck := sin((1.0 - atk) * PI) if atk > 0.0 else 0.0
	var m: float = o.get("moving", 0.0)
	var flap := sin(t * 7.0)
	_shadow(Vector2(-4, 0), Vector2(40, 6), 0.7)
	# Sube al bajar las alas / Rises as the wings beat down
	var bob := -flap * 4.0 - 4.0
	var body := Transform2D(0.08 * m + 0.1 * peck, Vector2(0, -66)) * Transform2D(0.0, Vector2(0, 66 + bob))
	var wing := -0.15 + flap * 0.55
	_put("druidf_vulture_wing_far", body * Transform2D(wing * 0.9, Vector2(1.0, 0.85 + 0.15 * flap), 0.0, Vector2(2, -86)))
	_put("druidf_vulture_body", body)
	_limb("druidf_vulture_head", Vector2(34, -82), 0.45 * peck + sin(t * 1.5) * 0.06, Transform2D(0.0, Vector2(4.0 * peck, 0)) * body)
	_put("druidf_vulture_wing", body * Transform2D(wing, Vector2(1.0, 0.8 + 0.2 * flap), 0.0, Vector2(8, -80)))
