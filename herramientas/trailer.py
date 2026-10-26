# -*- coding: utf-8 -*-
"""Rueda y monta el trailer de Who Am I.

Sustituye al montaje a mano de capturas/mont/lista.txt. Hace dos cosas y se
pueden pedir por separado:

  python herramientas/trailer.py --rodar     graba cada plano con Godot
  python herramientas/trailer.py --montar    corta, encadena y codifica
  python herramientas/trailer.py            las dos, en orden

  --musica ruta.mp3    pega la pista de audio y le hace un fundido al final
  --plano NOMBRE       vuelve a rodar solo ese plano (para iterar uno suelto)

El GUION de abajo es el montaje: que plano, desde que segundo y cuanto dura. Los
planos se ruedan mas largos de lo que se usan a proposito, para poder mover el
punto de entrada sin volver a grabar.

Se graba a 384x216, la resolucion interna del juego, y se amplia x5 a 1920x1080
con filtro NEAREST. Asi el pixel sale entero y sin interpolar: grabar
directamente a 1080p dejaria que el motor escalara con su propio filtro.
"""
import os
import subprocess
import sys

import imageio_ffmpeg

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.normpath(os.path.join(AQUI, ".."))
JUEGO = os.path.join(RAIZ, "juego")
PLANOS = os.path.join(RAIZ, "capturas", "planos")
SEGMENTOS = os.path.join(RAIZ, "capturas", "segmentos")
SALIDA = os.path.join(RAIZ, "capturas", "WAI_trailer.mp4")
SALIDA_LIGERA = os.path.join(RAIZ, "capturas", "WAI_trailer_ligero.mp4")

FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()

GODOT = os.path.join(os.path.expanduser("~"), "Downloads",
                     "Godot_v4.7.1-stable_win64.exe",
                     "Godot_v4.7.1-stable_win64_console.exe")

ANCHO, ALTO, FPS = 1920, 1080, 60


# (plano, rodar_seg, entra_en, dura, fundido_entrada, fundido_salida)
#
# El orden cuenta una cosa: primero QUE ES el mundo (apertura y paisaje), luego
# QUE SE HACE en el (movimiento, esquiva, combate), luego las dos armas que
# empujan a maquina, y solo entonces el mecanismo (CRT, diario, deriva de
# paleta) y el cierre. Las mecanicas van antes que el tema porque un trailer que
# empieza explicando no lo ve nadie.
GUION = [
    ("sadak",          12.0,  1.0,  8.0,  True,  False),
    ("caminata",       11.0,  1.5,  7.0,  False, False),
    ("salto",          10.0,  1.2,  6.5,  False, False),
    ("rodar",          10.0,  1.5,  6.5,  False, False),
    ("combate",        11.0,  1.5,  7.0,  False, False),
    ("pistola",         9.0,  1.5,  5.0,  False, False),
    ("plasma",          9.0,  1.5,  5.5,  False, False),
    ("radiacion",       9.0,  1.5,  5.5,  False, True),
    ("crt",            15.0,  2.5, 10.0,  True,  True),
    ("diario_humano",   9.0,  1.0,  5.5,  True,  False),
    ("deriva",         13.0,  1.5,  8.0,  False, False),
    ("diario_maquina",  9.0,  1.0,  5.5,  False, True),
    ("maquina",         9.0,  1.0,  6.0,  True,  False),
    ("cartela_final",   6.0,  0.3,  5.0,  True,  True),
]

FUNDIDO = 0.5   # segundos de entrada/salida a negro


def _correr(orden, titulo):
    print("  " + titulo)
    resultado = subprocess.run(orden, capture_output=True, text=True,
                               encoding="utf-8", errors="replace")
    if resultado.returncode != 0:
        print(resultado.stdout[-2000:])
        print(resultado.stderr[-2000:])
        raise SystemExit("fallo: %s" % titulo)


def rodar(solo=None):
    """Graba cada plano con el Movie Maker de Godot.

    NO se usa --headless: sin renderizador real la TerminalCRT no puede leer su
    SubViewport y el plano del CRT sale mal, en silencio (tools/captura.gd).
    """
    if not os.path.isfile(GODOT):
        raise SystemExit("no encuentro Godot en %s" % GODOT)
    os.makedirs(PLANOS, exist_ok=True)
    print("Rodaje (384x216 @ %d fps):" % FPS)
    for nombre, duracion, _e, _d, _fe, _fs in GUION:
        if solo and nombre != solo:
            continue
        destino = os.path.join(PLANOS, "%s.avi" % nombre)
        _correr([GODOT, "--path", JUEGO,
                 "--write-movie", destino,
                 "--resolution", "384x216",
                 "res://tools/captura.tscn",
                 "--", "--plano=%s" % nombre, "--duracion=%.1f" % duracion],
                "%-16s %.1f s" % (nombre, duracion))


def _segmento(nombre, entra, dura, fe, fs):
    """Corta un plano, lo amplia a 1080p sin interpolar y le pone los fundidos."""
    origen = os.path.join(PLANOS, "%s.avi" % nombre)
    if not os.path.isfile(origen):
        raise SystemExit("falta el plano %s: corre --rodar primero" % nombre)
    destino = os.path.join(SEGMENTOS, "%s.mp4" % nombre)

    filtros = ["scale=%d:%d:flags=neighbor" % (ANCHO, ALTO), "fps=%d" % FPS]
    if fe:
        filtros.append("fade=t=in:st=0:d=%.2f" % FUNDIDO)
    if fs:
        filtros.append("fade=t=out:st=%.2f:d=%.2f" % (dura - FUNDIDO, FUNDIDO))

    _correr([FFMPEG, "-v", "error", "-y",
             "-ss", "%.2f" % entra, "-t", "%.2f" % dura, "-i", origen,
             "-vf", ",".join(filtros),
             "-an", "-c:v", "libx264", "-preset", "medium", "-crf", "16",
             "-pix_fmt", "yuv420p", destino],
            "%-16s %.1f s  (desde %.1f)" % (nombre, dura, entra))
    return destino


def montar(musica=None):
    os.makedirs(SEGMENTOS, exist_ok=True)
    print("Montaje:")
    for nombre, _r, entra, dura, fe, fs in GUION:
        _segmento(nombre, entra, dura, fe, fs)

    lista = os.path.join(SEGMENTOS, "lista.txt")
    with open(lista, "w", encoding="utf-8") as f:
        for nombre, _r, _e, _d, _fe, _fs in GUION:
            f.write("file '%s.mp4'\n" % nombre)

    total = sum(g[3] for g in GUION)
    orden = [FFMPEG, "-v", "error", "-y", "-f", "concat", "-safe", "0",
             "-i", lista]
    if musica:
        # -shortest corta por el video: la pista puede ser mas larga sin
        # problema, y el fundido de audio se ata a la duracion del montaje.
        orden += ["-i", musica,
                  "-af", "afade=t=out:st=%.2f:d=1.5" % max(0.0, total - 1.5),
                  "-c:a", "aac", "-b:a", "192k", "-shortest"]
    orden += ["-c:v", "copy", SALIDA]
    _correr(orden, "concatenando %d planos" % len(GUION))

    # Version ligera para mandar. El maestro sale a ~10 Mbps porque el grano
    # del shader de paleta humana es ruido puro y ningun codec lo comprime; a
    # CRF 24 baja a la decima parte y a esta escala no se nota la diferencia.
    orden = [FFMPEG, "-v", "error", "-y", "-i", SALIDA,
             "-c:v", "libx264", "-preset", "slow", "-crf", "24",
             "-pix_fmt", "yuv420p"]
    orden += (["-c:a", "copy"] if musica else ["-an"])
    orden += [SALIDA_LIGERA]
    _correr(orden, "version ligera")

    mb = os.path.getsize(SALIDA) / 1048576.0
    mb_l = os.path.getsize(SALIDA_LIGERA) / 1048576.0
    print("\nlisto: %d planos, %.1f s" % (len(GUION), total))
    print("  capturas/WAI_trailer.mp4          %7.1f MB  maestro" % mb)
    print("  capturas/WAI_trailer_ligero.mp4   %7.1f MB  para mandar" % mb_l)
    if not musica:
        print("sin audio. Para pegarle la musica:")
        print("  python herramientas/trailer.py --montar --musica ruta/a/tu/pista.mp3")


if __name__ == "__main__":
    args = sys.argv[1:]

    def opcion(nombre):
        if nombre in args:
            i = args.index(nombre)
            return args[i + 1] if i + 1 < len(args) else True
        return None

    musica = opcion("--musica")
    solo = opcion("--plano")
    hacer_rodaje = "--rodar" in args or ("--montar" not in args)
    hacer_montaje = "--montar" in args or ("--rodar" not in args)

    if hacer_rodaje:
        rodar(solo if isinstance(solo, str) else None)
    if hacer_montaje:
        montar(musica if isinstance(musica, str) else None)
