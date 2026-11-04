# -*- coding: utf-8 -*-
"""Graba el video de jugabilidad: la demo desde el menu hasta derrotar al Custodio.

Uso:  python3 herramientas/grabar_jugabilidad.py [--montar]

Godot juega solo (juego/tools/piloto_video.tscn) con el Movie Maker a 384x216; se
amplia x5 sin filtrar. --montar solo vuelve a codificar lo ya grabado. Salen
capturas/WAI_jugabilidad.mp4 (1080p) y WAI_jugabilidad_ligero.mp4 (648p, para mandar).
"""
import os
import shutil
import subprocess
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.normpath(os.path.join(AQUI, ".."))
JUEGO = os.path.join(RAIZ, "juego")
CAPTURAS = os.path.join(RAIZ, "capturas")
CRUDO = os.path.join(CAPTURAS, "jugabilidad_crudo.avi")
# El JPEG del AVI se nota mucho al ampliar pixel art: se sube la calidad solo
# durante la grabacion. override.cfg no se versiona porque se borra al terminar.
OVERRIDE = os.path.join(JUEGO, "override.cfg")


def grabar():
    with open(OVERRIDE, "w") as f:
        f.write("[editor]\nmovie_writer/mjpeg_quality=0.97\n")
    try:
        subprocess.run(["godot", "--path", JUEGO, "--write-movie", CRUDO,
                        "--resolution", "384x216", "--fixed-fps", "60",
                        "res://tools/piloto_video.tscn"], check=True)
    finally:
        os.remove(OVERRIDE)


def codificar(salida, ancho, alto, crf):
    subprocess.run([shutil.which("ffmpeg"), "-y", "-loglevel", "error", "-i", CRUDO,
                    "-vf", "scale=%d:%d:flags=neighbor,format=yuv420p" % (ancho, alto),
                    "-c:v", "libx264", "-preset", "veryfast", "-crf", str(crf),
                    "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", salida],
                   check=True)
    print("%s  %.0f MB" % (salida, os.path.getsize(salida) / 1e6))


if __name__ == "__main__":
    if "--montar" not in sys.argv:
        grabar()
    # El grano del shader de paleta casi no se comprime: con crf 18 pasaba de 1 GB.
    # 1152x648 es x3 exacto; 720p seria x3.33 y deformaria los pixeles.
    codificar(os.path.join(CAPTURAS, "WAI_jugabilidad.mp4"), 1920, 1080, 25)
    codificar(os.path.join(CAPTURAS, "WAI_jugabilidad_ligero.mp4"), 1152, 648, 30)
