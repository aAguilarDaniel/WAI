# Placeholders pendientes de arte

Lista de tareas de arte. Cada vez que el código usa un asset provisional, se
agrega una fila acá. El código está escrito para que reemplazar el placeholder
por el arte final **no requiera tocar código**: solo cambiar el archivo.

## Los placeholders se generan, no se dibujan

Están todos en `art/placeholder/` y los producen cuatro scripts de `herramientas/`.
Si tocan uno a mano, la próxima vez que corran el script lo pisan.

| Script | Qué produce |
|---|---|
| `generar_siluetas.py` | Las 6 capas de parallax del exterior, el foso y el CRT |
| `generar_mundo.py` | El tileset de los dos niveles, los objetos de escenario, la fachada del edificio y las 4 capas del interior |
| `generar_jugador.py` | El spritesheet animado del protagonista |
| `generar_props.py` | Enemigo, proyectiles, recogibles, corazón del HUD |
| `generar_sprite_frames.py` | Los `.tres` de `SpriteFrames` del jugador y del enemigo |
| `generar_fuentes.py` | Las 4 fuentes bitmap (`.png` + `.fnt`) |
| `generar_luces.py` | Los halos y el destello de `art/placeholder/efectos/` |
| `generar_audio.py` | El ambiente en bucle y los 8 efectos de `audio/` |

```
python herramientas/generar_siluetas.py --contacto
python herramientas/generar_mundo.py --contacto
python herramientas/generar_jugador.py --contacto
python herramientas/generar_props.py --contacto
python herramientas/generar_sprite_frames.py
python herramientas/generar_fuentes.py --contacto
python herramientas/generar_luces.py
python herramientas/generar_audio.py
```

`--contacto` escribe una hoja de prueba ampliada en `capturas/`, para revisar el
resultado sin abrir Godot.

Al reemplazar un PNG por arte a mano, **borren o ignoren su script**: el `.tres`
de `SpriteFrames` sigue valiendo mientras la rejilla y el orden de filas no cambien.

### La regla dura de valor (léanla antes de pintar el fondo)

**El protagonista tiene que ser lo más oscuro del cuadro, siempre.** Su cuerpo es
`(17, 13, 17)`. Ninguna capa de fondo puede bajar de `(39, 26, 32)`.

Esto no es una preferencia: las capas 4 y 5 estaban pintadas más oscuras que el
personaje y la silueta **desaparecía dentro del fondo** mientras caminaba. En el
teaser anterior no se distinguía qué estaba pasando en pantalla. La única capa
que puede ser negra es la 6, porque va *delante* del jugador — y aun así tiene
que ser escasa, o lo tapa igual.

Escalera de valor actual, de fondo a frente:

```
cielo / brasa   lo más claro (lo pinta shaders/cielo.gdshader, no una textura)
capa 1          bruma, solo transparencias sobre el cielo
capa 2          (80, 50, 54)
capa 3          (60, 38, 44)
capa 4          (48, 31, 37)
capa 5          (39, 26, 32)   <- el último fondo detrás del jugador
TERRENO         (52, 38, 42)   + ceja iluminada (186, 116, 54)
JUGADOR         (17, 13, 17)   <- lo más oscuro
capa 6          (5, 4, 7)      va delante; escasa y por los bordes
```

**Segunda regla dura, de la misma familia: el terreno no puede ser más oscuro que
la capa 5.** Lo era —terreno `(34, 26, 30)` contra capa 5 `(39, 26, 32)`— y el
suelo se hundía en el fondo: el nivel entero se leía como una sola mancha marrón y
no se distinguía dónde se podía pisar. El terreno es lo más cercano que hay detrás
del jugador, así que le toca ser lo **más claro** del fondo, no lo más oscuro.

Y la ceja del canto pasó de `(78, 60, 52)` a `(186, 116, 54)`. Contra un cielo de
brasa, una ceja tenue es una ceja invisible: es lo único que hace que una
plataforma se lea como plataforma a contraluz.

Reglas (docs/ARTE.md §1 y §8):

- Arte producido a resolución nativa. No dibujar grande y reducir.
- Máximo 32 colores, todos de `art/paleta.gpl`.
- Protagonista ~24 px de alto.
- Animaciones a 8–12 fps.
- Respetar las dimensiones exactas de la tabla o se rompen las colisiones.

| Ruta final | Tamaño (px) | Frames | Descripción | Estado |
|---|---|---|---|---|
| `art/final/jugador/jugador.png` | 24×24 por celda | 41 (ver abajo) | Spritesheet del protagonista | **placeholder animado generado** |
| `art/final/plataformas/caja_blanca.png` | libre | 1 | Tileset del nivel de prueba (opcional, es descartable) | opcional |
| `art/final/enemigos/patrulla.png` | **16×20** por celda | 10 (ver abajo) | Enemigo básico de patrulla | **placeholder animado generado** |
| `art/final/ui/corazon.png` | 7×7 | 1 | Corazón del HUD. Se tiñe por código: dibujarlo en blanco | **placeholder generado** |
| `art/final/armas/tubo_metal.png` | 16×16 | 1 | Icono del Arsenal del diario | pendiente |
| `art/final/armas/pistola_reciclada.png` | 16×16 | 1 | Icono del Arsenal | pendiente |
| `art/final/armas/lanza_plasma.png` | 16×16 | 1 | Icono del Arsenal | pendiente |
| `art/final/armas/emisor_radiacion.png` | 16×16 | 1 | Icono del Arsenal | pendiente |
| `art/final/proyectiles/bala.png` | **10×6** | 1 | Proyectil de la pistola, ámbar | **placeholder generado** |
| `art/final/proyectiles/plasma.png` | **10×6** por celda | 3 | Proyectil de plasma, cian, late | **placeholder generado** |
| `art/final/proyectiles/radiacion.png` | **10×6** por celda | 3 | Proyectil de radiación, magenta | **placeholder generado** |
| `art/final/recogibles/arma.png` | 12×12 | 1 | Arma tirada en el suelo | **placeholder generado** |
| `art/final/recogibles/diario.png` | 12×12 | 1 | El cuaderno de campo | **placeholder generado** |
| `art/final/recogibles/venda.png` | 12×12 | 1 | Rollo de venda con cruz roja | **placeholder generado** |

Los iconos de arma van en el campo `sprite` de cada `.tres`. **Todavía no se ven
en ningún lado**: la pestaña Arsenal del diario es solo texto. Son la única fila
de esta lista que no urge.

### Proyectiles: una escena por arma

`proyectil.tscn` sigue existiendo como base, pero cada arma apunta ya a la suya:

| Arma | Escena | Sprite | Lectura |
|---|---|---|---|
| Pistola reciclada | `proyectil_bala.tscn` | `Sprite2D`, 1 frame | Recta, ámbar, con estela |
| Lanza de plasma | `proyectil_plasma.tscn` | `AnimatedSprite2D`, 3 frames | Gota cian con cola, late |
| Emisor de radiación | `proyectil_radiacion.tscn` | `AnimatedSprite2D`, 3 frames | Masa magenta irregular |

La hitbox se queda en **6×3** en los tres: el sprite puede ser mayor que la caja
de daño, y lo es. Cambiar el sprite no cambia la dificultad.

Los tres se distinguen por **forma** además de por color. En un cuadro de 384×216
un proyectil se ve un instante y el color solo no alcanza — sobre todo el de la
pistola, que es cálido como el cielo. Por eso la bala lleva **perfil oscuro**
arriba y abajo del núcleo: sin él era invisible durante todo el vuelo.

### Recogibles

`recogible.gd` elige la textura según `clase` y las tres se asignan en el
inspector de `recogible.tscn` (`textura_arma`, `textura_diario`, `textura_venda`).
Antes los tres eran el mismo cuadrado amarillo y no había forma de saber qué había
en el suelo.

Todos llevan **reborde cálido** por el canto derecho. Un objeto de 12 px sin canto
desaparece contra el suelo en un nivel a contraluz: ese reborde es lo que los hace
leerse como "recogible".

### Enemigo de patrulla

Hoja de **64×60**, celdas de **16×20** con los pies en el borde inferior. Colisión
de 12×20 con el origen en los pies (`position.y = -10`). El recurso es
`actors/enemies/enemigo_frames.tres`.

Es una máquina con un monitor CRT donde debería ir la cara (`ARTE.md` §5: rostros
sustituidos por pantallas). El tamaño del monitor respecto del cuerpo es lo que lo
hace legible a 20 px: si el cuerpo pesara más, parecería una persona.

| Animación | Frames | fps | Notas |
|---|---|---|---|
| `quieto` | 2 | 4 | Pantalla apagada |
| `caminar` | 4 | 8 | Patrulla. Las patas se abren y el cuerpo bota 1 px |
| `alerta` | 4 | 12 | **Te vio.** Pantalla encendida y dos puntos donde irían los ojos |

`alerta` es la única telegrafía que tiene este enemigo, que no ataca sino que
embiste. `enemigo_patrulla.gd` la cambia al entrar y salir de `Modo.PERSECUCION`,
por cambio de modo y no cada frame. El tinte rojo del daño lo sigue poniendo el
código con `modulate`, así que **no dibujen un frame de herido**.

### Las 6 capas de parallax del nivel 1

Estas son **el** trabajo de arte del proyecto. Reemplazan a los PNG de
`art/placeholder/parallax/`, que ahora mismo son columnas de color plano.

Todas: **768 x 216 px**, fondo transparente salvo la capa 1. Se repiten en
horizontal (`repeat_size = 768`), asi que **el borde izquierdo tiene que empalmar
con el derecho** o se vera la costura.

| Capa | Archivo | scroll | z | Que va |
|---|---|---|---|---|
| 1 | `capa_1_cielo.png` | 0.04 | -50 | Cielo. La hendidura incandescente del fondo. **Sin transparencia**: es el ultimo fondo |
| 2 | `capa_2_horizonte.png` | 0.14 | -40 | Horizonte lejanisimo. Casi del color del cielo: perspectiva atmosferica |
| 3 | `capa_3_torres.png` | 0.28 | -30 | Torres de refrigeracion, antenas como campanarios |
| 4 | `capa_4_racks.png` | 0.46 | -20 | Racks de servidores del tamano de naves de catedral |
| 5 | `capa_5_cercano.png` | 0.66 | -10 | Torres de celosia, pasarelas y cables. **Sin bloques macizos** |
| 6 | `capa_6_primer_plano.png` | 1.30 | **+20** | Va **delante** del jugador. Cableado, escombros que recortan el cuadro |

Las cuatro reglas de `ARTE.md` §3, en forma de checklist:

- [ ] **Escala por contraste, no por detalle.** La inmensidad sale de poner al
      personaje de 24 px al lado de algo enorme, no de dibujar mas cosas.
- [ ] **Una sola fuente de luz**, al fondo y baja, que recorte todo en silueta.
- [ ] **Arquitectura imposible**: arcos repetidos hasta el horizonte, pasarelas
      suspendidas, escaleras sin final.
- [ ] **Vacio en el centro.** Martin deja abismos. No llenen el cuadro.

Y la regla dura: **el jugador nunca debe confundir fondo con plataforma.** Si hay
duda, bajenle contraste al fondo. Las capas 1 a 3 casi monocromas.

### Tileset de los dos niveles

| Ruta final | Tamano | Celdas | Descripcion | Estado |
|---|---|---|---|---|
| `art/final/tilesets/mundo.png` | **128x32** (16 px por celda) | 16 | Exterior (fila 0) e interior (fila 1) | **placeholder generado** |

`art/placeholder/tileset_mundo.png`, de `herramientas/generar_mundo.py`. Lo usan
los dos niveles a traves de `levels/comun/tileset_mundo.tres`. **La posicion de cada
celda es la definitiva**: el codigo las nombra en `tools/constructor_nivel.gd`.

| Celda | Exterior (fila 0) | Interior (fila 1) |
|---|---|---|
| 0 | Escombro solido | Suelo de chapa con canto iluminado |
| 1 | Superficie con ceja | Muro de paneles |
| 2 | Relleno, **sin colision** | Muro con rejilla |
| 3 | Viga de acero (plataformas sueltas) | Pasarela de rejilla, **un solo sentido** (4 px de arriba) |
| 4 | Profundo, **sin colision** | Techo (labio de abajo iluminado) |
| 5 | Superficie con zanja de cables | Relleno, **sin colision** |
| 6 | Solida con tubo (va en tramos) | Suelo con franjas de peligro |
| 7 | Solida con placa base | Bloque de rack |

Reemplazar el PNG con las mismas celdas en el mismo sitio no toca nada. Si cambian
de sitio, hay que tocar las constantes de `constructor_nivel.gd` y **regenerar**
los niveles (y regenerar **pisa** lo editado a mano).

### Objetos de escenario y fachada (`art/placeholder/props/`)

Todos de `herramientas/generar_mundo.py`. Se apoyan por el **centro de su borde
inferior**, asi que cualquier tamano nuevo sigue posandose en el suelo. Las luces
de cada uno estan encajadas a mano en los generadores de nivel: si se redibuja un
objeto con la bombilla en otro sitio, hay que mover su luz alli.

| Ruta final | Tamano (px) | Frames | Descripcion | Estado |
|---|---|---|---|---|
| `art/final/escenario/edificio_fachada.png` | 224x352 | 1 | Fachada del final del nivel 1. Portal de 32x48 en el centro | **placeholder generado** |
| `art/final/escenario/farola.png` | 12x48 | 1 | Farola doblada. Bombilla en (8-10, 9) | **placeholder generado** |
| `art/final/escenario/poste.png` | 12x64 | 1 | Poste de cables con aisladores | **placeholder generado** |
| `art/final/escenario/cartel.png` | 40x30 | 1 | Neon roto, sin letras. Ojo en (13, 8) | **placeholder generado** |
| `art/final/escenario/chatarra.png` | 32x12 | 1 | Escombros con carcasa de monitor | **placeholder generado** |
| `art/final/escenario/barril.png` | 10x14 | 1 | Barril oxidado | **placeholder generado** |
| `art/final/escenario/servidor_caido.png` | 30x14 | 1 | Rack volcado. Led en (6, 7) | **placeholder generado** |
| `art/final/escenario/valla.png` | 36x18 | 1 | Barandilla rota | **placeholder generado** |
| `art/final/escenario/rack.png` | 24x56 | 1 | Armario de servidores en pie | **placeholder generado** |
| `art/final/escenario/consola.png` | 32x22 | 1 | Mesa con terminal y teclado | **placeholder generado** |
| `art/final/escenario/lampara.png` | 10x40 | 1 | Lampara colgante con cadena | **placeholder generado** |
| `art/final/escenario/muro_monitores.png` | 112x72 | 1 | El santuario del final del nivel 2 | **placeholder generado** |
| `art/final/escenario/ventanal.png` | 40x96 | 1 | Ventanal gotico roto con la brasa detras | **placeholder generado** |
| `art/final/escenario/tuberia.png` | 64x10 | 1 | Tuberia de pared | **placeholder generado** |
| `art/final/escenario/ascensor.png` | 40x60 | 1 | La salida del nivel 2 | **placeholder generado** |
| `art/final/peligros/emisor_arco.png` | 12x10 | 1 | Nodo del arco electrico (se voltea para el techo) | **placeholder generado** |
| `art/final/peligros/montacargas.png` | 48x12 | 1 | Plataforma movil. Colision 48x6 arriba | **placeholder generado** |
| `art/final/efectos/cono.png` | 48x64 | 1 | Haz de lampara, **en blanco** (se tine por codigo) | **placeholder generado** |

### Las 4 capas del interior (nivel 2)

`art/placeholder/interior/`, **768x216**, repetidas en horizontal como las del
exterior. El fondo de todo no es una capa: es `shaders/interior.gdshader`.

| Capa | Archivo | scroll | z | Que va |
|---|---|---|---|---|
| 1 | `capa_i1_nave.png` | 0.12 | -50 | La nave: arcada apuntada y ventanales con la brasa |
| 2 | `capa_i2_racks.png` | 0.32 | -40 | Torres de servidores con leds sueltos |
| 3 | `capa_i3_columnas.png` | 0.58 | -30 | Columnas cercanas y haces de cable |
| 4 | `capa_i4_cables.png` | 1.25 | **+20** | Delante del jugador: cables y cadenas colgando |

### Las fuentes bitmap

**Hechas.** Están en `ui/diario/fuentes/` y las genera
`herramientas/generar_fuentes.py` desde la tabla de `herramientas/fuente_datos.py`:
una rejilla de **5×7 px por glifo**, 118 glifos, con acentos y eñe. Formato BMFont
(`.fnt` + `.png`), importadas con `scaling_mode = 1` (solo escalas enteras) y sin
antialiasing. Alto de línea 12 px, altura de mayúscula 7: cumple `ARTE.md` §6.

| Archivo | Dónde se usa | Carácter |
|---|---|---|
| `wai_base.fnt` | Ya no la usa el tema global: desde el 2026-11-03 el tema usa `ui/fuentes/adventurer.ttf` (definitiva, del equipo) | Limpia, sin temblor |
| `wai_humana.fnt` | Diario, ruta humana | Línea base que baila, trazo grueso, tinta |
| `wai_hibrida.fnt` | Diario, ruta ambigua | Unas letras a mano, otras mecanografiadas |
| `wai_maquina.fnt` | Diario, ruta máquina | Monoespaciada, espaciado perfecto |

Las tres del diario están asignadas en el nodo `Tipografia` de `diario.tscn`.

**Son variantes de la misma base a propósito.** Lo que tiene que leerse es que es
la misma mano la que cambia, no que hay tres alfabetos distintos.

> El primer intento hacía temblar **cada fila** de cada glifo y salía ilegible:
> cizallar una letra de 5×7 px no da manuscrita, rompe la forma de la letra. El
> temblor mueve el glifo **entero** y nunca lo deforma. Si las redibujan a mano,
> respeten eso.

Si quieren reemplazarlas por fuentes dibujadas: mismo formato, filtro **Nearest** y
antialiasing desactivado, o se verán borrosas.

### Luces y efectos

`herramientas/generar_luces.py`. Blanco puro: el color lo pone el código con
`modulate`, así que una textura sirve para el ojo verde del enemigo, el ámbar de un
recogible y el fósforo del CRT.

| Ruta final | Tamaño | Descripción | Estado |
|---|---|---|---|
| `art/final/efectos/brillo.png` | 32×32 | Halo radial | **placeholder generado** |
| `art/final/efectos/brillo_grande.png` | 64×64 | Halo radial ancho | **placeholder generado** |
| `art/final/efectos/destello.png` | 17×17 | Cruz de impacto | **placeholder generado** |

Todo lo que emita luz lleva `art/materiales/aditivo.tres` (`blend_mode = 1`). Va
como recurso suelto y no como sub-recurso en cada escena para que cambiar cómo se
comporta la luz del juego sea un archivo, no diez.

Las partículas (`systems/efectos/`) son `CPUParticles2D` sin textura: a 384×216 una
mota de 1–3 px se dibuja mejor con el cuadrado que trae el nodo que con un sprite.

### Audio

`herramientas/generar_audio.py`. Síntesis con la librería estándar de Python: nada
de samples descargados, nada de licencias que revisar.

| Archivo | Qué es |
|---|---|
| `ambiente.wav` | Drones graves desafinados, viento y golpes lejanos. **En bucle** |
| `crt_zumbido.wav` | Transformador y flyback del tubo. **En bucle** |
| `salto.wav`, `aterrizar.wav` | Movimiento |
| `golpe.wav`, `dano.wav`, `rotura.wav` | Combate |
| `recoger.wav` | El único sonido amable del juego |
| `menu_mover.wav`, `menu_aceptar.wav` | Interfaz |

Para reemplazarlos: mismo nombre de archivo en `audio/` y ya está.
`DirectorAudio` escanea la carpeta al arrancar y los sirve por nombre, así que no
hay ninguna lista que actualizar. **Los dos que van en bucle necesitan
`edit/loop_mode=1` en su `.import`**: Godot importa los `.wav` sin bucle por
defecto y el ambiente se cortaría a los 22 segundos sin volver.

### Corazón del HUD

Dibujarlo **en blanco puro**: `barra_salud.gd` lo tiñe con `modulate` según esté
lleno o vacío. Los dos colores son `@export` en el nodo `HUD`, así que se ajustan
desde el inspector sin tocar el sprite.

### Terminal CRT

| Ruta final | Tamano (px) | Frames | Descripcion | Estado |
|---|---|---|---|---|
| `art/final/terminales/crt_cuerpo.png` | 30x28 | 1-2 | Carcasa del monitor. Parpadeo opcional | pendiente |
| `art/final/terminales/crt_cable.png` | 28x2 | 1 | Cable entre el jugador y la maquina | pendiente |

El **cable tiene que verse**: en TV Buddha de Paik el circuito cerrado es visible,
y es lo que hace legible la cita (ARTE.md §4). No lo escondan.

La **pantalla no lleva sprite**: es la textura del SubViewport con el shader CRT.

La animacion **`sentado`** ya existe (de perfil, piernas cruzadas, la rodilla
adelantada). `Jugador.sentarse()` ya no achata el sprite: se lo pide al
`AnimadorJugador`, que sostiene la pose mientras dure la escena porque la maquina
de estados se queda en `Quieto` y no emite nada.

### Detalle del spritesheet del jugador

Hoja de **192×240**: celdas de **24×24**, **una fila por animación**, en el orden
de la lista `ORDEN` de `herramientas/generar_jugador.py`. El recurso es
`actors/player/jugador_frames.tres` (una `AtlasTexture` por celda).

Personaje de ~16×24 centrado y apoyado en el borde inferior de la celda. El nodo
`Sprite` tiene `position.y = -12`, así que el origen del jugador queda en los
pies. Si respetan esa medida, no hay que tocar ni el código ni la colisión (un
rectángulo de 12×24, y 12×14 agachado).

| Fila | Animación | Frames | fps | Bucle | Qué tiene que leerse |
|---|---|---|---|---|---|
| 0 | `quieto` | 4 | 6 | sí | Respiración lenta y nada más |
| 1 | `caminar` | 8 | 10 | sí | Ciclo de paso completo |
| 2 | `correr` | 8 | 12 | sí | Zancada larga, tronco echado, codo cerrado |
| 3 | `saltar` | 3 | 12 | no | Impulso → extensión → sostenido |
| 4 | `caer` | 2 | 8 | no | Piernas abiertas → anticipación de aterrizaje |
| 5 | `agachado` | 2 | 6 | sí | **14 px de alto**, lo que mide la colisión agachada |
| 6 | `rodar` | 6 | 20 | no | Se tira → 4 giros → se levanta |
| 7 | `atacar` | 4 | 13 | no | Anticipación → extensión → seguimiento → recuperación |
| 8 | `herido` | 2 | 9 | no | Impacto arqueado hacia atrás → recomponerse |
| 9 | `sentado` | 2 | 5 | sí | Perfil, piernas cruzadas, para la TerminalCRT |

**Los nombres de fila son los nombres de los nodos de estado en minúsculas**
(`actors/player/estados/`). Esa es la única regla y por eso `AnimadorJugador` no
tiene ni un caso especial: añadir un estado con una animación del mismo nombre ya
funciona. Si una animación no existe, deja la que hubiera puesta.

#### Lo que hay que respetar al redibujarlo

- **`rodar` dura exactamente lo que dure el estado.** `AnimadorJugador` escala la
  velocidad para que los 6 frames entren en `duracion_rodar` (0.30 s). Si dibujan
  8 frames en vez de 6, sigue cuadrando solo. Lo mismo con `atacar`
  (`duracion_total_ataque()`) y `herido` (`duracion_aturdimiento`).
- **`caminar` y `correr` se acompasan a la velocidad real** del personaje, así que
  el ciclo tiene que empezar y terminar en la misma pose o se verá el salto.
- **`atacar` lleva el arma dibujada en los cuatro frames**, y cambiando de ángulo.
  Es lo único que hace legible que es un golpe y no un tropiezo. El frame 2 es la
  extensión máxima y coincide con la ventana en que la hitbox existe de verdad.
- **`rodar` no puede ser una bola perfecta.** Los cuatro frames del medio son la
  misma silueta girada 72°; si fuera un círculo, el giro no se vería y la voltereta
  no se leería. Necesita la cabeza metida y un pie asomando. Y la luz de canto va
  **después** de girar: la brasa del fondo no gira con él.
- **La luz de canto va por el borde derecho** y el motor voltea el sprite con
  `flip_h`, así que dibujen siempre mirando a la derecha.
