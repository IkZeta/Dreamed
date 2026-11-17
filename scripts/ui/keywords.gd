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
	"bleed": {"es": "sangr\\w*", "en": "bleed\\w*", "pt": "sangr\\w*", "fr": "saign\\w*", "ca": "sagn\\w*", "zh": "流血"},
	"burn": {"es": "quem\\w*", "en": "burn\\w*", "pt": "queim\\w*", "fr": "brûl\\w*", "ca": "crem\\w*", "zh": "灼烧|燃烧"},
	"slow": {"es": "cámara lenta|ralentiz\\w*", "en": "slow motion|slows|slowing|slowed", "pt": "câmera lenta|desaceler\\w*", "fr": "ralenti\\w*", "ca": "càmera lenta|alent\\w*", "zh": "慢动作|减速"},
	"freeze": {"es": "congel\\w*", "en": "freez\\w*|frozen", "pt": "congel\\w*", "fr": "congel\\w*|gel(?:é|ée|és|ées|er)", "ca": "congel\\w*", "zh": "冻结|冰冻"},
	"glitch": {"es": "glitch\\w*", "en": "glitch\\w*", "pt": "glitch\\w*", "fr": "glitch\\w*", "ca": "glitch\\w*", "zh": "故障"},
	"fluff": {"es": "pelusas?", "en": "fluff", "pt": "fiapos?", "fr": "duvets?", "ca": "borrissols?", "zh": "绒毛"},
	"stuck": {"es": "pegad[oa]s", "en": "stuck", "pt": "grudad[oa]s?", "fr": "collé(?:e|s|es)?", "ca": "enganxat(?:s|da|des)?", "zh": "粘住"},
	"heavy": {"es": "golpes? fuertes?", "en": "heavy hits?", "pt": "golpes? fortes?", "fr": "coups? puissants?", "ca": "cops? forts?", "zh": "重击"},
	"knockback": {"es": "empuj\\w*", "en": "push\\w*|shov\\w*", "pt": "empurr\\w*", "fr": "repouss\\w*", "ca": "empeny\\w*|empent\\w*", "zh": "击退"},
	# Paralizado e inmovilizado son lo mismo / Paralysed and rooted are the same thing
	"rooted": {"es": "inmoviliz\\w*|clavad[oa]|paraliz\\w*", "en": "rooted|immobili\\w*|paraly\\w*", "pt": "imobiliz\\w*|paralis\\w*", "fr": "immobilis\\w*|paralys\\w*", "ca": "immobilitz\\w*|paralitz\\w*", "zh": "定身|麻痹"},
	"stench": {"es": "mal olor|peste|huel\\w* tan mal", "en": "stench|stink\\w*|smell\\w*", "pt": "mau cheiro|fedor\\w*", "fr": "puanteur|pu(?:e|ent) tellement", "ca": "pudor\\w*|fa tanta pudor", "zh": "恶臭"},
	"hack": {"es": "hacke\\w*", "en": "hack\\w*", "pt": "hacke\\w*", "fr": "hack\\w*", "ca": "hacke\\w*", "zh": "入侵"},
	"crit": {"es": "crític\\w*", "en": "critical|crits?", "pt": "crític\\w*", "fr": "critique\\w*", "ca": "crític\\w*", "zh": "暴击"},
	"defense": {"es": "defensa", "en": "defen[cs]e", "pt": "defesa", "fr": "défense", "ca": "defensa", "zh": "防御"},
	"luck": {"es": "suerte", "en": "luck", "pt": "sorte", "fr": "chance", "ca": "sort", "zh": "幸运"},
	"parry": {"es": "parry", "en": "parry", "pt": "parry", "fr": "parry", "ca": "parry", "zh": "格挡"},
	"attack_speed": {"es": "velocidad de ataque", "en": "attack speed", "pt": "velocidade de ataque", "fr": "vitesse d'attaque", "ca": "velocitat d'atac", "zh": "攻击速度"},
	"regen": {"es": "regeneración|recuperación de salud", "en": "regeneration|regen", "pt": "regeneração", "fr": "régénération", "ca": "regeneració", "zh": "生命恢复"},
	"lifesteal": {"es": "robo de (?:salud|vida)", "en": "lifesteal|life steal", "pt": "roubo de vida", "fr": "vol de vie", "ca": "robatori de vida", "zh": "吸血"},
	"reality": {"es": "Realidad Fragmentada", "en": "Fragmented Reality", "pt": "Realidade Fragmentada", "fr": "Réalité Fragmentée", "ca": "Realitat Fragmentada", "zh": "碎裂现实"},
	"bully": {"es": "abusón|indefens\\w*", "en": "bully|defen[cs]eless", "pt": "valentão|indefes\\w*", "fr": "caïd|sans défense", "ca": "abusó|indefens\\w*", "zh": "恃强凌弱|毫无防备"},
	"grudge": {"es": "revancha|fichad[oa]s?", "en": "payback|on (?:the|his|your) list", "pt": "revanche|na (?:sua )?lista", "fr": "revanche|sur (?:sa|ta|la) liste", "ca": "revenja|a la llista", "zh": "报复|记仇"},
	"plaster": {"es": "tiritas", "en": "plasters", "pt": "curativos", "fr": "pansements", "ca": "tiretes", "zh": "创可贴"},
	"rescue": {"es": "segunda opinión", "en": "second opinion", "pt": "segunda opinião", "fr": "deuxième avis", "ca": "segona opinió", "zh": "第二意见"},
}

static var _regex := {}
static var _tip: KeywordTip


## Devuelve el texto con las palabras clave resaltadas en BBCode / Returns the text with keywords highlighted in BBCode
static func markup(text: String) -> String:
	var lang := TranslationServer.get_locale().substr(0, 2)
	if not (PATTERNS["luck"] as Dictionary).has(lang):
		lang = "en"
	if not _regex.has(lang):
		var parts: Array[String] = []
		for id: String in PATTERNS:
			parts.append("(?<%s>%s)" % [id, PATTERNS[id].get(lang, PATTERNS[id]["en"])])
		var re := RegEx.new()
		if lang == "zh":
			# En chino no hay espacios entre palabras: sin límites de palabra (solo que no esté dentro de un [url=...])
			# Chinese has no spaces between words: no word boundaries (only not inside a [url=...])
			re.compile("(?<![\\[=])(?:%s)" % "|".join(parts))
		else:
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
	var src := TranslationServer.translate(text)
	l.text = markup(Settings.controls_text(src))
	# Si habla de controles, se actualiza al cambiar entre teclado y mando
	# If it mentions controls, it updates when switching between keyboard and gamepad
	if "{" in src and not l.has_meta("controls"):
		l.set_meta("controls", true)
		Settings.input_device_changed.connect(func(_pad: bool) -> void:
			if is_instance_valid(l):
				l.text = markup(Settings.controls_text(String(l.get_meta("controls_src"))))
		)
	l.set_meta("controls_src", src)


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
		# Esperar a que el botón esté colocado: al abrir una pantalla el foco llega antes de maquetar
		# y la tarjeta saldría en la esquina de arriba a la izquierda
		# Wait until the button has been laid out: when a screen opens, focus arrives before layout
		# and the card would show up in the top-left corner
		var tree := owner.get_tree()
		await tree.process_frame
		await tree.process_frame
		if not is_instance_valid(owner) or not owner.has_focus() or not owner.is_visible_in_tree():
			return
		var rect := owner.get_global_rect()
		if rect.size.x < 2.0 or rect.position == Vector2.ZERO:
			return
		if owner.get_global_rect().has_point(owner.get_global_mouse_position()):
			return
		if not is_instance_valid(_tip):
			_tip = KeywordTip.new()
			tree.root.add_child(_tip)
		_tip.show_many(ids, rect))
	owner.focus_exited.connect(hide_tip)
	owner.tree_exiting.connect(hide_tip)


static func hide_tip() -> void:
	if is_instance_valid(_tip):
		_tip.hide_tip()
