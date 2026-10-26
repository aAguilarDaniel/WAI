# Who Am I — contexto del proyecto

Juego 2D pixel art hecho en Godot para la clase de Desarrollo de Videojuegos.
Autores: Daniel Felipe Aguilar Latorre (522709), Juan David Monsalve Niño (525559).

Este archivo es la fuente de verdad técnica. Los detalles de diseño están en:
- `docs/ARQUITECTURA.md` — estructura de código, autoloads, diagramas
- `docs/ARTE.md` — dirección de arte, referencias, pipeline de assets
- `docs/HITOS.md` — plan de trabajo por hitos (seguirlo en orden)

---

## 1. Qué es el juego

Plataformero 2D de acción, pixel art, ambientado en un post-apocalipsis futurista
donde la tecnología desplazó a la vida y se volvió la última religión. El
protagonista despierta sin recuerdos. La pregunta que sostiene todo el juego es
**"¿soy humano o soy una máquina más?"** — y el juego **nunca la responde
directamente**.

**El mecanismo central**: la respuesta la construye el jugador con **cómo juega**,
no con diálogos de decisión explícita. Las armas cuerpo a cuerpo y de fuego
empujan hacia lo humano; las de plasma y radiación empujan hacia lo máquina.
Evitar el combate también cuenta como humano. Eso mueve un eje interno (ver §3)
que cambia el tono narrativo, la tipografía del diario, la paleta y el final.

**Dos finales** (uno tercero posible en la ruta ambigua):
- Ruta humana → tono emotivo, valor de la vida, vínculo afectivo posible.
- Ruta máquina → tono bélico, acción seca, revelación temprana de que es una máquina.

**Referentes de jugabilidad**: Celeste (feel de plataformas), Rain World
(ambiente y hostilidad), Ultrakill (agresividad del combate), Hollow Knight
(estructura de jefes), Detroit: Become Human e *I Have No Mouth and I Must Scream*
(temática).

---

## 2. Stack y configuración

- **Motor**: Godot 4.x, rama estable. Antes de nada, corré `godot --version` y
  anotá la versión exacta en `README.md`. No uses APIs de Godot 3.
- **Lenguaje**: GDScript, **siempre con tipado estático**.
- **Resolución base**: `384x216` (escala entera ×5 = 1920x1080).
  - `display/window/stretch/mode = "viewport"`, `aspect = "keep"`.
  - `rendering/2d/snap/snap_2d_transforms_to_pixel = true`
  - `rendering/2d/snap/snap_2d_vertices_to_pixel = true`
  - Filtro de texturas: **Nearest**, mipmaps off.
- **Control**: teclado (WASD + espacio + botones de ataque/curar/interactuar) y
  mando. **Todo pasa por el InputMap**, nunca leas teclas físicas directamente.
- **Guardado**: `user://` en JSON versionado (campo `save_version`).

Acciones del InputMap (definilas en el Hito 0 y no las renombres después):
`mover_izq`, `mover_der`, `mirar_arriba`, `agachar`, `saltar`, `correr`,
`rodar`, `atacar`, `curar`, `interactuar`, `diario`, `cambiar_arma`.

---

## 3. Sistemas clave (especificación)

### 3.1 Eje Humanidad ↔ Máquina (`Alma`)

Autoload `Alma`. Un solo `float` en `[-1.0, 1.0]`:
`-1.0` = máquina total, `0.0` = neutro, `+1.0` = humano.

Reglas:
- **Nunca se muestra como número, barra ni porcentaje al jugador.** Se comunica
  solo por tipografía del diario, paleta, voz narrativa y reacción de los NPC.
- Cada arma tiene un `peso_hum` (ver §3.2). Al eliminar un enemigo se aplica.
- Terminar una zona sin matar a nadie da un empujón humano pequeño.
- Curarse con vendas (humano) vs. repararse en una terminal (máquina) también pesa.
- Umbrales: `<= -0.4` ruta máquina, `>= 0.4` ruta humana, en medio ruta ambigua.
- Emite `señal umbral_cruzado(estado_anterior, estado_nuevo)`. Los sistemas de
  UI, shader y audio se suscriben; **no consultan el valor cada frame**.
- El cambio debe ser lento y acumulativo, no una decisión puntual. Una sola
  acción nunca debe mover el eje más de `0.03`.

### 3.2 Armas (data-driven)

`Resource` `ArmaData` con: `nombre`, `tipo` (enum `MELEE, FUEGO, PLASMA, RADIACION`),
`daño`, `cadencia`, `retroceso`, `peso_hum: float`, `texto_diario: String`,
`sprite`, `sfx`. Las armas viven como archivos `.tres` en
`systems/weapons/data/`. **Agregar un arma nueva no debe requerir tocar código.**

`peso_hum` sugerido: melee `+0.02`, fuego `+0.01`, plasma `-0.02`, radiación `-0.03`.

### 3.3 El diario

Es el menú de pausa, pero diegético: **está escrito por el protagonista**. Pestañas:
Bitácora (misiones), Arsenal, Estadísticas, Ajustes (audio/gráficos/controles).

- Pausa real: `get_tree().paused = true`, el nodo del diario en
  `PROCESS_MODE_WHEN_PAUSED`.
- Al recoger un arma se escribe una entrada nueva **en primera persona**,
  redactada como si él estuviera descubriendo para qué sirve.
- **La tipografía es el medidor del eje.** Tres fuentes bitmap que se intercambian
  según `Alma`: manuscrita → híbrida → máquina de escribir. En ruta máquina el
  texto además tiene glitch y corrección automática de palabras emotivas.
- El diario aparece a los pocos minutos de empezar, no desde el frame 0. Antes de
  eso, pausar solo muestra un menú mínimo sin estilo.

### 3.4 Guardado + referencia a TV Buddha

Los puntos de guardado son PC/monitores CRT abandonados. Al interactuar:

1. La cámara corta a un **plano fijo, lateral, centrado y quieto**: el
   protagonista sentado en el suelo frente al CRT.
2. El CRT muestra **su propia imagen en vivo**, no un sprite pregrabado.
   Implementación: `SubViewport` con una `Camera2D` apuntando al jugador,
   su textura aplicada al material del monitor con shader de scanlines,
   deriva de color y ruido.
3. Se mantiene varios segundos sin música, solo el zumbido del tubo. El jugador
   puede irse cuando quiera.

Eso es una cita directa a *TV Buddha* de Nam June Paik y es el corazón temático
del juego: la criatura contemplando su propia imagen mediada por una máquina,
sin poder confirmar qué está viendo. **Es una escena de contemplación, no un menú
con una animación encima.** Tratala con ese peso.

### 3.5 Vida, muerte, curación

Vidas infinitas. Barra de salud simple. Al morir, reaparición en el último CRT.
Curación con vendas recogidas por el mundo (limitadas, consumibles). Sin
penalización dura por muerte más allá del retroceso.

---

## 4. Reglas de código (obligatorias)

- **Tipado estático siempre**: `var vel: Vector2 = Vector2.ZERO`,
  `func recibir_daño(cantidad: int) -> void:`. Nada de `var x = ...` sin tipo.
- **Composición sobre herencia**. Nada de un `Entidad` base de la que hereden
  jugador, enemigos y jefes. Usá componentes: `HealthComponent`, `HitboxComponent`,
  `HurtboxComponent`, `WeaponComponent`.
- El jugador usa una **máquina de estados** con un script por estado, no un
  `_physics_process` de 300 líneas con `if/elif`.
- **Señales sobre polling**. Nada de `get_node("/root/...")` regado por el código:
  autoloads por nombre, dependencias locales por `@export` o `@onready`.
- Nombres de archivos `snake_case.gd`, clases `PascalCase` con `class_name`.
- Código y comentarios **en español**, igual que el resto del proyecto.
- Cada script nuevo con un comentario de cabecera de 1–2 líneas: qué hace y quién
  lo usa.

## 5. Reglas de trabajo (obligatorias)

- **Seguí `docs/HITOS.md` en orden.** No adelantes hitos. Al terminar uno,
  parás y me mostrás qué hacer para probarlo en el editor.
- **No podés dibujar pixel art.** Todo asset visual es placeholder (rectángulos
  de color, `PlaceholderTexture2D`, formas simples) hasta que nosotros lo
  reemplacemos. Por cada placeholder que crees, agregá una fila a
  `art/PLACEHOLDERS.md` con: ruta del archivo final, dimensiones exactas en px,
  número de frames de animación y descripción de una línea. Esa tabla es nuestra
  lista de tareas de arte.
- El código debe estar escrito para que **cambiar el placeholder por el arte
  final no requiera tocar el código**, solo el recurso.
- Después de cada cambio, verificá que el proyecto importa sin errores:
  `godot --headless --quit --path .` y revisá la salida.
- **No hagas `git commit` ni `git push` sin que yo te lo pida.** Cuando commitees,
  mensajes en español y cortos (`feat: máquina de estados del jugador`).
- Si una decisión de diseño no está en estos documentos, **preguntá antes de
  inventarla**. No rellenes huecos narrativos por tu cuenta.
- Si algo que pido choca con el alcance de una entrega de clase, decímelo en vez
  de construirlo igual.

## 6. Alcance realista

El GDD describe un juego completo. Para una entrega de clase eso no se termina.
El objetivo real es una **rebanada vertical de 10–15 minutos** que demuestre
todos los sistemas: movimiento sólido, dos armas de cada bando, el eje funcionando
y visible en el diario, un CRT de guardado, un nivel con el paisaje sublime, y un
jefe. Si el tiempo alcanza, se extiende. Priorizá que lo que exista esté pulido
antes que exista más.

---

## 7. Decisiones tomadas durante el desarrollo

Esta sección la mantiene Claude Code al cerrar cada sesión. Son acuerdos que no
estaban en el diseño original y que ya están implementados.

### Alcance

- **El objetivo real de entrega son los hitos 0 a 5 más un nivel corto.** Los
  hitos 6, 7 y 8 son bonus. Acordado tras revisar la carga de arte: los sistemas
  se terminan, el pixel art de 7 capas de parallax y un jefe animado no.
- Recomendación abierta: usar **fuentes bitmap libres existentes** para las tres
  tipografías del diario en vez de dibujarlas. Tres fuentes con altura de
  mayúscula de 7 px es un proyecto en sí mismo.

### Motor y convenciones

- Godot **4.7.1.stable**, renderizador `gl_compatibility`.
- **Los identificadores que se guardan en `.tscn` o `.tres` no pueden llevar `ñ`
  ni tildes.** Se comprobó: un `@export var daño: int` compila en GDScript pero
  el valor del archivo **no se carga**, en silencio y sin error. Por eso el
  código usa `dano`, `mira`, etc. Los comentarios y los textos de cara al
  jugador sí van en español correcto.
- Por la misma razón, **un `@export var x: MiClase` cableado escribiendo
  `NodePath("...")` a mano en el archivo tampoco se resuelve**: hay que asignarlo
  arrastrando el nodo en el inspector. Los componentes traen un respaldo que
  busca su pareja dentro de la misma entidad si no se les asignó nada.
- El enum de rutas de `Alma` se llama `Ruta`, no `Estado`: `class_name Estado` ya
  existe (la clase base de los estados del jugador) y los `class_name` son globales.

### Jugabilidad

- **Referente de combate: Castlevania, en su versión moderna (Symphony of the
  Night).** Se toma el alcance largo con recuperación notable, el ataque en tres
  fases y los enemigos de patrón predecible. **No** se toma la rigidez del
  Castlevania de NES: el control aéreo, el perdón del salto y el knockback suave
  se mantienen como estaban, porque el referente de *feel* sigue siendo Celeste.
- **Rodar da invulnerabilidad, como en Dark Souls.** La ventana **no** cubre todo
  el rodar (0.18 s de 0.30 s, empezando a los 0.04 s), para que esquivar exija
  timing y no sea spam. Todo configurable en el inspector del jugador.
- El **ataque permite moverse a velocidad reducida** (40 %) y **se puede atacar en
  el aire**. Ambos con `@export`: poner `factor_velocidad_atacando` en 0 y
  `permitir_ataque_aereo` en false da el comportamiento del diagrama original.
- El **enemigo básico no ataca**: hace daño por contacto y persigue si te ve.
  Enemigos con ataque telegrafiado quedan para el jefe.
- **Muerte**: reaparece en la última `TerminalCRT` activada. Si todavía no tocó
  ninguna, en la posición inicial del nivel.

### El diario (Hito 4)

- `CLAUDE.md` §3.3 pedía el nodo del diario en `PROCESS_MODE_WHEN_PAUSED`. **Se
  cambió a `PROCESS_MODE_ALWAYS`**: con `WHEN_PAUSED` el diario no procesa input
  mientras el juego corre, así que no habría forma de abrirlo. La pausa real
  (`get_tree().paused = true`) funciona igual.
- Las tres fuentes bitmap no existen todavía. El código genera un sustituto con
  `FontVariation` para que el sistema se pueda ver y probar hoy; al asignar las
  fuentes reales en el inspector, el sustituto deja de usarse sin tocar código.
- El diccionario de "palabras emotivas autocorregidas" está vacío a propósito:
  es contenido narrativo y va en `docs/TEXTOS_PENDIENTES.md`.
- `empezar_con_todas` del `ComponenteArma` sigue en `true` para poder probar las
  cuatro armas. En el nivel real va en `false`, con el tubo de metal como
  recogible al principio.

### Guardado y CRT (Hito 5)

- **La recursión del `SubViewport` se resolvió por capas de visibilidad**, no por
  encuadre: la `Pantalla` está en `visibility_layer = 2` y el `SubViewport` tiene
  `canvas_cull_mask = 1`, así que no puede verse a sí misma. Era el riesgo que
  señalé al leer `CLAUDE.md` §3.4 y estaba confirmado: sin eso, Godot devuelve negro.
- **El retardo de la imagen cuesta**: un `get_image()` por frame sincroniza con la
  GPU. El `SubViewport` está apagado (`UPDATE_DISABLED`) salvo durante la escena.
  Si hiciera falta, `frames_de_retardo = 0` lo elimina y la imagen va en vivo.
- **Se implementaron las vendas** de `CLAUDE.md` §3.5, que el JSON de guardado
  necesitaba. Lo que **no** está es el "repararse en una terminal (máquina)" de
  §3.1: falta decidir si la terminal CRT sirve también para eso y con qué peso.
- Guardar es **silencioso y automático** al sentarse. No hay confirmación en
  pantalla: sería UI encima de una escena que `ARTE.md` §4 pide sin UI.

### Nivel 1 y Plano 1 (Hito 6)

- **El nivel se genera con una herramienta** (`tools/generar_nivel_01.tscn`), no
  se escribió a mano. Genera la estructura: terreno, parallax, checkpoints,
  enemigos y recogibles. **El diseño de niveles es suyo**: la colocación fina se
  hace en el editor, y volver a correr la herramienta pisa lo que editen.
- **Los límites de cámara los deriva `Nivel._ready()` del terreno.** Se descubrió
  que `PackedScene.pack()` **no guarda los cambios hechos a nodos internos de una
  escena instanciada**: ponerlos a mano desde la herramienta no sobrevivía al
  guardado. Derivarlos además se ajusta solo si agrandan el nivel.
- **La apertura no cambia de cámara.** Usa la del jugador con zoom y offset de
  apertura y los anima a los valores normales mientras devuelve el control. Es
  lo que hace que no haya corte, como pide `ARTE.md` §2.
- **Un `TileData` necesita pertenecer ya a un `TileSet`** para poder añadirle
  colisiones: hay que llamar a `add_source()` **antes** de `create_tile()`. Si no,
  `add_collision_polygon(0)` falla con "physics.size() = 0".
- Las 6 capas de parallax son placeholders de color plano. `art/PLACEHOLDERS.md`
  tiene las dimensiones exactas, el `scroll_scale` de cada una y la checklist de
  las cuatro reglas de John Martin.

### Animación del protagonista y legibilidad (sesión del tráiler)

- **El protagonista ya está animado.** Diez animaciones (`quieto`, `caminar`,
  `correr`, `saltar`, `caer`, `agachado`, `rodar`, `atacar`, `herido`, `sentado`)
  en `art/placeholder/jugador.png`, generadas con `herramientas/generar_jugador.py`.
  No es pixel art a mano: es una figura articulada rasterizada por código, o sea
  sigue siendo placeholder según §5. La rejilla y los nombres de fila **ya son los
  definitivos**, así que redibujarlo encima no toca código.
- **Un nodo `Animador` (`AnimadorJugador`) maneja el sprite**, suscrito a
  `MaquinaEstados.estado_cambiado`. El nombre de la animación es el del nodo de
  estado en minúsculas: no hay ni un `match` de estados. Le pregunta al jugador
  cuánto dura el estado (`duracion_rodar`, `duracion_total_ataque()`,
  `duracion_aturdimiento`) y escala la velocidad para que la animación entre justa.
  Así la voltereta termina exactamente cuando vuelve el control, y cambiar esos
  valores en el inspector reajusta la animación sola.
- **`Jugador.sentarse()` ya no achata el sprite**: reproduce `sentado`. El animador
  sostiene la pose porque durante la escena del CRT la máquina de estados se queda
  en `Quieto` y no emite nada.

#### Tres bugs que el teaser anterior escondía

Los tres estaban en el juego, no en el vídeo, y ninguno daba error:

1. **Las capas 4 y 5 del parallax eran más oscuras que el jugador.** El cuerpo es
   `(17, 13, 17)` y la capa 5 era `(9, 7, 11)`, así que la silueta desaparecía
   dentro del fondo mientras caminaba. Corregido en `generar_siluetas.py`: ninguna
   capa de fondo baja de `(39, 26, 32)`. La escalera completa está en
   `art/PLACEHOLDERS.md`. **El jugador tiene que ser lo más oscuro del cuadro.**
2. **Los proyectiles nacían a la altura de los pies.** `ComponenteArma` caía en
   `owner` como origen de disparo, y el origen del jugador está en los pies: el
   proyectil aparecía dentro del suelo, su hitbox tocaba la capa 1 y se liberaba
   en el mismo frame. **No se veía ni un disparo de las tres armas a distancia.**
   Ahora hay un `Marker2D` llamado `OrigenDisparo` a la altura del pecho y un
   respaldo que lo busca por nombre. De paso, el proyectil cuelga del nivel y no
   de quien dispara, que antes salía bien por accidente.
3. **La cámara del circuito del CRT nunca se encendía.** `CamaraCircuito` nace
   `enabled = false` en la escena y nadie la activaba, así que el `SubViewport` se
   renderizaba sin cámara — desde el origen del mundo. La pantalla mostraba el
   tile 0 del nivel con ruido verde encima, nunca al protagonista. **La cita a
   TV Buddha no funcionaba**, que es el corazón temático del juego (§3.4).
   `TerminalCRT.iniciar()` la enciende y `terminar()` la apaga.

#### El tráiler

- `herramientas/trailer.py` rueda y monta. Sustituye al montaje a mano de
  `capturas/mont/lista.txt`. El `GUION` de ese archivo **es** el montaje: qué
  plano, desde qué segundo y cuánto dura. Los planos se ruedan más largos de lo
  que se usan para poder mover el punto de entrada sin volver a grabar.
- Resultado: `capturas/WAI_trailer.mp4`, 14 planos, **1:31**, 1920×1080 a 60 fps.
  Y `WAI_trailer_ligero.mp4` para mandar. Sin audio: la música la ponen ustedes
  con `--musica ruta.mp3`.
- Se graba a 384×216 y se amplía ×5 con filtro NEAREST. Grabar directo a 1080p
  dejaría que el motor escalara con su propio filtro.
- **`captura.gd` tiene `zoom` por plano.** Los planos de paisaje se quedan en 1.0
  y los de mecánica suben a 1.5–1.9. Un personaje de 24 px en un cuadro de 384 es
  perfecto para el sublime de `ARTE.md` §3 e ilegible para *enseñar* una mecánica.
  Es lenguaje de tráiler: no toca la cámara del juego.
- Planos nuevos: `rodar`, `salto`, `pistola`, `plasma`, `radiacion`. El teaser
  anterior no enseñaba **ninguna** mecánica, porque con el protagonista estático
  rodar y saltar no se distinguían de caminar.

### Pulido para la sustentación (esta sesión)

Sesión pedida con el objetivo explícito de poder enseñarle el juego corriendo al
profesor: que las mecánicas se entiendan solas, que los enemigos tengan sentido y
que el cuadro tenga presencia. El tráiler **no se tocó**, por decisión suya.

#### Lo que estaba roto y no daba error

1. **Dos franjas grises en casi todos los encuadres.** La capa 1 del parallax era
   una textura de 216 px de alto y la cámara del nivel recorre unos 730 px de
   mundo: por encima y por debajo se veía el color de fondo de Godot. Se sustituyó
   por `shaders/cielo.gdshader` en una `CanvasLayer` a `layer = -100`, que no se
   puede quedar corta. La capa 1 pasó a ser bruma con transparencia.
2. **El terreno era más oscuro que la capa de fondo que tenía detrás.** Terreno
   `(34, 26, 30)` contra capa 5 `(39, 26, 32)`: el suelo se hundía en el fondo y
   el nivel se leía como una sola mancha marrón. Ahora el terreno es `(52, 38, 42)`
   con una ceja caliente de `(186, 116, 54)` en el canto: es lo único que hace que
   una plataforma se lea como plataforma a contraluz.
3. **`mostrar_estado` del jugador venía en `true`.** Había un "Quieto" flotando
   sobre la cabeza del protagonista en toda la partida, y en el tráiler.
4. **El HUD no enseñaba el arma equipada.** `BarraSalud._ready()` leía
   `duenio.arma`, que es un `@onready` del `Jugador`, y los `_ready()` de los hijos
   corren **antes** que el del padre: siempre valía `null`. Ahora busca el nodo
   por ruta.
5. **El primer abismo no se podía cruzar.** Medía 3 tiles (48 px) y un salto
   andando alcanza 44. Los abismos ahora están medidos contra el salto real y
   documentados en la tabla `ABISMOS` de la herramienta.

#### La legibilidad de la interfaz

- **Hay cuatro fuentes bitmap propias**, generadas por
  `herramientas/generar_fuentes.py` desde una rejilla de 5×7 px por glifo. Formato
  BMFont, `scaling_mode = 1` (solo escalas enteras), sin antialiasing. Resuelven la
  fila pendiente de `art/PLACEHOLDERS.md` y el punto de "usar fuentes bitmap libres
  existentes": salieron más baratas de generar que de buscar.
- Las tres del diario son **variantes de la misma base**, no tres alfabetos: lo
  que tiene que leerse es que es la misma mano la que cambia. El primer intento
  cizallaba las filas de cada glifo y era ilegible; el temblor mueve el glifo
  entero y nunca lo deforma.
- **`ui/tema_wai.tres` es el tema global** (`project.godot`, `gui/theme/custom`).
  Toda la UI nace con la fuente y la paleta correctas sin overrides uno por uno.
  Antes todo usaba el tema por defecto de Godot: una TTF a 16 px ampliada ×5 desde
  un cuadro de 384×216.

#### Cosas nuevas

- **Menú principal** (`ui/menu/menu_principal.tscn`), que ahora es la escena de
  arranque. Diegético: un monitor que arranca, el título tecleándose. Con
  `-- --saltar-menu` se entra directo al nivel, para desarrollar.
- **`CargadorEscenas.cambiar_a()`** está implementado (fundido + cambio de escena).
  Estaba declarado y vacío desde el Hito 0.
- **`Impacto`** (autoload): congelación de imagen y sacudida de cámara. Emite
  señales, no conoce a nadie.
- **`Efectos`**: chispas, polvo y restos. Clase de funciones estáticas, no autoload.
- **`CamaraJugador`**: sacudida y adelanto. Ojo: el encuadre propio va en
  `offset_base`, porque la sacudida escribe `offset` cada frame.
- **`PistaContextual`**: la tecla aparece solo si el jugador lleva unos segundos
  atascado sin haber usado nunca esa acción, lee el nombre del InputMap y no
  vuelve a salir. No es un tutorial y no dice los controles al empezar.
- **Audio**: `herramientas/generar_audio.py` sintetiza el ambiente en bucle y ocho
  efectos con la librería estándar. `DirectorAudio` los sirve por nombre desde una
  reserva de 8 reproductores.
- **`tools/prueba_nivel.tscn`**: un piloto automático recorre el nivel entero y
  dice en qué tile se atasca. Es lo que encontró el abismo imposible.

#### Decisiones que estaban pendientes y ahora están tomadas

- **`Alma.ESCALA` calibrada a 2.5.** Estaba en la lista de "pendiente de decisión
  del equipo: depende de cuántos enemigos tenga el nivel final". El nivel final
  tiene 9, y con ESCALA 1.0 el eje no cruzaba ningún umbral jugando. A 2.5 las tres
  rutas son alcanzables en una sola partida. **Si cambian el número de enemigos,
  hay que recalcular esto** (la tabla está en `juego/README.md`).
- **`empezar_con_todas` del `ComponenteArma` pasa a `false`.** El tubo de metal se
  recoge en el tile 52, antes del primer enemigo.
- **El nivel 1 se rediseñó como secuencia de lecciones.** Ya no es terreno por
  senos con enemigos cada 20 tiles: es una tabla escrita a mano, tramo por tramo,
  documentada en `tools/generar_nivel_01.gd` y en `juego/README.md`.
- **El enemigo básico ahora sí ataca**, con anticipación y ventana de castigo.
  Esto contradice la nota anterior de §7 ("el enemigo básico no ataca... enemigos
  con ataque telegrafiado quedan para el jefe"): se cambió porque un enemigo sin
  patrón no enseña nada y el nivel 1 tenía que enseñar a rodar y a atacar.

#### Tres cosas más, después de verlo correr

Reportadas jugando, las tres invisibles desde el código:

6. **Cuadrados negros flotando en el fondo.** Eran los bloques de la capa 5 del
   parallax. Su canto inferior quedaba a media pantalla: la imagen mide 216 px,
   estaba colocada 46 px más arriba y además subía y bajaba con la cámara
   (`scroll_scale.y = 0.22`). Con el jugador en alto, ese canto subía por encima
   del suelo. Ahora `scroll_scale.y = 0` y las imágenes se apoyan en el borde de
   abajo del cuadro: su base queda siempre detrás del terreno. De regalo, el
   horizonte de las siluetas coincide ahora con la hendidura del cielo, que antes
   quedaba 46 px más abajo.
7. **La TerminalCRT dejaba un recuadro negro al salir.** `crt.gdshader` devolvía
   siempre `alfa = 1.0`, así que apagar la pantalla (`encendido = 0.0`) no la
   apagaba: la dejaba en **negro opaco**. Ahora el alfa acompaña a `encendido`, y
   `terminar()` además suelta la textura para no quedarse con la última foto del
   jugador en memoria.
8. **Casi ninguna plataforma se alcanzaba.** Estaban a 4 y a 5 tiles del suelo
   (64 y 80 px) y el salto sube 48. La lanza de plasma, el emisor de radiación y
   la ruta alta de evasión eran inalcanzables. **Regla nueva: ninguna plataforma
   a más de 2 tiles de la superficie desde la que se salta**, porque para posarse
   encima hay que rebasar el canto y a 3 tiles se llega raspando.

#### Dos ajustes más, viéndolo ya jugable

9. **Los cuadrados negros seguían ahí después del arreglo anterior.** El primero
   solo corrigió que se vieran *flotando*; el problema de fondo era otro. La capa 5
   eran **rectángulos rellenos con el canto de arriba recto**, y a esa distancia
   eso no se lee como un edificio: se lee como una caja negra pegada al suelo que
   se mueve cuando te mueves. Ahora la capa 5 **no lleva ni un bloque macizo**:
   son torres de celosía, pasarelas colgadas y escombreras de perfil escalonado.
   Silueta calada en vez de masa, que además deja ver la brasa a través. A los
   bloques de la capa 4 se les mordió el remate y se les puso una antena, por lo
   mismo. **Regla nueva para las capas cercanas: nada con el canto superior recto.**
10. **Se quitó la pregunta del menú.** El subtítulo decía "¿soy humano o soy una
    máquina más?". Es la pregunta de §1, y ponerla escrita en la primera pantalla
    la contesta: deja de ser algo que el jugador se plantea y pasa a ser algo que
    el juego le dice. El nodo `Subtitulo` sigue en el árbol, vacío.

#### Lo que sigue pendiente

- Los **textos del diario** (`docs/TEXTOS_PENDIENTES.md`). El cuaderno del tile 78
  sigue con el marcador `[PENDIENTE]` y se ve en pantalla.
- El **diccionario de palabras autocorregidas** en ruta máquina sigue vacío.
- Los **iconos de arma** de los `.tres` siguen sin dibujarse: el Arsenal es texto.
- **Qué es una "zona"** para `Alma.registrar_zona_pacifica()`. Sigue sin llamarse
  desde ningún sitio, así que evitar el combate hoy deja el eje en 0 (ambiguo) en
  vez de empujarlo hacia lo humano.
- **Repararse en una terminal** (§3.1). Las vendas existen; la reparación no.

### Pendiente de decisión del equipo

- ~~**Calibrar `Alma.ESCALA`**~~ → hecho: 2.5, con el nivel 1 cerrado a 9 enemigos.
  Si cambian el número de enemigos, hay que recalcularlo.
- **Qué es una "zona"** para el empujón humano por no matar a nadie
  (`Alma.registrar_zona_pacifica()` ya existe, pero nadie la llama todavía).
- **Curarse con vendas vs. repararse en una terminal** (`CLAUDE.md` §3.1 dice que
  ambas cosas pesan en el eje). Las vendas existen; la reparación en terminal no.
  Falta decidir si la `TerminalCRT` también repara y cuánto mueve el eje.
- Los **textos del diario** están en `docs/TEXTOS_PENDIENTES.md`. Claude Code no
  los escribe. La cartela de cierre del tráiler usa la pregunta de §1; la otra
  cartela (`--cartela="..."`) sigue sin texto y por eso **no está en el montaje**.
- **Los iconos de arma no se ven en ninguna parte.** La pestaña Arsenal del diario
  es solo texto, así que el campo `sprite` de los `.tres` no se dibuja. O se pintan
  los iconos en el Arsenal, o esa fila de `art/PLACEHOLDERS.md` sobra.
- **El enemigo no tiene animación de muerte**: `queue_free()` y desaparece. En los
  planos de combate del tráiler se nota.
