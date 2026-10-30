class_name Demo
## Versión demo: sin los botones pensados para hacer pruebas (desbloquear todo, desbloquear el
## bestiario y los personajes, modo Dios) y con su propio guardado, para que no se mezcle con el
## progreso de las pruebas. Se activa exportando con la etiqueta de característica "demo" (el
## preset "Demo" de export_presets.cfg ya la lleva) o, para probarla en el editor, marcando
## Ajustes del proyecto > dreamed/demo.
## Demo build: without the testing buttons (unlock everything, unlock the bestiary and the
## characters, god mode) and with its own save, so it doesn't mix with the testing progress. It
## is turned on by exporting with the "demo" feature tag (the "Demo" preset in
## export_presets.cfg already has it) or, to try it in the editor, by ticking
## Project Settings > dreamed/demo.

const SETTING := "dreamed/demo"


static func on() -> bool:
	return OS.has_feature("demo") or bool(ProjectSettings.get_setting(SETTING, false))


## Ruta de guardado: la demo usa sus propios archivos / Save path: the demo uses its own files
static func save_path(path: String) -> String:
	return path.replace(".cfg", "_demo.cfg") if on() else path
