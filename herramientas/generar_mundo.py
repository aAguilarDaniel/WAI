# -*- coding: utf-8 -*-
"""Genera el arte del mundo jugable: tileset, objetos de escenario, la fachada
del edificio del final del nivel 1 y todo el interior del nivel 2.

Uso:  python herramientas/generar_mundo.py [--contacto]

Igual que generar_siluetas.py y generar_props.py, esto NO es pixel art definitivo:
es composicion geometrica legible para que el juego se pueda ver y probar. Las
medidas de cada PNG son las definitivas (art/PLACEHOLDERS.md), asi que
reemplazarlos por arte a mano no toca codigo.

Reglas de valor que respeta (art/PLACEHOLDERS.md):
  - El protagonista (17, 13, 17) es lo mas oscuro del cuadro. Nada de lo que va
    DETRAS de el baja de ese valor.
  - Solo lo que va DELANTE del jugador (la capa de cables del interior) puede ser
    casi negro.
  - El color fuerte se reserva para las luces: ambar humano, verde fosforo y
    cian maquina (ARTE.md §1). El resto vive en la escala de marrones/grises.
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "juego", "art")
PH = os.path.join(RAIZ, "placeholder")
CAPTURAS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "capturas")

# --- Exterior (mismos valores que generar_siluetas.py) ---
TERRENO = (52, 38, 42)
VETA = (40, 29, 34)
CEJA_F = (186, 116, 54)
CEJA_M = (118, 72, 44)
CEJA_S = (72, 48, 42)
ESTRATO_1 = (46, 33, 38)
ESTRATO_2 = (38, 28, 33)
ESTRATO_3 = (33, 24, 29)

METAL = (70, 62, 66)
METAL_CLARO = (104, 90, 88)
METAL_OSC = (46, 40, 46)
OXIDO = (104, 62, 40)
OXIDO_OSC = (72, 44, 34)

# --- Interior: el polo frio, apagado. La luz la ponen las lamparas. ---
PANEL = (50, 47, 58)
PANEL_OSC = (38, 36, 46)
PANEL_MAS_OSC = (30, 28, 37)
PANEL_CLARO = (68, 64, 76)
BORDE_INT = (172, 140, 100)      # canto del suelo, luz de lampara de tungsteno
BORDE_INT_M = (110, 92, 78)

# --- Luces (ARTE.md §1, los dos polos) ---
AMBAR = (250, 214, 132)
AMBAR_M = (214, 138, 58)
FOSFORO = (108, 196, 126)
FOSFORO_VIVO = (176, 255, 190)
CIAN = (120, 232, 246)
ROJO = (214, 72, 52)


def A(c, a=255):
    return tuple(c[:3]) + (a,)


def lienzo(w, h, color=(0, 0, 0, 0)):
    return Image.new("RGBA", (w, h), color)


def rect(d, x0, y0, x1, y1, c):
    if x1 < x0 or y1 < y0:
        return
    d.rectangle([x0, y0, x1, y1], fill=A(c))


def picado(img, x0, y0, w, h, base, veta, prob, rnd):
    """Dithering irregular (ARTE.md §5), nunca ruido uniforme."""
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            img.putpixel((x, y), A(veta if rnd.random() < prob else base))


def mezcla(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def remaches(d, puntos, color):
    for (x, y) in puntos:
        d.point([(x, y)], fill=A(color))


# =========================================================== TILESET ==========
# 128x32: 8 columnas x 2 filas de 16x16.
#   Fila 0, exterior:  0 solida  1 superficie  2 relleno  3 viga
#                      4 profundo  5 superficie con zanja  6 solida con tubo
#                      7 solida con placa base
#   Fila 1, interior:  0 suelo  1 muro  2 muro con rejilla  3 pasarela (un sentido)
#                      4 techo  5 relleno  6 suelo con franjas  7 bloque de rack
# Que celdas llevan colision lo decide tools/constructor_nivel.gd, no el PNG.

def _solida_ext(img, d, ox, oy, rnd):
    picado(img, ox, oy, 16, 16, TERRENO, VETA, 0.22, rnd)
    # Estratos: lineas rotas horizontales. Le dan al suelo lectura de capas de
    # escombro compactado en vez de bloque de plastilina.
    for _ in range(2):
        y = oy + rnd.randint(3, 13)
        x = ox + rnd.randint(0, 6)
        rect(d, x, y, min(ox + 15, x + rnd.randint(4, 10)), y, VETA)
    # Algun cascote mas claro.
    for _ in range(3):
        x, y = ox + rnd.randint(1, 14), oy + rnd.randint(2, 14)
        rect(d, x, y, x + 1, y, (64, 48, 50))


def _ceja(d, ox, oy, rnd):
    rect(d, ox, oy, ox + 15, oy, CEJA_F)
    rect(d, ox, oy + 1, ox + 15, oy + 1, CEJA_M)
    rect(d, ox, oy + 2, ox + 15, oy + 2, CEJA_S)
    for mx in range(ox, ox + 16):
        if rnd.random() < 0.2:
            d.point([(mx, oy)], fill=A(CEJA_M))
        if rnd.random() < 0.12:
            d.point([(mx, oy + 2)], fill=A(CEJA_M))


def tileset():
    img = lienzo(128, 32)
    d = ImageDraw.Draw(img)
    rnd = random.Random(1812)

    # --- fila 0: exterior ---
    _solida_ext(img, d, 0, 0, rnd)                                   # 0

    _solida_ext(img, d, 16, 0, rnd)                                  # 1
    _ceja(d, 16, 0, rnd)

    picado(img, 32, 0, 16, 16, ESTRATO_1, ESTRATO_2, 0.3, rnd)      # 2
    for _ in range(2):
        y = rnd.randint(2, 13)
        rect(d, 32 + rnd.randint(0, 5), y, 32 + rnd.randint(9, 15), y, ESTRATO_2)

    # 3: viga de acero. Una plataforma suelta tiene que leerse como algo
    # colocado, no como un pedazo de suelo flotando.
    rect(d, 48, 0, 63, 0, CEJA_F)
    rect(d, 48, 1, 63, 2, METAL_CLARO)
    rect(d, 48, 3, 63, 3, METAL_OSC)
    rect(d, 50, 4, 61, 11, METAL)
    for cx in (52, 59):                         # agujeros de aligeramiento
        rect(d, cx - 1, 6, cx + 1, 9, METAL_OSC)
        rect(d, cx, 5, cx, 10, METAL_OSC)
    rect(d, 48, 12, 63, 13, METAL)
    rect(d, 48, 14, 63, 15, METAL_OSC)
    remaches(d, [(49, 2), (55, 2), (62, 2), (49, 13), (62, 13)], (140, 120, 104))
    for _ in range(5):                          # oxido
        x, y = rnd.randint(49, 62), rnd.randint(4, 14)
        d.point([(x, y)], fill=A(OXIDO))

    picado(img, 64, 0, 16, 16, ESTRATO_3, ESTRATO_2, 0.35, rnd)     # 4

    # 5: superficie con zanja de cables
    _solida_ext(img, d, 80, 0, rnd)
    _ceja(d, 80, 0, rnd)
    rect(d, 80, 6, 95, 9, (28, 21, 25))
    rect(d, 80, 7, 95, 7, OXIDO_OSC)
    rect(d, 80, 8, 95, 8, (44, 52, 56))
    for x in range(81, 95, 4):
        d.point([(x, 6)], fill=A(METAL))

    # 6: solida con tubo
    _solida_ext(img, d, 96, 0, rnd)
    rect(d, 96, 5, 111, 10, METAL_OSC)
    rect(d, 96, 5, 111, 5, METAL_CLARO)
    rect(d, 96, 6, 111, 6, METAL)
    rect(d, 96, 10, 111, 10, (30, 24, 28))
    rect(d, 103, 4, 105, 11, OXIDO_OSC)          # abrazadera

    # 7: solida con placa base enterrada
    _solida_ext(img, d, 112, 0, rnd)
    rect(d, 113, 4, 126, 12, (50, 52, 44))
    rect(d, 113, 4, 126, 4, (70, 72, 58))
    for x in range(114, 126, 3):
        rect(d, x, 6, x, 11, (64, 62, 48))
    rect(d, 116, 7, 119, 9, (32, 30, 34))
    rect(d, 121, 7, 124, 9, (32, 30, 34))
    d.point([(117, 8)], fill=A((80, 40, 34)))   # un led muerto

    # --- fila 1: interior ---
    oy = 16

    def placa(ox, base=PANEL):
        picado(img, ox, oy, 16, 16, base, PANEL_OSC, 0.12, rnd)
        rect(d, ox, oy, ox, oy + 15, PANEL_MAS_OSC)       # juntas
        rect(d, ox + 15, oy, ox + 15, oy + 15, PANEL_CLARO)

    # 0: suelo de chapa con canto iluminado
    placa(0)
    rect(d, 0, oy, 15, oy, BORDE_INT)
    rect(d, 0, oy + 1, 15, oy + 1, BORDE_INT_M)
    rect(d, 0, oy + 2, 15, oy + 2, PANEL_CLARO)
    for x in range(2, 15, 4):                    # chapa estriada
        for y in range(oy + 5, oy + 15, 4):
            d.point([(x + (y // 4) % 2, y)], fill=A(PANEL_CLARO))
    remaches(d, [(2, oy + 4), (13, oy + 4)], (110, 104, 112))

    # 1: muro de paneles
    picado(img, 16, oy, 16, 16, PANEL_OSC, PANEL_MAS_OSC, 0.15, rnd)
    rect(d, 16, oy + 7, 31, oy + 7, PANEL_MAS_OSC)
    rect(d, 16, oy + 8, 31, oy + 8, PANEL)
    remaches(d, [(18, oy + 2), (29, oy + 2), (18, oy + 13), (29, oy + 13)], PANEL_CLARO)

    # 2: muro con rejilla de ventilacion
    picado(img, 32, oy, 16, 16, PANEL_OSC, PANEL_MAS_OSC, 0.15, rnd)
    rect(d, 34, oy + 3, 45, oy + 12, PANEL_MAS_OSC)
    for y in range(oy + 4, oy + 12, 2):
        rect(d, 35, y, 44, y, (22, 20, 28))
        rect(d, 35, y + 1, 44, y + 1, PANEL)

    # 3: pasarela de rejilla. Solo los 4 px de arriba son suelo (un sentido).
    ox = 48
    rect(d, ox, oy, ox + 15, oy, BORDE_INT)
    rect(d, ox, oy + 1, ox + 15, oy + 1, BORDE_INT_M)
    rect(d, ox, oy + 2, ox + 15, oy + 3, PANEL_CLARO)
    for x in range(ox + 1, ox + 16, 3):
        d.point([(x, oy + 2)], fill=A(PANEL_OSC))
    # Celosia de debajo: triangulos. Calada para que se vea el fondo detras.
    for i in range(0, 16, 8):
        for t in range(6):
            d.point([(ox + i + t, oy + 4 + t)], fill=A(PANEL))
            d.point([(ox + i + 7 - t, oy + 4 + t)], fill=A(PANEL))
    rect(d, ox, oy + 10, ox + 15, oy + 10, PANEL)

    # 4: techo. El labio de abajo recoge la luz de las lamparas.
    picado(img, 64, oy, 16, 16, PANEL_OSC, PANEL_MAS_OSC, 0.18, rnd)
    rect(d, 64, oy + 13, 79, oy + 13, PANEL_CLARO)
    rect(d, 64, oy + 14, 79, oy + 15, (60, 52, 58))
    for x in range(66, 79, 6):
        rect(d, x, oy + 3, x + 2, oy + 9, PANEL_MAS_OSC)

    # 5: relleno interior, sin colision. Mas oscuro que el muro pero no mucho:
    # mas negro se leia como un hueco en la pared y no como masa.
    picado(img, 80, oy, 16, 16, (36, 34, 44), (32, 30, 40), 0.3, rnd)
    rect(d, 80, oy + 7, 95, oy + 7, (30, 28, 37))
    rect(d, 87, oy, 87, oy + 15, (32, 30, 39))

    # 6: suelo con franjas de peligro gastadas
    placa(96)
    rect(d, 96, oy, 111, oy, BORDE_INT)
    rect(d, 96, oy + 1, 111, oy + 1, BORDE_INT_M)
    for x in range(96, 112):
        for y in range(oy + 3, oy + 7):
            if ((x + y) // 3) % 2 == 0 and rnd.random() > 0.18:
                d.point([(x, y)], fill=A((150, 116, 46)))
            else:
                d.point([(x, y)], fill=A((40, 36, 42)))

    # 7: bloque de rack (caja solida para escalones y coberturas)
    ox = 112
    rect(d, ox, oy, ox + 15, oy + 15, (60, 58, 68))
    rect(d, ox, oy, ox + 15, oy, BORDE_INT_M)
    rect(d, ox + 2, oy + 2, ox + 13, oy + 13, (34, 32, 42))
    for y in range(oy + 4, oy + 13, 3):
        rect(d, ox + 3, y, ox + 12, y, (46, 44, 54))
    d.point([(ox + 11, oy + 4)], fill=A(FOSFORO))
    d.point([(ox + 11, oy + 7)], fill=A(AMBAR_M))
    d.point([(ox + 9, oy + 4)], fill=A((60, 120, 72)))
    return img


# ========================================================= PROPS EXT ==========

def farola():
    """12x48. Farola doblada. La luz la pone un Sprite aditivo en el juego."""
    img = lienzo(12, 48)
    d = ImageDraw.Draw(img)
    rect(d, 4, 10, 5, 47, METAL_OSC)
    rect(d, 5, 10, 5, 47, METAL)
    rect(d, 3, 44, 7, 47, METAL_OSC)
    for (x, y) in [(5, 9), (6, 8), (7, 7), (8, 6), (9, 6)]:     # brazo curvado
        d.point([(x, y)], fill=A(METAL))
    rect(d, 7, 7, 11, 8, METAL_OSC)                # pantalla
    rect(d, 8, 9, 10, 9, AMBAR)                    # bombilla
    rect(d, 8, 10, 10, 10, AMBAR_M)
    for y in range(14, 44, 7):
        d.point([(4, y)], fill=A(OXIDO))
    return img


def poste():
    """12x64. Poste de cables con travesano y aisladores."""
    img = lienzo(12, 64)
    d = ImageDraw.Draw(img)
    rect(d, 5, 2, 6, 63, (58, 44, 42))
    rect(d, 6, 2, 6, 63, (74, 56, 50))
    rect(d, 0, 6, 11, 7, (58, 44, 42))
    rect(d, 2, 14, 9, 15, (58, 44, 42))
    for x in (0, 3, 8, 11):
        rect(d, x, 4, x, 5, (120, 110, 100))
    rect(d, 2, 12, 2, 13, (120, 110, 100))
    rect(d, 9, 12, 9, 13, (120, 110, 100))
    return img


def cartel():
    """40x30. Armazon de un cartel de neon roto. Sin letras: los tubos dibujan
    formas que ya no dicen nada. Los tramos encendidos son cian."""
    img = lienzo(40, 30)
    d = ImageDraw.Draw(img)
    rect(d, 2, 0, 37, 17, (40, 36, 44))
    rect(d, 3, 1, 36, 16, (28, 26, 32))
    rect(d, 6, 18, 7, 29, METAL_OSC)
    rect(d, 32, 18, 33, 29, METAL_OSC)
    # tubos: un ojo (la maquina como religion) y unas barras
    for a in range(0, 360, 8):
        x = 13 + int(round(math.cos(math.radians(a)) * 6))
        y = 8 + int(round(math.sin(math.radians(a)) * 4))
        apagado = 200 < a < 300
        d.point([(x, y)], fill=A((52, 70, 76) if apagado else CIAN))
    rect(d, 12, 7, 14, 9, CIAN)
    rect(d, 23, 5, 33, 5, CIAN)
    rect(d, 23, 9, 29, 9, (52, 70, 76))
    rect(d, 23, 12, 33, 12, CIAN)
    rect(d, 30, 9, 33, 9, CIAN)
    return img


def chatarra():
    """32x12. Monton de escombros con una carcasa de monitor."""
    img = lienzo(32, 12)
    d = ImageDraw.Draw(img)
    rnd = random.Random(5)
    perfil = [11, 9, 8, 7, 6, 6, 5, 5, 4, 4, 5, 6, 4, 3, 3, 4,
              5, 6, 6, 5, 5, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11]
    for x, top in enumerate(perfil):
        for y in range(top, 12):
            c = (64, 48, 50) if rnd.random() < 0.3 else (48, 36, 40)
            d.point([(x, y)], fill=A(c))
        d.point([(x, top)], fill=A(CEJA_M))
    rect(d, 11, 2, 18, 7, (60, 56, 64))           # carcasa de monitor
    rect(d, 12, 3, 17, 6, (30, 36, 34))
    d.point([(16, 4)], fill=A((70, 120, 86)))
    rect(d, 22, 3, 29, 4, METAL)                  # una barra suelta
    return img


def barril():
    """10x14."""
    img = lienzo(10, 14)
    d = ImageDraw.Draw(img)
    rect(d, 1, 0, 8, 13, OXIDO_OSC)
    rect(d, 2, 0, 3, 13, OXIDO)
    rect(d, 0, 3, 9, 3, (60, 40, 32))
    rect(d, 0, 10, 9, 10, (60, 40, 32))
    rect(d, 1, 0, 8, 0, (140, 92, 60))
    return img


def servidor_caido():
    """30x14. Rack volcado. El led que todavia parpadea va aparte."""
    img = lienzo(30, 14)
    d = ImageDraw.Draw(img)
    rect(d, 0, 3, 29, 13, (56, 52, 60))
    rect(d, 0, 3, 29, 3, (92, 84, 84))
    rect(d, 2, 5, 27, 12, (34, 32, 40))
    for x in range(4, 26, 4):
        rect(d, x, 6, x + 2, 11, (44, 42, 50))
    d.point([(6, 7)], fill=A((60, 110, 70)))
    rect(d, 24, 0, 29, 2, METAL_OSC)              # tapa doblada
    return img


def valla():
    """36x18. Barandilla rota."""
    img = lienzo(36, 18)
    d = ImageDraw.Draw(img)
    for x in (1, 12, 24):
        rect(d, x, 2, x + 1, 17, METAL_OSC)
    rect(d, 0, 3, 26, 3, METAL)
    rect(d, 0, 9, 22, 9, METAL)
    for i in range(10):                            # tramo doblado
        d.point([(26 + i, 3 + i // 2)], fill=A(METAL))
    rect(d, 34, 16, 35, 17, METAL_OSC)
    return img


# ===================================================== FACHADA (nivel 1) =====

def edificio():
    """224x352. La fachada del edificio en el que termina el nivel 1.

    Es una catedral de servidores (ARTE.md §3, "racks del tamano de naves de
    catedral"): nervios verticales de hormigon, ventanas en rejilla casi todas
    muertas, un roseton que es un ventilador gigante con un tubo de fosforo en
    el centro, y abajo el portal: la unica abertura con luz, verde, que es lo
    que dice "por aqui" sin escribir nada.

    El portal mide 32x48 y su centro queda en x = 112 (mitad de la fachada).
    """
    w, h = 224, 352
    img = lienzo(w, h)
    d = ImageDraw.Draw(img)
    rnd = random.Random(1854)
    muro = (60, 45, 51)
    muro_osc = (48, 36, 42)
    nervio = (74, 56, 60)
    nervio_luz = (132, 84, 58)

    # Silueta: cuerpo central alto y dos alas mas bajas, remate mordido.
    rect(d, 24, 40, 199, h - 1, muro)
    rect(d, 0, 120, 23, h - 1, muro_osc)
    rect(d, 200, 104, 223, h - 1, muro_osc)
    for x in range(24, 200, 8):                  # remate roto
        alto = rnd.choice([0, 3, 6, 10, 14])
        rect(d, x, 40 - alto, x + 5, 40, muro)
    rect(d, 108, 0, 109, 40, METAL_OSC)           # antena
    rect(d, 104, 12, 113, 12, METAL_OSC)
    rect(d, 102, 22, 115, 22, METAL_OSC)
    d.point([(108, 0)], fill=A(ROJO))

    for _ in range(2600):                          # picado de la piedra
        x, y = rnd.randrange(w), rnd.randrange(h)
        if img.getpixel((x, y))[3] > 0:
            d.point([(x, y)], fill=A(muro_osc))

    # Nervios verticales con canto iluminado por la brasa (que llega de la izquierda)
    for x in (24, 60, 96, 124, 160, 196):
        rect(d, x, 40, x + 3, h - 1, nervio)
        rect(d, x, 40, x, h - 1, nervio_luz)
    for y in (96, 176, 256):                      # cornisas
        rect(d, 20, y, 203, y + 3, nervio)
        rect(d, 20, y, 203, y, nervio_luz)

    # Ventanas: casi todas muertas. Unas pocas ambar (humano) y verde (maquina).
    for y in range(104, 256, 18):
        for x in range(30, 196, 12):
            if 82 <= x <= 140 and y < 176:         # hueco del roseton
                continue
            if any(abs(x - n) < 6 for n in (60, 96, 124, 160)):
                continue
            r = rnd.random()
            color = (24, 20, 26)
            if r < 0.07:
                color = AMBAR_M
            elif r < 0.11:
                color = FOSFORO
            elif r < 0.32:
                color = (40, 30, 34)
            rect(d, x, y, x + 5, y + 9, color)
            rect(d, x, y + 10, x + 5, y + 10, nervio)
    for x, y in ((6, 140), (6, 170), (6, 200), (206, 130), (206, 190), (210, 230)):
        rect(d, x, y, x + 9, y + 12, (24, 20, 26))

    # El roseton: un ventilador del tamano de un roseton gotico.
    cx, cy, r = 112, 140, 26
    for yy in range(cy - r - 3, cy + r + 4):
        for xx in range(cx - r - 3, cx + r + 4):
            dist = math.hypot(xx - cx, yy - cy)
            if dist <= r + 3:
                d.point([(xx, yy)], fill=A(nervio if dist > r else (20, 26, 26)))
    for a in range(0, 360, 30):                    # aspas
        for t in range(4, r):
            ang = math.radians(a + t * 2.2)
            d.point([(cx + int(math.cos(ang) * t), cy + int(math.sin(ang) * t))],
                    fill=A((58, 70, 68)))
    for yy in range(cy - 5, cy + 6):               # el ojo de fosforo
        for xx in range(cx - 5, cx + 6):
            if math.hypot(xx - cx, yy - cy) <= 5:
                d.point([(xx, yy)], fill=A(FOSFORO))
    rect(d, cx - 2, cy - 2, cx + 2, cy + 2, FOSFORO_VIVO)

    # El portal: arco apuntado, interior oscuro con brillo verde abajo.
    px0, px1, ptop = 96, 127, h - 56
    rect(d, px0 - 6, ptop - 20, px1 + 6, h - 1, nervio)
    for x in range(px0 - 6, px1 + 7):
        d.point([(x, ptop - 20)], fill=A(nervio_luz))
    medio = (px0 + px1) / 2.0
    for y in range(ptop - 14, h):
        for x in range(px0, px1 + 1):
            if y < ptop:
                ancho = (y - (ptop - 14)) * 16.0 / 14.0
                if abs(x - medio) > ancho:
                    continue
            t = (y - (ptop - 14)) / 70.0
            d.point([(x, y)], fill=A(mezcla((16, 20, 20), (44, 104, 70), t - 0.2)))
    rect(d, px0 - 10, h - 3, px1 + 10, h - 1, (64, 50, 52))    # umbral
    rect(d, px0 - 10, h - 3, px1 + 10, h - 3, CEJA_M)

    for x0 in (40, 150, 186):                      # cables por la fachada
        x = x0
        for y in range(60, h - 30):
            if rnd.random() < 0.08:
                x += rnd.choice((-1, 1))
            d.point([(x, y)], fill=A((34, 26, 30)))
    return img


# ======================================================== INTERIOR ============

ANCHO, ALTO = 768, 216


def _envolver(d, x0, y0, x1, y1, c):
    """Rectangulo que se repite por el borde: las capas hacen scroll infinito."""
    rect(d, x0, y0, x1, y1, c)
    if x1 >= ANCHO:
        rect(d, x0 - ANCHO, y0, x1 - ANCHO, y1, c)
    if x0 < 0:
        rect(d, x0 + ANCHO, y0, x1 + ANCHO, y1, c)


def capa_nave():
    """La nave de la catedral: arcada apuntada repetida hasta perderse, con
    ventanales altos por los que entra la brasa del exterior. Lo mas lejano del
    interior: poco contraste, casi monocromo (perspectiva atmosferica)."""
    img = lienzo(ANCHO, ALTO)
    d = ImageDraw.Draw(img)
    pilar = (52, 46, 58)
    pilar_luz = (66, 56, 64)
    vano = 96
    for i in range(ANCHO // vano):
        x = i * vano
        vx0, vx1 = x + 34, x + 62                    # ventanal: la luz de fuera
        medio = (vx0 + vx1) / 2.0
        for y in range(18, 150):
            for xx in range(vx0, vx1):
                if y < 34 and abs(xx - medio) > (y - 18) * 0.9:
                    continue
                t = 1.0 - (y - 18) / 132.0
                c = mezcla((44, 36, 44), (124, 78, 52), t * 0.85)
                if (xx - vx0) % 7 == 0 or (y - 18) % 22 == 0:
                    c = pilar                       # tracerias
                d.point([(xx, y)], fill=A(c))
        _envolver(d, x - 6, 0, x + 6, ALTO - 1, pilar)
        _envolver(d, x - 6, 0, x - 6, ALTO - 1, pilar_luz)
        for t in range(0, 49):                       # arcos apuntados
            ay = int(70 - math.sqrt(max(0.0, 48 * 48 - (t - 48) ** 2)) * 0.9)
            _envolver(d, x + t, ay, x + t, ay + 3, pilar)
            _envolver(d, x + vano - t, ay, x + vano - t, ay + 3, pilar)
    for y in range(150, ALTO):                       # bruma en la base
        a = int(150 * (y - 150) / 66.0)
        for x in range(ANCHO):
            p = img.getpixel((x, y))
            base = p[:3] if p[3] > 0 else (40, 34, 42)
            img.putpixel((x, y), A(mezcla(base, (46, 38, 46), 0.6), max(p[3], a)))
    return img


def capa_racks():
    """Torres de servidores a media distancia. Leds sueltos, casi todos muertos;
    los vivos en verde fosforo y ambar, nunca muchos."""
    img = lienzo(ANCHO, ALTO)
    d = ImageDraw.Draw(img)
    rnd = random.Random(42)
    x = 0
    cuerpo = (44, 40, 52)
    canto = (60, 54, 66)
    while x < ANCHO:
        w = rnd.randint(18, 30)
        alto = rnd.randint(110, 190)
        top = ALTO - alto
        _envolver(d, x, top, x + w - 1, ALTO - 1, cuerpo)
        _envolver(d, x, top, x + w - 1, top, canto)
        for yy in range(top + 6, ALTO - 4, 6):
            _envolver(d, x + 2, yy, x + w - 3, yy, (38, 34, 46))
            if rnd.random() < 0.22:
                c = FOSFORO if rnd.random() < 0.6 else AMBAR_M
                lx = x + rnd.randint(3, w - 4)
                _envolver(d, lx, yy + 2, lx, yy + 2, mezcla(c, cuerpo, 0.35))
        if rnd.random() < 0.5:                       # cable entre torres
            cy = top + rnd.randint(4, 20)
            largo = rnd.randint(20, 46)
            for t in range(largo):
                sag = int(math.sin(t / float(largo) * math.pi) * 8)
                _envolver(d, x + w + t, cy + sag, x + w + t, cy + sag, (36, 32, 42))
        x += w + rnd.randint(6, 26)
    return img


def capa_columnas():
    """Columnas cercanas con haces de cable. Mas contraste, pero nunca por
    debajo del protagonista."""
    img = lienzo(ANCHO, ALTO)
    d = ImageDraw.Draw(img)
    rnd = random.Random(7)
    col = (42, 36, 46)
    luz = (80, 62, 62)
    for x in (40, 290, 520):
        _envolver(d, x, 0, x + 27, ALTO - 1, col)
        _envolver(d, x, 0, x, ALTO - 1, luz)
        for y in range(0, ALTO, 24):
            _envolver(d, x - 2, y, x + 29, y + 2, (50, 42, 50))
        for k in range(4):                           # haz de cables
            cx = x + 30 + k * 3
            largo = rnd.randint(60, 150)
            for y in range(0, largo):
                desvio = 1 if (y // 9 + k) % 3 == 0 else 0
                _envolver(d, cx + desvio, y, cx + desvio, y, (34, 30, 38))
    _envolver(d, 0, 40, ANCHO - 1, 42, (46, 40, 50))  # pasarela lejana
    for x in range(0, ANCHO, 12):
        _envolver(d, x, 43, x, 49, (40, 34, 44))
    return img


def capa_cables():
    """Delante del jugador. Cables y cadenas que recortan el cuadro desde
    arriba. Casi transparente: si tapa, estorba."""
    img = lienzo(ANCHO, ALTO)
    d = ImageDraw.Draw(img)
    rnd = random.Random(3)
    negro = (10, 8, 12)
    for _ in range(9):
        x = rnd.randrange(ANCHO)
        largo = rnd.randint(18, 70)
        cadena = rnd.random() < 0.35
        for y in range(largo):
            if cadena and y % 3 == 1:
                _envolver(d, x - 1, y, x + 1, y, negro)
            else:
                _envolver(d, x, y, x, y, negro)
    for _ in range(3):                              # cable en catenaria
        x0 = rnd.randrange(ANCHO)
        luz = rnd.randint(80, 200)
        flecha = rnd.randint(14, 34)
        for t in range(luz):
            y = int(math.sin(t / float(luz) * math.pi) * flecha)
            _envolver(d, x0 + t, y, x0 + t, y + 1, negro)
    return img


# ------------------------------------------------------- props interior -------

def rack():
    """24x56. Armario de servidores en pie. Los leds vivos los pone el juego."""
    img = lienzo(24, 56)
    d = ImageDraw.Draw(img)
    rnd = random.Random(11)
    rect(d, 0, 0, 23, 55, (62, 58, 70))
    rect(d, 0, 0, 23, 0, BORDE_INT_M)
    rect(d, 2, 2, 21, 53, (34, 32, 42))
    for y in range(4, 52, 4):
        rect(d, 3, y, 20, y + 2, (44, 42, 52))
        rect(d, 3, y + 2, 20, y + 2, (30, 28, 36))
        if rnd.random() < 0.4:
            d.point([(18, y + 1)], fill=A((60, 104, 70)))
    rect(d, 21, 2, 21, 53, (50, 48, 58))
    return img


def consola():
    """32x22. Mesa con terminal apagado y teclado."""
    img = lienzo(32, 22)
    d = ImageDraw.Draw(img)
    rect(d, 0, 12, 31, 13, (70, 62, 66))
    rect(d, 0, 12, 31, 12, BORDE_INT_M)
    rect(d, 2, 14, 3, 21, METAL_OSC)
    rect(d, 28, 14, 29, 21, METAL_OSC)
    rect(d, 6, 0, 21, 11, (60, 56, 64))
    rect(d, 8, 2, 19, 9, (22, 30, 28))
    rect(d, 9, 3, 13, 3, (60, 120, 80))
    rect(d, 23, 9, 30, 11, (48, 46, 54))
    for x in range(24, 30, 2):
        d.point([(x, 10)], fill=A((80, 76, 84)))
    return img


def lampara():
    """10x40. Lampara colgante industrial con su cadena. La luz va aparte."""
    img = lienzo(10, 40)
    d = ImageDraw.Draw(img)
    for y in range(0, 30):
        if y % 3 != 2:
            d.point([(5, y)], fill=A(METAL_OSC))
        else:
            rect(d, 4, y, 6, y, METAL_OSC)
    rect(d, 2, 30, 7, 33, (70, 62, 66))
    rect(d, 0, 34, 9, 35, (70, 62, 66))
    rect(d, 3, 36, 6, 37, AMBAR)
    return img


def muro_monitores():
    """112x72. El santuario: una pared de monitores apilados. Es TV Buddha
    multiplicado (ARTE.md §4), el final de la demo."""
    img = lienzo(112, 72)
    d = ImageDraw.Draw(img)
    rnd = random.Random(1974)
    y = 72
    for fila, (sangria, n) in enumerate([(0, 7), (6, 6), (12, 5), (20, 4)]):
        alto = 16
        y -= alto + 1
        for k in range(n):
            x = sangria + k * 16 + (fila % 2) * 3
            if x + 15 > 111:
                continue
            rect(d, x, y, x + 14, y + alto - 1, (64, 60, 70))
            rect(d, x, y, x + 14, y, (92, 84, 88))
            vivo = rnd.random() < 0.45
            pantalla = (22, 36, 30) if not vivo else (40, 90, 60)
            rect(d, x + 2, y + 2, x + 12, y + alto - 4, pantalla)
            if vivo:
                for ly in range(y + 3, y + alto - 4, 2):
                    rect(d, x + 3, ly, x + 11, ly, (60, 130, 84))
    return img


def ventanal():
    """40x96. Ventanal gotico roto en la pared del fondo. Detras, la brasa."""
    img = lienzo(40, 96)
    d = ImageDraw.Draw(img)
    marco = (56, 48, 56)
    for y in range(96):
        for x in range(40):
            if y < 20 and abs(x - 19.5) > y * 1.0:
                continue
            d.point([(x, y)], fill=A(mezcla((176, 104, 52), (60, 36, 40), y / 96.0)))
    for x in (0, 1, 13, 26, 38, 39):
        rect(d, x, 14, x, 95, marco)
    for y in (34, 58, 82):
        rect(d, 0, y, 39, y + 1, marco)
    rect(d, 13, 40, 13, 50, (150, 90, 50))          # cristal reventado
    return img


def emisor_arco():
    """12x10. Nodo de un arco electrico (en el suelo y, volteado, en el techo)."""
    img = lienzo(12, 10)
    d = ImageDraw.Draw(img)
    rect(d, 1, 6, 10, 9, (60, 56, 66))
    rect(d, 1, 6, 10, 6, BORDE_INT_M)
    rect(d, 4, 2, 7, 5, (80, 74, 84))
    rect(d, 5, 0, 6, 1, (170, 220, 230))
    for x in (2, 9):
        d.point([(x, 8)], fill=A((150, 116, 46)))
    return img


def montacargas():
    """48x12. Plataforma de carga con franjas de peligro."""
    img = lienzo(48, 12)
    d = ImageDraw.Draw(img)
    rect(d, 0, 0, 47, 7, (70, 64, 72))
    rect(d, 0, 0, 47, 0, BORDE_INT)
    rect(d, 0, 1, 47, 1, BORDE_INT_M)
    for x in range(0, 48):
        for y in range(3, 6):
            c = (150, 116, 46) if ((x + y) // 3) % 2 == 0 else (40, 36, 42)
            d.point([(x, y)], fill=A(c))
    rect(d, 0, 7, 47, 7, (40, 36, 44))
    rect(d, 4, 8, 7, 11, METAL_OSC)
    rect(d, 40, 8, 43, 11, METAL_OSC)
    return img


def ascensor():
    """40x60. La salida del nivel 2: un montacargas de servicio con la luz de
    llamada encendida."""
    img = lienzo(40, 60)
    d = ImageDraw.Draw(img)
    rect(d, 0, 0, 39, 59, (64, 58, 68))
    rect(d, 0, 0, 39, 0, BORDE_INT_M)
    rect(d, 4, 8, 35, 59, (26, 24, 32))
    rect(d, 4, 8, 19, 59, (40, 38, 48))
    rect(d, 20, 8, 35, 59, (36, 34, 44))
    rect(d, 19, 8, 20, 59, (18, 16, 22))
    rect(d, 16, 2, 23, 5, (30, 28, 36))
    rect(d, 18, 3, 21, 4, FOSFORO)
    for y in range(12, 58, 6):
        rect(d, 6, y, 17, y, (46, 44, 54))
        rect(d, 22, y, 33, y, (42, 40, 50))
    return img


def tuberia():
    """64x10. Tuberia horizontal para los muros."""
    img = lienzo(64, 10)
    d = ImageDraw.Draw(img)
    rect(d, 0, 2, 63, 7, (62, 56, 64))
    rect(d, 0, 2, 63, 2, (96, 86, 88))
    rect(d, 0, 7, 63, 7, (36, 32, 40))
    for x in (8, 30, 52):
        rect(d, x, 0, x + 3, 9, OXIDO_OSC)
    return img


# =============================================================== salida =======

def guardar(img, ruta):
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    img.save(ruta)
    print("  %-40s %s" % (os.path.relpath(ruta, RAIZ), img.size))


def contacto(piezas, ruta, escala=3):
    fondo = (196, 118, 42, 255)
    ancho = sum(p.width for p in piezas) + 8 * len(piezas)
    alto = max(p.height for p in piezas)
    hoja = Image.new("RGBA", (ancho, alto), fondo)
    x = 0
    for p in piezas:
        hoja.alpha_composite(p, (x, alto - p.height))
        x += p.width + 8
    hoja = hoja.resize((ancho * escala, alto * escala), Image.NEAREST)
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    hoja.save(ruta)
    print("  contacto:", ruta)


if __name__ == "__main__":
    props = os.path.join(PH, "props")
    interior = os.path.join(PH, "interior")
    piezas = {
        os.path.join(PH, "tileset_mundo.png"): tileset(),
        os.path.join(PH, "edificio_fachada.png"): edificio(),
        os.path.join(props, "farola.png"): farola(),
        os.path.join(props, "poste.png"): poste(),
        os.path.join(props, "cartel.png"): cartel(),
        os.path.join(props, "chatarra.png"): chatarra(),
        os.path.join(props, "barril.png"): barril(),
        os.path.join(props, "servidor_caido.png"): servidor_caido(),
        os.path.join(props, "valla.png"): valla(),
        os.path.join(props, "rack.png"): rack(),
        os.path.join(props, "consola.png"): consola(),
        os.path.join(props, "lampara.png"): lampara(),
        os.path.join(props, "muro_monitores.png"): muro_monitores(),
        os.path.join(props, "ventanal.png"): ventanal(),
        os.path.join(props, "tuberia.png"): tuberia(),
        os.path.join(props, "emisor_arco.png"): emisor_arco(),
        os.path.join(props, "montacargas.png"): montacargas(),
        os.path.join(props, "ascensor.png"): ascensor(),
        os.path.join(interior, "capa_i1_nave.png"): capa_nave(),
        os.path.join(interior, "capa_i2_racks.png"): capa_racks(),
        os.path.join(interior, "capa_i3_columnas.png"): capa_columnas(),
        os.path.join(interior, "capa_i4_cables.png"): capa_cables(),
    }
    print("Mundo:")
    for ruta, img in piezas.items():
        guardar(img, ruta)
    if "--contacto" in sys.argv:
        pequenas = [img for ruta, img in piezas.items()
                    if img.width <= 128 and "capa_" not in ruta]
        contacto(pequenas, os.path.join(CAPTURAS, "hoja_mundo.png"))
        contacto([piezas[os.path.join(PH, "edificio_fachada.png")]],
                 os.path.join(CAPTURAS, "hoja_edificio.png"), escala=2)
        fondo = Image.new("RGBA", (ANCHO, ALTO), (22, 18, 26, 255))
        for ruta, img in piezas.items():
            if "capa_" in ruta:
                fondo.alpha_composite(img)
        fondo.resize((ANCHO * 2, ALTO * 2), Image.NEAREST).save(
            os.path.join(CAPTURAS, "hoja_interior.png"))
        print("  contacto:", os.path.join(CAPTURAS, "hoja_interior.png"))
