extends SceneTree
## Vuelca las cadenas originales (español e inglés) a tools/i18n/source.json, para traducir.
## Dumps the original strings (Spanish and English) to tools/i18n/source.json, for translating.
## godot --headless --script tools/i18n_dump.gd

func _init() -> void:
	var src: Script = load("res://scripts/autoload/i18n.gd")
	var d: Dictionary = src.get_script_constant_map()["STRINGS"]
	var out := {}
	for k: String in d:
		out[k] = {"es": d[k]["es"], "en": d[k]["en"]}
	var f := FileAccess.open("res://tools/i18n/source.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t", false))
	print("%d cadenas / strings" % out.size())
	quit()
