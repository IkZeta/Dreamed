class_name Keywords
## Palabras clave: en los textos (mejoras, objetos, bestiario...) se resaltan las palabras que
## hay que explicar (estadísticas y estados) y, al pasar el ratón por encima, sale una tarjeta
## con la explicación. Así los textos no tienen que explicarlo todo.
## Keywords: in texts (upgrades, items, bestiary...) the words that need explaining (stats and
## states) are highlighted and, when the mouse goes over them, a card with the explanation
## appears. That way the texts don't have to explain everything.
##
## Para añadir una: un patrón por idioma en PATTERNS y las claves KW_<ID>_NAME / KW_<ID>_DESC.
## To add one: a pattern per language in PATTERNS and the keys KW_<ID>_NAME / KW_<ID>_DESC.

const COLOR := "#ffd27a"
## Patrones (expresiones regulares, sin distinguir mayúsculas) / Patterns (regular expressions, case-insensitive)
const PATTERNS := {
	"bleed": {"es": "sangr\\w*", "en": "bleed\\w*"},
	"burn": {"es": "quem\\w*", "en": "burn\\w*"},
	"slow": {"es": "cámara lenta|ralentiz\\w*", "en": "slow motion|slows|slowing|slowed"},
	"freeze": {"es": "congel\\w*", "en": "freez\\w*|frozen"},
	"glitch": {"es": "glitch\\w*", "en": "glitch\\w*"},
	"fluff": {"es": "pelusas?", "en": "fluff"},
	"stuck": {"es": "pegad[oa]s", "en": "stuck"},
	"knockback": {"es": "empuj\\w*", "en": "push\\w*|shov\\w*"},
	"paralysis": {"es": "paraliz\\w*", "en": "paraly\\w*"},
	"stench": {"es": "mal olor|peste|huel\\w* tan mal", "en": "stench|stink\\w*|smell\\w*"},
	"hack": {"es": "hacke\\w*", "en": "hack\\w*"},
	"crit": {"es": "crític\\w*", "en": "critical|crits?"},
	"defense": {"es": "defensa", "en": "defen[cs]e"},
	"luck": {"es": "suerte", "en": "luck"},
	"attack_speed": {"es": "velocidad de ataque", "en": "attack speed"},
	"regen": {"es": "regeneración|recuperación de salud", "en": "regeneration|regen"},
	"lifesteal": {"es": "robo de (?:salud|vida)", "en": "lifesteal|life steal"},
	"reality": {"es": "Realidad Fragmentada", "en": "Fragmented Reality"},
}

static var _regex := {}
static var _tip: KeywordTip


## Devuelve el texto con las palabras clave resaltadas en BBCode / Returns the text with keywords highlighted in BBCode
static func markup(text: String) -> String:
	var lang := TranslationServer.get_locale().substr(0, 2)
	if lang != "es":
		lang = "en"
	if not _regex.has(lang):
		var parts: Array[String] = []
		for id: String in PATTERNS:
			parts.append("(?<%s>%s)" % [id, PATTERNS[id][lang]])
		var re := RegEx.new()
		re.compile("(?i)(?<![\\p{L}\\[=])(?:%s)(?![\\p{L}])" % "|".join(parts))
		_regex[lang] = re
	var out := ""
	var last := 0
	for m: RegExMatch in (_regex[lang] as RegEx).search_all(text):
		var id := ""
		for n: String in PATTERNS:
			if m.get_string(n) != "":
				id = n
				break
		out += text.substr(last, m.get_start() - last)
		out += "[url=%s][color=%s]%s[/color][/url]" % [id, COLOR, m.get_string()]
		last = m.get_end()
	return out + text.substr(last)


## Etiqueta de texto con palabras clave (con las mismas fuentes que UITheme.label)
## Text label with keywords (with the same fonts as UITheme.label)
static func label(text: String, font_size := 20, color := UITheme.BONE, role := "body") -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_override("normal_font", UITheme.font(role))
	l.add_theme_font_size_override("normal_font_size", UITheme.pixel_size(font_size))
	l.add_theme_color_override("default_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	l.meta_underlined = true
	l.set_meta("keywords", true)
	set_text(l, text)
	l.meta_hover_started.connect(func(meta: Variant) -> void: show_tip(l, String(meta)))
	l.meta_hover_ended.connect(func(_meta: Variant) -> void: hide_tip())
	l.tree_exiting.connect(hide_tip)
	return l


## Cambia el texto (traducido) de una etiqueta hecha con label() / Sets the (translated) text of a label made with label()
static func set_text(l: RichTextLabel, text: String) -> void:
	l.text = markup(TranslationServer.translate(text))


## Hace que una RichTextLabel que ya existe muestre las tarjetas / Makes an existing RichTextLabel show the cards
static func enable(l: RichTextLabel) -> void:
	l.bbcode_enabled = true
	l.meta_underlined = true
	l.set_meta("keywords", true)
	if l.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		l.mouse_filter = Control.MOUSE_FILTER_PASS
	if not l.meta_hover_started.is_connected(_on_hover):
		l.meta_hover_started.connect(_on_hover.bind(l))
		l.meta_hover_ended.connect(func(_meta: Variant) -> void: hide_tip())


static func _on_hover(meta: Variant, l: RichTextLabel) -> void:
	show_tip(l, String(meta))


static func show_tip(from: Control, id: String) -> void:
	if not PATTERNS.has(id):
		return
	if not is_instance_valid(_tip):
		_tip = KeywordTip.new()
		from.get_tree().root.add_child(_tip)
	_tip.show_for(id)


## Palabras clave que aparecen en un texto, sin repetir / Keywords that appear in a text, without repeats
static func ids_in(text: String) -> Array[String]:
	var out: Array[String] = []
	var re := RegEx.new()
	re.compile("\\[url=(\\w+)\\]")
	for m: RegExMatch in re.search_all(markup(TranslationServer.translate(text))):
		if not out.has(m.get_string(1)):
			out.append(m.get_string(1))
	return out


## Con mando o teclado no hay ratón: al seleccionar "owner" se enseñan a su lado las tarjetas de
## todas las palabras clave de "label". With a gamepad or keyboard there's no mouse: when "owner"
## is selected, the cards for every keyword in "label" are shown beside it.
static func on_focus(owner: Control, label: RichTextLabel) -> void:
	owner.focus_entered.connect(func() -> void:
		# Si el ratón está encima, ya se encarga el ratón / If the mouse is over it, the mouse handles it
		if owner.get_global_rect().has_point(owner.get_global_mouse_position()):
			return
		var ids: Array[String] = []
		var re := RegEx.new()
		re.compile("\\[url=(\\w+)\\]")
		for m: RegExMatch in re.search_all(label.text):
			if not ids.has(m.get_string(1)):
				ids.append(m.get_string(1))
		if ids.is_empty():
			return
		if not is_instance_valid(_tip):
			_tip = KeywordTip.new()
			owner.get_tree().root.add_child(_tip)
		_tip.show_many(ids, owner.get_global_rect()))
	owner.focus_exited.connect(hide_tip)
	owner.tree_exiting.connect(hide_tip)


static func hide_tip() -> void:
	if is_instance_valid(_tip):
		_tip.hide_tip()
