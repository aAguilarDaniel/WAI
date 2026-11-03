# -*- coding: utf-8 -*-
"""Genera las siluetas de parallax, el foso y los assets del CRT.

No es pixel art dibujado a mano: es composicion geometrica, que es lo que pide
ARTE.md §3 ("escala por contraste, no por detalle", "una sola fuente de luz al
fondo y baja que recorte todo en silueta", "arquitectura imposible", "vacio en
el centro"). El refinado a mano se hace encima, en Aseprite.

Uso:  python herramientas/generar_siluetas.py
      python herramientas/generar_siluetas.py --contacto

Todas las capas son 768x216 y se repiten en horizontal (repeat_size = 768), asi
que TODA figura que cruza el borde derecho se vuelve a dibujar en el izquierdo.
De eso se encarga _barra(); si se anaden formas nuevas, usarla siempre o se vera
la costura al hacer scroll.

CAMBIO IMPORTANTE respecto de la version anterior: la capa 1 YA NO ES EL CIELO.
El cielo lo pinta shaders/cielo.gdshader en una CanvasLayer de pantalla completa,
porque una textura de 216 px de alto no podia cubrir el recorrido vertical de la
camara y dejaba dos franjas grises. La capa 1 es ahora la bruma mas lejana, con
transparencia, para que el degradado del shader se vea detras.
"""
import os
import random
import sys

from PIL import Image, ImageDraw

ANCHO, ALTO = 768, 216
RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "juego", "art")
PARALLAX = os.path.join(RAIZ, "placeholder", "parallax")

# --- Escalera de valor, de fondo a frente ---
#
# La regla dura de art/PLACEHOLDERS.md: el JUGADOR (17, 13, 17) tiene que ser lo
# mas oscuro del cuadro. Ninguna capa de fondo baja de (39, 26, 32).
#
# Y una regla nueva de esta sesion: el TERRENO tampoco puede ser mas oscuro que
# la capa 5. Antes lo era -- terreno (34, 26, 30) contra capa 5 (39, 26, 32) --,
# asi que el suelo se hundia en el fondo y el nivel entero se leia como una sola
# mancha marron. El terreno es lo mas cercano que hay detras del jugador: le toca
# ser lo mas CLARO del fondo, no lo mas oscuro.
BRUMA_LEJOS = (96, 62, 62)
SIL_LEJOS = (80, 50, 54)
SIL_MEDIA = (60, 38, 44)
SIL_CERCA = (48, 31, 37)
SIL_FRENTE = (39, 26, 32)
TERRENO = (52, 38, 42)
TERRENO_VETA = (40, 29, 34)
# La ceja: la brasa del fondo prendiendo en el canto de la plataforma. Es lo
# unico que hace que una plataforma se lea como plataforma y no como recorte.
CEJA_FUERTE = (186, 116, 54)
CEJA_MEDIA = (118, 72, 44)
NEGRO_FRENTE = (5, 4, 7)

# Puntos de luz sueltos: "una instalacion todavia encendida en el horizonte"
# (ARTE.md §2). Poquisimos y solo en las capas lejanas: si los llevara la capa
# cercana pareceria una ciudad habitada, y esto es infraestructura muerta.
LUZ_AMBAR = (214, 138, 58)


def _lienzo(color=(0, 0, 0, 0)):
    img = Image.new("RGBA", (ANCHO, ALTO), color)
    return img, ImageDraw.Draw(img)


def _barra(d, x, y, w, h, color):
    """Rectangulo que envuelve por el borde: mantiene la costura invisible."""
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=color)
    if x + w > ANCHO:
        d.rectangle([x - ANCHO, y, x + w - 1 - ANCHO, y + h - 1], fill=color)
    if x < 0:
        d.rectangle([x + ANCHO, y, x + w - 1 + ANCHO, y + h - 1], fill=color)


def _mezcla(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


# ---------- Capa 1: bruma lejanisima ----------

def capa_1_cielo():
    """Bandas de bruma horizontal, con mucha transparencia. YA NO es el cielo:
    el cielo es shaders/cielo.gdshader. Esto solo rompe el degradado limpio del
    shader para que no se lea como un degradado de programa."""
    img, d = _lienzo()
    rnd = random.Random(11)
    for _ in range(10):
        y = rnd.randint(100, 170)
        alto = rnd.randint(1, 4)
        largo = rnd.randint(150, 460)
        x = rnd.randrange(ANCHO)
        alfa = rnd.randint(14, 34)
        _barra(d, x, y, largo, alto, BRUMA_LEJOS + (alfa,))
        # Las bandas se afilan por los extremos: un rectangulo puro se ve.
        _barra(d, x, y, 18, alto, BRUMA_LEJOS + (alfa // 2,))
        _barra(d, x + largo - 18, y, 18, alto, BRUMA_LEJOS + (alfa // 2,))
    return img


# ---------- Capa 2: horizonte lejanisimo ----------

def capa_2_horizonte():
    """Macizos derrumbados en el limite de la vista. Casi del color del cielo:
    perspectiva atmosferica (ARTE.md §3)."""
    img, d = _lienzo()
    rnd = random.Random(20)
    x = 0
    while x < ANCHO:
        w = rnd.randint(34, 86)
        cima = rnd.randint(140, 156)
        _barra(d, x, cima, w, ALTO - cima, SIL_LEJOS + (135,))
        # Escalonado de la cima: una linea recta a esta distancia se lee como
        # una regla, no como una ruina.
        if rnd.random() < 0.6:
            paso = rnd.randint(6, 18)
            _barra(d, x, cima - rnd.randint(2, 7), paso, 8, SIL_LEJOS + (135,))
        x += w
    return img


# ---------- Capa 3: torres de refrigeracion y antenas ----------

def capa_3_torres():
    """Cuatro piezas y nada mas. La inmensidad sale del contraste, no de llenar
    el cuadro, y el tercio central se deja abierto a proposito (ARTE.md §3)."""
    img, d = _lienzo()
    rnd = random.Random(33)
    for cx in (52, 188, 548, 690):
        cx += rnd.randint(-12, 12)
        if rnd.random() < 0.5:
            # Torre de refrigeracion: cintura marcada para que lea en silueta.
            base_y, cima_y = ALTO, rnd.randint(58, 84)
            ancho_base, cuello = rnd.randint(48, 66), rnd.randint(22, 30)
            for y in range(cima_y, base_y):
                t = (y - cima_y) / float(base_y - cima_y)
                w = int(cuello + (ancho_base - cuello) * abs(t - 0.42) / 0.58)
                _barra(d, cx - w // 2, y, w, 1, SIL_MEDIA + (255,))
            # Boca de la torre: un labio mas claro arriba. Sin el, la torre es
            # una silueta maciza y no se entiende que esta hueca.
            _barra(d, cx - cuello // 2, cima_y, cuello, 2, SIL_LEJOS + (255,))
        else:
            # Antena como campanario: mastil, travesanos y una luz de baliza.
            alto_antena = rnd.randint(26, 46)
            _barra(d, cx, alto_antena, 3, ALTO - alto_antena, SIL_MEDIA + (255,))
            for i in range(5):
                y = alto_antena + 10 + i * 20
                w = 9 + i * 8
                _barra(d, cx - w // 2 + 1, y, w, 2, SIL_MEDIA + (255,))
            d.rectangle([cx, alto_antena - 2, cx + 1, alto_antena - 1],
                        fill=LUZ_AMBAR + (255,))
    # Arcos repetidos hasta el horizonte: la "arquitectura imposible" de §3.
    # Se van cerrando y aclarando hacia la derecha, que es lo que da la fuga.
    base = 150
    for i in range(9):
        w = 62 - i * 5
        h = 46 - i * 3
        x = 268 + i * (w + 3)
        if w < 12:
            break
        alfa = max(40, 200 - i * 14)
        _barra(d, x, base - h, 2, h, SIL_MEDIA + (alfa,))
        _barra(d, x + w - 2, base - h, 2, h, SIL_MEDIA + (alfa,))
        _barra(d, x, base - h, w, 2, SIL_MEDIA + (alfa,))
    return img


# ---------- Capa 4: racks del tamano de naves de catedral ----------

def capa_4_racks():
    """Las masas que dan la escala. El personaje mide 24 px y esto no tiene
    techo visible: se sale del cuadro por arriba."""
    img, d = _lienzo()
    rnd = random.Random(444)
    # Las ranuras se pintan MAS OSCURAS, no se calan. Calarlas contra el cielo
    # encendido las convertia en ventanas iluminadas, y esto es infraestructura
    # muerta, no una ciudad habitada.
    ranura = (28, 19, 25, 255)
    x = -20
    while x < ANCHO + 20:
        # Hueco ancho en el tercio central: "vacio en el centro" (ARTE.md §3).
        if 300 < x < 440:
            x += 70
            continue
        w = rnd.randint(44, 90)
        if rnd.random() > 0.24:
            cima = rnd.randint(100, 148)
            _barra(d, x, cima, w, ALTO - cima, SIL_CERCA + (255,))
            for sx in range(x + 6, x + w - 6, 9):
                for sy in range(cima + 8, ALTO - 6, 14):
                    _barra(d, sx, sy, 3, 7, ranura)
            # Remate mordido: un canto recto de 90 px se lee como una caja, no
            # como una ruina. Dos o tres escalones bastan para romperlo.
            for _ in range(rnd.randint(2, 3)):
                mx = rnd.randint(x, x + max(1, w - 12))
                _barra(d, mx, cima, rnd.randint(6, 16), rnd.randint(4, 10), (0, 0, 0, 0))
            # Y una antena o un respiradero asomando por arriba.
            if rnd.random() < 0.6:
                _barra(d, x + rnd.randint(4, max(5, w - 5)), cima - rnd.randint(8, 22),
                       rnd.choice([1, 2]), 24, SIL_CERCA + (255,))
        x += w + rnd.randint(8, 30)

    # Dos naves colosales que se salen por arriba, con arcada en la base. La
    # arcada es lo que las separa de "un edificio": un rack del tamano de una
    # nave de catedral tiene que tener vanos por los que cabria un camion.
    for cx, ancho in ((112, 108), (592, 132)):
        _barra(d, cx, -40, ancho, ALTO + 40, SIL_CERCA + (255,))
        for sx in range(cx + 8, cx + ancho - 8, 11):
            for sy in range(6, ALTO - 46, 16):
                _barra(d, sx, sy, 4, 9, ranura)
        vano_w, hueco = 18, 12
        vx = cx + 8
        while vx + vano_w < cx + ancho - 8:
            d.rectangle([vx, ALTO - 38, vx + vano_w - 1, ALTO - 1], fill=(0, 0, 0, 0))
            _barra(d, vx, ALTO - 41, vano_w, 3, SIL_MEDIA + (255,))
            vx += vano_w + hueco

    # Pasarela suspendida cruzando el vacio central: conecta las dos masas y
    # ocupa el hueco sin llenarlo.
    _barra(d, 300, 96, 146, 3, SIL_CERCA + (255,))
    for px in range(304, 444, 16):
        _barra(d, px, 96, 1, 9, SIL_CERCA + (200,))
    return img


# ---------- Capa 5: estructuras cercanas ----------

def capa_5_cercano():
    """La capa que queda justo detras del jugador.

    NO LLEVA BLOQUES MACIZOS, y esa es toda la regla de esta capa. Los llevaba, y
    a esta distancia un rectangulo relleno con el borde de arriba recto no se lee
    como un edificio: se lee como un cuadrado negro pegado al suelo que se mueve
    cuando te mueves. Era lo mas molesto del cuadro.

    Lo que si se lee a esta escala es la ESTRUCTURA: torres de celosia, pasarelas
    colgadas, cables. Silueta calada en vez de masa, que ademas deja ver la brasa
    del fondo a traves y no tapa al personaje."""
    img, d = _lienzo()
    rnd = random.Random(55)
    color = SIL_FRENTE + (255,)
    color_flojo = SIL_FRENTE + (150,)

    x = -10
    while x < ANCHO + 10:
        eleccion = rnd.random()
        if eleccion < 0.42:
            # Torre de celosia: dos montantes y travesanos. Calada de arriba abajo.
            alto = rnd.randint(38, 88)
            ancho = rnd.randint(9, 16)
            cima = ALTO - alto
            _barra(d, x, cima, 2, alto, color)
            _barra(d, x + ancho, cima, 2, alto, color)
            for y in range(cima + 4, ALTO, rnd.randint(7, 11)):
                _barra(d, x, y, ancho + 2, 1, color_flojo)
            _barra(d, x, cima, ancho + 2, 2, color)          # remate
            if rnd.random() < 0.5:                            # antena encima
                _barra(d, x + ancho // 2, cima - rnd.randint(6, 18), 1, 18, color)
            paso = ancho + rnd.randint(18, 46)
        elif eleccion < 0.72:
            # Escombrera: perfil escalonado, nunca un canto recto de lado a lado.
            ancho_total = rnd.randint(26, 58)
            altura = rnd.randint(6, 16)
            cx = x
            while cx < x + ancho_total:
                tramo = rnd.randint(5, 13)
                altura = max(4, min(22, altura + rnd.randint(-4, 4)))
                _barra(d, cx, ALTO - altura, tramo, altura, color)
                cx += tramo
            paso = ancho_total + rnd.randint(20, 52)
        else:
            # Pasarela suspendida con sus tirantes.
            largo = rnd.randint(30, 62)
            alto_p = rnd.randint(26, 58)
            _barra(d, x, ALTO - alto_p, largo, 2, color)
            for px in range(x + 2, x + largo, 8):
                _barra(d, px, ALTO - alto_p, 1, rnd.randint(4, 10), color_flojo)
            _barra(d, x, ALTO - alto_p, 2, alto_p, color)     # pila izquierda
            _barra(d, x + largo - 2, ALTO - alto_p, 2, alto_p, color)
            paso = largo + rnd.randint(24, 60)
        x += paso

    # Cables sueltos colgando entre estructuras, para que la capa no sea solo
    # verticales rectas.
    for _ in range(14):
        cx = rnd.randrange(ANCHO)
        largo = rnd.randint(10, 30)
        caida = ALTO - rnd.randint(20, 60)
        _barra(d, cx, caida, largo, 1, color_flojo)
    return img


# ---------- Capa 6: el primer plano que recorta el cuadro ----------

def capa_6_primer_plano():
    """Va DELANTE del jugador (z=+20). Por eso el centro queda vacio: el
    placeholder original eran tres bloques opacos que tapaban al personaje justo
    en el plano de la TerminalCRT."""
    img, d = _lienzo()
    rnd = random.Random(66)
    negro = NEGRO_FRENTE + (255,)
    # Cableado colgando del borde superior.
    for _ in range(26):
        x = rnd.randrange(ANCHO)
        caida = rnd.randint(14, 52)
        _barra(d, x, 0, rnd.choice([1, 1, 2]), caida, negro)
        if rnd.random() < 0.5:                # la comba del cable
            _barra(d, x, caida, rnd.randint(4, 16), 1, negro)
    # Viga superior rota, solo en los tercios laterales.
    _barra(d, -30, 0, 150, rnd.randint(8, 14), negro)
    _barra(d, 640, 0, 190, rnd.randint(8, 14), negro)
    # Escombros en el borde inferior. Cortos y separados a proposito: antes eran
    # bloques de hasta 22 px cada 4 px y borraban al personaje entero al pasar.
    x = 0
    while x < ANCHO:
        w = rnd.randint(14, 40)
        if rnd.random() < 0.32:
            alto = rnd.randint(4, 10)
            _barra(d, x, ALTO - alto, w, alto, negro)
        x += w + rnd.randint(24, 70)
    return img


# ---------- Tileset del terreno ----------

# El tileset ya no sale de aqui: lo genera generar_mundo.py (tileset_mundo.png,
# 8x2 celdas para exterior e interior).


# ---------- Foso ----------

def foso():
    """96x176. Va detras del terreno, tapando el hueco de los abismos. Antes se
    veia el parallax a traves y el vacio no se leia como profundidad.
    El truco es el de siempre: paredes que convergen hacia abajo y poco
    contraste, para que no compita con la plataforma (ARTE.md §3)."""
    w, h = 96, 176
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(91)
    pared = (26, 19, 25, 255)
    pared_osc = (13, 10, 14, 255)
    ranura = (36, 27, 33, 255)
    brillo = (168, 100, 40)

    d.rectangle([0, 0, w - 1, h - 1], fill=pared_osc)   # el pozo, negro calido
    for y in range(h):
        t = y / float(h)
        borde = int(6 + 20 * t)
        d.rectangle([0, y, borde, y], fill=pared)
        d.rectangle([w - 1 - borde, y, w - 1, y], fill=pared)
    # Ranuras de rack descendiendo por las dos paredes.
    for y in range(4, h - 30, 11):
        t = y / float(h)
        borde = int(6 + 20 * t)
        d.rectangle([2, y, max(2, borde - 2), y + 3], fill=ranura)
        d.rectangle([w - 1 - borde + 2, y, w - 3, y + 3], fill=ranura)
    for _ in range(7):
        x = rnd.randrange(10, w - 10)
        d.rectangle([x, 0, x, rnd.randint(20, 70)], fill=pared_osc)
    # Algo sigue encendido ahi abajo. No se ve que es, y ese es el punto.
    # Va al 55% de la altura y no al fondo: con la camara centrada en el jugador
    # solo se ven unos 220 px de mundo, y mas abajo quedaria fuera de cuadro.
    cy = int(h * 0.55)
    for y in range(cy - 26, cy + 30):
        caida = abs(y - cy) / 30.0
        t = (1.0 - caida) ** 2.2
        if t <= 0.01:
            continue
        borde = int(6 + 20 * (y / float(h)))
        for x in range(borde + 2, w - borde - 2):
            # Se apaga tambien hacia los lados: es un rescoldo, no una barra.
            lat = abs(x - w / 2.0) / max(w / 2.0 - borde, 1.0)
            k = t * (1.0 - min(lat, 1.0) ** 2) * 0.8
            if k <= 0.01:
                continue
            base = img.getpixel((x, y))[:3]
            img.putpixel((x, y), _mezcla(base, brillo, k) + (255,))
    # Labio superior: la ceja del borde del abismo, para que el canto se lea.
    d.rectangle([0, 0, w - 1, 0], fill=CEJA_MEDIA + (255,))
    return img


# ---------- Terminal CRT ----------

def crt_cuerpo():
    """30x28. La pantalla NO va aqui: es la textura del SubViewport."""
    img = Image.new("RGBA", (30, 28), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    carcasa, borde, sombra = (72, 66, 76, 255), (34, 31, 39, 255), (22, 20, 27, 255)
    luz = (128, 108, 96, 255)
    d.rectangle([1, 0, 28, 23], fill=carcasa)      # cuerpo del tubo
    d.rectangle([0, 1, 29, 22], fill=carcasa)      # esquinas mordidas
    d.rectangle([1, 0, 28, 0], fill=luz)           # canto superior iluminado
    d.rectangle([3, 2, 26, 18], fill=borde)        # marco hundido de la pantalla
    d.rectangle([2, 20, 27, 22], fill=sombra)      # rejilla inferior
    for rx in range(4, 26, 3):
        d.rectangle([rx, 20, rx, 22], fill=(52, 48, 56, 255))
    d.rectangle([6, 24, 23, 27], fill=sombra)      # peana
    d.rectangle([24, 20, 26, 22], fill=(214, 92, 52, 255))   # piloto de encendido
    return img


def crt_cable():
    """28x2. ARTE.md §4: en TV Buddha el circuito cerrado tiene que VERSE."""
    img = Image.new("RGBA", (28, 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 27, 0], fill=(52, 48, 58, 255))
    d.rectangle([0, 1, 27, 1], fill=(20, 18, 24, 255))
    return img


def guardar(img, ruta):
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    img.save(ruta)
    print("  %-56s %s" % (os.path.relpath(ruta, RAIZ), img.size))


def hoja_de_contacto():
    """Apila las seis capas sobre un degradado parecido al del shader del cielo,
    con una tira de terreno y tres figuras del tamano del jugador encima. Sirve
    para revisar la escalera de valor sin abrir Godot."""
    fondo = Image.new("RGB", (ANCHO, ALTO), (11, 8, 16))
    px = fondo.load()
    for y in range(ALTO):
        t = y / float(ALTO)
        if t < 0.49:
            c = _mezcla((11, 8, 16), (58, 32, 38), t / 0.49)
        elif t < 0.62:
            c = _mezcla((58, 32, 38), (252, 202, 103), (t - 0.49) / 0.13)
        else:
            c = _mezcla((216, 132, 47), (26, 18, 26), (t - 0.62) / 0.38)
        for x in range(ANCHO):
            px[x, y] = c
    fondo = fondo.convert("RGBA")
    for f in (capa_1_cielo, capa_2_horizonte, capa_3_torres, capa_4_racks,
              capa_5_cercano, capa_6_primer_plano):
        fondo = Image.alpha_composite(fondo, f())
    d = ImageDraw.Draw(fondo)
    d.rectangle([0, 178, ANCHO - 1, ALTO - 1], fill=TERRENO + (255,))
    d.rectangle([0, 178, ANCHO - 1, 178], fill=CEJA_FUERTE + (255,))
    d.rectangle([0, 179, ANCHO - 1, 179], fill=CEJA_MEDIA + (255,))
    for fx in (120, 360, 600):
        d.rectangle([fx, 154, fx + 11, 177], fill=(17, 13, 17, 255))
    ruta = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                        "capturas", "contacto_parallax.png")
    fondo.resize((ANCHO * 2, ALTO * 2), Image.NEAREST).save(ruta)
    print("hoja de contacto: %s" % os.path.normpath(ruta))


if __name__ == "__main__":
    print("Parallax (768x216, empalmando por el borde):")
    guardar(capa_1_cielo(), os.path.join(PARALLAX, "capa_1_cielo.png"))
    guardar(capa_2_horizonte(), os.path.join(PARALLAX, "capa_2_horizonte.png"))
    guardar(capa_3_torres(), os.path.join(PARALLAX, "capa_3_torres.png"))
    guardar(capa_4_racks(), os.path.join(PARALLAX, "capa_4_racks.png"))
    guardar(capa_5_cercano(), os.path.join(PARALLAX, "capa_5_cercano.png"))
    guardar(capa_6_primer_plano(), os.path.join(PARALLAX, "capa_6_primer_plano.png"))
    print("Terreno:")
    guardar(foso(), os.path.join(RAIZ, "placeholder", "foso.png"))
    print("Terminal CRT:")
    guardar(crt_cuerpo(), os.path.join(RAIZ, "placeholder", "crt", "crt_cuerpo.png"))
    guardar(crt_cable(), os.path.join(RAIZ, "placeholder", "crt", "crt_cable.png"))
    if "--contacto" in sys.argv:
        hoja_de_contacto()
