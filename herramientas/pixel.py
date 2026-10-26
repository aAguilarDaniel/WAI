# -*- coding: utf-8 -*-
"""Utilidades de dibujo a pixel para los generadores de arte de Who Am I.

Nada de esto interpola ni suaviza: cada primitiva escribe pixeles enteros. Es lo
que pide ARTE.md 1 ("todo el arte se produce a resolucion nativa, no se dibuja
grande y se reduce").

Lo usan generar_jugador.py y generar_props.py.
"""
import math

from PIL import Image, ImageDraw

TRANSPARENTE = (0, 0, 0, 0)


def lienzo(ancho, alto):
    return Image.new("RGBA", (ancho, alto), TRANSPARENTE)


def punto(img, x, y, color):
    x, y = int(round(x)), int(round(y))
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), color)


def brocha(img, x, y, grosor, color):
    """Cuadrado de lado `grosor` centrado en (x, y). El pincel de los trazos."""
    o = (grosor - 1) // 2
    for dy in range(grosor):
        for dx in range(grosor):
            punto(img, x - o + dx, y - o + dy, color)


def trazo(img, p0, p1, grosor, color):
    """Segmento grueso. Se camina a pasos enteros: sin antialias, sin huecos."""
    x0, y0 = int(round(p0[0])), int(round(p0[1]))
    x1, y1 = int(round(p1[0])), int(round(p1[1]))
    pasos = max(abs(x1 - x0), abs(y1 - y0))
    for i in range(pasos + 1):
        t = i / float(pasos) if pasos else 0.0
        brocha(img, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, grosor, color)


def barra(img, p0, p1, ancho, color):
    """Cuadrilatero entre dos puntos. Para el torso, que no es una linea gruesa:
    tiene que terminar EXACTAMENTE en las articulaciones o los hombros se pasan
    de la cabeza."""
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    largo = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / largo * ancho / 2.0, dx / largo * ancho / 2.0
    ImageDraw.Draw(img).polygon(
        [(p0[0] + nx, p0[1] + ny), (p1[0] + nx, p1[1] + ny),
         (p1[0] - nx, p1[1] - ny), (p0[0] - nx, p0[1] - ny)], fill=color)


def disco(img, centro, radio, color):
    ImageDraw.Draw(img).ellipse(
        [centro[0] - radio, centro[1] - radio, centro[0] + radio, centro[1] + radio],
        fill=color)


def extremo(origen, angulo, largo):
    """Punto a `largo` de `origen` en `angulo` grados.

    Convencion de todo el proyecto: 0 grados apunta HACIA ABAJO y el angulo crece
    hacia +x (la derecha). Asi una extremidad colgando es 0 y no hay que pensar.
    """
    a = math.radians(angulo)
    return (origen[0] + math.sin(a) * largo, origen[1] + math.cos(a) * largo)


def canto(img, color_borde, color_alto=None, alto_hasta=0):
    """Luz de canto por el borde derecho.

    ARTE.md 3 pide "una sola fuente de luz al fondo y baja que recorte todo en
    silueta". Como todas las poses miran a la derecha (el motor voltea el sprite
    con flip_h), el reborde va siempre por ahi: se pinta el pixel opaco mas a la
    derecha de cada fila. `color_alto` enciende mas fuerte las filas de la
    coronilla, que es lo primero que el ojo busca para leer la figura.
    """
    for y in range(img.height):
        borde = None
        for x in range(img.width):
            if img.getpixel((x, y))[3] > 0:
                borde = x
        if borde is None:
            continue
        if color_alto is not None and y < alto_hasta:
            img.putpixel((borde, y), color_alto)
        else:
            img.putpixel((borde, y), color_borde)


def pegar(hoja, celda, columna, fila):
    hoja.paste(celda, (columna * celda.width, fila * celda.height))


def contacto(celdas, escala=6, fondo=(196, 118, 42, 255), columnas=None, suelo=None):
    """Hoja de contacto ampliada, para revisar las poses de un vistazo.

    El fondo es la BRASA del cielo a proposito: el personaje se disena para
    leerse a contraluz (ARTE.md 3), asi que revisarlo sobre negro no dice nada.
    `suelo` pinta la fila de apoyo de cada celda: sin esa referencia no se puede
    juzgar si un pie flota o se hunde.
    """
    columnas = columnas or max(len(f) for f in celdas)
    w = celdas[0][0].width
    h = celdas[0][0].height
    img = Image.new("RGBA", (columnas * w * escala, len(celdas) * h * escala), fondo)
    d = ImageDraw.Draw(img)
    for f, fila in enumerate(celdas):
        oy = f * h * escala
        if suelo is not None:
            y = oy + (suelo + 1) * escala
            d.rectangle([0, y, img.width, y + 1], fill=(120, 58, 18, 255))
        for c, celda in enumerate(fila):
            grande = celda.resize((w * escala, h * escala), Image.NEAREST)
            img.alpha_composite(grande, (c * w * escala, oy))
        d.rectangle([0, oy, img.width, oy], fill=(120, 58, 18, 255))
    return img
