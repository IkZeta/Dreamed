class_name KeywordTip
extends CanvasLayer
## Tarjeta que explica una palabra clave; sigue al ratón y se cierra al salir de la palabra.
## Card explaining a keyword; it follows the mouse and closes when leaving the word.

var _panel: PanelContainer
var _title: Label
var _body: Label


func _ready() -> void:
	layer = 120
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1a1638", 0.97)
	sb.border_color = Color(Keywords.COLOR)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)
	_title = UITheme.label("", 22, Color(Keywords.COLOR), "caps")
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	v.add_child(_title)
	_body = UITheme.label("", 18, UITheme.BONE, "body")
	_body.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.x = 420
	v.add_child(_body)
	_panel.visible = false


func show_for(id: String) -> void:
	_title.text = tr("KW_%s_NAME" % id.to_upper())
	_body.text = tr("KW_%s_DESC" % id.to_upper())
	_panel.visible = true
	_panel.reset_size()
	_place()


func hide_tip() -> void:
	if _panel:
		_panel.visible = false


func _process(_delta: float) -> void:
	if _panel.visible:
		_place()


## Junto al ratón, sin salirse de la pantalla / Next to the mouse, without leaving the screen
func _place() -> void:
	var vp := get_viewport().get_visible_rect().size
	var m := get_viewport().get_mouse_position()
	var p := m + Vector2(24, 24)
	var s := _panel.size
	if p.x + s.x > vp.x - 10:
		p.x = m.x - s.x - 16
	if p.y + s.y > vp.y - 10:
		p.y = m.y - s.y - 16
	_panel.position = p
