# Who Am I

Plataformero 2D pixel art. Trabajo para la clase de Desarrollo de Videojuegos.

Daniel Felipe Aguilar Latorre (522709) · Juan David Monsalve Niño (525559)

## Motor

**Godot 4.7.1.stable.official** (`a13da4feb`)

Renderizador: `gl_compatibility`. El juego es 2D puro y no usa iluminación ni
efectos 3D, así que este backend corre en cualquier integrada y evita problemas
en las máquinas del laboratorio. Si algún shader necesitara Forward+, se cambia
en Proyecto → Ajustes → Rendering → Renderer.

## Cómo abrirlo y jugarlo

1. Abrir Godot → **Importar** → seleccionar `juego/project.godot`.
2. **F5**. La escena principal es `ui/menu/menu_principal.tscn`. Desde ahí,
   *DESPERTAR* entra al nivel 1.

Sin abrir el editor:

```
godot --path juego                        el juego, desde el menú
godot --path juego -- --saltar-menu       entra directo al nivel 1
```

`--saltar-menu` es un atajo de desarrollo: sirve para probar el nivel sin pasar
por el menú veinte veces al día.

> Si crean scripts desde fuera del editor, Godot puede quejarse de
> `Could not find base class`. El caché de clases globales lo genera el editor:
> abrirlo una vez, o correr `godot --headless --editor --quit --path juego`.

## Cómo verificar que no hay errores sin abrir el editor

```
godot --headless --quit --path juego
```

Importa todos los recursos, arranca los autoloads y sale. Si imprime errores,
hay algo roto. Correr esto después de cada cambio.

## Configuración base

| Ajuste | Valor | Por qué |
|---|---|---|
| Resolución interna | 384×216 | Escala entera ×5 → 1920×1080 |
| Stretch | `viewport` / `keep` | Escala la imagen completa sin deformar |
| Filtro de textura | Nearest (`0`) | Píxeles duros al ampliar |
| Snap 2D transforms | activado | Evita píxeles a medias al mover nodos |
| Snap 2D vertices | activado | Igual, para la geometría |

## Controles

| Acción | Teclado | Mando |
|---|---|---|
| `mover_izq` / `mover_der` | A / D | D-pad ← → · stick izq. X |
| `mirar_arriba` / `agachar` | W / S | D-pad ↑ ↓ · stick izq. Y |
| `saltar` | Espacio | A |
| `correr` | Shift | RB |
| `rodar` | Ctrl | B |
| `atacar` | J | X |
| `curar` | K | Gatillo izq. |
| `interactuar` | E | Y |
| `cambiar_arma` | Q | LB |
| `diario` | Tab | Start |
| `debug_alma` (temporal) | F3 | — |

`cambiar_arma` rota por el arsenal. `atacar` usa el arma equipada: melee o disparo
según el `.tres`.

`debug_alma` es el indicador del eje del Hito 3 y **se elimina en el Hito 8**.

Todo el input pasa por el InputMap. Nunca leer teclas físicas directamente en
el código: usar `Input.is_action_pressed("saltar")`, no `KEY_SPACE`.

## Documentación

La fuente de verdad está un nivel arriba: `../CLAUDE.md`, `../docs/ARQUITECTURA.md`,
`../docs/ARTE.md`, `../docs/HITOS.md`.

## Capas de colisión

| Capa | Nombre | Quién está |
|---|---|---|
| 1 | `mundo` | Plataformas y paredes (`StaticBody2D`) |
| 2 | `jugador` | Cuerpo del protagonista (`CharacterBody2D`) |
| 3 | `enemigos` | Cuerpo de los enemigos |
| 4 | `hitbox_jugador` | El golpe del jugador. Solo escanea la 7 |
| 5 | `hurtbox_jugador` | El cuerpo vulnerable del jugador |
| 6 | `hitbox_enemigo` | El contacto dañino del enemigo. Solo escanea la 5 |
| 7 | `hurtbox_enemigo` | El cuerpo vulnerable del enemigo |

Cada hitbox solo escanea la hurtbox del bando contrario. Por eso nadie se pega a
sí mismo **sin un solo `if` comprobando quién es quién**: lo resuelven las capas.

## Animación del jugador

El nodo `Animador` (`actors/player/animador_jugador.gd`) se suscribe a
`MaquinaEstados.estado_cambiado` y reproduce la animación que se llame **igual que
el nodo de estado, en minúsculas**. Esa es la única regla: no hay un `match` de
estados en ninguna parte, y añadir un estado con su animación del mismo nombre ya
funciona.

Dos cosas que hace y que no son obvias:

- **Encaja la animación en lo que dura el estado.** Le pregunta al jugador
  (`duracion_rodar`, `duracion_total_ataque()`, `duracion_aturdimiento`) y escala
  `speed_scale`. Por eso la voltereta termina exactamente cuando vuelve el control.
  Si cambian esos valores en el inspector, la animación se reajusta sola.
- **Acompasa `caminar` y `correr` a la velocidad real.** Sin eso los pies patinan
  cada vez que acelera o frena.

El spritesheet y sus 10 animaciones están descritos en `art/PLACEHOLDERS.md`. Se
regenera con:

```
python herramientas/generar_jugador.py --contacto
python herramientas/generar_sprite_frames.py
```

`--contacto` escribe `capturas/hoja_jugador.png`, la hoja de contacto ampliada,
para revisar las poses sin abrir Godot.

## Componentes (composición, no herencia)

`ComponenteSalud`, `ComponenteHitbox` y `ComponenteHurtbox` viven en
`systems/components/`. Jugador y enemigo usan **los mismos tres nodos**; lo único
que cambia son las capas de colisión y los valores del inspector.

Convención: si a una `Hurtbox` o a la `BarraSalud` no se les asigna la propiedad
`salud` en el inspector, buscan automáticamente el `ComponenteSalud` que cuelga
de la misma entidad.

> **Trampa de Godot que ya nos mordió:** un `@export var x: MiClaseDeNodo` se
> guarda en el `.tscn` como `NodePath("...")`, pero la conversión de vuelta a
> `Node` la hace el editor. Si se escribe esa línea a mano en el archivo, la
> propiedad queda en `null` **sin ningún error**. Asignar esas referencias
> arrastrando el nodo en el inspector, o dejar que el fallback las resuelva.

## Armas (data-driven)

Cada arma es un `.tres` en `systems/weapons/data/`. `ComponenteArma` **escanea esa
carpeta al arrancar**, así que agregar un arma es soltar un archivo ahí: no hay
ninguna lista que actualizar ni código que tocar.

| Arma | Tipo | Daño | Cadencia | `peso_hum` | Alcance |
|---|---|---|---|---|---|
| Tubo de metal | Melee | 2 | 0.32 s | **+0.02** | cuerpo a cuerpo |
| Pistola reciclada | Fuego | 1 | 0.28 s | **+0.01** | proyectil |
| Lanza de plasma | Plasma | 2 | 0.45 s | **−0.02** | proyectil |
| Emisor de radiación | Radiación | 3 | 0.70 s | **−0.03** | proyectil |

El arsenal se ordena de más humana a más máquina, así que se arranca con el tubo.

Cada arma a distancia apunta a **su propia escena de proyectil**
(`proyectil_bala.tscn`, `proyectil_plasma.tscn`, `proyectil_radiacion.tscn`), que
solo se diferencian en el sprite. La hitbox es 6×3 en las tres.

> **Trampa que ya nos mordió:** los proyectiles nacen del `Marker2D`
> `OrigenDisparo` del jugador, a la altura del pecho, **no del jugador**. El
> origen del jugador está en los PIES: un proyectil que nazca ahí aparece dentro
> del suelo, su hitbox toca la capa 1 y se libera en el mismo frame en que se
> dispara. Estuvimos sin ver un solo disparo y sin ningún error en consola.

## Los enemigos

`actors/enemies/enemigo_patrulla.tscn`. Una máquina de mantenimiento con un
monitor donde iría la cara (`ARTE.md` §5: rostros sustituidos por pantallas).

**Antes no atacaba**: caminaba hacia ti y hacía daño por contacto. Eso no es un
enemigo, es un obstáculo móvil, y no se podía aprender nada de él. Ahora tiene el
patrón predecible que pide el referente de Castlevania:

```
PATRULLA  pantalla apagada, anda despacio, gira en los bordes
   |  te ve
ALERTA    se para, enciende la pantalla en verde, 0.5 s       <- el aviso
   |
PERSECUCIÓN  camina hacia ti
   |  de cerca (46 px)
ANTICIPACIÓN  se echa atrás e inclina, la luz se pone roja     <- AQUÍ SE ESQUIVA
   |  0.45 s
EMBESTIDA  rápido y recto; NO gira, o no se podría esquivar
   |  0.42 s
ATURDIDO   parado 0.9 s y sin hacer daño por contacto          <- AQUÍ SE CASTIGA
```

Esas dos ventanas **son el combate entero**: la anticipación te dice cuándo rodar
y el aturdimiento es cuando pegar sale gratis. Todos los tiempos son `@export`.

Dos detalles que hacen que se lea a 20 px de alto:

- **El halo.** Un `Sprite2D` aditivo detrás del monitor que se apaga en patrulla,
  se enciende en verde al verte y late en rojo mientras se prepara. La pantalla
  encendida sola no se ve a ese tamaño. Cada enemigo lo desfasa según su posición
  en el nivel: si latieran a la vez se leerían como un solo sistema.
- **La inclinación.** El sprite se inclina hacia atrás al prepararse, hacia
  delante al embestir y se queda torcido al aturdirse. Es la única forma de que la
  embestida se lea como embestida sin dibujar frames nuevos.

Un golpe recibido en plena ANTICIPACIÓN la **cancela** y lo manda a ATURDIDO:
castigar la preparación tiene que servir de algo o el patrón no se puede jugar.
Al morir suelta chatarra, un fogonazo verde de tubo reventado y para la imagen.

## El eje del alma

`Alma` es un `float` en `[-1, 1]`. **Nunca se le muestra al jugador** como número
ni barra: se comunica por tipografía, paleta y voz narrativa (`CLAUDE.md` §3.1).

El flujo, y por qué está montado así:

```
ComponenteHitbox --mato(objetivo)--> ComponenteArma --registrar(peso)--> Alma
                                                                          |
                                              umbral_cruzado(anterior, nueva)
                                                     |            |         |
                                                  Diario       Shader     Audio
```

`ComponenteArma` es el **único** archivo del proyecto que nombra a `Alma`. Los
enemigos y las hitboxes no saben que el eje existe: solo informan que alguien
murió. El diagrama de `docs/ARQUITECTURA.md` §3.1 conectaba el `HurtboxComponent`
del enemigo directo al autoload; se cambió para no repartir el autoload por todo
el código, que es lo que pide `CLAUDE.md` §4.

Ninguna acción mueve el eje más de `CAMBIO_MAXIMO` (0.03), aplicado con `clamp`.

**`Alma.ESCALA` está calibrada a 2.5** contra el nivel 1 ya cerrado. Con 1.0 hacían
falta entre 13 y 40 muertes para cruzar un umbral, y el nivel tiene 9 enemigos: el
eje no se movía nunca y las tres tipografías del diario no llegaban a verse jugando.
A 2.5:

| Cómo se juega el nivel 1 | Eje al final | Ruta |
|---|---|---|
| Matar a los 9 con el tubo de metal (+0.02) | +0.45 | Humano |
| Matarlos con plasma (−0.02) o radiación (−0.03) | −0.45 a −0.67 | Máquina |
| Pasar sin matar a nadie | 0.00 | Ambiguo |

Es decir: **las tres rutas son alcanzables en una sola partida del nivel 1**, que
es lo que hacía falta para poder enseñar el mecanismo central del juego sin las
herramientas de captura del tráiler.

**F3** abre el indicador de depuración del eje. Es temporal: `docs/HITOS.md`
manda quitarlo en el Hito 8.

## El diario

Menú de pausa diegético (`ui/diario/`). Se abre con **Tab** y pausa de verdad
(`get_tree().paused = true`).

- **Antes de encontrarlo in-game** solo aparece un menú mínimo sin estilo. El
  cuaderno se recoge en el mundo: es un `Recogible` de clase `DIARIO`.
- Cuatro pestañas: Bitácora, Arsenal, Estadísticas y Ajustes.
- **Los Ajustes son funcionales**: volumen por bus, pantalla completa y remapeo
  de controles. Se guardan en `user://ajustes.cfg`. En el remapeo, Escape cancela
  y reasignar una tecla no borra el mapeo del mando.

### La tipografía es el medidor del eje

`TipografiaAlma` se suscribe a `Alma.umbral_cruzado` y reconstruye el `Theme` del
diario entero. No hay ninguna notificación al jugador: abre el diario en algún
momento y su propia letra ya no es la misma (`ARTE.md` §6).

| Ruta | Fuente | Color |
|---|---|---|
| Humano (>= 0.4) | Manuscrita | Crema de papel |
| Ambiguo | Híbrida | Gris neutro |
| Máquina (<= -0.4) | Máquina de escribir | Verde fósforo |

**Las tres fuentes bitmap ya existen** y están asignadas en el nodo `Tipografia`:
`ui/diario/fuentes/wai_humana.fnt`, `wai_hibrida.fnt` y `wai_maquina.fnt`. Las
genera `herramientas/generar_fuentes.py` a partir de una rejilla de 5×7 px por
glifo (`herramientas/fuente_datos.py`), en formato BMFont, sin antialiasing.

Son variantes de la **misma** base a propósito: lo que tiene que leerse es que es
la misma mano la que cambia, no que hay tres alfabetos distintos. La humana tiene
la línea base bailando y salpicaduras de tinta; la de máquina es monoespaciada y
perfecta. El código sigue teniendo el sustituto por `FontVariation` para cuando
algún `@export` esté vacío.

En ruta máquina el texto además se corrompe y "autocorrige" palabras emotivas:

```
original:   siento que no puedo saber si esto es un reflejo
en máquina: #<gistro ~/< <+ pu*%o saber ~i es>+ e# un #e+^<jo
en humano:  siento que no puedo saber si esto es un reflejo
```

El diccionario de correcciones está **vacío**: las palabras son contenido
narrativo y van en `docs/TEXTOS_PENDIENTES.md`.

## Recogibles

`systems/pickups/recogible.tscn` sirve para armas, para el diario y para vendas.
Lo que entrega lo decide el inspector (`clase`), no el código.

## Guardado

`user://partida.json`, versionado y validado. `Guardado` consulta a `Alma` y a
`EstadoJuego` al serializar; los datos del jugador se los pasa quien llama (la
terminal), asi que el autoload no anda buscando nodos por el arbol.

Al cargar se **rechaza con mensaje claro** una partida de version futura, de
version vieja sin migracion, o con JSON corrupto. Nunca se cargan datos a medias.

## Terminales CRT (TV Buddha)

`systems/save_points/terminal_crt.tscn`. Se activan con **E**. No son un menu:
la camara corta a un plano fijo lateral, el jugador se sienta, la musica se apaga
y la pantalla enciende. Se sale con **E** otra vez, cuando uno quiera.

El circuito cerrado y por que no se rompe:

```
Pantalla (Sprite2D)  visibility_layer = 2  <- el SubViewport NO la ve
Circuito (SubViewport)  canvas_cull_mask = 1  <- solo ve la capa 1
   +-- CamaraCircuito (Camera2D)  enfoca al jugador
```

Ese par de numeros es lo que evita la recursion infinita: si el SubViewport
encuadrara su propia pantalla, Godot devolveria negro. Al dejar la pantalla en
una capa de visibilidad aparte, queda fuera de su propio encuadre.

`world_2d` del SubViewport se iguala al del viewport principal en `_ready()`. Sin
eso, el SubViewport renderizaria un mundo vacio.

**El retardo**: `frames_de_retardo` (6 por defecto) mantiene un buffer circular de
`ImageTexture`. La pantalla no muestra el presente, muestra unos frames atras. Mas
un glitch de deriva vertical que salta solo, sin relacion con lo que hace el
jugador. Eso es lo que impide saber si es un reflejo o una transmision (ARTE.md §4).

> **Trampa que ya nos mordió:** `CamaraCircuito` nace `enabled = false` en la
> escena y hay que **encenderla** en `iniciar()`. Un `SubViewport` sin cámara se
> renderiza desde el origen del mundo, así que la pantalla mostraba el tile 0 del
> nivel con ruido verde encima, nunca al protagonista. La cita a *TV Buddha*
> depende entera de que se vea a sí mismo. No daba ningún error.

> **Coste**: el retardo hace un `get_image()` por frame, que sincroniza con la GPU.
> Por eso el `SubViewport` esta en `UPDATE_DISABLED` salvo durante la escena, que
> es estatica y corta. Si notan tirones, bajen `frames_de_retardo` a 0: la imagen
> pasa a ser en vivo y el coste desaparece.

El shader esta en `shaders/crt.gdshader`: scanlines, curvatura de barril, bloom
verde de fosforo, aberracion cromatica, ruido y deriva. Todos sus valores son
uniforms editables desde el inspector del nodo `Pantalla`.

## Vendas

`vendas` en el jugador, limitadas y consumibles (`CLAUDE.md` §3.5). Se usan con
**K** y solo si falta salud. Se recogen del mundo con un `Recogible` de clase
`VENDA`.

## Nivel 1

`levels/nivel_01/nivel_01.tscn`. 216 tiles de ancho (3456 px), 3 checkpoints CRT,
9 enemigos, 8 recogibles, 4 abismos con `ZonaMortal` debajo y 2 pasillos con
techo bajo.

### Es una secuencia de lecciones, no un pasillo con cosas

El nivel enseña **con la forma del terreno**, en este orden, y sin un solo cartel:

| Tile | Lo que hay | Lo que enseña |
|---|---|---|
| 5–16 | Llano, sin nada que pueda matarte | Caminar |
| 17 | Un escalón que no se sube andando | Saltar |
| 34 | Un CRT encendido, lo único con luz | Interactuar y guardar |
| 45–46 | Abismo justo después del CRT | Comprometerse, y para qué servía el checkpoint |
| 52 | El tubo de metal, en mitad del camino | Recoger un arma |
| 61–74 | Pasillo con techo bajo y un enemigo | Atacar (por encima no se puede) |
| 78 | El cuaderno de campo | El diario |
| 101–114 | Dos enemigos con una ruta alta encima | Que **evitarlos también vale** |
| 97–99 | Hueco que un salto andando no cubre | Correr |
| 125–136 | Pasillo bajo con un enemigo que embiste | Rodar |
| 141–144, 165–168 | Plasma y radiación, arriba y fuera del camino | Que la ruta es tuya |
| 193–211 | Mirador alto sobre la brasa | Cerrar |

**Los abismos están medidos, no puestos a ojo.** Con `altura_salto` 48,
`tiempo_subida` 0.35 y `multiplicador_caida` 1.6 son 0.63 s en el aire: andando
(70 px/s) se alcanzan 44 px y corriendo (115 px/s), 72 px. Por eso los huecos son
de 2 tiles (32 px, se cruzan andando) o de 3 (48 px, **no** se cruzan andando y sí
corriendo). Un hueco de 4 tiles dejaba 8 px de margen incluso corriendo y no
pasaba ni el piloto automático: por eso ya no hay ninguno.

### Las pistas contextuales

`systems/pista_contextual.tscn`. **No es un tutorial.** Solo aparece si el jugador
lleva unos segundos dentro de la zona sin haber usado nunca esa acción, y en
cuanto la usa una vez, ninguna pista de esa acción vuelve a salir en toda la
partida. El nombre de la tecla lo lee del **InputMap**, así que si remapean los
controles la pista cambia sola; con un mando conectado enseña el botón.

### Comprobar que sigue siendo jugable

```
godot --path juego res://tools/prueba_nivel.tscn
```

Un piloto automático lo recorre entero con cinco reglas (andar a la derecha,
saltar si se acaba el suelo, correr si el hueco es ancho, pegar de cerca, rodar si
lo tiene encima) y dice **en qué tile se atasca**. Si un humano no podría pasar con
esas cinco reglas, el tramo está mal diseñado. Deja capturas en `capturas/prueba_*.png`.

### Revisar el aspecto sin jugar

Tres herramientas más, para iterar sobre el arte sin tener que llegar jugando
hasta el sitio. Todas dejan la captura en `capturas/`:

```
godot --path juego res://tools/vistazo_menu.tscn     el menú, en tres momentos
godot --path juego res://tools/vistazo_diario.tscn   el diario en las tres rutas
godot --path juego res://tools/vistazo_pista.tscn    una pista contextual saliendo
```

`vistazo_diario` es la única forma rápida de ver las tres tipografías: llegar a
cruzar un umbral jugando cuesta media partida.

`Nivel` (`levels/nivel.gd`) **deriva los limites de la camara del terreno** en
`_ready()`. Si agrandan el nivel en el editor, los limites se ajustan solos.

### Regenerarlo

```
godot --headless --path juego res://tools/generar_nivel_01.tscn
```

> **Cuidado: regenerar PISA el nivel.** La herramienta genera la *estructura*; la
> colocacion fina de plataformas y enemigos es diseno de niveles y se hace en el
> editor. Una vez que lo editen a mano, no vuelvan a correrla.

Va como escena y no como `--script` a proposito: con `--script` sobre un
`SceneTree` los autoloads no se instancian y las escenas del juego no compilan.

## Parallax

6 capas de `Parallax2D` en `Nivel01/Parallax`, de `scroll_scale.x` 0.03 (bruma) a
1.28 (primer plano, que va **delante** del jugador). Las dimensiones exactas y qué
debe ir en cada una están en `art/PLACEHOLDERS.md`.

**`scroll_scale.y` es 0 y las imágenes se apoyan en el borde inferior del cuadro.**
No es un descuido: con desplazamiento vertical las capas subían y bajaban con la
cámara, y el canto de abajo de los bloques de la capa 5 acababa por encima del
suelo. Se veían como **cuadrados negros flotando en el aire**. Apoyadas abajo, su
base queda siempre detrás del terreno (que llega hasta la fila 16, o sea siempre
hasta el fondo de la pantalla) y no se ve ningún canto suelto. De paso el horizonte
de las siluetas coincide ahora con la hendidura del cielo.

**Las plataformas sueltas no pueden estar a más de 2 tiles (32 px)** de la
superficie desde la que se salta. El salto sube 48 px —3 tiles justos— pero para
posarse encima hay que rebasar el canto: a 3 tiles se llega raspando y a 4 no se
llega. Estaban a 4 y a 5, así que la lanza de plasma, el emisor de radiación y la
ruta alta de evasión eran **inalcanzables**. La ruta alta ahora sube en dos
peldaños pegados de 2 tiles cada uno.

## Apertura (el Plano 1)

`ui/apertura_sadak.gd`. Plano fijo de 4 s con el titulo y despues devuelve el
control **sin corte**: nada de "presione cualquier tecla" (`ARTE.md` §2).

El truco para que no haya corte es que **no se cambia de camara**. Se usa la del
jugador con el zoom y el desplazamiento de la apertura, y se animan hasta los
valores normales *mientras* se devuelve el control. El jugador no sabe en que
momento empezo a jugar.

## El menú principal

`ui/menu/menu_principal.tscn`, la escena de arranque. Es diegético, como el
diario: no es una pantalla de título con botones encima de un fondo, es **un
monitor que arranca**. El título se teclea letra a letra, el subtítulo y las
opciones se encienden después, y el fondo es el mismo cielo y el mismo parallax
del nivel, quietos y derivando muy despacio, con el protagonista mirando la brasa.

*SEGUIR DONDE ESTABA* aparece desactivado si no hay `user://partida.json`.
*DESPERTAR* borra la partida y empieza de cero.

`CargadorEscenas.cambiar_a()` hace el fundido a negro y el cambio de escena. El
velo va en una `CanvasLayer` a `layer = 100`, por encima incluso del diario.

## El cielo

`shaders/cielo.gdshader` sobre una `CanvasLayer` a `layer = -100`
(`ui/cielo.gd`). Pinta la cúpula, la hendidura incandescente y la bruma de abajo,
con el horizonte ondulando y la brasa respirando.

> **Por qué no es una capa de parallax:** lo era, y estaba mal. La capa 1 era una
> textura de 216 px de alto, y la cámara del nivel recorre unos 730 px de mundo.
> Por encima y por debajo de esa banda se veía el color de fondo de Godot: **dos
> franjas grises** ocupando casi un tercio del cuadro en muchos encuadres. Una
> `CanvasLayer` de pantalla completa no se puede quedar corta nunca.

La capa 1 del parallax sigue existiendo, pero ahora es bruma con transparencia:
bandas horizontales que rompen el degradado limpio del shader, que es lo que
delataba que el cielo estaba hecho por código.

## Sensación de golpe

`Impacto` (autoload) hace dos cosas y no conoce a nadie: **congela la imagen**
unos frames con `Engine.time_scale` y emite `sacudida_pedida`. Quien quiera se
suscribe; la que escucha es `CamaraJugador`.

| Llamada | Cuándo | Congela |
|---|---|---|
| `Impacto.golpe(f)` | Un golpe conecta | ~45 ms |
| `Impacto.muerte(f)` | Algo muere | ~100 ms |
| `Impacto.sacudir(i, d)` | Aterrizajes, sustos | no |

Por encima de ~80 ms la congelación deja de leerse como impacto y empieza a
leerse como que el juego va a tirones. Las sacudidas **no se suman**: un golpe
durante otra sacudida se queda con la más fuerte, o tres golpes seguidos mandan
la cámara fuera del nivel.

`Efectos` (clase de funciones estáticas, no autoload) suelta chispas, polvo y
restos. Los cuelga del **nivel**, no de quien los pide: colgados de un enemigo que
acaba de morir se liberarían en el mismo frame y no se verían. Es el mismo error
que ya tuvieron los proyectiles.

## La cámara

`actors/player/camara_jugador.gd`. Sobre la `Camera2D` normal añade sacudida y
**adelanto**: se mueve 26 px hacia donde mira el personaje y baja al caer rápido,
para que veas llegar lo que viene en vez de descubrirlo encima.

> El encuadre propio va en `offset_base`, **no** en `offset`: la sacudida escribe
> `offset` cada frame, así que un tween sobre `offset` se ve pisado al instante.
> La `AperturaSadak` lo hacía y por eso ahora detecta si la cámara es una
> `CamaraJugador` y anima la propiedad correcta.

## Audio

`DirectorAudio` (autoload) sostiene el ambiente en bucle y reproduce los efectos
desde una reserva de 8 reproductores. Con uno solo, tres golpes seguidos se cortan
entre sí y el combate suena a un único impacto.

Nadie más carga `.wav`: se piden por nombre de archivo sin extensión
(`DirectorAudio.efecto("golpe")`), y la carpeta se escanea al arrancar. Soltar un
archivo nuevo en `audio/` basta para poder pedirlo.

Los sonidos son placeholder generado, igual que el resto del arte:

```
python herramientas/generar_audio.py
```

Síntesis con la librería estándar de Python: nada de samples descargados, nada de
licencias que revisar. El ambiente son dos drones graves desafinados entre sí
(el batido lento es lo que suena a máquina y no a órgano), viento filtrado y algún
golpe metálico lejano; va en bucle con el final cruzado con el principio.

> El script escribe también el `.import` de los dos bucles con `edit/loop_mode=1`.
> Godot importa los `.wav` **sin** bucle por defecto, y un ambiente que se corta a
> los 22 segundos y no vuelve es peor que no tener ambiente.

## Post-proceso de paleta

`shaders/paleta_alma.gdshader` sobre un `ColorRect` a pantalla completa
(`ui/paleta_alma.gd`). Hace **dos cosas a la vez**:

**1. El grado base**, que no depende del eje y está siempre puesto: viñeta, grano
de película, un bloom cálido sobre la brasa del fondo, una aberración cromática
mínima y una elevación de negros. Es lo que separa "un tilemap con sprites encima"
de una imagen; sin esto el cuadro se ve plano por muy bien dibujado que esté. La
elevación de negros además evita que la silueta del protagonista —que es lo más
oscuro del cuadro por diseño— se convierta en un agujero.

**2. La inclinación de paleta** según el eje, suscrita a `Alma.umbral_cruzado`:

| Ruta | Efecto |
|---|---|
| Máquina | Aberración cromática, scanlines, más contraste, tinte frío |
| Humano | Grano, menos saturación en los cianes, luces cálidas |

La transición dura 3 s con un `Tween`: nunca es un corte.

## Alcance acordado

Hitos 0–5 más un nivel corto. Los hitos 6, 7 y 8 son bonus.

## El tráiler

`herramientas/trailer.py` rueda los planos con el Movie Maker de Godot y los monta
con ffmpeg. Sustituye al montaje a mano de `capturas/mont/lista.txt`.

```
python herramientas/trailer.py                 rueda y monta
python herramientas/trailer.py --montar        solo monta (rápido, para probar cortes)
python herramientas/trailer.py --rodar --plano rodar    vuelve a rodar uno suelto
python herramientas/trailer.py --montar --musica pista.mp3
```

Sale `capturas/WAI_trailer.mp4` (maestro, 1920×1080 a 60 fps) y
`WAI_trailer_ligero.mp4` para mandar. **El montaje es la lista `GUION`** del propio
script: qué plano, desde qué segundo y cuánto dura. Los planos se ruedan más largos
de lo que se usan, así que mover un corte no obliga a volver a grabar.

Los planos los define `tools/captura.gd`. Para ver los que hay:

```
godot --path juego res://tools/captura.tscn -- --listar
```

Cada plano tiene un `zoom` de cámara: los de paisaje se quedan en 1.0 y los de
mecánica suben a 1.5–1.9. Un personaje de 24 px en un cuadro de 384 es perfecto
para el paisaje e ilegible para enseñar una mecánica. Eso es solo del tráiler: no
toca la cámara del juego.

> **No usen `--headless` para filmar.** Sin renderizador real la `TerminalCRT` no
> puede leer su `SubViewport` y el plano del CRT sale mal, en silencio.
