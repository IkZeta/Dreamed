class_name MenuFall
extends Control
## El fondo del menú principal: Kroker cae dormido, despacio, a través de sus sueños. Pasan hacia
## arriba los trozos de cada acto que ya ha soñado (los juguetes de su cuarto, los muebles del
## salón, las taquillas del colegio, farolas y coches de la ciudad), en tres capas de profundidad,
## y el cielo cambia de color con cada acto. Al principio solo está su cuarto: el menú crece con la
## partida. De vez en cuando cruza una oveja de las que cuenta para dormirse.
## The main menu's background: Kroker falls asleep, slowly, through his dreams. Pieces of every
## act he has already dreamed drift upwards past him (his room's toys, the living-room furniture,
## the school lockers, the city's lamps and cars), in three depth layers, and the sky changes colour
## with each act. At first there's only his room: the menu grows with your progress. Now and then
## one of the sheep he counts to fall asleep floats across.

## Lienzo de referencia (el PixelView lo dibuja a la mitad) / Reference canvas (the PixelView draws it at half size)
const REF := Vector2(960, 540)
## Segundos que se pasa en cada acto antes de caer al siguiente / Seconds spent in each act before falling into the next
const ACT_TIME := 15.0
const BLEND := 3.5
## Cielo de cada acto: arriba, abajo y el color de las nebulosas / Each act's sky: top, bottom and nebula colour
const SKY := {
	1: [Color("0d1238"), Color("2c2a6e"), Color("8d7ff0")],
	2: [Color("1a0f2e"), Color("5a2a52"), Color("ff9a6a")],
	3: [Color("08202c"), Color("1f5560"), Color("7fdcc8")],
	4: [Color("170a30"), Color("6a1f6a"), Color("ff5fd2")],
	5: [Color("08080c"), Color("23232e"), Color("c8283a")],
}
## Lo que pasa flotando de cada acto / What drifts past from each act
const PROPS := {
	1: ["room_teddy", "room_book", "room_ball", "room_blocks", "room_bunny", "room_nightstand", "room_chair",
		"room_glasses", "room_toy_chest", "room_shelf", "room_bed"],
	2: ["lroom_sofa", "lroom_armchair", "lroom_lamp", "lroom_tv", "lroom_plant", "lroom_painting", "lroom_phone_table", "lroom_table"],
	3: ["#lockers", "#door", "#board", "hall_sign", "hall_bucket", "#lockers"],
	4: ["@lamp", "@car0", "@car1", "@bench", "@vending", "@bin", "@tree", "@planter"],
	5: ["city_noir_lamp", "city_noir_car0", "city_noir_bench", "city_noir_bin", "city_noir_vending"],
}
## Trozos del pasillo del colegio (en píxeles de hall_wall_0) / Pieces of the school corridor (in hall_wall_0 pixels)
const HALL := {"#lockers": Rect2(93, 22, 80, 88), "#door": Rect2(271, 10, 59, 100), "#board": Rect2(354, 26, 105, 55)}
const CITY_STYLES := ["synthwave", "steampunk", "cheese", "aero", "solarpunk", "dieselpunk", "brutalist"]

## -1..1: hacia dónde está el ratón / -1..1: where the mouse is
var parallax := Vector2.ZERO
## 0..1: al empezar, Kroker se hunde en el sueño y todo pasa a toda velocidad
## 0..1: on starting, Kroker sinks into the dream and everything rushes past
var dive := 0.0
## Pijama con el que sueña Kroker / The pajama Kroker dreams in
var outfit := "bat"
var shades := false
## Se emite al cambiar de acto (para el rótulo del menú) / Emitted when the act changes (for the menu's caption)
signal act_changed(act: int)

var _t := 0.0
var _acts: Array[int] = [1]
var _act_i := 0
var _act_t := 0.0
var _stars: Array[Dictionary] = []
var _props: Array[Dictionary] = []
var _prop_cd := 0.0
var _sheep: Array[Dictionary] = []
var _sheep_cd := 6.0
var _zs: Array[Dictionary] = []
var _z_cd := 1.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	# Los actos que ya ha soñado (el sueño 20 cuenta como uno más, en negro) / The acts already dreamed (dream 20 counts as one more, in noir)
	var best := maxi(1, int(Progress.stats.get("best_depth", 1)))
	_acts.clear()
	for a in range(1, GameState.act_of(best) + 1):
		_acts.append(a)
	if best >= 20:
		_acts.append(5)


func current_act() -> int:
	return _acts[_act_i]


func _s() -> float:
	return minf(size.x / REF.x, size.y / REF.y) if size.x > 0.0 else 1.0


func _new_star(anywhere: bool) -> Dictionary:
	var z := randf_range(0.15, 1.0)
	return {"p": Vector2(randf() * maxf(size.x, 1.0), (randf() if anywhere else 1.02 + randf() * 0.1) * maxf(size.y, 1.0)),
		"z": z, "ph": randf() * TAU, "big": randf() < 0.08}


## Una pieza del acto actual entra por abajo. "k" (0..1) la coloca ya a media pantalla al principio.
## A piece of the current act comes in from below. "k" (0..1) places it mid-screen at the start.
func _spawn_prop(k := -1.0) -> void:
	var act := current_act()
	var pool: Array = PROPS[act]
	var name: String = pool[randi() % pool.size()]
	if name.begins_with("@"):
		name = "city_%s_%s" % [CITY_STYLES[randi() % CITY_STYLES.size()], name.substr(1)]
	# Capa: lejos (pequeña y apagada), en medio, o cerca (grande y rápida, por los lados)
	# Layer: far (small and dim), middle, or near (big and fast, along the sides)
	var roll := randf()
	var z := randf_range(0.25, 0.45) if roll < 0.5 else (randf_range(0.6, 0.8) if roll < 0.88 else randf_range(1.1, 1.35))
	var w := maxf(size.x, 1.0)
	# Nunca por el centro, donde cae Kroker / Never down the middle, where Kroker falls
	var x := w * 0.5 + (-1.0 if randf() < 0.5 else 1.0) * w * randf_range(0.14, 0.5)
	if z > 0.55:
		# Las de cerca no tapan a Kroker ni el panel: van por los lados / Close ones don't cover Kroker or the panel: they go along the sides
		var side := -1.0 if randf() < 0.5 else 1.0
		x = w * 0.5 + side * w * randf_range(0.3 if z < 1.0 else 0.38, 0.48)
	var y := maxf(size.y, 1.0) * (1.15 if k < 0.0 else lerpf(1.1, -0.1, k))
	_props.append({"n": name, "act": act, "p": Vector2(x, y), "z": z, "rot": randf_range(-0.6, 0.6),
		"spin": randf_range(-0.25, 0.25), "sway": randf() * TAU})


var _seeded := false


func _process(delta: float) -> void:
	# Hasta que no tiene tamaño no se puede repartir nada por la pantalla / Nothing can be spread over the screen until it has a size
	if size.x <= 0.0:
		return
	if not _seeded:
		_seeded = true
		for i in 140:
			_stars.append(_new_star(true))
		# Ya hay cosas flotando al abrir el menú / There are already things drifting when the menu opens
		for i in 14:
			_spawn_prop(randf())
	_t += delta
	var s := _s()
	var rush := 1.0 + dive * dive * 14.0
	# Cambio de acto / Act change
	if _acts.size() > 1:
		_act_t += delta
		if _act_t > ACT_TIME:
			_act_t = 0.0
			_act_i = (_act_i + 1) % _acts.size()
			act_changed.emit(current_act())
	# Estrellas que suben (se cae hacia abajo) / Stars rising (we're falling down)
	for st: Dictionary in _stars:
		var p: Vector2 = st["p"]
		p.y -= (20.0 + 150.0 * float(st["z"])) * s * rush * delta
		if p.y < -20.0:
			st.merge(_new_star(false), true)
		else:
			st["p"] = p
	# Piezas de los sueños / Dream pieces
	_prop_cd -= delta * (1.0 + dive * 4.0)
	if _prop_cd <= 0.0:
		_prop_cd = randf_range(0.55, 1.0)
		_spawn_prop()
	for pr: Dictionary in _props:
		var z: float = pr["z"]
		var p: Vector2 = pr["p"]
		p.y -= (14.0 + 62.0 * z) * s * rush * delta
		p.x += sin(_t * 0.4 + float(pr["sway"])) * 6.0 * z * s * delta
		pr["p"] = p
		pr["rot"] = float(pr["rot"]) + float(pr["spin"]) * delta
	_props = _props.filter(func(pr: Dictionary) -> bool: return Vector2(pr["p"]).y > -260.0 * s)
	# Ovejas que cruzan de lado, saltando una valla invisible / Sheep crossing sideways, leaping an invisible fence
	_sheep_cd -= delta
	if _sheep_cd <= 0.0 and dive <= 0.0:
		_sheep_cd = randf_range(9.0, 15.0)
		var dir := 1.0 if randf() < 0.5 else -1.0
		_sheep.append({"x": -60.0 if dir > 0.0 else size.x + 60.0, "y": size.y * randf_range(0.18, 0.62), "dir": dir, "ph": 0.0})
	for sh: Dictionary in _sheep:
		sh["x"] = float(sh["x"]) + float(sh["dir"]) * 46.0 * s * delta
		sh["y"] = float(sh["y"]) - 10.0 * s * rush * delta
		sh["ph"] = float(sh["ph"]) + delta
	_sheep = _sheep.filter(func(sh: Dictionary) -> bool: return float(sh["x"]) > -100.0 and float(sh["x"]) < size.x + 100.0)
	# Zetas que se le escapan a Kroker / Z's escaping from Kroker
	_z_cd -= delta
	if _z_cd <= 0.0:
		_z_cd = 1.4
		_zs.append({"t": 0.0, "big": _zs.size() % 2 == 0})
	for zz: Dictionary in _zs:
		zz["t"] = float(zz["t"]) + delta
	_zs = _zs.filter(func(zz: Dictionary) -> bool: return float(zz["t"]) < 3.0)
	queue_redraw()


## Colores del cielo, mezclando con el acto siguiente al final de cada tramo
## Sky colours, blending into the next act at the end of each stretch
func _sky() -> Array:
	var a: Array = SKY[current_act()]
	if _acts.size() < 2 or _act_t < ACT_TIME - BLEND:
		return a
	var b: Array = SKY[_acts[(_act_i + 1) % _acts.size()]]
	var k := smoothstep(ACT_TIME - BLEND, ACT_TIME, _act_t)
	return [Color(a[0]).lerp(b[0], k), Color(a[1]).lerp(b[1], k), Color(a[2]).lerp(b[2], k)]


func _draw() -> void:
	var s := _s()
	var sky := _sky()
	var top: Color = sky[0]
	var bot: Color = sky[1]
	var neb: Color = sky[2]
	# Cielo: más claro abajo, hacia donde cae / Sky: lighter below, where he's falling to
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
		PackedColorArray([top, top, bot, bot]))
	var soft := DreamBackground.soft_texture()
	# Nebulosas que suben despacio / Nebulae drifting slowly up
	for i in 4:
		var k := fposmod(_t * 0.012 * (1.0 + i * 0.3) + i * 0.27, 1.0)
		var c := Vector2(size.x * (0.15 + 0.23 * i) + sin(_t * 0.1 + i) * 30.0 * s, size.y * (1.25 - k * 1.6))
		var r := Vector2(260, 170) * s * (1.0 + 0.3 * sin(i * 2.1))
		draw_texture_rect(soft, Rect2(c - r, r * 2.0), false, Color(neb, 0.13))
	# Luz al fondo del pozo / Light at the bottom of the well
	draw_texture_rect(soft, Rect2(Vector2(size.x * 0.5, size.y * 1.05) - Vector2(420, 220) * s, Vector2(840, 440) * s), false, Color(neb.lerp(Color.WHITE, 0.4), 0.22 + dive * 0.6))
	_draw_stars(s)
	_draw_props(s, top, false)
	_draw_sheep(s)
	_draw_kroker(s)
	_draw_props(s, top, true)
	# Al zambullirse, un fogonazo suave / When diving in, a soft flash
	if dive > 0.5:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.97, 0.9, (dive - 0.5) * 1.6))


func _draw_stars(s: float) -> void:
	var rush := 1.0 + dive * dive * 14.0
	for st: Dictionary in _stars:
		var z: float = st["z"]
		var p: Vector2 = st["p"] - parallax * Vector2(10.0, 6.0) * z * s
		var tw := 0.55 + 0.45 * sin(_t * (1.5 + z * 2.0) + float(st["ph"]))
		var col := Color(UITheme.BONE, (0.25 + 0.6 * z) * tw)
		# Estela hacia abajo: lo que se queda atrás al caer / A trail downwards: what's left behind as he falls
		var trail := (2.0 + 9.0 * z) * s * rush
		draw_line(p, p + Vector2(0, trail), Color(col, col.a * 0.45), maxf(1.0, z * 1.5 * s))
		if st["big"]:
			DreamBackground.draw_star(self, p, 2.5 * s * (0.8 + 0.4 * tw), Color(UITheme.GOLD, 0.9 * tw))
		else:
			draw_rect(Rect2(p - Vector2(0.5, 0.5) * s, Vector2(1, 1) * s * (1.0 + z)), col)


## Las piezas, de lejos a cerca; las de cerca ("front") van delante de Kroker
## The pieces, far to near; close ones ("front") go in front of Kroker
func _draw_props(s: float, sky_top: Color, front: bool) -> void:
	var order := _props.filter(func(pr: Dictionary) -> bool: return (float(pr["z"]) > 1.0) == front)
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["z"]) < float(b["z"]))
	var soft := DreamBackground.soft_texture()
	for pr: Dictionary in order:
		var z: float = pr["z"]
		var name: String = pr["n"]
		var p: Vector2 = Vector2(pr["p"]) - parallax * Vector2(18.0, 10.0) * z * s
		# Tamaño: lo más largo de la pieza mide esto en el lienzo / Size: the piece's longest side measures this on the canvas
		var target := (70.0 * z + 10.0) * s
		# Las de lejos se funden con el cielo / Far ones melt into the sky
		var mod := sky_top.lerp(Color.WHITE, clampf(0.25 + z * 0.85, 0.0, 1.0))
		var glow: Color = SKY[int(pr["act"])][2]
		draw_texture_rect(soft, Rect2(p - Vector2(target, target) * 0.75, Vector2(target, target) * 1.5), false, Color(glow, 0.1 * minf(z, 1.0)))
		if HALL.has(name):
			var src: Rect2 = HALL[name]
			var k := target / maxf(src.size.x, src.size.y)
			draw_set_transform(p, float(pr["rot"]), Vector2(k, k))
			draw_texture_rect_region(Sprites.tex("hall_wall_0"), Rect2(-src.size * 0.5, src.size), src, mod)
		else:
			var r: Rect2 = SpriteRects.RECTS[name]
			var k := target / maxf(r.size.x, r.size.y)
			draw_set_transform(p, float(pr["rot"]), Vector2(k, k))
			Sprites.draw(self, name, mod, -r.get_center())
		draw_set_transform(Vector2.ZERO)


## Kroker, dormido, cae dando vueltas muy despacio con los brazos en alto y el pijama al viento
## Kroker, asleep, falls tumbling very slowly with his arms up and his pajama in the wind
func _draw_kroker(s: float) -> void:
	var soft := DreamBackground.soft_texture()
	var c := Vector2(size.x * 0.5, size.y * 0.385) + Vector2(sin(_t * 0.5) * 14.0, sin(_t * 0.8) * 8.0) * s - parallax * Vector2(8.0, 5.0) * s
	c.y += dive * dive * size.y * 0.7
	var ks := 0.46 * s * (1.0 - dive * 0.5)
	# Halo de luz alrededor para que se despegue del fondo / A halo around him so he stands out from the background
	draw_texture_rect(soft, Rect2(c - Vector2(110, 120) * s, Vector2(220, 240) * s), false, Color(UITheme.GOLD, 0.16))
	var rot := sin(_t * 0.33) * 0.42 + sin(_t * 0.9) * 0.05
	# Líneas de viento que suben a su alrededor / Wind lines rising around him
	for i in 7:
		var k := fposmod(_t * 0.9 + i * 0.37, 1.0)
		var wx := (-1.0 if i % 2 == 0 else 1.0) * (30.0 + 16.0 * sin(i * 2.7)) * s
		var wy := lerpf(70.0, -110.0, k) * s
		draw_line(c + Vector2(wx, wy), c + Vector2(wx, wy + 22.0 * s), Color(UITheme.BONE, 0.35 * sin(k * PI)), maxf(1.0, s))
	# El centro del dibujo de Kroker (200 x 288) queda en "c" / The centre of Kroker's drawing (200 x 288) sits on "c"
	var xf := Transform2D(rot, Vector2(ks, ks), 0.0, c) * Transform2D(0.0, Vector2(-100, -170))
	KrokerArt.draw(self, xf, outfit, _t, {"stretch": 0.85 + sin(_t * 0.7) * 0.15, "armed": false, "asleep": true,
		"shadow": false, "shades": shades, "hires": true})
	draw_set_transform(Vector2.ZERO)
	# Zetas / Z's
	var font := UITheme.font("display")
	var head := xf * Vector2(112, 118)
	for zz: Dictionary in _zs:
		var k := float(zz["t"]) / 3.0
		var p := head + Vector2(22.0 + k * 40.0 + sin(k * 7.0) * 6.0, -k * 70.0) * s
		var fs := int((10.0 + k * 10.0) * s * (1.3 if zz["big"] else 1.0))
		var a := sin(k * PI) * (1.0 - dive)
		UITheme.ink_text(self, font, p.round(), "z", fs, Color(UITheme.GOLD, a), 1.0, Color(UITheme.INK, 0.5))


## Ovejas de las que se cuentan: dan un salto lento en el aire / Counting sheep: they take a slow leap in the air
func _draw_sheep(s: float) -> void:
	for sh: Dictionary in _sheep:
		var ph: float = sh["ph"]
		var dir: float = sh["dir"]
		var hop := -absf(sin(ph * 1.4)) * 18.0 * s
		var p := Vector2(float(sh["x"]), float(sh["y"]) + hop)
		var k := 0.32 * s
		var f := Vector2(dir * k, k)
		var tuck := absf(sin(ph * 1.4))
		for i in 4:
			var lx: float = [-22.0, -12.0, 12.0, 22.0][i]
			draw_set_transform(p + Vector2(lx * dir, -18.0) * k, (0.7 if i < 2 else -0.7) * tuck * dir, f)
			Sprites.draw(self, "sheep_leg")
		draw_set_transform(p, sin(ph * 1.4) * 0.08 * dir, f)
		Sprites.draw(self, "sheep_body")
		draw_set_transform(p + Vector2(30.0 * dir, -36.0) * k, sin(ph) * 0.1, f)
		Sprites.draw(self, "sheep_head")
		draw_set_transform(Vector2.ZERO)
