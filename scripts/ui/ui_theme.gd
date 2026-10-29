class_name UITheme
extends RefCounted
## Estilo visual de Dreamed: noche de ensueño, muy estrellada y luminosa.
## Azules profundos, lavanda y luz de estrellas; superficies translúcidas que brillan.
## Dreamed's visual style: a dreamy, star-filled, luminous night.
## Deep blues, lavender and starlight; translucent surfaces that glow.

# Paleta / Palette
const INK := Color("0e1336")      # cielo profundo / deep sky
const VOID := Color("1b2258")     # paneles / panels
const SLATE := Color("2a3274")    # superficies elevadas / raised surfaces
const LINE := Color("7d86d6")     # bordes (se usa con transparencia) / borders (used translucent)
const BONE := Color("f7f2ea")     # luz de luna, texto principal / moonlight, main text
const ASH := Color("bcc0ea")      # lavanda, texto secundario / lavender, secondary text
const GOLD := Color("f6d993")     # luz de estrella, acento / starlight, accent
const MIST := Color("a9bcff")     # azul de ensueño / dreamy blue
const EMBER := Color("ff9fb1")    # vida / health
const ROSE := Color("e8a6d8")     # nebulosa rosada / pink nebula

# Alias de versiones anteriores / Older aliases
const TEXT := BONE
const MUTED := ASH
const MOON := GOLD
const LAVENDER := MIST
const NIGHT := INK
const DEEP := VOID
const PANEL := SLATE

## Fuente pixel art propia (tools/make_font.py), escalada solo en múltiplos enteros
## Our own pixel-art font (tools/make_font.py), scaled only by whole multiples
const _PIX := preload("res://assets/fonts/dreampix.fnt")
const _PIX_ITALIC := preload("res://assets/fonts/dreampix_italic.fnt")

static var _fonts := {}


## Roles: "display" (negrita / bold), "italic", "body", "light", "caps" (versalitas espaciadas / spaced capitals)
static func font(role := "body") -> Font:
	if _fonts.has(role):
		return _fonts[role]
	var f: Font
	match role:
		"display":
			# Títulos: la misma letra, con un poco más de aire / Titles: the same letters, with a little more air
			var v := FontVariation.new()
			v.base_font = _PIX
			v.spacing_glyph = 1
			f = v
		"italic":
			f = _PIX_ITALIC
		"caps":
			var v := FontVariation.new()
			v.base_font = _PIX
			v.spacing_glyph = 2
			f = v
		_:
			f = _PIX
	_fonts[role] = f
	return f


static func box(bg: Color, border := Color.TRANSPARENT, bw := 0, radius := 12, pad := 16.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	return s


## Caja con halo de luz / Box with a soft glow
static func glow_box(bg: Color, border: Color, glow: Color, glow_size := 14, radius := 12, pad := 16.0) -> StyleBoxFlat:
	var s := box(bg, border, 1, radius, pad)
	s.shadow_color = glow
	s.shadow_size = glow_size
	return s


static func bar(color: Color, thickness := 2.0) -> StyleBoxFlat:
	var s := box(color, Color.TRANSPARENT, 0, 4, 0.0)
	s.content_margin_top = thickness
	s.content_margin_bottom = thickness
	return s


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font("body")
	t.default_font_size = 26

	# Botones: cristal translúcido que brilla al enfocarlos
	# Buttons: translucent glass that glows when focused
	var normal := box(Color(VOID, 0.55), Color(LINE, 0.45), 1, 12, 14)
	normal.content_margin_left = 28
	normal.content_margin_right = 28
	var hover := glow_box(Color(SLATE, 0.75), Color(GOLD, 0.8), Color(GOLD, 0.22), 14, 12, 14)
	hover.content_margin_left = 28
	hover.content_margin_right = 28
	var pressed := glow_box(Color(SLATE, 0.9), GOLD, Color(GOLD, 0.35), 18, 12, 14)
	pressed.content_margin_left = 28
	pressed.content_margin_right = 28
	var disabled := box(Color(VOID, 0.3), Color(LINE, 0.18), 1, 12, 14)
	var focus := box(Color.TRANSPARENT, Color(GOLD, 0.9), 1, 14, 14)
	focus.expand_margin_left = 4
	focus.expand_margin_right = 4
	focus.expand_margin_top = 4
	focus.expand_margin_bottom = 4
	focus.shadow_color = Color(GOLD, 0.18)
	focus.shadow_size = 12
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("hover_pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", Color(BONE, 0.9))
	t.set_color("font_hover_color", "Button", BONE)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_hover_pressed_color", "Button", GOLD)
	t.set_color("font_focus_color", "Button", BONE)
	t.set_color("font_disabled_color", "Button", Color(ASH, 0.45))

	# Entradas del menú principal: solo texto / Main menu entries: text only
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		t.set_stylebox(state, "MenuEntry", empty)
	t.set_type_variation("MenuEntry", "Button")
	t.set_font("font", "MenuEntry", font("display"))
	t.set_font_size("font_size", "MenuEntry", 46)
	t.set_color("font_color", "MenuEntry", Color(ASH, 0.9))
	t.set_color("font_hover_color", "MenuEntry", BONE)
	t.set_color("font_focus_color", "MenuEntry", BONE)
	t.set_color("font_pressed_color", "MenuEntry", GOLD)
	t.set_color("font_hover_pressed_color", "MenuEntry", GOLD)
	t.set_color("font_outline_color", "MenuEntry", Color(GOLD, 0.0))

	# Interruptores / Switches
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		t.set_stylebox(state, "CheckButton", StyleBoxEmpty.new())
	t.set_icon("checked", "CheckButton", _switch_icon(true))
	t.set_icon("unchecked", "CheckButton", _switch_icon(false))

	t.set_color("font_color", "Label", BONE)

	t.set_stylebox("panel", "PanelContainer",
		glow_box(Color(VOID, 0.82), Color(LINE, 0.4), Color(MIST, 0.14), 30, 22, 44))

	# Deslizadores / Sliders
	t.set_stylebox("slider", "HSlider", bar(Color(LINE, 0.35), 2.0))
	t.set_stylebox("grabber_area", "HSlider", bar(GOLD, 2.0))
	t.set_stylebox("grabber_area_highlight", "HSlider", bar(GOLD, 2.0))
	t.set_icon("grabber", "HSlider", _star_icon(26, BONE))
	t.set_icon("grabber_highlight", "HSlider", _star_icon(30, GOLD))

	# Desplegables / Dropdowns
	t.set_stylebox("panel", "PopupMenu", box(Color(VOID, 0.97), Color(LINE, 0.5), 1, 10, 8))
	t.set_stylebox("hover", "PopupMenu", box(SLATE, Color.TRANSPARENT, 0, 8, 8))
	t.set_color("font_color", "PopupMenu", Color(BONE, 0.9))
	t.set_color("font_hover_color", "PopupMenu", GOLD)
	t.set_font_size("font_size", "PopupMenu", 24)

	# Barras / Bars
	t.set_stylebox("background", "ProgressBar", bar(Color(LINE, 0.25), 2.0))
	t.set_stylebox("fill", "ProgressBar", bar(GOLD, 2.0))
	return t


## Estrella de cuatro puntas suave / Soft four-pointed star
static func _star_icon(d: int, color: Color) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var r := d / 2.0
	for y in d:
		for x in d:
			var p := Vector2(x + 0.5 - r, y + 0.5 - r) / r
			# forma de estrella: |x|^0.5 + |y|^0.5 < 1
			var m := sqrt(absf(p.x)) + sqrt(absf(p.y))
			var a := clampf((1.0 - m) * 6.0, 0.0, 1.0)
			var glow := clampf(1.0 - p.length(), 0.0, 1.0) * 0.35
			img.set_pixel(x, y, Color(color, maxf(a, glow)))
	return ImageTexture.create_from_image(img)


static func _switch_icon(on: bool) -> ImageTexture:
	var w := 64
	var h := 30
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var r := h / 2.0
	var knob_x := w - r if on else r
	var track := Color(GOLD, 0.35) if on else Color(LINE, 0.25)
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var cx := clampf(p.x, r, w - r)
			var d := p.distance_to(Vector2(cx, r))
			var col := Color(track, track.a * clampf(r - d, 0.0, 1.0))
			var k := clampf(r - 4.0 - p.distance_to(Vector2(knob_x, r)), 0.0, 1.0)
			if k > 0.0:
				col = col.blend(Color(GOLD if on else ASH, k))
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## Etiqueta con estilo / Styled label. role: display, italic, body, light, caps
static func label(key: String, font_size := 26, color := BONE, role := "body") -> Label:
	var l := Label.new()
	l.text = key
	l.add_theme_font_override("font", font(role))
	l.add_theme_font_size_override("font_size", pixel_size(font_size))
	l.add_theme_color_override("font_color", color)
	l.uppercase = role == "caps"
	return l


## La fuente pixel art solo se ve nítida en múltiplos de su tamaño (12). Nada por debajo de x2.
## The pixel font is only crisp at multiples of its size (12). Nothing below x2.
static func pixel_size(font_size: int) -> int:
	return maxi(2, roundi(font_size / 12.0)) * 12


static func rule(color := LINE, width := 0.0) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(width, 1)
	return r


static func ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		ignore_mouse(child)
