class_name FitScroll
extends ScrollContainer
## Desplazamiento que crece con su contenido hasta lo que quepa en pantalla y, a partir de ahí,
## se desplaza (rueda, barra, foco y stick derecho del mando). Para paneles que van dentro de un
## CenterContainer y pueden llenarse mucho: el resumen de la pausa, el panel del modo Dios.
## "outer" es el panel entero, para saber cuánto ocupa el resto (títulos, botones, márgenes).
## A scroll area that grows with its content up to what fits on screen and scrolls beyond that
## (wheel, bar, focus and the gamepad's right stick). For panels inside a CenterContainer that can
## get very full: the pause summary, the god mode panel. "outer" is the whole panel, to know how
## much the rest takes up (titles, buttons, margins).

## Hueco que se deja arriba y abajo de la pantalla / Gap left at the top and bottom of the screen
var margin := 36.0
var outer: Control
## Pista «Stick derecho: ver más», visible solo si no cabe y se usa mando
## "Right stick: see more" hint, visible only when it doesn't fit and a gamepad is in use
var hint: Control
var _fitting := false


func _ready() -> void:
	horizontal_scroll_mode = SCROLL_MODE_DISABLED
	vertical_scroll_mode = SCROLL_MODE_AUTO
	follow_focus = true
	var pad := PadScroll.new()
	pad.active = true
	pad.auto = false
	add_child(pad)
	pad.overflow_changed.connect(func(o: bool) -> void:
		if is_instance_valid(hint):
			hint.visible = o and Settings.using_pad)
	get_viewport().size_changed.connect(_fit)
	for c in get_children():
		if c is Control:
			(c as Control).minimum_size_changed.connect(_fit)
			(c as Control).resized.connect(_fit)
	_fit.call_deferred()
	# Al abrir, arriba del todo (el foco inicial a veces la mueve antes de colocarse)
	# On opening, at the very top (the initial focus sometimes moves it before layout settles)
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(self):
		scroll_vertical = 0


func _content() -> Control:
	for c in get_children():
		if c is Control:
			return c
	return null


func _fit() -> void:
	var c := _content()
	if _fitting or c == null or not is_inside_tree():
		return
	_fitting = true
	var want := c.get_combined_minimum_size().y
	# Lo que ocupa el resto del panel / What the rest of the panel takes up
	var rest := 0.0
	if is_instance_valid(outer):
		rest = outer.get_combined_minimum_size().y - get_combined_minimum_size().y
	var room := get_viewport_rect().size.y - margin * 2.0 - rest
	var h := clampf(want, 0.0, maxf(room, 160.0))
	if not is_equal_approx(h, custom_minimum_size.y):
		custom_minimum_size.y = h
	# Siempre con el hueco de la barra, salga o no: si el ancho cambiara al aparecer la barra, el texto
	# se reajustaría, cambiaría la altura y la barra podría aparecer y desaparecer sin parar
	# Always with room for the bar, shown or not: if the width changed when the bar appears, the text
	# would rewrap, the height would change and the bar could keep appearing and disappearing
	var bar := get_v_scroll_bar().get_combined_minimum_size().x + 8.0
	var w := c.get_combined_minimum_size().x + bar
	if not is_equal_approx(w, custom_minimum_size.x):
		custom_minimum_size.x = w
	_fitting = false
