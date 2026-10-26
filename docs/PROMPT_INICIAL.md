# Prompt inicial para Claude Code

## Antes de pegar nada

1. Creá la carpeta del proyecto y meté ahí `CLAUDE.md`, `docs/` y el GDD original.
2. `git init` y un commit inicial con solo la documentación.
3. Abrí una terminal en esa carpeta y corré `claude`.
4. Activá **plan mode** (Shift+Tab dos veces) para el primer mensaje, así te
   propone el plan antes de tocar archivos.

---

## Mensaje 1 — arranque (pegar tal cual)

> Vas a ayudarme a desarrollar **Who Am I**, un plataformero 2D en pixel art hecho
> en Godot para mi clase de Desarrollo de Videojuegos. Somos dos personas y no
> tenemos experiencia previa con Godot, así que además de escribir el código
> necesito que me expliques lo que estás haciendo a medida que avanzás.
>
> Empezá leyendo, en este orden: `CLAUDE.md`, `docs/ARQUITECTURA.md`,
> `docs/ARTE.md` y `docs/HITOS.md`. Ahí está todo el diseño acordado.
>
> Antes de escribir una sola línea de código:
>
> 1. Verificá qué versión de Godot tengo instalada (`godot --version`) y decime
>    si hay algo en los documentos que no aplique a esa versión.
> 2. Decime qué decisiones de diseño te parecen ambiguas, contradictorias o
>    demasiado grandes para el alcance de un trabajo de clase. Quiero tu opinión
>    honesta sobre el alcance antes de arrancar, no después.
> 3. Proponeme el plan concreto del **Hito 0** de `docs/HITOS.md`: qué archivos
>    vas a crear y qué va en cada uno.
>
> Esperá mi aprobación antes de ejecutar. No avances al Hito 1 en el mismo turno.

---

## Mensaje tipo para cada hito siguiente

> Aprobado el Hito N. Antes de empezar el Hito N+1:
> - Resumime en 3 líneas qué quedó funcionando y qué quedó a medias.
> - Decime qué abro en el editor para probarlo.
>
> Luego proponeme el plan del Hito N+1 y esperá mi ok.

---

## Frases útiles durante el desarrollo

- **Cuando algo no se siente bien**: "el salto se siente flotante — mostrame los
  valores exportados que puedo tocar y qué hace cada uno, no lo cambies vos".
- **Cuando escribe de más**: "eso es más de lo que pedí. Volvé al alcance del hito
  y quitá lo que sobra."
- **Cuando no entendés el código**: "explicame este script línea por línea como si
  nunca hubiera usado Godot."
- **Para arte**: "no dibujes nada, dejá placeholder y agregá la fila a
  `art/PLACEHOLDERS.md` con las dimensiones exactas."
- **Cuando algo se rompe**: "corré `godot --headless --quit --path .` y arreglá los
  errores que salgan antes de seguir."
- **Al cerrar sesión**: "actualizá `CLAUDE.md` con las decisiones nuevas que
  tomamos hoy, para que la próxima sesión arranque con contexto."

---

## Lo que conviene hacer ustedes y no delegar

- **El feel del movimiento.** Los números del salto se ajustan jugando, no
  leyendo. Pediles los `@export` y tocalos ustedes.
- **Todo el pixel art y la música.** Es la mitad de la nota en una clase de
  videojuegos y es lo único que no se puede generar acá.
- **El diseño de niveles.** La colocación de plataformas y enemigos es criterio de
  juego, no de código.
- **Entender el código antes de entregarlo.** Si el profesor pregunta cómo
  funciona el eje del alma y no saben responder, el proyecto no sirvió de nada.
  Pedile explicaciones a Claude Code hasta que puedan reescribir cualquier
  script de memoria.
