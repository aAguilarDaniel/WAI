# Who Am I (WAI)

Plataformero 2D pixel art hecho en **Godot 4.7.1.stable** (`gl_compatibility`).
Trabajo para la clase de Desarrollo de Videojuegos.

Daniel Felipe Aguilar Latorre (522709) · Juan David Monsalve Niño (525559)

## Jugar en Windows

Descargar `WhoAmI.exe` de la [última Release](https://github.com/aAguilarDaniel/WAI/releases/latest)
y ejecutarlo: es un solo archivo y no hay que instalar nada. Como no está firmado,
Windows puede avisar con SmartScreen: *Más información* → *Ejecutar de todas formas*.

Los controles están en un cartel al principio del nivel 1. Las partidas se guardan
en `%APPDATA%\Godot\app_userdata\Who Am I\`.

## Generar el .exe

Hace falta la plantilla de exportación de Windows de la misma versión de Godot
(Editor → Administrar plantillas de exportación). El preset está en
`juego/export_presets.cfg`.

```bash
mkdir -p build
godot --headless --path juego --export-release "Windows" ../build/WhoAmI.exe
```

El `.exe` pesa unos 115 MB, más que el límite de 100 MB de GitHub, así que **no va en
el repo** (`build/` y `*.exe` están en `.gitignore`): se sube a una Release.

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
godot --path juego res://tools/prueba_tramo_final.tscn  # niveles 3-7, el Custodio y el final
godot --path juego res://tools/prueba_secreto.tscn      # el registro, el Reflejo y el final secreto
godot --path juego res://tools/prueba_controles.tscn    # el cartel de controles
godot --path juego res://tools/prueba_pinchos.tscn      # los pozos con pinchos
```
