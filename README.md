# Who Am I (WAI)

Plataformero 2D pixel art hecho en **Godot 4.7.1.stable** (`gl_compatibility`).
Trabajo para la clase de Desarrollo de Videojuegos.

Daniel Felipe Aguilar Latorre (522709) · Juan David Monsalve Niño (525559)

## Arrancar

```bash
git clone <url-de-este-repo>
cd WAI
```

Abrir Godot → **Importar** → `juego/project.godot` → **F5**.

Sin abrir el editor:

```bash
godot --path juego                     # desde el menú principal
godot --path juego -- --saltar-menu    # directo al nivel 1
godot --headless --quit --path juego   # comprobar que no hay errores
```

Para las herramientas de generación de arte y audio:

```bash
pip install -r requirements.txt
```

## Qué hay en cada carpeta

| Carpeta | Contenido |
|---|---|
| `juego/` | El proyecto Godot. Punto de entrada: `juego/project.godot` |
| `docs/` | Arquitectura, dirección de arte, hitos y textos pendientes |
| `herramientas/` | Scripts Python que generan sprites, fuentes, audio y el tráiler |
| `capturas/` | Salida de las herramientas de captura. **No se versiona** (ver abajo) |

## Documentación

Leer en este orden:

1. **[`CLAUDE.md`](CLAUDE.md)** — la fuente de verdad: diseño, convenciones y reglas del proyecto
2. **[`juego/README.md`](juego/README.md)** — cómo funciona cada sistema del juego por dentro
3. [`docs/ARQUITECTURA.md`](docs/ARQUITECTURA.md) · [`docs/ARTE.md`](docs/ARTE.md) · [`docs/HITOS.md`](docs/HITOS.md)

## Nota sobre `capturas/`

Está en `.gitignore` a propósito: los AVI que saca el Movie Maker de Godot van sin
comprimir y pesan cientos de MB por minuto (son ~700 MB en local). Todo lo de esa
carpeta se regenera:

```bash
godot --path juego res://tools/captura.tscn   # planos del tráiler
python herramientas/trailer.py                # rueda y monta el tráiler
```

## Antes de subir cambios

```bash
godot --headless --quit --path juego              # ¿importa sin errores?
godot --path juego res://tools/prueba_nivel.tscn  # ¿el nivel sigue siendo jugable?
godot --path juego res://tools/prueba_nivel_02.tscn     # paso al nivel 2 y sus mecánicas
godot --path juego res://tools/prueba_tramo_final.tscn  # niveles 3-5, jefe y final
```
