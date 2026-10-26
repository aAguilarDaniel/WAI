# -*- coding: utf-8 -*-
"""Genera los assets que hoy no se entienden al mirarlos.

El problema que resuelve: en el teaser hay cosas en pantalla que el espectador no
puede identificar. El enemigo es un bloque quieto, los tres proyectiles son el
MISMO rectangulo blanco de 6x3 (asi que plasma y radiacion, que son la mitad del
tema del juego, no se distinguen de una bala), y los recogibles son todos el
mismo cuadrado amarillo, den un arma, el diario o una venda.

Uso:  python herramientas/generar_props.py [--contacto]

Nada de esto es pixel art definitivo: es composicion geometrica legible, igual
que generar_siluetas.py. Todas las medidas respetan las colisiones que ya existen
en las escenas, asi que reemplazar estos PNG por arte a mano no toca ni una linea
de codigo (art/PLACEHOLDERS.md).
"""
import os
import sys

import pixel
from pixel import canto, disco, lienzo, punto, trazo

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "juego", "art")
PLACEHOLDER = os.path.join(RAIZ, "placeholder")

# Polo maquina de ARTE.md 1: verde fosforo de CRT, cian, magenta de radiacion.
CHASIS = (46, 42, 48, 255)
CHASIS_OSC = (26, 24, 30, 255)
METAL = (64, 58, 62, 255)
TUBO_APAGADO = (26, 54, 36, 255)
FOSFORO = (108, 196, 126, 255)
FOSFORO_VIVO = (176, 255, 190, 255)

CIAN = (120, 232, 246, 255)
CIAN_OSC = (34, 118, 146, 255)
MAGENTA = (236, 108, 210, 255)
MAGENTA_OSC = (122, 40, 110, 255)
AMBAR = (250, 214, 132, 255)
AMBAR_OSC = (196, 118, 42, 255)

# Polo humano: crema del papel del diario, ocres, rojo de sangre seca.
CREMA = (232, 218, 186, 255)
CREMA_OSC = (168, 150, 118, 255)
CUERO = (120, 74, 44, 255)
SANGRE = (150, 46, 42, 255)


# =============================================================== enemigo =======
# 16x20 con los pies en el borde inferior: son las medidas que ya tiene
# enemigo_patrulla.tscn (colision 12x20, Sprite en position.y = -10). Cambiarlas
# rompe las colisiones, asi que el spritesheet las respeta.

ENEMIGO_W, ENEMIGO_H = 16, 20


def _enemigo(pierna_izq, pierna_der, bote, tubo, encendido, brazo=0):
    """Una pose del enemigo. `tubo` es el color de la pantalla y `encendido`
    dibuja los dos puntos que parecen ojos: es como se lee que te ha visto."""
    img = lienzo(ENEMIGO_W, ENEMIGO_H)
    y = bote

    # Piernas primero: van detras del cuerpo.
    trazo(img, (6, 15 + y), (6 + pierna_izq, 19), 2, CHASIS_OSC)
    trazo(img, (9, 15 + y), (9 + pierna_der, 19), 2, CHASIS_OSC)

    # Antena. Es lo que da la lectura de "aparato", no de "persona".
    trazo(img, (8, 0 + y), (8, 3 + y), 1, METAL)
    trazo(img, (6, 0 + y), (9, 0 + y), 1, METAL)

    # Carcasa del monitor donde deberia haber una cara (ARTE.md 5: rostros
    # sustituidos por pantallas).
    for fy in range(3 + y, 12 + y):
        trazo(img, (2, fy), (13, fy), 1, CHASIS)
    for fy in range(4 + y, 11 + y):
        trazo(img, (3, fy), (12, fy), 1, CHASIS_OSC)
    for fy in range(5 + y, 10 + y):
        trazo(img, (4, fy), (11, fy), 1, tubo)

    # Linea de barrido: recorre el tubo y delata que sigue encendido.
    barrido = 6 + y + (1 if bote else 0)
    trazo(img, (4, barrido), (11, barrido), 1, FOSFORO_VIVO if encendido else FOSFORO)
    if encendido:
        punto(img, 6, 8 + y, FOSFORO_VIVO)
        punto(img, 9, 8 + y, FOSFORO_VIVO)

    # Cuerpo, estrecho: el monitor tiene que pesar mas que el resto.
    for fy in range(12 + y, 16 + y):
        trazo(img, (6, fy), (9, fy), 1, CHASIS)
    trazo(img, (4, 13 + y + brazo), (5, 14 + y + brazo), 2, METAL)
    trazo(img, (10, 13 + y - brazo), (11, 14 + y - brazo), 2, METAL)

    canto(img, (128, 96, 70, 255))
    return img


def enemigo_quieto():
    return [_enemigo(0, 0, 0, TUBO_APAGADO, False),
            _enemigo(0, 0, 1, TUBO_APAGADO, False)]


def enemigo_caminar():
    """Las patas se abren y se cierran y el cuerpo bota 1 px. A 20 px de alto no
    hace falta mas: lo que tiene que leerse es que se DESPLAZA por su cuenta."""
    return [_enemigo(-2, 2, 0, TUBO_APAGADO, False, 1),
            _enemigo(0, 0, 1, TUBO_APAGADO, False, 0),
            _enemigo(2, -2, 0, TUBO_APAGADO, False, -1),
            _enemigo(0, 0, 1, TUBO_APAGADO, False, 0)]


def enemigo_alerta():
    """Te ha visto. Misma pose, pantalla encendida y dos puntos donde irian los
    ojos. Es la unica telegrafia que tiene el enemigo basico, que no ataca."""
    return [_enemigo(-3, 3, 0, (40, 96, 56, 255), True, 2),
            _enemigo(0, 0, 1, (52, 122, 70, 255), True, 0),
            _enemigo(3, -3, 0, (40, 96, 56, 255), True, -2),
            _enemigo(0, 0, 1, (52, 122, 70, 255), True, 0)]


ENEMIGO_ORDEN = [
    ("quieto", 4.0, True, enemigo_quieto),
    ("caminar", 8.0, True, enemigo_caminar),
    ("alerta", 12.0, True, enemigo_alerta),
]


# ============================================================ proyectiles =====
# Los tres se distinguen por FORMA ademas de por color: en un cuadro de 384x216
# un proyectil de 10 px se ve un instante, y el color solo no alcanza.

PROY_W, PROY_H = 10, 6


def _proyectil(nucleo, halo, forma, fase):
    img = lienzo(PROY_W, PROY_H)
    if forma == "bala":
        # Recta y con estela: es cinetica, no energia.
        #
        # Lleva perfil OSCURO debajo del nucleo. El ambar del disparo humano cae
        # justo en el color del cielo de brasa, asi que sin ese contorno la bala
        # es invisible durante todo el vuelo. El plasma y la radiacion no lo
        # necesitan: son frios y el fondo es calido.
        trazo(img, (0, 1), (9, 1), 1, (18, 12, 14, 255))
        trazo(img, (0, 4), (9, 4), 1, (18, 12, 14, 255))
        trazo(img, (0, 3), (5, 3), 1, halo)
        trazo(img, (3, 2), (9, 2), 1, nucleo)
        trazo(img, (6, 2), (9, 2), 1, (255, 248, 226, 255))
    elif forma == "plasma":
        # Gota: nucleo redondo delante y cola detras. Empuja al polo maquina.
        disco(img, (6.5, 2.5), 2.4 + 0.4 * fase, halo)
        disco(img, (6.5, 2.5), 1.2 + 0.3 * fase, nucleo)
        trazo(img, (0, 2), (5, 2), 1 + fase, halo)
        trazo(img, (1, 3), (4, 3), 1, nucleo)
    else:
        # Radiacion: masa irregular que late. No tiene punta ni direccion clara,
        # y eso es lo que la hace desagradable de mirar.
        disco(img, (5.5, 2.5), 2.6, halo)
        for i, (dx, dy) in enumerate(((0, -3), (3, 0), (0, 3), (-3, -1), (2, 2))):
            if (i + fase) % 3 != 0:
                punto(img, 5 + dx, 2 + dy, halo)
        disco(img, (5.5, 2.5), 1.0 + 0.5 * ((fase + 1) % 3), nucleo)
    return img


def proy_bala():
    return [_proyectil(AMBAR, AMBAR_OSC, "bala", 0)]


def proy_plasma():
    return [_proyectil(CIAN, CIAN_OSC, "plasma", f) for f in range(3)]


def proy_radiacion():
    return [_proyectil(MAGENTA, MAGENTA_OSC, "radiacion", f) for f in range(3)]


# ============================================================== recogibles ====
# 12x12. Hoy los tres son el mismo cuadrado amarillo y no hay forma de saber si
# lo que hay en el suelo es un arma, el diario o una venda.

REC = 12


def _recogible(dibujar):
    img = lienzo(REC, REC)
    dibujar(img)
    # Reborde calido: en un nivel a contraluz un objeto pequeno sin canto
    # desaparece contra el suelo. Esto es lo que lo hace "recogible" a la vista.
    canto(img, (214, 150, 80, 255))
    return img


def rec_arma():
    """Un tubo tirado en el suelo, con la empunadura marcada."""
    def d(img):
        trazo(img, (1, 8), (10, 6), 2, METAL)
        trazo(img, (1, 8), (3, 8), 3, CUERO)
        punto(img, 10, 5, (150, 140, 132, 255))
    return _recogible(d)


def rec_diario():
    """Un cuaderno de canto, con paginas. Crema de papel: polo humano."""
    def d(img):
        for x in range(2, 10):
            trazo(img, (x, 2), (x, 10), 1, CREMA if x % 2 else CREMA_OSC)
        trazo(img, (2, 2), (2, 10), 1, CUERO)     # el lomo
        trazo(img, (3, 1), (9, 1), 1, CUERO)      # la tapa asoma
    return _recogible(d)


def rec_venda():
    """Un rollo de venda con la cruz. La cruz es lo unico que lo separa del
    cuaderno de un vistazo, asi que va en rojo pleno."""
    def d(img):
        disco(img, (5.5, 5.5), 4.4, CREMA_OSC)
        disco(img, (5.5, 5.5), 3.2, CREMA)
        trazo(img, (5, 3), (5, 8), 2, SANGRE)
        trazo(img, (3, 5), (8, 5), 2, SANGRE)
    return _recogible(d)


# ================================================================== HUD =======

def corazon():
    """7x7 en BLANCO PURO: barra_salud.gd lo tine por codigo segun este lleno o
    vacio, y los dos colores son @export del HUD (art/PLACEHOLDERS.md)."""
    img = lienzo(7, 7)
    b = (255, 255, 255, 255)
    for x, y in [(1, 1), (2, 1), (4, 1), (5, 1),
                 (0, 2), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2),
                 (0, 3), (1, 3), (2, 3), (3, 3), (4, 3), (5, 3), (6, 3),
                 (1, 4), (2, 4), (3, 4), (4, 4), (5, 4),
                 (2, 5), (3, 5), (4, 5),
                 (3, 6)]:
        punto(img, x, y, b)
    return img


# ================================================================ salida ======

def _hoja(filas, ancho, alto):
    columnas = max(len(f) for f in filas)
    hoja = lienzo(columnas * ancho, len(filas) * alto)
    for y, fila in enumerate(filas):
        for x, celda in enumerate(fila):
            hoja.paste(celda, (x * ancho, y * alto))
    return hoja


def _guardar(img, *ruta):
    destino = os.path.join(PLACEHOLDER, *ruta)
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    img.save(destino)
    print("  %-40s %dx%d" % (os.path.join(*ruta), img.width, img.height))


if __name__ == "__main__":
    print("Enemigo (16x20 por celda, 3 animaciones):")
    filas_en = [fn() for _n, _f, _b, fn in ENEMIGO_ORDEN]
    _guardar(_hoja(filas_en, ENEMIGO_W, ENEMIGO_H), "enemigo.png")

    print("Proyectiles (10x6 por celda):")
    _guardar(_hoja([proy_bala()], PROY_W, PROY_H), "proyectiles", "bala.png")
    _guardar(_hoja([proy_plasma()], PROY_W, PROY_H), "proyectiles", "plasma.png")
    _guardar(_hoja([proy_radiacion()], PROY_W, PROY_H), "proyectiles", "radiacion.png")

    print("Recogibles (12x12):")
    _guardar(rec_arma(), "recogibles", "arma.png")
    _guardar(rec_diario(), "recogibles", "diario.png")
    _guardar(rec_venda(), "recogibles", "venda.png")

    print("HUD:")
    _guardar(corazon(), "ui", "corazon.png")

    if "--contacto" in sys.argv:
        ruta = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            "..", "capturas", "hoja_props.png")
        pixel.contacto(filas_en + [proy_plasma(), proy_radiacion(),
                                   [rec_arma(), rec_diario(), rec_venda()]],
                       escala=10, columnas=4).save(ruta)
        print("hoja de contacto -> capturas/hoja_props.png")
