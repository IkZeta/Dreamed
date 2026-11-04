class_name AdSpam
extends CanvasLayer
## Ataque de Evil Ad: te llena la pantalla de pop-ups de anuncios chillones que no dejan ver. Cada
## uno se cierra con un QTE: la tecla (1-4) o el botón del mando que enseña en su barra (los cuatro
## de la cara: abajo, derecha, izquierda, arriba; el dibujo cambia según el mando: Xbox, PlayStation
## o Nintendo). Con ratón también se pueden cerrar pulsando su X. Si pulsas el que no es, la ventana
## tiembla. Los que sigan abiertos al acabar el tiempo estallan y hacen un poco de daño.
## Evil Ad's attack: fills the screen with garish advert pop-ups that block the view. Each one closes
## with a QTE: the key (1-4) or gamepad button shown on its bar (the four face buttons: bottom, right,
## left, top; the icon changes with the pad: Xbox, PlayStation or Nintendo). With a mouse you can also
## close them by clicking their X. Pressing the wrong one makes the window shake. Those still open
## when time runs out burst and deal a little damage.

signal finished

const LIFE := 9.0
const DAMAGE := 1.5
const SIZE := Vector2(430, 260)
const WORDS := ["SPAM_1", "SPAM_2", "SPAM_3", "SPAM_4", "SPAM_5", "SPAM_6", "SPAM_7", "SPAM_8"]
const COLORS := [Color("ff2a6a"), Color("ffd400"), Color("2ad0ff"), Color("7aff3a"), Color("ff7a1a"), Color("c04aff")]

var run: Node
var count := 5
var _left := 0
var _t := 0.0
var _done := false


var _slots: Array[Vector2] = []


func _ready() -> void:
	layer = 18
	# Huecos repartidos por toda la pantalla, en desorden / Slots spread across the whole screen, shuffled
	for y in 3:
		for x in 4:
			_slots.append(Vector2(120 + x * 420 + randf_range(-40, 40), 170 + y * 250 + randf_range(-30, 30)))
	_slots.shuffle()
	for i in count:
		get_tree().create_timer(0.18 * i, false).timeout.connect(_open_one.bind(i))
	_left = count


func _open_one(i: int) -> void:
	if _done:
		return
	var p := AdWindow.new()
	p.spam = self
	p.button = randi() % 4
	p.word = WORDS[randi() % WORDS.size()]
	p.col = COLORS[randi() % COLORS.size()]
	p.size = SIZE * randf_range(0.85, 1.15)
	# Por el centro de la pantalla, que es donde más molesta / Around the middle of the screen, where it bothers most
	var at: Vector2 = _slots[i % _slots.size()]
	p.position = Vector2(clampf(at.x, 40, 1920 - 40 - p.size.x), clampf(at.y, 120, 1080 - 120 - p.size.y))
	p.rotation = randf_range(-0.05, 0.05)
	add_child(p)
	Audio.play("glitch", -14.0, 0.3)
	Audio.play("ui_hover", -10.0, 0.4)


func _process(delta: float) -> void:
	_t += delta
	if _done:
		return
	if _t > LIFE:
		# Los que quedan estallan / The ones left burst
		var n := 0
		for c in get_children():
			if c is AdWindow and not (c as AdWindow).closing:
				(c as AdWindow).close(false)
				n += 1
		if n > 0 and is_instance_valid(run.player):
			run.player.take_damage(DAMAGE * mini(n, 3) * GameState.enemy_dmg_mult(), null)
			run.shake(6.0)
		_finish()


func _input(event: InputEvent) -> void:
	if _done:
		return
	for i in 4:
		if event.is_action_pressed("qte_%d" % (i + 1)):
			get_viewport().set_input_as_handled()
			_press(i)
			return


## Cierra el pop-up de más arriba que pida ese botón; si ninguno lo pide, tiemblan todos
## Closes the top pop-up that asks for that button; if none does, they all shake
func _press(b: int) -> void:
	var kids := get_children()
	for k in range(kids.size() - 1, -1, -1):
		var p := kids[k] as AdWindow
		if p and not p.closing and p.button == b:
			p.close(true)
			return
	for c in kids:
		if c is AdWindow and not (c as AdWindow).closing:
			(c as AdWindow).wrong()
	Audio.play("deal_lost", -14.0)


func popup_closed() -> void:
	_left -= 1
	if _left <= 0:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	get_tree().create_timer(0.6, false).timeout.connect(queue_free)


func done() -> bool:
	return _done


## Una ventana de anuncio chillona / A garish advert window
class AdWindow extends Control:
	var spam: AdSpam
	var button := 0
	var word := ""
	var col := Color.RED
	var closing := false
	var _t := 0.0
	var _shake := 0.0
	var _pop := 0.0

	func _ready() -> void:
		pivot_offset = size / 2.0
		scale = Vector2(0.3, 0.3)
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		mouse_filter = MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		# Con el ratón, se cierra pulsando la X / With the mouse, it closes by clicking the X
		if event is InputEventMouseButton and event.pressed and not closing:
			if _close_rect().has_point(event.position):
				close(true)
			accept_event()

	func _close_rect() -> Rect2:
		return Rect2(size.x - 52, 6, 46, 34)

	func wrong() -> void:
		_shake = 0.3

	func close(ok: bool) -> void:
		closing = true
		if ok:
			Audio.play("ui_click", -6.0, 0.2)
		var tw := create_tween().set_parallel()
		tw.tween_property(self, "scale", Vector2(0.2, 0.2) if ok else Vector2(1.3, 1.3), 0.15)
		tw.tween_property(self, "modulate:a", 0.0, 0.15)
		tw.chain().tween_callback(queue_free)
		spam.popup_closed()

	func _process(delta: float) -> void:
		_t += delta
		_shake = maxf(0.0, _shake - delta)
		position.x += sin(_t * 60.0) * 6.0 * _shake
		# Se mueven un poco, para molestar más / They drift a little, to be more annoying
		position += Vector2(sin(_t * 1.3 + button), cos(_t * 1.1 + button)) * 12.0 * delta
		queue_redraw()

	func _draw() -> void:
		var flash := fmod(_t * 3.0, 1.0) < 0.5
		var bg := col if flash else col.lightened(0.35)
		draw_rect(Rect2(Vector2(8, 10), size), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(Vector2.ZERO, size), Color("101018"))
		draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), bg)
		# Barra de título con el botón para cerrar / Title bar with the close button
		draw_rect(Rect2(3, 3, size.x - 6, 40), Color("1a1a2a"))
		var font := UITheme.font("caps")
		draw_string(font, Vector2(14, 30), "AD.exe", HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.pixel_size(18), Color.WHITE)
		QteGlyph.draw_glyph(self, Vector2(size.x - 82, 23), button, 15.0)
		var cr := _close_rect()
		draw_rect(cr, Color("e0303a"))
		draw_line(cr.position + Vector2(14, 9), cr.end - Vector2(14, 9), Color.WHITE, 3.0)
		draw_line(Vector2(cr.end.x - 14, cr.position.y + 9), Vector2(cr.position.x + 14, cr.end.y - 9), Color.WHITE, 3.0)
		# El anuncio, que bota y cambia de color / The advert, bouncing and changing colour
		var big := UITheme.font("display")
		var bounce := sin(_t * 9.0) * 6.0
		var text := tr(word)
		var fs := UITheme.pixel_size(34 if text.length() < 14 else 22)
		draw_string(big, Vector2(0, size.y * 0.45 + bounce), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color("101018"))
		draw_string(big, Vector2(-2, size.y * 0.45 + bounce - 2), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color.WHITE if flash else Color("ffe84a"))
		# El QTE en grande: qué hay que pulsar para cerrarla / The QTE, big: what to press to close it
		var gc := Vector2(size.x / 2.0, size.y * 0.7)
		draw_circle(gc, 40.0, Color(0.06, 0.06, 0.1, 0.85))
		QteGlyph.draw_glyph(self, gc, button, 26.0)
		# Estrellitas de oferta / Offer starbursts
		for i in 2:
			var c := Vector2(48 + i * (size.x - 96), size.y - 56)
			var pts := PackedVector2Array()
			for k in 16:
				var r := 30.0 if k % 2 == 0 else 18.0
				pts.append(c + Vector2.from_angle(TAU * k / 16.0 + _t * 2.0) * r)
			draw_colored_polygon(pts, Color("ffe84a") if i == 0 else Color("ff2a6a"))
		draw_string(font, Vector2(0, size.y - 20), tr("SPAM_CLOSE"), HORIZONTAL_ALIGNMENT_CENTER, size.x, UITheme.pixel_size(16), Color("101018"))
		# Barra del tiempo que le queda / Bar showing the time left
		var k2 := clampf(1.0 - spam._t / AdSpam.LIFE, 0.0, 1.0)
		draw_rect(Rect2(3, size.y - 9, (size.x - 6) * k2, 6), Color("101018"))


## El botón o tecla que hay que pulsar, dibujado según el mando en uso / The button or key to press, drawn for the device in use
class QteGlyph:
	static func draw_glyph(ci: CanvasItem, c: Vector2, b: int, r: float) -> void:
		var font := UITheme.font("caps")
		if not Settings.using_pad:
			# Tecla con su número / A keycap with its number
			ci.draw_rect(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), Color("e8e4f0"))
			ci.draw_rect(Rect2(c - Vector2(r, r) + Vector2(0, r * 1.6), Vector2(r * 2.0, r * 0.4)), Color("9a96a8"))
			ci.draw_string(font, c + Vector2(-r, r * 0.45), str(b + 1), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, UITheme.pixel_size(int(r * 1.3)), Color("101018"))
			return
		# Rombo de los cuatro botones con el que toca encendido / Diamond of the four buttons with the right one lit
		var offs := [Vector2(0, 1), Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1)]
		var fam := Settings.pad_family()
		var xbox_col := [Color("5ad04a"), Color("e8403a"), Color("3a8ae8"), Color("f0c81a")]
		var nin := ["B", "A", "Y", "X"]
		var xb := ["A", "B", "X", "Y"]
		var sr := r * 0.55
		for i in 4:
			var p: Vector2 = c + offs[i] * r * 1.05
			var on := i == b
			ci.draw_circle(p, sr + 1.5, Color("101018"))
			ci.draw_circle(p, sr, (xbox_col[i] if fam == "XBOX" else Color("e8e4f0")) if on else Color(0.5, 0.5, 0.55, 0.5))
			if not on:
				continue
			var ink := Color("101018")
			if fam == "PS":
				match i:
					0:   # cruz / cross
						ci.draw_line(p - Vector2(sr, sr) * 0.5, p + Vector2(sr, sr) * 0.5, Color("3a8ae8"), 2.5)
						ci.draw_line(p + Vector2(-sr, sr) * 0.5, p + Vector2(sr, -sr) * 0.5, Color("3a8ae8"), 2.5)
					1:   # círculo / circle
						ci.draw_arc(p, sr * 0.5, 0, TAU, 12, Color("e8403a"), 2.5)
					2:   # cuadrado / square
						ci.draw_rect(Rect2(p - Vector2(sr, sr) * 0.45, Vector2(sr, sr) * 0.9), Color("e86ab8"), false, 2.5)
					3:   # triángulo / triangle
						ci.draw_polyline(PackedVector2Array([p + Vector2(0, -sr * 0.55), p + Vector2(sr * 0.5, sr * 0.4), p + Vector2(-sr * 0.5, sr * 0.4), p + Vector2(0, -sr * 0.55)]), Color("3ac8a0"), 2.5)
			else:
				var letter: String = (nin if fam == "NIN" else xb)[i]
				ci.draw_string(font, p + Vector2(-sr, sr * 0.45), letter, HORIZONTAL_ALIGNMENT_CENTER, sr * 2.0, UITheme.pixel_size(int(sr * 1.4)), ink)
