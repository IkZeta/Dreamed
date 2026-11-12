class_name CityProp
extends Node2D
## Árbol, seto, farola o banco / A tree, hedge, lamp or bench

var sprite := ""
var sway := false
var size := 1.0
var flip := false

## Los que se mecen (árboles, setos) lo hacen en la tarjeta gráfica con un sombreado compartido: el
## vaivén sale del tiempo y de dónde está cada uno, así que no gastan nada por fotograma (hay cientos)
## The swaying ones (trees, hedges) do it on the GPU with a shared shader: the sway comes from the
## time and where each one stands, so they cost nothing per frame (there are hundreds)
static var _sway_mat: ShaderMaterial


func _ready() -> void:
	scale = Vector2(Bedroom.S * size * (-1.0 if flip else 1.0), Bedroom.S * size)
	set_process(false)
	if sway:
		if _sway_mat == null:
			var sh := Shader.new()
			sh.code = """shader_type canvas_item;
void vertex() {
	float ph = MODEL_MATRIX[3].x * 0.013 + MODEL_MATRIX[3].y * 0.007;
	float a = sin(TIME * 1.3 + ph) * 0.02;
	VERTEX = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * VERTEX;
}"""
			_sway_mat = ShaderMaterial.new()
			_sway_mat.shader = sh
		material = _sway_mat


func _draw() -> void:
	Sprites.draw(self, sprite)
