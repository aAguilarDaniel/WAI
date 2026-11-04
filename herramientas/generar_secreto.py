# -*- coding: utf-8 -*-
"""Placeholders de los niveles 5-6 y del jefe secreto: dron, prensa y el gran
CRT de la sala secreta.

Uso:  python herramientas/generar_secreto.py [--contacto]

El jefe secreto (El Reflejo) NO tiene hoja propia a proposito: es el
protagonista. Usa jugador_frames.tres tenido de negro desde la escena, asi que
cuando redibujen al protagonista, su reflejo cambia con el.
"""
import os
import sys

import pixel
from pixel import canto, disco, lienzo, punto, trazo
from generar_jefe import (_frames, _guardar, _hoja, CHASIS, CHASIS_OSC, FOSFORO,
                          FOSFORO_VIVO, ROJO, ROJO_VIVO, OXIDO, AMBAR, JUEGO)

METAL = (64, 58, 62, 255)
METAL_LUZ = (104, 94, 96, 255)

# ================================================================== dron ======
DRON_W, DRON_H = 16, 12


def _dron(ojo, aspa, inclinacion=0):
    img = lienzo(DRON_W, DRON_H)
    # Aspas: una barra que cambia de largo para leer el giro
    trazo(img, (8 - aspa, 1), (8 + aspa, 1), 1, METAL_LUZ)
    trazo(img, (8, 1), (8, 3), 1, METAL)
    # Cuerpo: un ojo de camara en una carcasa
    for y in range(3, 10):
        trazo(img, (3 + inclinacion, y), (12 + inclinacion, y), 1, CHASIS)
    disco(img, (7.5 + inclinacion, 6.5), 2.4, CHASIS_OSC)
    disco(img, (7.5 + inclinacion, 6.5), 1.2, ojo)
    trazo(img, (5 + inclinacion, 10), (4 + inclinacion, 11), 1, METAL)
    trazo(img, (10 + inclinacion, 10), (11 + inclinacion, 11), 1, METAL)
    canto(img, (128, 96, 70, 255))
    return img


def dron_flotar():
    return [_dron(FOSFORO, 6), _dron(FOSFORO, 3)]


def dron_apuntar():
    return [_dron(ROJO_VIVO, 6), _dron(ROJO, 2)]


def dron_picado():
    return [_dron(ROJO_VIVO, 6, 1), _dron(ROJO_VIVO, 4, 1)]


def dron_aturdido():
    return [_dron((40, 54, 44, 255), 1), _dron((40, 54, 44, 255), 0)]


DRON_ORDEN = [
    ("flotar", 10.0, True, dron_flotar),
    ("apuntar", 14.0, True, dron_apuntar),
    ("picado", 16.0, True, dron_picado),
    ("aturdido", 4.0, True, dron_aturdido),
]

# ================================================================ prensa ======

def prensa_cabeza():
    """32x16: la cara que golpea. Franjas abajo: es lo que avisa de por donde baja."""
    img = lienzo(32, 16)
    for y in range(16):
        trazo(img, (0, y), (31, y), 1, METAL if y < 11 else CHASIS_OSC)
    for x in range(0, 32, 6):
        trazo(img, (x, 12), (x + 2, 15), 1, (170, 120, 40, 255))
    trazo(img, (0, 0), (31, 0), 1, METAL_LUZ)
    for x in (4, 27):
        punto(img, x, 4, AMBAR)
    return img


def prensa_vastago():
    """8x16, se repite en vertical: el piston que la sostiene."""
    img = lienzo(8, 16)
    for y in range(16):
        trazo(img, (1, y), (6, y), 1, METAL)
        punto(img, 2, y, METAL_LUZ)
    trazo(img, (0, 15), (7, 15), 1, OXIDO)
    return img


# =============================================================== pinchos ======

def pinchos():
    """16x12, se repite en horizontal: el fondo de los pozos. Claros y con la punta
    ambar, porque van sobre lo mas oscuro del cuadro y tienen que verse al caer."""
    img = lienzo(16, 12)
    for base in (0, 8):
        for y in range(12):
            medio = (y + 1) // 2 if y < 8 else 4
            for x in range(4 - medio, 4 + medio):
                color = METAL_LUZ if x < 4 else METAL
                punto(img, base + x, y, color)
        punto(img, base + 3, 0, AMBAR)
        punto(img, base + 4, 0, AMBAR)
        punto(img, base + 3, 1, AMBAR)
    return img


# ============================================================ gran pantalla ===

def pantalla_secreta():
    """128x96: el CRT de la sala del Reflejo. Del que sale."""
    img = lienzo(128, 96)
    for y in range(4, 84):
        trazo(img, (4, y), (123, y), 1, CHASIS)
    for y in range(10, 78):
        trazo(img, (10, y), (117, y), 1, CHASIS_OSC)
    for y in range(14, 74):
        trazo(img, (14, y), (113, y), 1, (12, 22, 16, 255))
    for i, x in enumerate((18, 40, 88, 110)):
        trazo(img, (x, 84), (x - 8 + i * 5, 95), 2, (40, 32, 38, 255))
    canto(img, (128, 96, 70, 255))
    return img


if __name__ == "__main__":
    filas = [fn() for _n, _f, _b, fn in DRON_ORDEN]
    _guardar(_hoja(filas, DRON_W, DRON_H), "dron.png")
    _frames(DRON_ORDEN, DRON_W, DRON_H, "res://art/placeholder/dron.png",
            os.path.join(JUEGO, "actors", "enemies", "dron_frames.tres"))
    _guardar(prensa_cabeza(), "props", "prensa_cabeza.png")
    _guardar(prensa_vastago(), "props", "prensa_vastago.png")
    _guardar(pantalla_secreta(), "props", "pantalla_secreta.png")
    _guardar(pinchos(), "props", "pinchos.png")
    if "--contacto" in sys.argv:
        ruta = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "capturas", "hoja_secreto.png")
        pixel.contacto(filas + [[prensa_cabeza(), prensa_vastago()]], escala=8, columnas=2).save(ruta)
        print("hoja de contacto -> capturas/hoja_secreto.png")
