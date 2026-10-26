# -*- coding: utf-8 -*-
"""Genera las fuentes bitmap de Who Am I a partir de herramientas/fuente_datos.py.

Produce cuatro pares .png/.fnt en juego/ui/diario/fuentes/. El .fnt va en formato
BMFont de texto, que Godot 4 importa como FontFile sin antialiasing ni hinting.

    wai_base.fnt       Interfaz general: HUD, menu principal, ajustes.
    wai_humana.fnt     Diario en ruta humana: trazo irregular, baseline que baila.
    wai_hibrida.fnt    Diario en ruta ambigua: unas letras tiemblan y otras no.
    wai_maquina.fnt    Diario en ruta maquina: monoespaciada dura, sin temblor.

ARTE.md §6 pide tres fuentes legibles a 384x216 con altura de mayuscula 7-8 px y
que el cambio entre ellas sea el medidor del eje. Son variantes de la MISMA base
a proposito: lo que tiene que leerse es que es la misma mano la que cambia, no
que hay tres alfabetos distintos.

Uso:  python herramientas/generar_fuentes.py
      python herramientas/generar_fuentes.py --contacto
"""
import os
import random
import sys

from PIL import Image

import fuente_datos

ANCHO_CELDA = 5
ALTO_CELDA = 7
# Filas extra reservadas arriba para tildes y virgulillas.
ALTO_DIACRITICO = 2
ALTO_GLIFO = ALTO_CELDA + ALTO_DIACRITICO
# Descendente: g, j, p, q, y bajan por debajo de la linea base.
DESCENDENTE = 2
ALTO_LINEA = ALTO_GLIFO + DESCENDENTE + 1

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "juego")
DESTINO = os.path.join(RAIZ, "ui", "diario", "fuentes")

CON_COLA = set("gjpqy")
COLA_DESPLAZAMIENTO = 1


def _columnas_usadas(filas):
    """Primera y ultima columna con pixeles. Es lo que da el ancho variable."""
    usadas = [x for x in range(ANCHO_CELDA)
              for y in range(len(filas)) if filas[y][x] == "#"]
    if not usadas:
        return 0, 3
    return min(usadas), max(usadas) + 1


class Glifo(object):
    """Un caracter compuesto: mapa de bits, diacritico opcional y si lleva cola."""

    def __init__(self, caracter, filas, diacritico=None):
        self.caracter = caracter
        self.filas = list(filas)
        self.diacritico = diacritico
        self.baja = caracter in CON_COLA

    def pintar(self, estilo, rnd):
        """Lista de (x, y, intensidad) en coordenadas locales del glifo.

        El temblor mueve el GLIFO ENTERO, nunca sus filas por separado. Cizallar
        las filas a 5x7 px no da letra manuscrita: rompe la forma de la letra y
        el texto deja de leerse. La sensacion de mano se consigue con la baseline
        que baila de una letra a otra, un trazo mas grueso y alguna salpicadura.
        """
        puntos = []
        desvio_y = 0
        desvio_x = 0
        if estilo["baile_baseline"] and rnd.random() < estilo["prob_temblor"]:
            desvio_y = rnd.choice([-1, 1])
        if estilo["baile_horizontal"] and rnd.random() < estilo["prob_temblor"] * 0.6:
            desvio_x = 1
        cola = COLA_DESPLAZAMIENTO if self.baja else 0
        for y, fila in enumerate(self.filas):
            for x, celda in enumerate(fila):
                if celda == "#":
                    puntos.append((x + desvio_x, y + ALTO_DIACRITICO + cola + desvio_y, 1.0))
        if self.diacritico:
            for x, celda in enumerate(self.diacritico):
                if celda == "#":
                    puntos.append((x + desvio_x, desvio_y, 1.0))
        # Engrosado: un trazo escrito a mano no tiene un pixel de ancho constante.
        if estilo["engrosar"] and puntos:
            extra = []
            for bx, by, _ in puntos:
                if rnd.random() < estilo["prob_engrosar"]:
                    extra.append((bx, by + 1, 0.55))
            puntos.extend(extra)
        # Salpicadura de tinta al lado del trazo. Solo la manuscrita la lleva.
        if estilo["tinta"] and puntos and rnd.random() < estilo["prob_tinta"]:
            bx, by, _ = puntos[rnd.randrange(len(puntos))]
            puntos.append((bx + rnd.choice([-1, 1]), by, 0.45))
        return puntos


def construir_glifos():
    glifos = {}
    for caracter, filas in fuente_datos.BASE.items():
        glifos[caracter] = Glifo(caracter, filas)
    for caracter, par in fuente_datos.ACENTUADAS.items():
        glifos[caracter] = Glifo(caracter, fuente_datos.BASE[par[0]], par[1])
    return glifos


ESTILOS = [
    ("base", {
        "baile_baseline": False, "baile_horizontal": False, "engrosar": False,
        "tinta": False, "prob_temblor": 0.0, "prob_engrosar": 0.0, "prob_tinta": 0.0,
        "monoespaciada": False, "espaciado": 1, "semilla": 1,
        "descripcion": "Interfaz general. Limpia, sin temblor.",
    }),
    ("humana", {
        "baile_baseline": True, "baile_horizontal": True, "engrosar": True,
        "tinta": True, "prob_temblor": 0.42, "prob_engrosar": 0.14, "prob_tinta": 0.30,
        "monoespaciada": False, "espaciado": 1, "semilla": 1974,
        "descripcion": "Manuscrita: baseline que baila, trazo grueso, tinta.",
    }),
    ("hibrida", {
        "baile_baseline": True, "baile_horizontal": False, "engrosar": True,
        "tinta": True, "prob_temblor": 0.20, "prob_engrosar": 0.05, "prob_tinta": 0.08,
        "monoespaciada": False, "espaciado": 1, "semilla": 2006,
        "descripcion": "Hibrida: unas letras a mano, otras mecanografiadas.",
    }),
    ("maquina", {
        "baile_baseline": False, "baile_horizontal": False, "engrosar": False,
        "tinta": False, "prob_temblor": 0.0, "prob_engrosar": 0.0, "prob_tinta": 0.0,
        "monoespaciada": True, "espaciado": 1, "semilla": 7,
        "descripcion": "Maquina de escribir: monoespaciada, espaciado perfecto.",
    }),
]


def _medida(caracter, glifo, estilo):
    """(columna izquierda del recorte, avance en px) del glifo en este estilo."""
    if caracter == " ":
        return 0, 4
    if estilo["monoespaciada"]:
        return 0, ANCHO_CELDA + estilo["espaciado"]
    izq, der = _columnas_usadas(glifo.filas)
    ancho = der - izq
    if estilo["baile_horizontal"]:
        ancho += 1
    return izq, ancho + estilo["espaciado"]


def generar(nombre, estilo, glifos):
    rnd = random.Random(estilo["semilla"])
    orden = sorted(glifos.keys(), key=lambda c: ord(c))

    columnas = 16
    celda_w = ANCHO_CELDA + 4
    celda_h = ALTO_GLIFO + DESCENDENTE + 1
    filas_atlas = (len(orden) + columnas - 1) // columnas
    atlas = Image.new("RGBA", (columnas * celda_w, filas_atlas * celda_h), (255, 255, 255, 0))
    pixeles = atlas.load()

    lineas = []
    for indice, caracter in enumerate(orden):
        glifo = glifos[caracter]
        izq, avance = _medida(caracter, glifo, estilo)
        cx = (indice % columnas) * celda_w
        cy = (indice // columnas) * celda_h
        margen = 1 if estilo["baile_horizontal"] else 0
        for px, py, intensidad in glifo.pintar(estilo, rnd):
            ax, ay = cx + (px - izq) + margen, cy + py
            if 0 <= ax < atlas.width and 0 <= ay < atlas.height:
                valor = int(255 * intensidad)
                pixeles[ax, ay] = (255, 255, 255, max(pixeles[ax, ay][3], valor))
        lineas.append(
            "char id=%d x=%d y=%d width=%d height=%d xoffset=0 yoffset=0 "
            "xadvance=%d page=0 chnl=15" % (
                ord(caracter), cx, cy, celda_w - 1, celda_h - 1, avance + margen))

    os.makedirs(DESTINO, exist_ok=True)
    nombre_png = "wai_%s.png" % nombre
    atlas.save(os.path.join(DESTINO, nombre_png))

    cabecera = [
        'info face="WAI %s" size=%d bold=0 italic=0 charset="" unicode=1 '
        'stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0' % (nombre, ALTO_LINEA),
        "common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0" % (
            ALTO_LINEA, ALTO_GLIFO, atlas.width, atlas.height),
        'page id=0 file="%s"' % nombre_png,
        "chars count=%d" % len(lineas),
    ]
    with open(os.path.join(DESTINO, "wai_%s.fnt" % nombre), "w", encoding="utf-8") as f:
        f.write("\n".join(cabecera + lineas) + "\n")
    print("  %-18s %s  %d glifos  %s" % (
        "wai_%s.fnt" % nombre, atlas.size, len(lineas), estilo["descripcion"]))


def hoja_de_contacto(glifos):
    """Prueba visual: las cuatro variantes escribiendo la misma frase."""
    frase = "Soy humano o soy una maquina mas? 0123456789"
    frase2 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz"
    filas = []
    for nombre, estilo in ESTILOS:
        filas.append((estilo, frase))
        filas.append((estilo, frase2))
    alto = len(filas) * (ALTO_LINEA + 3) + 10
    img = Image.new("RGBA", (420, alto), (14, 11, 16, 255))
    pix = img.load()
    y = 5
    for estilo, texto in filas:
        rnd = random.Random(estilo["semilla"])
        x = 5
        for caracter in texto:
            glifo = glifos.get(caracter)
            if glifo is None:
                x += 4
                continue
            izq, avance = _medida(caracter, glifo, estilo)
            for px, py, intensidad in glifo.pintar(estilo, rnd):
                ax, ay = x + (px - izq), y + py
                if 0 <= ax < img.width and 0 <= ay < img.height:
                    v = int(200 * intensidad)
                    pix[ax, ay] = (v + 45, v + 40, v + 34, 255)
            x += avance
        y += ALTO_LINEA + 3
    img = img.resize((img.width * 3, img.height * 3), Image.NEAREST)
    ruta = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                        "capturas", "contacto_fuentes.png")
    img.save(ruta)
    print("hoja de contacto: %s" % os.path.normpath(ruta))


if __name__ == "__main__":
    fuente_datos.comprobar()
    tabla = construir_glifos()
    print("Fuentes bitmap (celda %dx%d, alto de linea %d):" % (
        ANCHO_CELDA, ALTO_CELDA, ALTO_LINEA))
    for nombre_estilo, datos in ESTILOS:
        generar(nombre_estilo, datos, tabla)
    if "--contacto" in sys.argv:
        hoja_de_contacto(tabla)
