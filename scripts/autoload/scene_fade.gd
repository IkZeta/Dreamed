extends CanvasLayer
## Cambios de escena sin pantallazos grises: tapa la pantalla con un color (el del fogonazo o el
## fundido de quien cambia de escena), carga la escena nueva en segundo plano, la pone, espera a que
## se haya dibujado un par de veces (lo que tarde en prepararse queda escondido) y se destapa con un
## fundido suave. Si la espera se alarga, aparecen unas estrellitas girando para que se note que
## está soñando, no colgado.
## Scene changes without grey flashes: covers the screen with a colour (that of the flash or the
## fade of whoever changes scene), loads the new scene in the background, swaps it in, waits for it
## to be drawn a couple of times (whatever it takes to get ready stays hidden) and uncovers with a
## gentle fade. If the wait drags on, a few little stars spin so you can tell it's dreaming, not hung.

const INK := Color("0d0a1c")
const REVEAL := 0.45
## A partir de cuánto tiempo tapado salen las estrellitas / After how long covered the little stars appear
const STARS_AFTER := 0.35

var _rect: ColorRect
var _stars: Control
var _path := ""
var _loading := false
var _covered_t := 0.0
var _tw: Tween


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = INK
	_rect.modulate.a = 0.0
	add_child(_rect)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stars = Control.new()
	_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stars.modulate.a = 0.0
	add_child(_stars)
	_stars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stars.draw.connect(_draw_stars)
	visible = false


## Empieza a cargar una escena ya (por ejemplo, al pulsar Jugar, mientras dura la animación)
## Starts loading a scene right away (for instance, on pressing Play, while the animation plays)
func preload_scene(path: String) -> void:
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(path)


## Tapa con "color" al instante, cambia a "path" y se destapa cuando la escena nueva ya se ve
## Covers with "color" at once, switches to "path" and uncovers once the new scene shows
func go(path: String, color := INK) -> void:
	if _tw:
		_tw.kill()
	visible = true
	_rect.color = color
	_rect.modulate.a = 1.0
	_covered_t = 0.0
	_path = path
	_loading = true
	preload_scene(path)


func _process(delta: float) -> void:
	if not visible:
		return
	if _rect.modulate.a >= 0.99:
		_covered_t += delta
	_stars.modulate.a = move_toward(_stars.modulate.a, 1.0 if _covered_t > STARS_AFTER and _loading else 0.0, delta * 4.0)
	_stars.queue_redraw()
	if not _loading:
		return
	var st := ResourceLoader.load_threaded_get_status(_path)
	if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	_loading = false
	var ps: PackedScene = ResourceLoader.load_threaded_get(_path) if st == ResourceLoader.THREAD_LOAD_LOADED else load(_path)
	get_tree().change_scene_to_packed(ps)
	_reveal()


func _reveal() -> void:
	# Dos fotogramas de la escena nueva tapados (lo que tarde en prepararse no se ve) y fundido
	# Two frames of the new scene covered (whatever it takes to get ready isn't seen) and a fade
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if _loading:
		return
	_tw = create_tween()
	_tw.tween_property(_rect, "modulate:a", 0.0, REVEAL).set_trans(Tween.TRANS_SINE)
	_tw.parallel().tween_property(_stars, "modulate:a", 0.0, 0.2)
	_tw.tween_callback(func() -> void: visible = false)


## Estrellitas de cuatro puntas girando en el centro / Little four-point stars spinning in the middle
func _draw_stars() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var c := _stars.size * 0.5
	var light := _rect.color.get_luminance() > 0.5
	var col := Color("6a5ab8") if light else UITheme.GOLD
	for i in 5:
		var a := t * 1.6 + i * TAU / 5.0
		var p := c + Vector2(cos(a), sin(a)) * 34.0
		var r := 6.0 + 3.0 * sin(t * 4.0 + i)
		var pts := PackedVector2Array()
		for k in 8:
			var ang := t * 2.0 + k * PI / 4.0
			pts.append(p + Vector2.from_angle(ang) * (r if k % 2 == 0 else r * 0.38))
		_stars.draw_colored_polygon(pts, Color(col, 0.35 + 0.65 * (0.5 + 0.5 * sin(t * 3.0 + i))))
