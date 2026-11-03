class_name PadScroll
extends Node
## Desplazamiento con mando para una ScrollContainer que no cabe: mientras está "active" (p. ej.
## con su carta seleccionada) baja sola despacio, espera y vuelve arriba; si se mueve el stick
## derecho, manda el jugador. Se cuelga como hija de la ScrollContainer.
## Gamepad scrolling for a ScrollContainer that doesn't fit: while "active" (e.g. with its card
## selected) it slowly scrolls down by itself, waits and goes back up; if the right stick moves,
## the player takes over. It hangs as a child of the ScrollContainer.

const DEADZONE := 0.25
const STICK_SPEED := 420.0    # píxeles por segundo con el stick a fondo / pixels per second with the stick fully pushed
const AUTO_SPEED := 38.0      # píxeles por segundo bajando sola / pixels per second scrolling by itself
const WAIT_START := 1.0       # segundos antes de empezar a bajar / seconds before starting to scroll
const WAIT_END := 1.6         # segundos abajo antes de volver arriba / seconds at the bottom before going back up

signal overflow_changed(overflows: bool)

var active := false:
	set(v):
		if v != active:
			active = v
			_reset()
var _scroll: ScrollContainer
var _pos := 0.0
var _wait := WAIT_START
var _manual := false
var _overflows := false


func _ready() -> void:
	_scroll = get_parent() as ScrollContainer
	process_mode = Node.PROCESS_MODE_ALWAYS


## El stick derecho, de todos los mandos conectados (−1 arriba, 1 abajo)
## The right stick, from every connected gamepad (−1 up, 1 down)
static func right_stick() -> float:
	var best := 0.0
	for d in Input.get_connected_joypads():
		var v := Input.get_joy_axis(d, JOY_AXIS_RIGHT_Y)
		if absf(v) > absf(best):
			best = v
	return best if absf(best) > DEADZONE else 0.0


## Cuánto se puede bajar / How far down it can go
func max_scroll() -> float:
	if not _scroll:
		return 0.0
	var bar := _scroll.get_v_scroll_bar()
	return maxf(0.0, bar.max_value - bar.page)


func _reset() -> void:
	_pos = 0.0
	_wait = WAIT_START
	_manual = false
	if _scroll:
		_scroll.scroll_vertical = 0


func _process(delta: float) -> void:
	if not _scroll:
		return
	var top := max_scroll()
	var over := top > 1.0
	if over != _overflows:
		_overflows = over
		overflow_changed.emit(over)
	if not active or not over or not Settings.using_pad:
		return
	var stick := right_stick()
	if stick != 0.0:
		_manual = true
		_pos = clampf(_pos + stick * STICK_SPEED * delta, 0.0, top)
	elif not _manual:
		# Baja sola, espera abajo y vuelve arriba / Scrolls down by itself, waits at the bottom and goes back up
		if _wait > 0.0:
			_wait -= delta
		elif _pos < top:
			_pos = minf(top, _pos + AUTO_SPEED * delta)
			if _pos >= top:
				_wait = WAIT_END
		else:
			_pos = 0.0
			_wait = WAIT_START
	_scroll.scroll_vertical = int(_pos)
