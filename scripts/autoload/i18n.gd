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

	# --- Más sueños / More dreams ---
	"RUN_INTRO_2": {"es": "Llegan los matones", "en": "Here come the thugs"},
	"RUN_INTRO_3": {"es": "Cuidado con los tirachinas", "en": "Watch out for the slingshots"},
	"RUN_INTRO_4": {"es": "Los huesos no se quedan quietos", "en": "The bones won't stay down"},
	"RUN_INTRO_5": {"es": "La habitación despierta", "en": "The bedroom wakes up"},
	"ENEMY_FINISH_IT": {"es": "¡Remátalo!", "en": "Finish it!"},
	"NEW_ENEMY_thug": {"es": "Matón: mucha vida y golpes fuertes, pero lento", "en": "Thug: lots of health and heavy hits, but slow"},
	"NEW_ENEMY_sling": {"es": "Tirachinas: dispara desde lejos; esquiva las piedras", "en": "Slingshot: shoots from afar; dodge the stones"},
	"NEW_ENEMY_skeleton": {"es": "Esqueleto: si cae, rompe sus huesos o volverá a levantarse", "en": "Skeleton: when it falls, smash its bones or it will get back up"},
	"BOSS_NAME": {"es": "La habitación despierta", "en": "The bedroom awakens"},
	"BOSS_PART_BED": {"es": "La cama", "en": "The bed"},
	"BOSS_PART_CHEST": {"es": "El baúl de juguetes", "en": "The toy chest"},
	"BOSS_PART_SHELF": {"es": "La estantería", "en": "The bookshelf"},
	"ACT1_CLEAR_TITLE": {"es": "Fin del Acto 1", "en": "End of Act 1"},
	"ACT1_CLEAR_SUB": {"es": "La habitación vuelve a dormir. Próximamente, Acto 2: el salón.", "en": "The bedroom falls back asleep. Coming soon, Act 2: the living room."},
	"RUN_INTRO_DEEP": {"es": "Cada vez más hondo", "en": "Deeper and deeper"},
	"RUN_SPECIAL_DEFEND": {"es": "E · Lanzar la almohada", "en": "E · Throw the pillow"},
	"RUN_SPECIAL_THROW": {"es": "E · Volver a defender", "en": "E · Back to defending"},

	# --- Plano astral / Astral plane ---
	"ASTRAL_TITLE": {"es": "Plano astral", "en": "Astral plane"},
	"ASTRAL_SUBTITLE": {"es": "Entre un sueño y otro, alguien te espera. Elige un don.", "en": "Between one dream and the next, someone is waiting. Choose a gift."},
	"ASTRAL_ACCEPT": {"es": "Aceptar el don", "en": "Accept the gift"},
	"UP_LEVEL": {"es": "Nivel %d", "en": "Level %d"},
	"UP_STOLK_COST": {"es": "Cuesta %d de vida máxima", "en": "Costs %d max health"},

	"GIVER_SVINHO_NAME": {"es": "Svinho", "en": "Svinho"},
	"GIVER_SVINHO_ROLE": {"es": "El futbolista", "en": "The footballer"},
	"GIVER_SVINHO_LINE": {"es": "«¡Joga bonito, Kroker! Todo lo que golpeas debería rebotar.»", "en": "“Joga bonito, Kroker! Everything you hit should bounce.”"},
	"GIVER_STOLK_NAME": {"es": "Stolk", "en": "Stolk"},
	"GIVER_STOLK_ROLE": {"es": "El matón del cole", "en": "The school bully"},
	"GIVER_STOLK_LINE": {"es": "«¿Quieres ser fuerte? Te va a doler.»", "en": "“Want to be strong? It's gonna hurt.”"},
	"GIVER_SILLY_NAME": {"es": "Silly", "en": "Silly"},
	"GIVER_SILLY_ROLE": {"es": "La hacker", "en": "The hacker"},
	"GIVER_SILLY_LINE": {"es": "«He encontrado un fallo en tu sueño. Vamos a usarlo.»", "en": "“I found a bug in your dream. Let's use it.”"},

	"UP_SVINHO_BAT_NAME": {"es": "Carambola", "en": "Carom"},
	"UP_SVINHO_BAT_DESC": {"es": "El enemigo golpeado sale volando y, si choca, golpea a {chain} enemigo(s) más con el {pct} % del daño.", "en": "The enemy you hit goes flying and, if it crashes, hits {chain} more enemy(ies) for {pct}% of the damage."},
	"UP_SVINHO_SHIELD_NAME": {"es": "Pase largo", "en": "Long pass"},
	"UP_SVINHO_SHIELD_DESC": {"es": "Pulsa E para lanzar la almohada: golpea a {hits} enemigo(s) con {dmg} de daño, cada {cd} s. Mientras, pierdes defensa. E de nuevo para defender.", "en": "Press E to throw the pillow: it hits {hits} enemy(ies) for {dmg} damage, every {cd} s. Meanwhile you lose defense. E again to defend."},
	"UP_SVINHO_BOOK_NAME": {"es": "Rebote de página", "en": "Page bounce"},
	"UP_SVINHO_BOOK_DESC": {"es": "Los rayos rebotan en {extra} enemigo(s) más.", "en": "Lightning bounces to {extra} more enemy(ies)."},
	"UP_SVINHO_VACUUM_NAME": {"es": "Chut", "en": "Volley"},
	"UP_SVINHO_VACUUM_DESC": {"es": "Cada {cd} s, la aspiradora escupe al enemigo que llega a la boquilla y sale rebotando ({dmg} de daño).", "en": "Every {cd} s, the vacuum spits out the enemy that reaches the nozzle and it ricochets away ({dmg} damage)."},

	"UP_STOLK_BAT_NAME": {"es": "Bate de matón", "en": "Bully's bat"},
	"UP_STOLK_BAT_DESC": {"es": "+{pct} % de daño con el bate.", "en": "+{pct}% bat damage."},
	"UP_STOLK_SHIELD_NAME": {"es": "Almohada de piedra", "en": "Stone pillow"},
	"UP_STOLK_SHIELD_DESC": {"es": "Los almohadazos hacen +{pct} % de daño y empujan +{push} %.", "en": "Pillow bashes deal +{pct}% damage and shove +{push}% harder."},
	"UP_STOLK_BOOK_NAME": {"es": "Libro de castigo", "en": "Detention book"},
	"UP_STOLK_BOOK_DESC": {"es": "Lanzas rayos un {pct} % más rápido.", "en": "You cast lightning {pct}% faster."},
	"UP_STOLK_VACUUM_NAME": {"es": "Turbo", "en": "Turbo"},
	"UP_STOLK_VACUUM_DESC": {"es": "+{pct} % de alcance, fuerza y daño de la aspiradora.", "en": "+{pct}% vacuum reach, pull and damage."},

	"UP_SILLY_BAT_NAME": {"es": "Golpe corrupto", "en": "Corrupted hit"},
	"UP_SILLY_BAT_DESC": {"es": "Cada golpe tiene un {chance} % de congelar al enemigo {secs} s con un glitch.", "en": "Each hit has a {chance}% chance to freeze the enemy for {secs} s with a glitch."},
	"UP_SILLY_SHIELD_NAME": {"es": "Desfase", "en": "Lag"},
	"UP_SILLY_SHIELD_DESC": {"es": "Cada almohadazo tiene un {chance} % de dejar al enemigo a cámara lenta {secs} s.", "en": "Each pillow hit has a {chance}% chance to put the enemy in slow motion for {secs} s."},
	"UP_SILLY_BOOK_NAME": {"es": "Rayo en bucle", "en": "Looping bolt"},
	"UP_SILLY_BOOK_DESC": {"es": "Cada rayo deja un eco: un segundo después se repite el {pct} % del daño.", "en": "Each bolt leaves an echo: one second later, {pct}% of the damage repeats."},
	"GIVER_DOC_NAME": {"es": "Doc", "en": "Doc"},
	"GIVER_DOC_ROLE": {"es": "El doctor", "en": "The doctor"},
	"GIVER_DOC_LINE": {"es": "«Abre la boca y di aaah. Te voy a dejar como nuevo... casi.»", "en": "“Open wide and say 'aaah'. I'll make you good as new... almost.”"},
	"UP_DOC_BAT_NAME": {"es": "Vitaminas", "en": "Vitamins"},
	"UP_DOC_BAT_DESC": {"es": "+{hp} de vida máxima, pero el bate hace un {pct} % menos de daño.", "en": "+{hp} max health, but the bat deals {pct}% less damage."},
	"UP_DOC_SHIELD_NAME": {"es": "Reposo", "en": "Bed rest"},
	"UP_DOC_SHIELD_DESC": {"es": "+{hp} de vida máxima, pero los almohadazos empujan un {pct} % menos.", "en": "+{hp} max health, but pillow bashes shove {pct}% less."},
	"UP_DOC_BOOK_NAME": {"es": "Jarabe", "en": "Cough syrup"},
	"UP_DOC_BOOK_DESC": {"es": "+{hp} de vida máxima, pero los rayos tardan un {pct} % más en salir.", "en": "+{hp} max health, but lightning takes {pct}% longer to come out."},
	"UP_DOC_VACUUM_NAME": {"es": "Escayola", "en": "Plaster cast"},
	"UP_DOC_VACUUM_DESC": {"es": "+{hp} de vida máxima, pero te mueves un {pct} % más lento.", "en": "+{hp} max health, but you move {pct}% slower."},
	"UP_SILLY_VACUUM_NAME": {"es": "Error de memoria", "en": "Memory leak"},
	"UP_SILLY_VACUUM_DESC": {"es": "Lo que absorbes recibe +{pct} % de daño durante {secs} s.", "en": "Whatever you suck in takes +{pct}% damage for {secs} s."},
}


func _enter_tree() -> void:
	for loc in LOCALES:
		var t := Translation.new()
		t.locale = loc
		for key: String in STRINGS:
			t.add_message(key, STRINGS[key][loc])
		TranslationServer.add_translation(t)
