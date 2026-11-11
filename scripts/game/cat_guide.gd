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


func _ready() -> void:
	# El bocadillo va fuera de la pantallita pixelada del mundo, a resolución completa
	# The bubble lives outside the world's pixelated little screen, at full resolution
	_ui = CanvasLayer.new()
	_ui.layer = 5
	run.add_child(_ui)
	_bubble = PanelContainer.new()
	_bubble.theme = UITheme.build()
	_bubble.add_theme_stylebox_override("panel", UITheme.glow_box(Color(UITheme.VOID, 0.95), Color(NpcArt.CAT_AURA, 0.85), Color(NpcArt.CAT_AURA, 0.18), 14, 10, 18))
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_bubble)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	_bubble.add_child(v)
	var head := UITheme.label("GIVER_CAT_NAME", 16, NpcArt.CAT_AURA, "caps")
	v.add_child(head)
	_label = Keywords.label("", 19, UITheme.BONE, "body")
	_label.custom_minimum_size.x = BUBBLE_W
	v.add_child(_label)
	# Piquito del bocadillo que apunta a su boca / The bubble's tail pointing at his mouth
	_tail = Control.new()
	_tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tail.draw.connect(func() -> void:
		var tip: Vector2 = _tail.get_meta("tip", Vector2.ZERO)
		var base: Vector2 = _tail.get_meta("base", Vector2.ZERO)
		var w := 14.0
		_tail.draw_colored_polygon(PackedVector2Array([base + Vector2(-w - 2, -2), base + Vector2(w + 2, -2), tip + (tip - base).normalized() * 3.0]), Color(NpcArt.CAT_AURA, 0.85))
		_tail.draw_colored_polygon(PackedVector2Array([base + Vector2(-w, -4), base + Vector2(w, -4), tip]), Color(UITheme.VOID, 0.95)))
	_ui.add_child(_tail)
	_ui.move_child(_tail, 0)
	_say(_text)


func _say(text: String) -> void:
	_text = text
	Keywords.set_text(_label, text)
	_label.visible_characters = 0
	_type_t = 0.0


var _type_t := 0.0


## El bocadillo sale de su boca (encima, o debajo si no cabe) y se queda dentro de la pantalla
## The bubble comes out of his mouth (above, or below if there's no room) and stays on screen
func _place_bubble(alpha: float) -> void:
	var xf := get_global_transform_with_canvas()
	var mouth: Vector2 = (xf * Vector2(0, -(288.0 - 214.0) * Player.ART_SCALE)) * float(Run.PIXEL_SHRINK)
	var vp := run.get_viewport().get_visible_rect().size
	_bubble.reset_size()
	var sz := _bubble.size
	var above := mouth.y - 70.0 - sz.y > 12.0
	var y := mouth.y - 70.0 - sz.y if above else mouth.y + 60.0
	# Hacia el lado contrario a Kroker, para no taparle / Towards the side away from Kroker, so it doesn't cover him
	var x := clampf(mouth.x - sz.x * 0.5 + _side * (sz.x * 0.5 - 50.0), 12.0, vp.x - sz.x - 12.0)
	_bubble.position = Vector2(x, y).round()
	_bubble.modulate.a = alpha
	var base := Vector2(clampf(mouth.x, x + 24.0, x + sz.x - 24.0), y + sz.y if above else y)
	var tip := mouth + (Vector2(0, -16) if above else Vector2(0, 16))
	_tail.set_meta("base", base if above else base + Vector2(0, 4))
	_tail.set_meta("tip", tip)
	_tail.size = vp
	_tail.modulate.a = alpha
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
	# Va escribiendo cuando ya se le ve la cara / Types out once his face is showing
	if _age > 0.35:
		_type_t += delta
		_label.visible_characters = int(_type_t * TYPE_CPS)
	var a := clampf((_age - 0.25) / 0.3, 0.0, 1.0)
	if _out >= 0.0:
		a = clampf(1.0 - _out / (OUT * 0.5), 0.0, 1.0)
	_place_bubble(a)
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
