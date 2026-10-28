extends Node
## Registra todas las cadenas del juego en español e inglés.
## Registers every game string in Spanish and English.
##
## Para añadir un texto nuevo: añade una clave aquí y usa la clave como `text`
## de cualquier Label/Button, o `tr("CLAVE")` en código.

const LOCALES: Array[String] = ["es", "en"]

const STRINGS := {
	# --- Menú principal / Main menu ---
	"GAME_SUBTITLE": {"es": "Cada oleada, un sueño dentro de otro", "en": "Every wave, a dream within a dream"},
	"MENU_PLAY": {"es": "Jugar", "en": "Play"},
	"MENU_SETTINGS": {"es": "Ajustes", "en": "Settings"},
	"MENU_QUIT": {"es": "Salir", "en": "Quit"},

	# --- Ajustes / Settings ---
	"SETTINGS_TITLE": {"es": "Ajustes", "en": "Settings"},
	"TAB_SOUND": {"es": "Sonido", "en": "Sound"},
	"TAB_LANGUAGE": {"es": "Idioma", "en": "Language"},
	"TAB_DISPLAY": {"es": "Pantalla", "en": "Display"},
	"SOUND_MASTER": {"es": "Volumen general", "en": "Master volume"},
	"SOUND_MUSIC": {"es": "Música", "en": "Music"},
	"SOUND_SFX": {"es": "Efectos", "en": "Sound effects"},
	"SOUND_MUTE": {"es": "Silenciar todo", "en": "Mute all"},
	"LANGUAGE_LABEL": {"es": "Idioma del juego", "en": "Game language"},
	"LANGUAGE_HINT": {"es": "El cambio se aplica al instante.", "en": "Changes apply instantly."},
	"DISPLAY_MODE": {"es": "Modo de pantalla", "en": "Window mode"},
	"MODE_WINDOWED": {"es": "Ventana", "en": "Windowed"},
	"MODE_FULLSCREEN": {"es": "Pantalla completa", "en": "Fullscreen"},
	"MODE_EXCLUSIVE": {"es": "Pantalla completa exclusiva", "en": "Exclusive fullscreen"},
	"DISPLAY_RESOLUTION": {"es": "Resolución (en ventana)", "en": "Resolution (windowed)"},
	"DISPLAY_VSYNC": {"es": "Sincronización vertical", "en": "Vertical sync"},
	"DISPLAY_FPS": {"es": "Límite de FPS", "en": "FPS limit"},
	"FPS_UNLIMITED": {"es": "Sin límite", "en": "Unlimited"},
	"DISPLAY_SHAKE": {"es": "Temblor de pantalla", "en": "Screen shake"},
	"BTN_BACK": {"es": "Volver", "en": "Back"},
	"BTN_RESET": {"es": "Restablecer", "en": "Reset defaults"},

	# --- Selección de personaje / Character select ---
	"SELECT_TITLE": {"es": "¿Qué soñará hoy Kroker?", "en": "What will Kroker dream tonight?"},
	"SELECT_SUBTITLE": {"es": "Siempre es Kroker. Cada noche se viste para un sueño distinto.", "en": "It's always Kroker. Every night he dresses for a different dream."},
	"SELECT_WEAPON": {"es": "Arma", "en": "Weapon"},
	"SELECT_BONUS": {"es": "Bonificación", "en": "Bonus"},
	"BTN_START": {"es": "Empezar a soñar", "en": "Start dreaming"},
	"STAT_ATTACK": {"es": "Ataque", "en": "Attack"},
	"STAT_DEFENSE": {"es": "Defensa", "en": "Defense"},
	"STAT_SPEED": {"es": "Velocidad", "en": "Speed"},
	"STAT_RANGE": {"es": "Alcance", "en": "Range"},

	"CHAR_BAT_NAME": {"es": "El Bateador", "en": "The Slugger"},
	"CHAR_BAT_TAG": {"es": "Equilibrado", "en": "Balanced"},
	"CHAR_BAT_WEAPON": {"es": "Bate", "en": "Bat"},
	"CHAR_BAT_BONUS": {"es": "+30 % de ataque", "en": "+30% attack"},
	"CHAR_BAT_OUTFIT": {"es": "Pijama de rayas", "en": "Striped pajamas"},
	"CHAR_BAT_DESC": {"es": "Golpea solo al enemigo más cercano, cuerpo a cuerpo. Sencillo y fiable.", "en": "Automatically strikes the nearest enemy up close. Simple and reliable."},

	"CHAR_SHIELD_NAME": {"es": "El Guardián", "en": "The Guardian"},
	"CHAR_SHIELD_TAG": {"es": "Defensivo", "en": "Defensive"},
	"CHAR_SHIELD_WEAPON": {"es": "Escudo-almohada", "en": "Pillow shield"},
	"CHAR_SHIELD_BONUS": {"es": "+3 de defensa", "en": "+3 defense"},
	"CHAR_SHIELD_OUTFIT": {"es": "Pijama de cuadros", "en": "Plaid pajamas"},
	"CHAR_SHIELD_DESC": {"es": "Sus almohadazos hacen poco daño, pero apartan a los enemigos con fuerza.", "en": "His pillow bashes deal little damage, but shove enemies far back."},

	"CHAR_BOOK_NAME": {"es": "El Cuentacuentos", "en": "The Storyteller"},
	"CHAR_BOOK_TAG": {"es": "A distancia", "en": "Ranged"},
	"CHAR_BOOK_WEAPON": {"es": "Libro", "en": "Book"},
	"CHAR_BOOK_BONUS": {"es": "Los rayos saltan entre enemigos", "en": "Lightning jumps between enemies"},
	"CHAR_BOOK_OUTFIT": {"es": "Pijama de estrellas", "en": "Starry pajamas"},
	"CHAR_BOOK_DESC": {"es": "Lanza rayos desde lejos y puede alcanzar a varios enemigos a la vez.", "en": "Casts lightning from afar and can hit several enemies at once."},

	"CHAR_VACUUM_NAME": {"es": "El Barrepesadillas", "en": "The Nightmare Sweeper"},
	"CHAR_VACUUM_TAG": {"es": "Arriesgado", "en": "Risky"},
	"CHAR_VACUUM_WEAPON": {"es": "Aspiradora", "en": "Vacuum cleaner"},
	"CHAR_VACUUM_BONUS": {"es": "+25 % de velocidad", "en": "+25% speed"},
	"CHAR_VACUUM_OUTFIT": {"es": "Pijama de lunares", "en": "Polka-dot pajamas"},
	"CHAR_VACUUM_DESC": {"es": "Apunta al enemigo más cercano y lo atrae hacia ti mientras lo daña. Arriesgado, pero rápido.", "en": "Aims at the nearest enemy and pulls it toward you while hurting it. Risky, but fast."},

	# --- Partida / Run ---
	"RUN_DREAM": {"es": "Sueño %d", "en": "Dream %d"},
	"RUN_WAVE1_INTRO": {"es": "Algo se mueve en la habitación", "en": "Something stirs in the bedroom"},
	"RUN_CONTROLS": {"es": "WASD o flechas para moverte · Esc para pausar · Tu arma ataca sola", "en": "WASD or arrows to move · Esc to pause · Your weapon attacks on its own"},
	"RUN_FOOX_LEFT": {"es": "Foox disipados: %d", "en": "Foox dispelled: %d"},
	"PAUSE_TITLE": {"es": "Pausa", "en": "Paused"},
	"PAUSE_RESUME": {"es": "Continuar", "en": "Resume"},
	"PAUSE_QUIT_RUN": {"es": "Abandonar el sueño", "en": "Leave the dream"},
	"WIN_TITLE": {"es": "Sueño superado", "en": "Dream cleared"},
	"WIN_NEXT_HINT": {"es": "Próximamente: antes del siguiente sueño elegirás una de dos mejoras.", "en": "Coming soon: before the next dream you'll pick one of two upgrades."},
	"LOSE_TITLE": {"es": "Kroker se ha despertado", "en": "Kroker woke up"},
	"BTN_DREAM_AGAIN": {"es": "Soñar de nuevo", "en": "Dream again"},
	"BTN_MAIN_MENU": {"es": "Menú principal", "en": "Main menu"},
}


func _enter_tree() -> void:
	for loc in LOCALES:
		var t := Translation.new()
		t.locale = loc
		for key: String in STRINGS:
			t.add_message(key, STRINGS[key][loc])
		TranslationServer.add_translation(t)
