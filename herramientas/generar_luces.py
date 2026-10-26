# -*- coding: utf-8 -*-
"""Genera las texturas de luz de Who Am I.

Son halos radiales en blanco puro: el color lo pone el codigo con modulate, asi
que una sola textura sirve para el ojo verde del enemigo, el ambar del recogible
y el fosforo del CRT. Se dibujan en blanco a proposito (misma regla que el
corazon del HUD, art/PLACEHOLDERS.md).

Uso:  python herramientas/generar_luces.py
"""
import os

from PIL import Image

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "juego", "art")
DESTINO = os.path.join(RAIZ, "placeholder", "efectos")


def halo(lado, dureza=2.4):
    """Degradado radial. dureza alta = nucleo pequeno y caida rapida."""
    img = Image.new("RGBA", (lado, lado), (255, 255, 255, 0))
    px = img.load()
    centro = (lado - 1) / 2.0
    radio = lado / 2.0
    for y in range(lado):
        for x in range(lado):
            d = ((x - centro) ** 2 + (y - centro) ** 2) ** 0.5 / radio
            if d >= 1.0:
                continue
            a = (1.0 - d) ** dureza
            px[x, y] = (255, 255, 255, int(255 * a))
    return img


def destello(lado=17):
    """Cruz de cuatro puntas con nucleo. Para el instante del impacto."""
    img = Image.new("RGBA", (lado, lado), (255, 255, 255, 0))
    px = img.load()
    c = lado // 2
    for i in range(lado):
        caida = 1.0 - abs(i - c) / float(c)
        v = int(255 * caida ** 1.6)
        if v > 0:
            px[i, c] = (255, 255, 255, v)
            px[c, i] = (255, 255, 255, v)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            px[c + dx, c + dy] = (255, 255, 255, 255)
    return img


def guardar(img, nombre):
    os.makedirs(DESTINO, exist_ok=True)
    ruta = os.path.join(DESTINO, nombre)
    img.save(ruta)
    print("  %-24s %s" % (nombre, img.size))


if __name__ == "__main__":
    print("Luces (blanco puro, se tinen por codigo):")
    guardar(halo(32, 2.6), "brillo.png")
    guardar(halo(64, 3.2), "brillo_grande.png")
    guardar(destello(), "destello.png")
