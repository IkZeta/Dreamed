extends CanvasLayer
## Contador de rendimiento en pantalla (Ajustes → Pantalla → «Mostrar rendimiento», o F3). Sirve
## para decir con números dónde baja: fotogramas por segundo, lo que tarda el fotograma medio y el
## peor del último segundo, órdenes de dibujo, objetos y, en partida, enemigos y efectos vivos.
## Lleva un historial de los últimos segundos en una gráfica mínima; el peor fotograma es el que
## delata los tirones aunque la media sea buena.
## On-screen performance counter (Settings → Display → "Show performance", or F3). It's there to
## say in numbers where things drop: frames per second, how long the average frame and the worst
## one of the last second take, draw calls, objects and, in a run, live enemies and effects. It keeps
## a history of the last few seconds in a tiny graph; the worst frame is the one that gives hitches
## away even when the average is good.

const HISTORY := 90
const GOOD := Color("9be38a")
const OKAY := Color("ffd36b")
const BAD := Color("ff7a7a")

var _panel: Control
var _frames := 0
var _acc := 0.0
var _worst := 0.0
var _last_us := 0
var _fps := 0.0
var _avg_ms := 0.0
var _worst_ms := 0.0
var _draws := 0
var _hist: PackedFloat32Array = []


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.draw.connect(_draw_panel)
	add_child(_panel)
	_last_us = Time.get_ticks_usec()
	visible = Settings.show_perf


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_F3:
		Settings.show_perf = not Settings.show_perf
		Settings.save_settings()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	visible = Settings.show_perf
	# Tiempo real entre fotogramas, sin que lo altere la cámara lenta ni la pausa
	# Real time between frames, unaffected by slow motion or pausing
	var now := Time.get_ticks_usec()
	var ms := (now - _last_us) / 1000.0
	_last_us = now
	if not visible:
		return
	_frames += 1
	_acc += ms
	_worst = maxf(_worst, ms)
	_hist.append(ms)
	if _hist.size() > HISTORY:
		_hist.remove_at(0)
	if _acc >= 500.0:
		_fps = _frames * 1000.0 / _acc
		_avg_ms = _acc / _frames
		_worst_ms = _worst
		_draws = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_frames = 0
		_acc = 0.0
		_worst = 0.0
	_panel.queue_redraw()


func _tone(ms: float) -> Color:
	return GOOD if ms <= 18.0 else (OKAY if ms <= 34.0 else BAD)


func _draw_panel() -> void:
	var font := UITheme.font("caps")
	var lines: Array = [
		["%d FPS" % roundi(_fps), _tone(_avg_ms)],
		["%s ms  ·  %s %s ms" % [_ms(_avg_ms), tr("PERF_WORST"), _ms(_worst_ms)], _tone(_worst_ms)],
		["%s %d  ·  %s %d" % [tr("PERF_DRAWS"), _draws, tr("PERF_NODES"), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))], UITheme.ASH],
	]
	var run := get_tree().current_scene as Run
	if run and run.enemies:
		lines.append(["%s %d  ·  %s %d" % [tr("PERF_ENEMIES"), run.enemies.get_child_count(), tr("PERF_FX"), run.fx._items.size() if run.fx else 0], UITheme.ASH])
	var w := 330.0
	var h := 22.0 * lines.size() + 44.0
	var at := Vector2(_panel.size.x - w - 16.0, _panel.size.y - h - 16.0)
	_panel.draw_rect(Rect2(at, Vector2(w, h)), Color(0.05, 0.04, 0.11, 0.72))
	var y := at.y + 20.0
	for l: Array in lines:
		UITheme.ink_text(_panel, font, Vector2(at.x + 10.0, y), l[0], 16, l[1], 1.0)
		y += 22.0
	# Gráfica: una barrita por fotograma, hasta 50 ms / Graph: one little bar per frame, up to 50 ms
	var gx := at.x + 10.0
	var gy := at.y + h - 8.0
	var bw := (w - 20.0) / HISTORY
	for i in _hist.size():
		var ms := _hist[i]
		var bh := clampf(ms / 50.0, 0.04, 1.0) * 26.0
		_panel.draw_rect(Rect2(gx + i * bw, gy - bh, maxf(1.0, bw - 1.0), bh), Color(_tone(ms), 0.85))
	# Línea de los 60 por segundo / The 60-a-second line
	_panel.draw_line(Vector2(gx, gy - 16.7 / 50.0 * 26.0), Vector2(at.x + w - 10.0, gy - 16.7 / 50.0 * 26.0), Color(1, 1, 1, 0.25), 1.0)


## Con coma o punto según el idioma, y un decimal / Comma or point by language, one decimal
func _ms(v: float) -> String:
	var s := "%.1f" % v
	return s.replace(".", ",") if TranslationServer.get_locale().begins_with("es") else s
