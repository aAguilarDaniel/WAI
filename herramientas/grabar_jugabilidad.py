# -*- coding: utf-8 -*-
"""Graba el video de jugabilidad: la demo desde el menu hasta derrotar al Custodio.

Uso:  python3 herramientas/grabar_jugabilidad.py [--montar]

Godot juega solo (juego/tools/piloto_video.tscn) con el Movie Maker a 384x216; se
amplia x3 sin filtrar. --montar solo vuelve a codificar lo ya grabado. Sale
capturas/WAI_jugabilidad.mp4 y, con lo que paso en la toma, capturas/jugabilidad.log.
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
        # A un archivo y no a un pipe: el resumen (RESCATES, muertes) no se pierde.
        with open(os.path.join(CAPTURAS, "jugabilidad.log"), "w") as registro:
            subprocess.run(["godot", "--path", JUEGO, "--write-movie", CRUDO,
                            "--resolution", "384x216", "--fixed-fps", "60",
                            "res://tools/piloto_video.tscn"],
                           check=True, stdout=registro, stderr=subprocess.STDOUT)
    finally:
        os.remove(OVERRIDE)


def codificar(salida):
    # Lo que pesa es el grano del shader de paleta: se filtra a resolucion nativa, antes
    # de ampliar. x3 exacto para que los pixeles sigan cuadrados; con 1080p eran 670 MB
    # sin ganar detalle, porque la imagen de origen mide 384x216.
    subprocess.run([shutil.which("ffmpeg"), "-y", "-loglevel", "error", "-i", CRUDO,
                    "-vf", "hqdn3d=4:4:10:10,fps=30,scale=1152:648:flags=neighbor,format=yuv420p",
                    "-c:v", "libx264", "-preset", "slow", "-crf", "32",
                    "-c:a", "aac", "-b:a", "96k", "-movflags", "+faststart", salida],
                   check=True)
    print("%s  %.0f MB" % (salida, os.path.getsize(salida) / 1e6))


if __name__ == "__main__":
    if "--montar" not in sys.argv:
        grabar()
    codificar(os.path.join(CAPTURAS, "WAI_jugabilidad.mp4"))
