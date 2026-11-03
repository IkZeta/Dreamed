# Dreamed

*Un roguelite de supervivencia en pixel art sobre un niño que sueña dentro de un sueño dentro de un sueño.*
*A pixel-art survival roguelite about a boy dreaming inside a dream inside a dream.* — [English summary below](#english-summary)

![Menú principal](docs/screenshots/menu.jpg)

Kroker es un niño con gafas y pelo negro que se queda dormido... y cada oleada es un sueño dentro del anterior, cada vez más raro y abstracto. Se juega como **Brotato**: el arma ataca sola y tú solo te mueves y esquivas. Entre sueño y sueño mejoras al estilo de **Hades**: en el plano astral aparecen dos personajes (tres desde el nivel 3 de Kroker) y cada uno te ofrece un don distinto.

- **Motor:** Godot 4.7, probado en **Godot 4.7.2**.
- **Idiomas:** español e inglés, que se cambian en Ajustes.
- **Controles:** teclado, ratón y mando. Los textos de controles cambian solos según uses teclado o mando.
- **Arte y sonido:** todo hecho con código, desde los sprites y la fuente hasta la música y los efectos (ver [Herramientas](#herramientas)).

---

## Cómo jugar

1. Abre `project.godot` con Godot 4.7.2 y pulsa **F5**.
2. En el menú principal, pulsa **Jugar** y elige un pijama: cada uno trae un arma distinta.
3. Sobrevive a cada sueño hasta que se acabe el tiempo. Tu arma ataca sola.
4. Recoge los **trozos de estrella** que sueltan los enemigos para subir de nivel.
5. Al acabar cada sueño, en el **plano astral**, elige uno de los dos dones que te ofrecen.
6. La partida se guarda al empezar cada sueño. Si sales, **Continuar** en el menú principal te devuelve al principio de ese sueño.

### Controles

| Acción | Teclado | Mando |
|---|---|---|
| Moverse | WASD o flechas | Stick izquierdo o cruceta |
| Modo especial (almohada de Svinho) | E | Y |
| Aceptar / avanzar diálogos | Intro, Espacio o clic | A |
| Volver | Esc | B |
| Pausa (con resumen de estadísticas y mejoras) | Esc | Start |
| Ver más en una ficha que no cabe | Rueda del ratón | Stick derecho |

El mando vibra al recibir golpes; se puede desactivar en *Ajustes → Accesibilidad*.

---

## Los pijamas

Siempre es Kroker, pero vestido distinto, y cada pijama trae su arma. Se empieza con cuatro y otros cuatro se desbloquean jugando. En la selección salen en páginas de cuatro, con una flecha a cada lado; los bloqueados se ven en silueta, con cómo se consiguen. Cada carta tiene una ficha con sus valoraciones y todas sus bonificaciones de serie; si no caben, la ficha se desplaza (con la rueda o, con mando, sola y con el stick derecho).

![Selección de personaje](docs/screenshots/seleccion.jpg)

| Pijama | Arma | Cómo ataca | De serie | Cómo se desbloquea |
|---|---|---|---|---|
| **El Bateador** | Bate | Golpe cuerpo a cuerpo al enemigo más cercano | +20 % de daño y 3 de regeneración | Desde el principio |
| **El Guardián** | Escudo-almohada | Poco daño, pero empuja mucho en cono | +4 de defensa, +5 de vida máxima, 2 de regeneración y algo más lento | Desde el principio |
| **El Cuentacuentos** | Libro | Hace caer de 1 a 3 rayos del cielo; cada uno golpea a un enemigo | −5 de vida máxima, −15 de suerte y 5 % de robo de salud | Desde el principio |
| **El Barrepesadillas** | Aspiradora | Atrae al enemigo al que apunta mientras lo daña. Si está a media vida o menos y lo arrastras por un agujero, se cae | +25 % de velocidad, +5 de vida máxima y 5 % de robo de salud | Desde el principio |
| **El Pistolero** | Pistola de dedos | Rayos láser con un efecto al azar: normal, atraviesa, empuja, crítico x1,75, rebota... o sale hacia atrás. La suerte hace más probables los buenos | +10 de suerte y 5 % de robo de salud | Llegar al Acto 2 |
| **El Abrazaosos** | Oso de peluche | Le arranca pelusa al osito y se la pega al enemigo: cada pelusa lo frena, los que se tocan se quedan pegados y una bola de 5 se aplasta | +6 de vida máxima y 3 de regeneración | Llegar al Acto 3 |
| **El Crack** | Pelota | La chuta al enemigo más cercano (poco alcance); rebota de uno a otro y vuelve. Mientras está en el aire no puede chutar otra | +15 % de daño, +20 % de velocidad, +6 de parry, −2 de defensa y −10 de suerte. Empieza con la mejora de Svinho a nivel 3 | Amistad 4 con Svinho |
| **El Ingeniero** | Portátil | Pone torretas que disparan solas y no desaparecen (ver abajo) | +3 de vida máxima, +5 de suerte y −15 % de velocidad de ataque | Amistad 4 con Silly |
| **El del 47** | Botas steampunk | Patadas propulsadas por los motores de las botas, en combo (ver abajo). Kroker las maneja con un mando pequeño en la mano | +10 % de velocidad, +1 de defensa y 2 de regeneración | Amistad 4 con Doc |

Cada pijama tiene un **post-it** con los actos que has superado con él (Actos I, II y III; estrella en normal, luna en pesadilla), al estilo de *The Binding of Isaac*. Superar un acto en pesadilla también marca el normal. Todo lo que tiene tiempo de recarga muestra un anillo de carga en la propia arma, como la stamina de *Zelda*.

### Las torretas del Portátil

- Como mucho hay **3 torretas de disparo** (más con Silly). Salen de tarde en tarde y, una vez puestas, se quedan; si una se queda muy lejos en el pasillo infinito, Kroker la recoloca.
- **Suben de nivel con el Ataque de Kroker**, también las que ya están puestas: nivel 2 con un 10 % (queman), 3 con un 25 % (empujan) y 4 con un 45 % (hacen sangrar). Cada nivel tiene un modelo más futurista; la de nivel 4 flota.
- Algunas mejoras traen **torretas especiales**, una de cada, que aparecen solas al empezar el sueño en sitios al azar y separadas (cerca de ellas no se pueden poner torretas de disparo):
  - **Doc:** torreta curativa que te dispara balas curativas si te falta vida.
  - **Stolk:** muñeco de boxeo que atrae a los enemigos cercanos y les da puñetazos con mucho empuje.
  - **Mr. Ad:** torreta dorada que apunta al enemigo con menos vida y remata a los que tienen menos del 15 %; cada remate da Realidad Fragmentada.
  - **El Pinche:** fogón que atrae enemigos y, si se juntan muchos a su lado, explota; al rato vuelve a aparecer.

### Las botas steampunk

- **Combo de tres golpes:** patada con la derecha, patada con la izquierda y un **giro** de 360° con la pierna estirada: es cuerpo a cuerpo como las patadas, hace poco daño pero **empuja mucho** a los que tiene al lado y **devuelve los proyectiles** que le llegan (vuelven dorados y dañan a los enemigos). Si pasa un rato sin atacar, el combo vuelve a empezar.
- **Dash:** pulsa **espacio** (R1 / RB en el mando). Kroker sale disparado hacia donde se mueve (o hacia donde mira si está quieto) con los motores a tope, no le pueden dar mientras dura ni un momento después (parpadea) y, si arrolla a un enemigo, le hace mucho daño y lo empuja lejos (sirve para tirarlos por los agujeros). Tiene su propio anillo de recarga.
- **Mejoras:** Svinho (Chilena: el pateado sale volando contra otros), Stolk (+daño), Silly (el dash se recarga antes y congela), Doc (vida máxima a cambio de patadas más lentas), Mr. Ad (+velocidad por cada 10 de Realidad Fragmentada) y el Pinche (las patadas queman).

---

## Los sueños

### Acto 1: la habitación (sueños 1–5)

![La habitación](docs/screenshots/habitacion.jpg)

Kroker se despierta, se pone las gafas y coge su arma. En cada sueño la habitación se corrompe un poco más: salen grietas, trozos de pared flotando y **agujeros** en el suelo y en la pared. Si empujas un enemigo a un agujero, cae y muere aunque le quede vida.

| Sueño | Enemigo nuevo |
|---|---|
| 1 | **Foox**: zorro fantasma, lento y frágil |
| 2 | **Matón**: enorme, mucha vida y golpes fuertes |
| 3 | **Tirachinas**: marca la trayectoria antes de disparar |
| 4 | **Esqueleto**: se desmonta y, si no rompes sus huesos, se vuelve a levantar |
| 5 | **Jefe: la habitación despierta**. Primero la cama, que salta y provoca un sismo; luego la estantería, que lanza libros; y por último el baúl, que huye y suelta enemigos |

### Acto 2: el salón (sueños 6–10)

![El salón](docs/screenshots/salon.jpg)

Tras vencer al jefe, el sueño se hunde un poco más y Kroker cae en el salón de casa: chimenea de piedra, sillón de la abuela, una tele antigua con nieve y un sofá que tapa a quien pasa por detrás.

| Sueño | Novedad |
|---|---|
| 6 | **Nidos y mosquitos**: el nido no se mueve, pero suelta mosquitos mientras no lo rompas. Los mosquitos son diminutos y frágiles, pero muy rápidos y salen a montones |
| 8 | **Cyberpunk** (raro, como mucho 2 a la vez): se lanza a base de dashes que marca antes en el suelo y, si se te queda cerca, te **hackea**: te baja una estadística al azar hasta que lo derrotas |
| 10 | **Jefe: El Chef**, un Kroker adulto cocinero que sale de la tele |

**El Chef** tiene tres ataques, todos avisados antes:

- **Cuchillos** en abanico: si te da uno, sangras durante un rato.
- **Sartenazo** de cerca: si te da, te quedas clavado medio segundo.
- **Platos** lanzados en arco a puntos marcados: al romperse dejan trozos en el suelo que hacen daño al pisarlos.

Con menos de la mitad de vida se enfada: ataca más a menudo y lanza más cosas.

El resto del salón:

- **Kioskera Charo** (*Karen* en inglés): la primera vez que llegas, te da la bienvenida y te explica dónde estás. De vez en cuando abre su kiosco para venderte cosas a cambio de **Realidad Fragmentada**. Una vez la conoces, también aparece tras el sueño 3 del Acto 1.
- **Realidad Fragmentada:** la moneda de Charo. Sale de lo que más guerra da y de lo que se cae y no vuelve... Una vez conoces a Charo, también se gana en el Acto 1 de las partidas siguientes. Tirar enemigos por los agujeros solo la da a veces (casi nunca durante un jefe).
- **El kiosco** tiene 16 artículos y mejora con cada acto: en el Acto 1 vende cosas flojas y baratas (4–5 ◆), en el 2 cosas medias (7–12 ◆) y en el 3 las mejores y más caras (14–24 ◆), como la tarta de cumpleaños (+5 de vida máxima), el pack de pilas (dos niveles) o el periódico del domingo (dos mejoras suben de nivel). Se puede pagar por **cambiar el mostrador**; los artículos ya comprados se quedan.
- **En la pausa** se ve lo que has comprado en el kiosco, con cuántos de cada (por ejemplo, *Pila del despertador x2*).
- **La chimenea:** en algunos sueños está encendida. Ponte delante y pulsa la **F** (A en el mando) para echar una de tus mejoras al fuego: pierde un nivel, pero ganas Realidad Fragmentada, más cuanto más nivel tenga (8, 12 o 16).

![El kiosco de Charo](docs/screenshots/kiosco.jpg)

### Segunda arma

Al vencer a El Chef eliges una **segunda arma**, siempre del otro tipo: si tu pijama lleva un arma cuerpo a cuerpo (bate, almohada, oso o botas), eliges una a distancia (libro, aspiradora, pistola de dedos, pelota o portátil), y al revés. Solo salen las que ya tengas desbloqueadas. Kroker lleva la segunda arma en la mano libre, ataca sola y tiene **sus propias mejoras**. En el plano astral, cada don tiene una pestaña por arma para decidir a cuál va.

### Acto 3: el pasillo del colegio (sueños 11–15)

![El pasillo del colegio](docs/screenshots/pasillo.jpg)

Un pasillo **infinito** hacia los lados, al estilo de la biblioteca de *Vampire Survivors*: la cámara sigue a Kroker entre taquillas, puertas de clase, baños, fuentes y vitrinas, todo con luz de anochecer. Las puertas se rompen y sirven de boquete para tirar enemigos.

| Sueño | Novedad |
|---|---|
| 11 | **Marionetas**: cada una sale con un brazo distinto: cuchilla (te hace sangrar), barra eléctrica (te paraliza) o arcabuz (bala potente, la marioneta sale despedida hacia atrás) |
| 13 | **Gólem de papel higiénico**: lento, con mucha vida y poca defensa. Si te pega, te deja **mal olor**: una de tus dos armas deja de atacar un rato |
| 14 | Kiosco de Charo |
| 15 | **Jefe: el Ovni** |

**El Ovni** pasa por el pasillo dando tumbos y lo destroza: quema las paredes, dispara láseres, abre agujeros en el suelo con su rayo y deja caer enemigos. Mientras vuela no se le puede dar; cada cierto tiempo se estrella justo donde está Kroker (con aviso en el suelo) y ahí sí, pero en el suelo suelta anillos de láseres con un hueco para esquivar. A media vida se enfada: más láseres, dos rayos a la vez y más enemigos. Al vencerlo se acaba la partida.

### Jefes con tiempo límite

Los jefes tienen cuenta atrás: 2:30 los muebles del Acto 1, 2:00 El Chef y 2:30 el Ovni. Si aguantas hasta el final, el jefe se retira y pasas igualmente. Si lo derrotas antes, te llevas **un nivel de regalo**.

- **La habitación despierta:** los muebles van uno detrás de otro y se mueven todo el rato. El baúl huye a ratos y luego se para, cansado y sudando: es el momento de pegarle.
- Todos los jefes son un 25 % más duros (atacan más a menudo y pegan más) en las dos dificultades.

### Eventos

Desde el sueño 2, algunos sueños traen un evento al azar:

- **Apagón:** solo ves alrededor de Kroker y, si la chimenea está encendida, alrededor del fuego.
- **Suelo inclinado:** todo resbala hacia un lado y luego hacia otro.
- **Timbre del colegio** (solo en el Acto 3, el más probable allí): avisa de que va a sonar, suena y durante un rato sale un montón de enemigos de las puertas.

Además, muy de vez en cuando aparece un **Foox dorado**: no hace daño y huye. Si lo pillas antes de que se esfume, te llueven estrellas.

![Apagón con la chimenea encendida](docs/screenshots/apagon.jpg)

### Élites

Son enemigos demoníacos, con cuernos, un contorno que late, ascuas que suben y el triple de vida. El color del contorno dice qué hacen:

- **Naranja:** al morir se parten en dos Foox.
- **Azul:** dejan charcos que te frenan.
- **Morado:** van mucho más rápido.

---

## Cómo mejora Kroker

### Plano astral

Entre un sueño y otro aparecen dos de estos personajes (tres desde el nivel 3 de Kroker). Cada uno da un tipo de mejora que cambia según tu arma y que sube hasta el nivel 3. Al elegir, te quedas a solas con él y te habla. Las palabras que hay que explicar (sangrado, suerte, parry...) salen resaltadas: pasa el ratón por encima, o selecciónalas con el mando, y sale una tarjeta que las explica.

| Personaje | Quién es | Tipo de mejora |
|---|---|---|
| **Svinho** | Futbolista brasileño | Rebotes: golpes que encadenan enemigos y una almohada que se lanza |
| **Stolk** | El matón del colegio | Mucho más poder a cambio de vida máxima |
| **Silly** | Una hacker | Glitches: congelar, ralentizar o dejar vulnerables a los enemigos |
| **Doc** | Un doctor | Más vida máxima a cambio de empeorar otra estadística |
| **Mr. Ad** | Un humanoide cubierto de anuncios de chocolatinas y comida basura | Más Realidad Fragmentada y una estadística que sube cuanta más tengas ahorrada. Se desbloquea al llegar por primera vez al Acto 2 (con un logro) y desde entonces puede salir desde el principio |
| **El Pinche** | El aprendiz de El Chef, con gorro de papel, cuchillo y soplete | Sangrado (daño residual fuerte) o quemadura (daño residual flojo, pero el enemigo hace menos daño y recibe más), según el arma. Se desbloquea al llegar por primera vez al Acto 3 |
| **Magnus** | Un magnate de los negocios detrás de su escritorio | **Inversiones**: le pagas Realidad Fragmentada y te sube varias estadísticas al momento, con un objetivo para el siguiente sueño (derrotar enemigos, tirarlos por agujeros, derrotar élites o no recibir muchos golpes). Si lo cumples, te las quedas y te devuelve más dinero; si no, te las quita y se queda el dinero. Se desbloquea al superar el Acto 3 |

![Magnus en el plano astral](docs/screenshots/magnus.jpg)

![Plano astral](docs/screenshots/plano-astral.jpg)

### Amistad

La amistad con cada personaje se guarda entre partidas y llega hasta el nivel 5.
- **Primera vez:** la primera vez que coges un don de alguien, se presenta con una frase única y todavía no admite propina.
- **Propina:** desde la segunda vez, en la charla puedes darle propina con Realidad Fragmentada (10 ◆ para el nivel 1, 13 para el 2, 16, 19 y 22). Solo una por personaje y partida. Al dársela te da las gracias; lo nuevo que tenga que contarte lo dirá la próxima vez que lo veas.
- **Mejores dones:** cada nivel de amistad mejora sus dones un 6 % (hasta un 30 %); en los de Doc, lo que empeora pesa menos y las recargas bajan.
- **Conversaciones:** cada personaje te cuenta algo distinto en cada nivel de amistad.
- **Charo:** en el kiosco también se le puede dar propina, una por partida. Su amistad no baja precios: da cambios gratis del mostrador (1 desde amistad 1 y 2 desde amistad 4), ofertas a mitad de precio (desde amistad 2) y más huecos (4 con amistad 3 y 5 con amistad 5). También cambia lo que te dice al saludarte.
- **Magnus:** con más amistad, sus tratos devuelven más dinero.
- **Pijamas nuevos:** la amistad 4 con Svinho desbloquea la pelota; con Silly, el portátil, y con Doc, las botas steampunk.
- **Dónde verla:** la amistad sale con corazones en el menú Personajes, en las cartas del plano astral y en el kiosco.

### Niveles

Los enemigos sueltan **trozos de estrella**; cuanto más duro es el enemigo, más sueltan. Al subir de nivel eliges 1 de 3 mejoras de estadística, cada una con su rareza: común, poco común, rara, épica o legendaria.

Las estadísticas son ataque, defensa, velocidad, velocidad de ataque, alcance, recuperación de salud, robo de salud, suerte y parry.

- La **suerte** hace más probables las rarezas altas, los consumibles y que vuelvan los personajes que ya te dieron un don. Puedes cambiar las tres opciones a cambio de 2 de suerte.
- El **parry** es una probabilidad de esquivar un golpe: Kroker chasquea los dedos y el que le iba a pegar, y hasta 3 enemigos de alrededor, caen fulminados (a los jefes solo les hace daño). Nunca pasa del 20 %.

### Consumibles

A veces un enemigo suelta un objeto, y la suerte hace que pase más a menudo:

- **Vaso de leche:** cura.
- **Almohada:** para el siguiente golpe.
- **Despertador:** congela a todos los enemigos.

### La vida y los estados

La vida no se rellena entre sueños: solo recuperas un 5 % de la vida máxima. Debajo de la vida, un indicador muestra los estados alterados que tienes en cada momento (sangrado, paralizado, mal olor, hackeado...). La hitbox de Kroker es solo el cuerpo: la cabeza no cuenta.

---

## Más

- **Dificultad Pesadilla:** se desbloquea al superar el Acto 1. Los enemigos tienen más vida y más daño, y salen más élites. En el jefe, los tres muebles atacan a la vez, aunque más despacio.
- **Plano astral (lobby):** opción del menú principal, al estilo de Hades. Es un archipiélago de islas flotantes de piedra astral unidas por puentes de piedras que flotan. En el centro está el cruce de los sueños, con una fuente de estrellas. A su alrededor aparece una isla por cada personaje que Kroker ya conoce, con un trozo de su mundo encima (césped, gimnasio, cocina, despacho...) y él haciendo lo suyo: Svinho chuta a portería, Stolk levanta la barra por encima de la cabeza en el gimnasio, Silly rueda en su silla de un monitor a otro con los cascos puestos, Doc pasa la lupa por un pie gigante en su clínica podológica, Mr. Ad salta hiperactivo de una tele a otra del escaparate con la cara en primer plano, el Pinche corre con el extintor por una cocina en llamas, Charo teje en su sillón y Magnus trabaja en su despacho. Las islas vecinas también están unidas entre sí por pasillos, así que no hace falta volver siempre al centro. Al acercarte puedes hablar con ellos con la **F** (o A en el mando): lore y lo que te cuentan según la amistad. También tiene:
  - **el armario**, con un maniquí por pijama (los que aún no tienes, con el soporte vacío);
  - **el museo**, que sustituye al bestiario: una estatua por cada enemigo que has visto, con su ficha al mirarla, y pedestales vacíos para los que faltan.
- **Desbloquear todo:** botón del menú principal (hay que pulsarlo dos veces) que desbloquea logros, pijamas, personajes, bestiario y la dificultad pesadilla.
- **Museo:** las estatuas son de piedra tallada y cada ficha está escrita con la voz de Kroker.
- **Logros:** hay 25 (entre ellos, vencer a El Chef, comprar en el kiosco, sacrificar en la chimenea, ahorrar 100 de Realidad Fragmentada y desbloquear la pelota, el portátil, las botas y a Magnus). Algunos pegan un dibujo infantil nuevo en la pared de la habitación.
- **Accesibilidad:**
  - intensidad de la sacudida de pantalla;
  - avisos para daltónicos;
  - números de daño;
  - vibración.
- **Al morir**, Kroker se despierta de golpe en su cama. **Al ganar**, duerme tranquilo y ves el resumen de la partida.

![El cruce de los sueños, en el plano astral](docs/screenshots/lobby.jpg)

![El museo, con las estatuas de los enemigos](docs/screenshots/bestiario.jpg)

### Modo Dios (para probar)

Se activa con el botón **Modo Dios** de la selección de personaje. Permite empezar en cualquier sueño (1–15), elegir una segunda arma y poner las mejoras de cada arma y las estadísticas que quieras. Desde el sueño 11, si no eliges segunda arma, se pone una de prueba. Las partidas en Modo Dios no se guardan. Si empiezas en el Acto 2, traes 30 ◆ para probar el kiosco.

Teclas durante la partida:

| Tecla | Efecto |
|---|---|
| **F** (Select en el mando) | Activa o desactiva la invulnerabilidad |
| **N** | Acaba el sueño, o el mueble, si estás en el jefe |
| **K** | Borra los enemigos |
| **L** | Sube de nivel |

### Demo

Hay tres exportaciones de demo (Windows, Linux y macOS) en `export_presets.cfg`. La demo se activa con la etiqueta de característica `demo` (o, para probarla en el editor, con *Ajustes del proyecto → dreamed/demo*). En la demo:

- no salen el Modo Dios ni los botones de desbloquear bestiario y personajes;
- **sí** está el botón «Desbloquear todo» del menú principal;
- el guardado va en archivos aparte (`*_demo.cfg`), para no mezclarse con el de las pruebas.

Para hacer una demo nueva basta con volver a exportar con esos presets.

---

## Estructura del proyecto

```
scenes/                 escenas principales (menú, selección, partida, plano astral, ajustes)
scripts/autoload/       I18n (textos ES/EN), Settings, GameState (datos y reglas), Progress (guardado y logros), Audio
scripts/game/           la partida: run.gd, bedroom.gd, living_room.gd, act3_room.gd, Kroker, enemigos, armas, jefes, HUD, efectos
scripts/ui/             menús, bestiario, logros, subida de nivel, plano astral, Charo y su kiosco, chimenea, tarjetas de palabras clave
scripts/visual/         dibujo de los sprites (Sprites, SpriteRects), Kroker, personajes y PixelView
assets/sprites/         sprites en pixel art (generados)
assets/audio/           música (.ogg) y efectos (.wav) (generados)
assets/fonts/           Dreampix, la fuente propia (generada)
assets/shaders/         contorno de los élites y oscuridad del apagón
tools/                  generadores de sprites, sonido y fuente
docs/screenshots/       capturas de este README
```

**Para cambiar el equilibrio del juego**, casi todo está a la vista en un solo sitio:

- **Oleadas:** `GameState.WAVES` (duración, enemigos, chimenea, kiosco).
- **Estadísticas base:** `GameState.BASE_STATS` y `GameState.BASE_LEVEL_STATS`.
- **Mejoras por nivel:** `GameState.UPGRADE_VALUES`.
- **Subidas de nivel y rarezas:** `GameState.STAT_STEPS` y `GameState.RARITY_WEIGHT`.
- **Kiosco y moneda:** `GameState.WARES` (nivel y precio de cada artículo), `GameState.WARE_TIER_WEIGHT` y `GameState.REALITY_*`.
- **Dureza de los jefes:** `GameState.BOSS_POWER` (un solo multiplicador para todos).
- **Tratos de Magnus:** `GameState.INVEST_SIZES` y `GameState.INVEST_GOALS`.
- **Tope del parry:** `GameState.PARRY_MAX`.
- **Daño, alcance y recarga de cada arma:** las constantes al principio de `scripts/game/weapon_*.gd`.
- **Textos:** `scripts/autoload/i18n.gd`, con cada clave en `es` y `en`.

## Herramientas

Todo el arte y el sonido se generan con los scripts de `tools/`:

| Script | Qué genera | Necesita |
|---|---|---|
| `make_sprites.py` | Dibuja cada pieza en SVG, la rasteriza con Chromium y la reduce a pixel art (paleta corta y contorno de 1 píxel). Crea `assets/sprites/*.png` y `scripts/visual/sprite_rects.gd` | Python 3, Pillow, Playwright con Chromium |
| `make_hub.py` | El terreno del plano astral píxel a píxel: islas de piedra astral con losas irregulares, canto, panza de roca con cristales y el suelo de cada personaje. Crea `assets/sprites/hub_isle_*.png` y `scripts/visual/hub_layout.gd` (posiciones y zonas por las que se anda). Los muebles del plano astral están en `hub_props.py` y los dibuja `make_sprites.py` | Python 3, numpy, Pillow |
| `make_audio.py` | Música y efectos con síntesis por modelado físico, siempre suaves | Python 3, numpy, scipy, ffmpeg (para .ogg) |
| `make_font.py` | La fuente pixel art Dreampix en formato BMFont | Python 3, Pillow |

```bash
python3 tools/make_sprites.py                     # todos los sprites
python3 tools/make_sprites.py npc_charo nest_body # solo esos
python3 tools/make_sprites.py hub               # solo los muebles del plano astral
python3 tools/make_hub.py                         # islas del plano astral
python3 tools/make_audio.py fire reality          # solo esos sonidos
python3 tools/make_font.py
godot --headless --path . --import                # que Godot importe lo nuevo
```

En los `.wav` nuevos hay que poner `compress/mode=0` en su `.import`, y en los que hacen bucle, también `edit/loop_mode=2`.

### Bot de equilibrio

`tools/balance_bot.gd` juega partidas enteras con cada pijama, acelerado y sin ventana, y guarda un informe con cómo acaba cada sueño: vida, nivel, Realidad Fragmentada y dónde muere. No es un jugador experto, así que sirve para **comparar** pijamas y cambios, no para medir la dificultad exacta.

1. Añade `B="*res://tools/balance_bot.gd"` en `[autoload]` de `project.godot` (sin subirlo).
2. Ejecuta:

```bash
godot --headless --path . --audio-driver Dummy -- --bot-runs=2   # 2 partidas por pijama
```

El informe queda en `user://balance_report.json`.

---

## English summary

**Dreamed** is a Brotato-style survival roguelite with Hades-style upgrades, made in Godot 4.7 (tested on 4.7.2), fully playable in **English and Spanish**.

- **Kroker:** a boy with glasses who falls asleep. Every wave is a dream inside the previous one, each stranger than the last.
- **Eight pajamas, eight auto-attacking weapons:** bat, pillow shield, storybook (lightning from the sky) and vacuum from the start; a finger gun (Act 2) and a teddy bear (Act 3) unlocked by playing; a bouncing football (friendship 4 with Svinho) and a laptop that places permanent turrets which level up with your attack (friendship 4 with Silly). The character select shows them in pages of four, each card with a full stat sheet.
- **Act 1, the bedroom:** Foox, thugs, slingshots and skeletons, then the living furniture: a bed, a bookshelf and a toy chest that runs away and gets tired.
- **Act 2, the living room:** mosquito nests, hacking Cyberpunks, a fireplace where you can sacrifice upgrades, *Karen the kiosk lady*, who trades in **Fragmented Reality**, and **The Chef**, a grown-up Kroker who climbs out of the TV.
- **Act 3, the endless school hallway at dusk:** puppets with random weapons, toilet-paper golems whose stench disables one of your weapons, a school-bell event, and **the UFO**, which wrecks the hallway, crashes down on you and fires rings of lasers.
- **Second weapon:** after The Chef you pick a second weapon of the other kind (melee or ranged), with its own upgrades.
- **Upgrades:** on the astral plane, Svinho, Stolk, Silly, Doc, Mr. Ad, the Kitchen Boy and **Magnus** (a magnate who lets you invest: pay for several stat boosts and keep them, with interest, if you meet his goal) each offer a different kind of upgrade. Star shards level Kroker up with stat boosts from common to legendary, including **parry**: a chance to dodge a hit and finger-snap the attacker and nearby enemies away.
- **Karen's kiosk** sells better and pricier items each act; friendship with her gives free restocks, half-price offers and more slots.
- **Extras:** Nightmare difficulty, a bestiary, 24 achievements, hover cards that explain keywords and status effects, accessibility options, full gamepad support (the UI adapts to keyboard or gamepad), a God mode for testing and demo builds for Windows, Linux and macOS.
- **Running it:** open `project.godot` and press **F5**. All sprites, sounds and the font are generated by the scripts in `tools/`.
