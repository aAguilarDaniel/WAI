# Dirección de arte — Who Am I

Estética: **"Divine Machinery"** en pixel art. La tecnología como catedral y como
religión; la figura humana diminuta frente a algo colosal e indiferente.

Todo el juego se construye sobre una tensión visual: **lo sublime romántico
(escala aplastante, luz de catástrofe) chocando con lo digital degradado
(scanlines, glitch, verde de fósforo)**. Esa es la traducción visual de la
pregunta del título.

---

## 1. Especificaciones técnicas

- Resolución interna **384×216**, escala entera ×5 → 1920×1080. Nada de escalas
  fraccionarias.
- **Todo el arte se produce a resolución nativa.** No se dibuja grande y se
  reduce: rompe el pixel.
- Tamaño del protagonista: **~24 px de alto**. Con 216 px de alto de pantalla,
  eso deja al personaje ocupando ~11% del cuadro — suficiente para que un
  paisaje se sienta monumental sin volverlo invisible.
- Paleta limitada, **32 colores máximo**, en un `.gpl` compartido en
  `art/paleta.gpl`. Ningún asset usa un color fuera de la paleta.
- Animaciones: 8–12 fps para el personaje. El pixel art se lee mejor con menos
  frames y poses más claras que con interpolación suave.

### Paleta — dos polos

La paleta se divide en dos mitades que conviven, y el shader de post-proceso
inclina el balance según el eje del alma:

- **Polo humano**: ocres, tierras quemadas, ámbar de fuego, rojo sangre seca,
  crema del papel del diario. Cálido, sucio, orgánico.
- **Polo máquina**: cian, verde fósforo de CRT, magenta de radiación, gris azulado,
  blanco de arco eléctrico. Frío, saturado, artificial.

En ruta máquina el shader sube la aberración cromática, las scanlines y el
contraste; en ruta humana sube el grano, baja la saturación de los cianes y
calienta las luces.

---

## 2. Plano 1 — la apertura (Sadak)

La primera imagen del juego reproduce la composición de **"Sadak in Search of
the Waters of Oblivion"** de John Martin (1812):

- Figura diminuta en el **cuadrante inferior**, de espaldas o de tres cuartos,
  aferrada a una roca, trepando hacia arriba y a la derecha.
- **Masas oscuras de roca ocupando casi todo el cuadro**, dejando solo una
  hendidura de cielo incandescente al fondo.
- Luz naranja/roja quemando desde el fondo, todo lo demás en silueta.
- El personaje se ve **agotado, no heroico**. Está trepando, no posando.

Traslado al mundo del juego: las rocas son **escombros de infraestructura** —
carcasas de servidores fundidos, torres de refrigeración colapsadas, cableado
como raíces, placas base erosionadas del tamaño de acantilados. El resplandor del
fondo no es lava: es el brillo de una instalación todavía encendida en el horizonte.

Ejecución: **arranca como plano fijo no jugable** durante unos segundos, con el
título apareciendo, y luego devuelve el control sin corte. El jugador descubre
que ya estaba jugando. Nada de cinemática con "presione cualquier tecla".

---

## 3. Fondos — el sublime de John Martin

Referencias: *The Great Day of His Wrath*, *Pandemonium*, *The Bard*, *Belshazzar's
Feast*.

Qué hay que robarle a Martin, concretamente:

1. **Escala por contraste, no por detalle.** La sensación de inmensidad viene de
   poner una figura minúscula al lado de algo enorme, no de dibujar más cosas.
2. **Una sola fuente de luz dramática**, generalmente al fondo y baja, que recorta
   todo en silueta.
3. **Arquitectura imposible**: columnatas que se pierden, escaleras sin final,
   arcos repetidos hasta el horizonte. En este juego eso son racks de servidores
   del tamaño de naves de catedral, antenas como campanarios, pasarelas suspendidas.
4. **Vacío en el centro.** Martin deja abismos. No llenes el cuadro.

Implementación: **5–7 capas de parallax**. Las capas lejanas casi monocromas y
con muy poco contraste (perspectiva atmosférica); solo la capa jugable tiene
color pleno y bordes definidos. Regla dura: **el jugador nunca debe confundir
fondo con plataforma**. Si hay duda, bajale contraste al fondo.

John Martin murió en 1854, así que su obra está en dominio público: podés usar
las pinturas directamente como referencia, calcarlas, proyectarlas, lo que sirva.

---

## 4. Terminales CRT — TV Buddha

Referencia directa a **TV Buddha** de Nam June Paik (1974): una figura sentada
frente a un monitor que le devuelve su propia imagen en circuito cerrado.

La cita tiene que ser **legible como cita**: plano lateral fijo, simetría,
personaje sentado en el suelo con las piernas cruzadas, monitor a su altura,
cable visible entre ambos, cámara que no se mueve, sin UI encima.

La diferencia con Paik es lo que hace que funcione aquí: el Buda de Paik se
reconoce a sí mismo. El protagonista **no puede saber si lo que ve en la pantalla
es un reflejo o una transmisión**. La imagen del CRT debe tener un retardo de
unos pocos frames y un glitch ocasional que no coincide con lo que hace el
jugador. Nunca lo señales con texto. Que lo note quien lo note.

El shader del CRT: scanlines, curvatura de barril leve, bloom verde, ruido y
deriva vertical ocasional.

---

## 5. Jefes y paisajes — Beksiński

Zdzisław Beksiński como fuente para jefes y para las zonas más hostiles. Lo que
define su lenguaje visual y hay que trasladar:

- **Figuras alargadas, óseas, erosionadas.** Estructura que parece haber estado
  expuesta a la intemperie durante siglos.
- **Rostros ausentes, vendados o reemplazados** por otra cosa. En este juego:
  rostros sustituidos por pantallas, lentes, mallas.
- **Arquitectura y carne fundidas** en una sola masa. Un jefe no es una máquina
  con partes orgánicas pegadas: es una sola cosa que nunca se pudo separar.
- **Cielos marrones, ocres y sepias**, atmósfera de polvo suspendido, niebla densa.
- **Texturas rugosas, superficies picadas y corroídas.** En pixel art eso se
  logra con dithering irregular, no con ruido uniforme.
- **Silencio y quietud.** Sus criaturas casi nunca están en acción: están ahí
  paradas. Un jefe que se queda inmóvil unos segundos antes de moverse da más
  miedo que uno que ataca sin parar.

Nota práctica: Beksiński murió en 2005 y Paik en 2006, así que sus obras siguen
protegidas. El estilo no se protege — inspirarse, citar conceptualmente y hacer
homenaje está perfectamente bien —, pero no copien una pintura suya concreta
píxel a píxel. Acredítenlos en los créditos y en el GDD como referencias; en un
trabajo de clase eso además suma.

---

## 6. Tipografía del diario

Tres fuentes bitmap, todas legibles a 384×216 (altura de mayúscula 7–8 px):

| Estado del eje | Fuente | Comportamiento |
|---|---|---|
| Humano (`>= 0.4`) | Manuscrita, trazo irregular | Ligeras variaciones de baseline, tachones, palabras corregidas a mano |
| Ambiguo | Híbrida | Mezcla: algunas letras a mano, otras mecanografiadas |
| Máquina (`<= -0.4`) | Máquina de escribir / monoespaciada dura | Espaciado perfecto, glitch ocasional, palabras emotivas "autocorregidas" |

El cambio es **gradual y sin aviso**. El jugador no debe recibir una notificación
de que cambió su ruta; debe abrir el diario en algún momento y notar que su
propia letra ya no es la misma. Eso es todo el juego en un gesto.

---

## 7. Audio

Ambient y electrónica de los 90 como base: Boards of Canada (deterioro de cinta,
nostalgia degradada) y Aphex Twin (*Selected Ambient Works Vol. II* para las
zonas de exploración). En combate y ruta máquina, la agresividad de Machine Girl
y Death Grips.

Estructura recomendada: **capas superpuestas**, no pistas separadas. Una base
ambiental constante, más capas de percusión/distorsión que entran y salen según
el eje y el estado de combate. Así la música responde a la ruta sin cortes bruscos.

---

## 8. Flujo de trabajo de assets

Claude Code **no dibuja pixel art**. Todo entra como placeholder y ustedes lo
reemplazan. El archivo `art/PLACEHOLDERS.md` funciona como la lista de pendientes
de arte:

| Ruta final | Tamaño (px) | Frames | Descripción | Estado |
|---|---|---|---|---|
| `art/final/jugador/caminar.png` | 24×24 | 8 | Ciclo de caminata | pendiente |

Herramienta recomendada: **Aseprite**. Exporten spritesheet + `.json`, y mantengan
las dimensiones exactas de la tabla para que el reemplazo sea directo, sin tocar
código ni reajustar colisiones.
