# Textos pendientes de escribir

Claude Code **no escribe narrativa**: `CLAUDE.md` §5 dice que si una decisión de
diseño no está en los documentos, se pregunta antes de inventarla. Estos textos
son contenido del juego y los escriben ustedes.

Cada uno está en el proyecto con el marcador
`[PENDIENTE] Escribir en primera persona. Ver docs/TEXTOS_PENDIENTES.md`.
Buscar ese texto encuentra todo lo que falta.

## Entradas del diario por arma

Van en el campo `texto_diario` de cada `.tres` de `juego/systems/weapons/data/`.
Se pueden editar desde el inspector de Godot al abrir el archivo.

`CLAUDE.md` §3.3: *"Al recoger un arma se escribe una entrada nueva en primera
persona, redactada como si él estuviera descubriendo para qué sirve."* Es decir:
no una descripción de estadísticas, sino alguien que encuentra un objeto y deduce
su función. Cuanto menos sepa el protagonista, mejor.

| Archivo | Arma | Tipo | Estado |
|---|---|---|---|
| `tubo_metal.tres` | Tubo de metal | Melee (humana) | pendiente |
| `pistola_reciclada.tres` | Pistola reciclada | Fuego (humana) | pendiente |
| `lanza_plasma.tres` | Lanza de plasma | Plasma (máquina) | pendiente |
| `emisor_radiacion.tres` | Emisor de radiación | Radiación (máquina) | pendiente |

Los nombres visibles también son provisionales: cámbienlos si tienen otros mejores.
Los `id` (`tubo_metal`, `pistola_reciclada`) sí conviene dejarlos, porque son los
que van al JSON de guardado de `docs/ARQUITECTURA.md` §5.

## Correcciones automaticas de la ruta maquina

`ARTE.md` §6: en ruta maquina el texto tiene *"palabras emotivas autocorregidas"*.
El mecanismo ya funciona; la lista de palabras esta **vacia** porque es contenido.

Va en el nodo `Tipografia` de `ui/diario/diario.tscn`, campo
`correcciones_automaticas`, como pares palabra -> reemplazo. Ejemplo del formato
(no es una propuesta de contenido, es solo la forma):

| Palabra original | Reemplazo de la maquina |
|---|---|
| `siento` | `registro` |

La gracia esta en que el reemplazo sea el termino tecnico y frio equivalente, para
que el jugador vea que algo esta reescribiendo lo que el protagonista quiso decir.
Cuantas menos palabras, mas fuerte el efecto.

## Entrada del cuaderno

`levels/plantillas/caja_blanca.tscn`, nodo `Recogibles/CuadernoDeCampo`, campo
`texto_entrada`. Es la primera cosa que el protagonista escribe en el juego.

## Audio pendiente

| Sonido | Donde | Nota |
|---|---|---|
| Zumbido del tubo CRT | Nodo `Zumbido` de `terminal_crt.tscn` | Debe poder sonar en bucle varios minutos sin cansar. Es lo unico que se oye en la escena |

## Pendientes de hitos posteriores

| Texto | Dónde | Hito |
|---|---|---|
| Entradas de bitácora de las misiones | `ui/diario/` | 4 |
| Entrada del diario al derrotar al jefe, una por ruta | `actors/bosses/` | 7 |
| Texto de los dos (o tres) finales | Gestor de finales | 8 |
| Créditos, acreditando a John Martin, Nam June Paik y Beksiński | Menú | 8 |

## Borradores del tramo final (sesión del 2026-11-03)

Para que la demo tuviera jefe y final se escribieron **borradores**. Son de
ustedes: reemplácenlos, y si alguno no sirve, bórrenlo. Se cambian desde el
inspector, sin tocar código.

| Texto | Dónde se cambia |
|---|---|
| Entrada del diario al derrotar al jefe, una por ruta | Nodo `Arena` de `levels/nivel_05/nivel_05.tscn` (`entrada_humana` / `_ambigua` / `_maquina`). También en `tools/generar_nivel_05.gd`, que los vuelve a poner al regenerar |
| Las líneas de los tres finales | `ui/final/final.tscn`, nodo raíz (`lineas_humano` / `_ambiguo` / `_maquina`) |
| El nombre del jefe, "El Custodio" | `titulo_entrada` del nodo `Arena` |

Criterio con el que se escribieron, por si sirve: ninguna contesta la pregunta de
`CLAUDE.md` §1. La humana se queda con lo que siente aunque sea un error; la
máquina habla de sí misma como unidad (la "revelación temprana" de §1); la ambigua
termina esperando una respuesta que no llega.
