class_name Darkness
extends Node2D
## Evento "apagón": la habitación se queda a oscuras y solo se ve alrededor de Kroker.
## En el salón, si la chimenea está encendida, su lumbre también ilumina alrededor.
## "Blackout" event: the room goes dark and only the area around Kroker can be seen.
## In the living room, if the fireplace is lit, its glow lights up the area around it too.

const LIGHT := 300.0
const FIRE_LIGHT := 360.0
const SHADER := preload("res://assets/shaders/darkness.gdshader")

var run: Node
var _t := 0.0
var _fade := 0.0
var _fire := 0.0
var _glow: Node2D


func _ready() -> void:
	z_index = 45
	var m := ShaderMaterial.new()
	m.shader = SHADER
	material = m
	# El brillo cálido va aparte, sin el shader / The warm glow goes separately, without the shader
	_glow = Node2D.new()
	_glow.draw.connect(_draw_glow)
	add_child(_glow)


func _process(delta: float) -> void:
	_t += delta
	_fade = move_toward(_fade, 1.0 if run.running else 0.0, delta * 1.5)
	var lr := run.room as LivingRoom
	var lit := lr != null and lr.fire_lit and not lr.fire_used
	_fire = move_toward(_fire, 1.0 if lit else 0.0, delta * 0.8)
	var m := material as ShaderMaterial
	m.set_shader_parameter("fade", _fade)
	m.set_shader_parameter("light0", run.player.global_position + Vector2(0, -36))
	m.set_shader_parameter("radius0", LIGHT * (1.0 + 0.04 * sin(_t * 7.0) + 0.03 * sin(_t * 13.0)))
	if lr:
		# La lumbre parpadea más que la luz de Kroker / The firelight flickers more than Kroker's light
		var flick := 1.0 + 0.06 * sin(_t * 9.0) * sin(_t * 3.7) + 0.03 * sin(_t * 17.0)
		m.set_shader_parameter("light1", Bedroom.to_world(LivingRoom.FIREBOX.get_center() + Vector2(0, 120)))
		m.set_shader_parameter("radius1", FIRE_LIGHT * flick * _fire)
	queue_redraw()
	_glow.queue_redraw()


func _draw() -> void:
	if _fade > 0.0:
		# Sigue a la cámara (en el pasillo infinito se mueve) / Follows the camera (it moves in the endless hallway)
		var c: Vector2 = run._camera.position
		draw_rect(Rect2(c - Vector2(1360, 940), Vector2(2720, 1880)), Color.WHITE)


## Brillo cálido de la lumbre sobre la oscuridad / Warm firelight glow over the darkness
func _draw_glow() -> void:
	if _fade <= 0.0 or _fire <= 0.0:
		return
	var c := Bedroom.to_world(LivingRoom.FIREBOX.get_center() + Vector2(0, 120))
	var r := FIRE_LIGHT * 0.9
	_glow.draw_texture_rect(DreamBackground.soft_texture(), Rect2(c - Vector2(r, r * 0.7), Vector2(r, r * 0.7) * 2.0), false,
		Color("ff9a4a", (0.14 + 0.04 * sin(_t * 8.0)) * _fire * _fade))
