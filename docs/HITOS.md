# Hitos — Who Am I

Orden obligatorio. Un hito no empieza hasta que el anterior corre sin errores en
el editor y yo lo aprobé. Al terminar cada uno, Claude Code debe parar y explicar
en dos líneas **qué abrir y qué probar** para verificarlo.

---

### Hito 0 — Esqueleto
- `project.godot` con resolución 384×216, stretch `viewport`/`keep`, snapping a píxel, filtro Nearest.
- Estructura de carpetas de `docs/ARQUITECTURA.md` §1, con `.gdignore` donde toque.
- InputMap completo (teclado + mando) con los nombres de acción de `CLAUDE.md` §2.
- Autoloads registrados, vacíos pero con sus señales declaradas.
- `.gitignore` de Godot 4, `README.md` con versión exacta del motor.
- `art/PLACEHOLDERS.md` creado con la tabla vacía.

**Listo cuando**: `godot --headless --quit --path .` no reporta errores.

---

### Hito 1 — El movimiento (el más importante)
- Escena de prueba con plataformas de caja blanca (`ColorRect` + `StaticBody2D`).
- Jugador con máquina de estados: quieto, caminar, correr, saltar, caer, agachar, rodar.
- Coyote time, jump buffer, altura variable, gravedad asimétrica, corner correction — todo `@export`.
- `Camera2D` con suavizado y límites, respetando el pixel perfect.

**Listo cuando**: se puede jugar 2 minutos saltando entre plataformas y **se
siente bien**. Este hito se itera hasta que el feel esté, no se pasa "por ahora".

---

### Hito 2 — Combate y salud
- `HealthComponent`, `HitboxComponent`, `HurtboxComponent`, capas de colisión documentadas.
- Ataque melee con hitbox temporal y frames de invulnerabilidad al recibir daño.
- Un enemigo simple con patrulla y detección.
- HUD mínimo: barra de salud.

---

### Hito 3 — Armas y eje del alma
- `ArmaData` como `Resource` + al menos 4 `.tres`: dos humanas (melee, fuego), dos máquina (plasma, radiación).
- `WeaponComponent` en el jugador, cambio de arma, proyectiles.
- `Alma` funcionando: acumula `peso_hum`, emite `umbral_cruzado`.
- Un indicador **temporal y solo de debug** del valor del eje (tecla F3), que se quita en el Hito 8.

---

### Hito 4 — El diario
- Menú de pausa diegético con pestañas: Bitácora, Arsenal, Estadísticas, Ajustes.
- Ajustes funcionales: volumen por bus, pantalla completa, remapeo de controles.
- Entradas escritas en primera persona al recoger armas.
- Intercambio de las tres fuentes según `Alma`, suscrito a la señal.
- El diario se obtiene in-game, no está disponible desde el inicio.

---

### Hito 5 — Guardado y terminales CRT
- `Guardado` con el JSON de `docs/ARQUITECTURA.md` §5, versionado y validado.
- `TerminalCRT` completa: plano fijo, `SubViewport` en vivo, shader CRT, retardo y glitch.
- Muerte y reaparición en el último checkpoint.

---

### Hito 6 — Nivel 1 y el Plano 1
- Nivel jugable de 5–8 minutos con TileMapLayer y 3 checkpoints.
- Parallax de 5–7 capas con la composición sublime de `docs/ARTE.md` §3.
- Apertura Sadak: plano fijo → control devuelto sin corte.
- Shader de post-proceso de paleta reaccionando al eje.

---

### Hito 7 — Jefe 1
- Jefe estilo Beksiński con máquina de estados propia, 2–3 fases y telegrafía clara de ataques.
- Arena cerrada, música propia, pausa de intimidación antes de moverse.
- Entrada del diario al derrotarlo, redactada según la ruta actual.

---

### Hito 8 — Cierre
- Ramificación de finales según `Alma` en el punto final.
- `DirectorAudio` con capas cruzadas por eje y estado de combate.
- Quitar el indicador de debug del eje.
- Menú principal, créditos (con las referencias artísticas acreditadas).
- Exportación a Windows y Linux, probada desde el ejecutable.

---

## Si el tiempo se acorta

Recortar en este orden, de menos a más doloroso: Hito 8 → Hito 7 → mitad del
Hito 6. **Los hitos 1 a 5 son el núcleo demostrable**: sin ellos no hay nada que
mostrar en clase. Un juego corto y pulido evalúa mejor que uno largo y roto.
