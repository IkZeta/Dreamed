#!/bin/bash
# Revisión antes de subir cambios: carga todos los scripts y recorre las pantallas del juego
# (tools/smoke_test.gd). Sale con error si el motor ha escrito algún «SCRIPT ERROR».
# Check before pushing: loads every script and walks the game's screens (tools/smoke_test.gd).
# Exits non-zero if the engine logged any "SCRIPT ERROR".
#
#   tools/check.sh [ruta/al/godot]      (por defecto «godot» / defaults to "godot")
#
# Usa una carpeta de guardado aparte, así que no toca tu partida. Con una pantalla (o Xvfb) dibuja
# de verdad; sin ella va en modo --headless.
# It uses its own save folder, so your progress is untouched. With a display (or Xvfb) it really
# draws; without one it runs --headless.
cd "$(dirname "$0")/.." || exit 2
GODOT="${1:-godot}"
LOG="${TMPDIR:-/tmp}/dreamed_smoke.log"
DATA="$(mktemp -d)"
cp project.godot "$DATA/project.godot.bak"
trap 'cp "$DATA/project.godot.bak" project.godot; rm -rf "$DATA"' EXIT
sed -i 's|^\[autoload\]|&\nSmokeTest="*res://tools/smoke_test.gd"|' project.godot
MODE="--headless"
if [ -n "$DISPLAY" ]; then MODE="--rendering-driver opengl3"; fi
XDG_DATA_HOME="$DATA" APPDATA="$DATA" timeout "${SMOKE_TIMEOUT:-900}" "$GODOT" $MODE --path . --audio-driver Dummy > "$LOG" 2>&1
errors=$(grep -c "SCRIPT ERROR\|Parse Error\|SHADER ERROR" "$LOG")
if ! grep -q "SMOKE DONE" "$LOG"; then
	echo "La prueba no ha terminado (se colgó o se cerró). Último paso / The test didn't finish. Last step:"
	grep "^SMOKE " "$LOG" | tail -1
	errors=$((errors + 1))
fi
if [ "$errors" -gt 0 ]; then
	echo "$errors error(s). Registro / Log: $LOG"
	grep -B1 -A5 "SCRIPT ERROR\|Parse Error\|SHADER ERROR" "$LOG" | grep -B30 "SMOKE\|ERROR" | head -60
	grep "^SMOKE " "$LOG" > "$LOG.steps"
	exit 1
fi
grep "SMOKE DONE" "$LOG"
echo "Sin errores / No errors"
