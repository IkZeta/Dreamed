class_name CatGuide
extends Node2D
## El Gato Siniestro en persona dentro del sueño: cuando salta un consejo, aparece al lado de
## Kroker (primero la sonrisa, luego el resto), se lo cuenta en un bocadillo que le sale de la
## boca, le sigue un poco de lejos mientras habla y se desvanece (el cuerpo primero; la sonrisa,
## lo último). No estorba ni se le puede pegar.
## The Sinister Cat in person inside the dream: when a tip pops up he appears beside Kroker (grin
## first, then the rest), tells it in a speech bubble coming out of his mouth, follows him at a
## distance while he talks and fades away (body first; the grin last). He doesn't get in the way
## and can't be hit.

const IN := 0.9
const OUT := 1.1
const SIDE := 96.0          # a qué distancia de Kroker se sienta / how far from Kroker he sits

var run: Run
var _t := 0.0
var _life := 0.0            # cuánto le queda de hablar / how long he has left to talk
var _age := 0.0
var _out := -1.0            # >= 0: desvaneciéndose / fading away
var _side := 1.0
var _hop := 0.0
var _text := ""
var _ui: CanvasLayer
var _bubble: PanelContainer
var _label: RichTextLabel
var _tail: Control
const BUBBLE_W := 430.0
const TYPE_CPS := 60.0      # letras por segundo / letters per second


## Hace que aparezca (o que se quede más si ya estaba) / Makes him appear (or stay longer if he was already there)
static func appear(r: Run, text: String) -> void:
	# Tiempo para leerlo con calma / Time to read it calmly
	var secs := clampf(3.0 + text.length() / 22.0, 5.0, 12.0)
	for c in r._actors.get_children():
		if c is CatGuide and (c as CatGuide)._out < 0.0:
			(c as CatGuide)._say(text)
			(c as CatGuide)._life = secs
			return
	var g := CatGuide.new()
	g.run = r
	g._life = secs
	g._text = text
	g._side = -1.0 if r.player._facing > 0.0 else 1.0     # detrás de Kroker / behind Kroker
	g.position = g._spot()
	r._actors.add_child(g)
	Audio.play("giver_cat", -14.0)
	r.fx.ring(g.position + Vector2(0, -40), 26.0, NpcArt.CAT_AURA, 0.5, 1.6)


const PLUM := Color("241630")
const PLUM_DARK := Color("140a1c")
const GAP := 26.0           # de la boca al bocadillo / from the mouth to the bubble


func _ready() -> void:
	# El bocadillo va fuera de la pantallita pixelada del mundo, a resolución completa
	# The bubble lives outside the world's pixelated little screen, at full resolution
	_ui = CanvasLayer.new()
	_ui.layer = 5
	run.add_child(_ui)
	# Cuerpo del bocadillo: ciruela con borde turquesa y sombra dura, como pixel art
	# Bubble body: plum with a turquoise border and a hard shadow, like pixel art
	_bubble = PanelContainer.new()
	_bubble.theme = UITheme.build()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PLUM, 0.97)
	sb.border_color = NpcArt.CAT_AURA
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(PLUM_DARK, 0.7)
	sb.shadow_size = 0
	sb.shadow_offset = Vector2(0, 5)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 14
	_bubble.add_theme_stylebox_override("panel", sb)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_bubble)
	_label = Keywords.label("", 19, UITheme.BONE, "body")
	_bubble.add_child(_label)
	# Piquito (encima del borde para que no se vea la costura), pestaña con su nombre y flechita
	# de «sigue» / Tail (over the border so there's no seam), name tab and a little "more" arrow
	_tail = Control.new()
	_tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tail.draw.connect(_draw_extras)
	_ui.add_child(_tail)
	_tab = PanelContainer.new()
	var tb := StyleBoxFlat.new()
	tb.bg_color = NpcArt.CAT_AURA
	tb.set_corner_radius_all(8)
	tb.content_margin_left = 10
	tb.content_margin_right = 10
	tb.content_margin_top = 2
	tb.content_margin_bottom = 2
	tb.shadow_color = Color(PLUM_DARK, 0.7)
	tb.shadow_offset = Vector2(0, 3)
	_tab.add_theme_stylebox_override("panel", tb)
	_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab.add_child(UITheme.label("GIVER_CAT_NAME", 15, PLUM_DARK, "caps"))
	_ui.add_child(_tab)
	_say(_text)


var _tab: PanelContainer
var _pop := 0.0
var _clicks := 0


func _say(text: String) -> void:
	_text = text
	Keywords.set_text(_label, text)
	_label.visible_characters = 0
	_type_t = 0.0
	_clicks = 0
	_pop = 0.0
	# Ancho según lo largo que sea: los consejos cortos, en un bocadillo más estrecho
	# Width by length: short tips get a narrower bubble
	_label.custom_minimum_size.x = clampf(160.0 + text.length() * 2.6, 300.0, BUBBLE_W)


var _type_t := 0.0


func _draw_extras() -> void:
	var tip: Vector2 = _tail.get_meta("tip", Vector2.ZERO)
	var base: Vector2 = _tail.get_meta("base", Vector2.ZERO)
	var up: bool = _tail.get_meta("up", true)
	var dir := 1.0 if up else -1.0
	# Piquito curvo hacia la boca / Curved tail towards the mouth
	var w := 13.0
	var a := base + Vector2(-w, -dir * 4.0)
	var b := base + Vector2(w, -dir * 4.0)
	var mid := (base + tip) * 0.5 + Vector2((tip.x - base.x) * 0.25, 0)
	var pts := PackedVector2Array([a, a.lerp(mid, 0.5) + Vector2(-3, 0), mid + Vector2(-2, 0), tip, mid + Vector2(3, 0), b.lerp(mid, 0.5) + Vector2(3, 0), b])
	_tail.draw_colored_polygon(pts, Color(PLUM, 0.97))
	_tail.draw_polyline(PackedVector2Array([pts[0] + Vector2(0, dir * 3.0), pts[1], pts[2], pts[3]]), NpcArt.CAT_AURA, 3.0)
	_tail.draw_polyline(PackedVector2Array([pts[3], pts[4], pts[5], pts[6] + Vector2(0, dir * 3.0)]), NpcArt.CAT_AURA, 3.0)
	# Flechita que bota cuando ya ha terminado de hablar / A little arrow bobbing once he's done talking
	if _label.visible_characters >= _label.get_total_character_count() and _label.get_total_character_count() > 0:
		var r := _bubble.get_rect()
		var c := r.end - Vector2(20, 14 - absf(sin(_t * 5.0)) * 3.0)
		_tail.draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -4), c + Vector2(6, -4), c + Vector2(0, 3)]), NpcArt.CAT_AURA)
	# Motitas de estrella en las esquinas, como en su pelo / Star specks at the corners, like in his fur
	var rr := _bubble.get_rect()
	for k in 3:
		var p := rr.position + Vector2(rr.size.x - 16.0 - k * 9.0, 9.0)
		_tail.draw_rect(Rect2(p, Vector2(2, 2)), Color(NpcArt.CAT_AURA, 0.35 + 0.35 * sin(_t * 3.0 + k)))


## El bocadillo sale de su boca (encima, o debajo si no cabe) hacia el lado contrario a Kroker,
## y se queda dentro de la pantalla. Al salir, da un saltito desde el piquito.
## The bubble comes out of his mouth (above, or below if there's no room) towards the side away
## from Kroker, and stays on screen. When it appears, it pops out from the tail.
func _place_bubble(alpha: float, delta: float) -> void:
	var xf := get_global_transform_with_canvas()
	var k := float(Run.PIXEL_SHRINK)
	var mouth: Vector2 = (xf * Vector2(0, -(288.0 - 214.0) * Player.ART_SCALE)) * k
	var head: Vector2 = (xf * Vector2(0, -(288.0 - 128.0) * Player.ART_SCALE)) * k
	var vp := run.get_viewport().get_visible_rect().size
	_bubble.reset_size()
	var sz := _bubble.size
	var above := head.y - GAP - sz.y > 60.0
	var y := head.y - GAP - sz.y if above else mouth.y + GAP + 30.0
	var x := clampf(mouth.x - sz.x * 0.5 + _side * (sz.x * 0.5 - 56.0), 12.0, vp.x - sz.x - 12.0)
	var base := Vector2(clampf(mouth.x + _side * 26.0, x + 26.0, x + sz.x - 26.0), y + sz.y if above else y)
	# Saltito al aparecer / Pop when appearing
	_pop = minf(1.0, _pop + delta * 5.0)
	var sc := 0.7 + 0.3 * (1.0 - pow(1.0 - _pop, 3.0)) + 0.06 * sin(_pop * PI)
	_bubble.pivot_offset = base - Vector2(x, y)
	_bubble.scale = Vector2(sc, sc)
	_bubble.position = Vector2(x, y).round()
	_bubble.modulate.a = alpha
	_tab.reset_size()
	_tab.position = _bubble.position + Vector2(18, -_tab.size.y * 0.55)
	_tab.pivot_offset = base - _tab.position
	_tab.scale = _bubble.scale
	_tab.modulate.a = alpha
	_tail.set_meta("base", base)
	# El piquito se queda justo encima de la cabeza (o debajo de la barbilla), sin taparle la cara
	# The tail stops just above his head (or below his chin), without covering his face
	_tail.set_meta("tip", Vector2(mouth.x + _side * 8.0, head.y - 2.0) if above else mouth + Vector2(_side * 8.0, 26.0))
	_tail.set_meta("up", above)
	_tail.size = vp
	_tail.modulate.a = alpha * clampf((_pop - 0.3) / 0.4, 0.0, 1.0)
	_tail.queue_redraw()


func _exit_tree() -> void:
	if is_instance_valid(_ui):
		_ui.queue_free()


func _spot() -> Vector2:
	var want: Vector2 = run.player.global_position + Vector2(_side * SIDE, 6.0)
	var p: Vector2 = run.clamp_to_arena(want, 30.0)
	# Si no cabe por ese lado, al otro / If there's no room on that side, the other one
	if p.distance_to(want) > 30.0:
		_side = -_side
		p = run.clamp_to_arena(run.player.global_position + Vector2(_side * SIDE, 6.0), 30.0)
	return p


func _process(delta: float) -> void:
	_t += delta
	_age += delta
	_hop = maxf(0.0, _hop - delta * 3.0)
	if _out < 0.0:
		_life -= delta
		if _life <= 0.0 or not run.player.alive:
			_out = 0.0
			Audio.play("cat_vanish", -16.0, 0.05)
	else:
		_out += delta
		if _out >= OUT:
			queue_free()
			return
	# Le sigue sin prisa; si se queda muy lejos, se desvanece y reaparece al lado (un saltito)
	# Follows unhurriedly; if left far behind, he blinks out and back in beside him (a little hop)
	var target := _spot()
	if position.distance_to(target) > 380.0:
		position = target
		_hop = 1.0
	else:
		position = position.lerp(target, minf(1.0, delta * 2.2))
	# Va escribiendo cuando ya se le ve la cara, con un ronroneo suave cada pocas letras
	# Types out once his face is showing, with a soft purr every few letters
	if _age > 0.35:
		_type_t += delta
		var n := int(_type_t * TYPE_CPS)
		if n < _label.get_total_character_count() and n / 4 > _clicks:
			_clicks = n / 4
			Audio.play("ui_click", -30.0, 0.25)
		_label.visible_characters = n
	var a := clampf((_age - 0.25) / 0.3, 0.0, 1.0)
	if _out >= 0.0:
		a = clampf(1.0 - _out / (OUT * 0.5), 0.0, 1.0)
	_place_bubble(a, delta)
	queue_redraw()


func _draw() -> void:
	# Aparece la sonrisa, luego el cuerpo; al irse, al revés / The grin appears, then the body; leaving, the reverse
	var body := clampf((_age - 0.35) / (IN - 0.35), 0.0, 1.0)
	var face := clampf(_age / 0.35, 0.0, 1.0)
	if _out >= 0.0:
		body = minf(body, clampf(1.0 - _out / (OUT * 0.6), 0.0, 1.0))
		face = clampf(1.0 - (_out - OUT * 0.5) / (OUT * 0.5), 0.0, 1.0)
	var s := Player.ART_SCALE
	var hop := sin(_hop * PI) * 10.0
	if body > 0.0:
		draw_colored_polygon(_oval(Vector2(0, 0), Vector2(22, 6)), Color(0.05, 0.02, 0.15, 0.3 * body))
	var flip := -_side   # mira hacia Kroker / looks towards Kroker
	NpcArt.draw(self, Transform2D(0.0, Vector2(s * flip, s), 0.0, Vector2(-100.0 * s * flip, -288.0 * s - hop)), "cat", _t,
		{"body": body, "face": face, "talk": _out < 0.0 and _label != null and _label.visible_characters < _label.get_total_character_count()})


func _oval(c: Vector2, r: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts
