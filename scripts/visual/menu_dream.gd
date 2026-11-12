class_name MenuDream
extends Control
## El sueño del menú principal: la cama de Kroker vuela por el cielo de noche, como en los tebeos
## de antes, con Kroker dormido dentro, una estela de polvo de estrellas y las «zetas» saliendo de
## su cabeza. Alrededor orbitan los personajes que ya ha conocido: el menú crece con la partida.
## The main menu's dream: Kroker's bed flies through the night sky, like in old comics, with
## Kroker asleep in it, a trail of stardust and the "z"s coming out of his head. The characters
## he has already met orbit around it: the menu grows along with your progress.

## Centro de la cama en el lienzo de la habitación (Bedroom.BED) / Bed centre on the room canvas
const BED := Rect2(150, 236, 200, 262)
const AURA := {
	"svinho": Color("9be38a"), "stolk": Color("ff8f9e"), "silly": Color("5ff2ff"), "doc": Color("ffe3a3"),
	"ad": Color("ffb04a"), "pinche": Color("ff9a3a"), "magnus": Color("4fd39a"), "superk": Color("b48cff"),
	"lilkey": Color("ff6a8a"), "lynx": Color("e0303a"), "luna": Color("c9d4ff"), "charo": Color("e8a6d8"),
}
## Orden en la órbita (el de la historia) / Order in the orbit (story order)
const CREW := ["svinho", "stolk", "silly", "doc", "pinche", "charo", "ad", "magnus", "superk", "lilkey", "lynx", "luna"]

## -1..1: hacia dónde está el ratón, para el paralaje / -1..1: where the mouse is, for parallax
var parallax := Vector2.ZERO
## 0..1: al pulsar Jugar, la cama se acerca y Kroker «cae» dentro del sueño
## 0..1: on pressing Play, the bed comes closer and Kroker "falls" into the dream
var dive := 0.0
var _t := 0.0
var _crew: Array[String] = []
var _motes: Array[Dictionary] = []
var _zs: Array[Dictionary] = []
var _z_cd := 0.6
var _mote_cd := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	for who: String in CREW:
		if Progress.met(who):
			_crew.append(who)


## Cuántos personajes orbitan / How many characters are orbiting
func crew_size() -> int:
	return _crew.size()


func _process(delta: float) -> void:
	_t += delta
	var s := _scale()
	var c := _center()
	# Estela de polvo de estrellas: sale por debajo de la cama y se queda atrás
	# Stardust trail: comes out from under the bed and drifts behind
	_mote_cd -= delta
	if _mote_cd <= 0.0:
		_mote_cd = 0.07
		_motes.append({"p": c + Vector2(randf_range(-60.0, 70.0), randf_range(40.0, 90.0)) * s,
			"v": Vector2(randf_range(-55.0, -25.0), randf_range(8.0, 30.0)) * s, "life": 0.0,
			"max": randf_range(2.0, 3.5), "r": randf_range(0.8, 2.0) * s, "c": [UITheme.GOLD, UITheme.BONE, UITheme.MIST, UITheme.ROSE][randi() % 4]})
	for m: Dictionary in _motes:
		m["life"] = float(m["life"]) + delta
		m["p"] = Vector2(m["p"]) + Vector2(m["v"]) * delta
	_motes = _motes.filter(func(m: Dictionary) -> bool: return float(m["life"]) < float(m["max"]))
	# Zetas que suben desde la cabeza de Kroker / Z's rising from Kroker's head
	_z_cd -= delta
	if _z_cd <= 0.0:
		_z_cd = 1.5
		_zs.append({"t": 0.0, "big": _zs.size() % 2 == 0})
	for z: Dictionary in _zs:
		z["t"] = float(z["t"]) + delta
	_zs = _zs.filter(func(z: Dictionary) -> bool: return float(z["t"]) < 3.2)
	queue_redraw()


## Escala respecto a un lienzo de 960 x 540 / Scale relative to a 960 x 540 canvas
func _scale() -> float:
	return minf(size.y / 540.0, size.x / 960.0)


func _center() -> Vector2:
	var s := _scale()
	return Vector2(size.x * 0.665, size.y * 0.54) + parallax * Vector2(16.0, 9.0) * s \
		+ Vector2(cos(_t * 0.45) * 6.0, sin(_t * 0.9) * 7.0) * s


func _draw() -> void:
	var s := _scale()
	var c := _center()
	var zoom := 1.0 + dive * dive * 2.2
	var fade := 1.0 - dive
	# Halo de luz de luna debajo, como si la cama flotara sobre una nube
	# A moonlight halo underneath, as if the bed floated on a cloud
	var soft := DreamBackground.soft_texture()
	draw_texture_rect(soft, Rect2(c + Vector2(-210, -60) * s * zoom, Vector2(420, 300) * s * zoom), false, Color(UITheme.MIST, 0.16))
	_draw_crew(c, s, false, fade)
	for m: Dictionary in _motes:
		var k := float(m["life"]) / float(m["max"])
		DreamBackground.draw_star(self, Vector2(m["p"]), float(m["r"]) * (1.0 + sin(_t * 6.0 + float(m["max"]) * 9.0) * 0.3), Color(m["c"], (1.0 - k) * 0.8 * fade))
	_draw_clouds(c, s * zoom, fade)
	# Sombra suave bajo la cama, para que se despegue del cielo / A soft shadow under the bed, so it lifts off the sky
	draw_texture_rect(soft, Rect2(c + Vector2(-90, 40) * s * zoom, Vector2(200, 110) * s * zoom), false, Color(UITheme.INK, 0.35))
	_draw_bed(c, s * zoom)
	_draw_crew(c, s, true, fade)
	_draw_zs(c, s, fade)


## La cama vista desde arriba, inclinada y meciéndose / The bed seen from above, tilted and rocking
func _draw_bed(c: Vector2, s: float) -> void:
	var bs := 0.6 * s
	var tilt := -0.12 + sin(_t * 0.6) * 0.035
	var xf := Transform2D(tilt, Vector2(bs, bs), 0.0, c) * Transform2D(0.0, -BED.get_center())
	draw_set_transform_matrix(xf)
	Sprites.draw(self, "room_bed")
	Sprites.draw(self, "room_bed_pillow")
	var pillow := Rect2(BED.position.x + 24, BED.position.y + 24, BED.size.x - 48, 58)
	# Kroker se revuelve un poco en sueños / Kroker stirs a little in his sleep
	var turn := sin(_t * 0.5) * 0.12 + tilt
	KrokerArt.draw_sleeping(self, xf * (pillow.get_center() + Vector2(0, 6)), 0.9 * bs, _t, turn)
	draw_set_transform_matrix(xf)
	var top := BED.position.y + 88.0
	Sprites.draw_top(self, "room_quilt", top - 2.0, BED.end.y + 6.0)
	# Bulto que respira bajo el edredón / The breathing shape under the quilt
	var rise := sin(_t * 1.6) * 3.0
	draw_texture_rect(DreamBackground.soft_texture(), Rect2(BED.position.x + 30, top + 10 - rise, 140, 150), false, Color(1, 1, 1, 0.12))
	draw_set_transform(Vector2.ZERO)


## Jirones de nube bajo la cama, que se deshacen hacia atrás / Cloud wisps under the bed, trailing off
func _draw_clouds(c: Vector2, s: float, fade: float) -> void:
	var soft := DreamBackground.soft_texture()
	for i in 7:
		var k := fposmod(_t * 0.12 + i / 7.0, 1.0)
		var p := c + Vector2(lerpf(70.0, -170.0, k), 92.0 + sin(i * 1.7) * 14.0 + k * 20.0) * s
		var r := (40.0 + 18.0 * sin(i * 2.3)) * (1.0 - k * 0.4) * s
		draw_texture_rect(soft, Rect2(p - Vector2(r, r * 0.55), Vector2(r * 2.0, r * 1.1)), false, Color(UITheme.BONE, 0.2 * sin(k * PI) * fade))


## Los conocidos orbitan alrededor de la cama: los de atrás se dibujan antes, más pequeños y más
## oscuros. / Known characters orbit the bed: the ones at the back are drawn first, smaller and dimmer.
func _draw_crew(c: Vector2, s: float, front: bool, fade: float) -> void:
	var n := _crew.size()
	if n == 0:
		return
	var soft := DreamBackground.soft_texture()
	var order: Array = []
	for i in n:
		var a := _t * 0.11 + i * TAU / n
		var depth := sin(a)
		if (depth >= 0.0) != front:
			continue
		order.append([depth, a, i])
	order.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	for item: Array in order:
		var a: float = item[1]
		var i: int = item[2]
		var depth: float = item[0]
		var who := _crew[i]
		# Al zambullirse, salen despedidos hacia fuera / When diving in, they're flung outwards
		var spread := 1.0 + dive * dive * 2.5
		var feet := c + Vector2(cos(a) * 235.0 * spread, sin(a) * 105.0 * spread + 40.0 + sin(_t * 1.3 + i) * 6.0) * s
		var ns := (0.27 + 0.06 * depth) * s
		var dim := 0.55 + 0.45 * (depth * 0.5 + 0.5)
		var col: Color = AURA.get(who, UITheme.GOLD)
		draw_texture_rect(soft, Rect2(feet + Vector2(-70, -150) * ns / 0.27, Vector2(140, 150) * ns / 0.27), false, Color(col, 0.22 * dim * fade))
		var face := 1.0 if cos(a) < 0.0 else -1.0
		NpcArt.draw(self, Transform2D(0.0, Vector2(ns * face, ns), 0.0, feet - Vector2(100.0 * ns * face, 288.0 * ns)), who, _t + i * 3.0)
		# Los de atrás quedan en penumbra / Those at the back fall into shadow
		if depth < 0.0 or fade < 1.0:
			var shade := clampf(-depth * 0.45 + (1.0 - fade), 0.0, 1.0)
			draw_texture_rect(soft, Rect2(feet + Vector2(-60, -120) * ns / 0.27, Vector2(120, 130) * ns / 0.27), false, Color(UITheme.INK, shade * 0.6))


func _draw_zs(c: Vector2, s: float, fade: float) -> void:
	var font := UITheme.font("display")
	var head := c + Vector2(-8.0, -82.0) * s
	for z: Dictionary in _zs:
		var k := float(z["t"]) / 3.2
		var p := head + Vector2(18.0 + k * 50.0 + sin(k * 7.0) * 8.0, -k * 110.0) * s
		var fs := int((16.0 + k * 18.0) * s * (1.3 if z["big"] else 1.0))
		draw_string_outline(font, p, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(UITheme.INK, sin(k * PI) * 0.5 * fade))
		draw_string(font, p, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UITheme.GOLD, sin(k * PI) * fade))
