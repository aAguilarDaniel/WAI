# -*- coding: utf-8 -*-
"""Placeholders del tramo final: torreta, plataforma fragil, compuerta, el gran
monitor del final y el jefe (El Custodio).

Uso:  python herramientas/generar_jefe.py [--contacto]

Igual que generar_props.py: composicion geometrica legible, NO pixel art final.
Las medidas son las de las colisiones de las escenas (art/PLACEHOLDERS.md), asi
que redibujar encima no toca codigo.

El jefe sigue la direccion de ARTE.md (Beksinski): una figura alargada, de hueso
y cable, sin cara. Donde iria el craneo hay un monitor agrietado; las costillas
son haces de cable; los brazos llegan al suelo. Es lo unico del juego mas alto
que una puerta.
"""
import io
import os
import sys

import pixel
from pixel import canto, disco, lienzo, punto, trazo, barra

AQUI = os.path.dirname(os.path.abspath(__file__))
JUEGO = os.path.join(AQUI, "..", "juego")
PLACEHOLDER = os.path.join(JUEGO, "art", "placeholder")

HUESO = (186, 168, 140, 255)
HUESO_OSC = (118, 100, 84, 255)
HUESO_SOMBRA = (70, 56, 54, 255)
OXIDO = (92, 48, 38, 255)
CABLE = (40, 32, 38, 255)
CABLE_LUZ = (66, 52, 60, 255)
CHASIS = (46, 42, 48, 255)
CHASIS_OSC = (26, 24, 30, 255)
FOSFORO = (108, 196, 126, 255)
FOSFORO_VIVO = (176, 255, 190, 255)
ROJO = (226, 70, 52, 255)
ROJO_VIVO = (255, 156, 120, 255)
AMBAR = (250, 214, 132, 255)

# =============================================================== torreta =====
# 16x16, el pie en el borde inferior. La escena la cuelga del techo volteandola.
TORRETA = 16


def _torreta(tubo, ojo, canon_y):
    img = lienzo(TORRETA, TORRETA)
    # Base atornillada
    trazo(img, (2, 15), (13, 15), 1, CHASIS_OSC)
    trazo(img, (4, 14), (11, 14), 1, CHASIS)
    # Cuerpo: un monitor pequeno con un canon debajo
    for y in range(4, 13):
        trazo(img, (3, y), (12, y), 1, CHASIS)
    for y in range(5, 11):
        trazo(img, (4, y), (11, y), 1, tubo)
    punto(img, 7, 7, ojo)
    punto(img, 8, 7, ojo)
    trazo(img, (6, 2 + canon_y), (9, 2 + canon_y), 2, CHASIS_OSC)
    canto(img, (128, 96, 70, 255))
    return img


def torreta_reposo():
    return [_torreta((26, 54, 36, 255), FOSFORO, 0), _torreta((26, 54, 36, 255), (40, 96, 56, 255), 0)]


def torreta_apuntar():
    return [_torreta((96, 30, 26, 255), ROJO_VIVO, 0), _torreta((140, 40, 32, 255), ROJO_VIVO, 1)]


TORRETA_ORDEN = [
    ("reposo", 2.0, True, torreta_reposo),
    ("apuntar", 10.0, True, torreta_apuntar),
]


def proyectil_enemigo():
    """8x8: una bola de fosforo rojo. Tiene que leerse como peligro a 4 px."""
    img = lienzo(8, 8)
    disco(img, (3.5, 3.5), 3.2, (150, 40, 32, 255))
    disco(img, (3.5, 3.5), 2.0, ROJO)
    disco(img, (3.5, 3.5), 0.9, ROJO_VIVO)
    return img


# ===================================================== plataforma fragil =====

def plataforma_fragil():
    """32x8: una placa de rejilla oxidada con remaches. Se lee distinta de la
    viga del tileset a proposito: es lo que avisa de que no aguanta."""
    img = lienzo(32, 8)
    for y in range(0, 4):
        trazo(img, (0, y), (31, y), 1, OXIDO if y else (150, 92, 58, 255))
    for x in range(1, 31, 3):
        trazo(img, (x, 4), (x, 6), 1, (70, 40, 34, 255))
    for x in (2, 15, 29):
        punto(img, x, 1, AMBAR)
    # Grieta en el medio
    trazo(img, (16, 0), (14, 3), 1, CHASIS_OSC)
    return img


# ============================================================== compuerta ====

def compuerta():
    """16x64: hoja de metal con franjas de peligro. Cierra la arena."""
    img = lienzo(16, 64)
    for y in range(64):
        trazo(img, (1, y), (14, y), 1, CHASIS)
        if (y // 4) % 2 == 0 and y > 52:
            trazo(img, (2, y), (13, y), 1, (150, 110, 40, 255))
    for y in range(4, 52, 8):
        trazo(img, (2, y), (13, y), 1, CHASIS_OSC)
    trazo(img, (0, 0), (0, 63), 1, CHASIS_OSC)
    trazo(img, (15, 0), (15, 63), 1, CHASIS_OSC)
    return img


# ========================================================== el gran monitor ==

def origen():
    """64x80: el monitor del final, mas grande que el protagonista sentado.
    Pantalla apagada: la imagen la pone la escena del final."""
    img = lienzo(64, 80)
    for y in range(8, 60):
        trazo(img, (4, y), (59, y), 1, CHASIS)
    for y in range(13, 54):
        trazo(img, (9, y), (54, y), 1, CHASIS_OSC)
    for y in range(16, 51):
        trazo(img, (12, y), (51, y), 1, (16, 30, 22, 255))
    # Pie y cables que se hunden en el suelo
    barra(img, (32, 60), (32, 72), 10, CHASIS)
    for i, x in enumerate((10, 20, 44, 54)):
        trazo(img, (x, 60), (x - 6 + i * 4, 79), 2, CABLE)
    trazo(img, (2, 78), (61, 78), 2, CHASIS_OSC)
    canto(img, (128, 96, 70, 255))
    return img


# ================================================================ el jefe ====
# 56x72 por celda. Los pies en el borde inferior; el monitor-craneo arriba.
# La colision de custodio.tscn es 28x60 centrada: nada de lo que sobresale
# (brazos, cables) cuenta para el cuerpo.
JEFE_W, JEFE_H = 56, 72


def _jefe(inclinacion=0, brazo_izq=(0, 0), brazo_der=(0, 0), paso=0, pantalla=FOSFORO,
          ojo=FOSFORO_VIVO, boca=False, grieta=0, bote=0):
    img = lienzo(JEFE_W, JEFE_H)
    cx = 28 + inclinacion
    y0 = bote

    # Cola de cables: lo que lo ata al edificio. Va detras de todo.
    for i, dx in enumerate((-10, -6, 6, 10)):
        trazo(img, (cx + dx // 2, 36 + y0), (cx + dx, 71), 1, CABLE if i % 2 else CABLE_LUZ)

    # Piernas largas, de hueso, con la rodilla hacia atras (no es humano).
    for lado, desfase in ((-1, paso), (1, -paso)):
        cadera = (cx + lado * 5, 44 + y0)
        rodilla = (cx + lado * 9 + desfase, 57 + y0)
        pie = (cx + lado * 6 + desfase * 2, 71)
        trazo(img, cadera, rodilla, 3, HUESO_OSC)
        trazo(img, rodilla, pie, 2, HUESO_OSC)
        trazo(img, (pie[0] - 3, 71), (pie[0] + 3, 71), 1, HUESO_SOMBRA)

    # Pelvis y columna
    barra(img, (cx - 7, 44 + y0), (cx + 7, 44 + y0), 4, HUESO_OSC)
    trazo(img, (cx, 22 + y0), (cx, 44 + y0), 3, HUESO)

    # Costillas: haces de cable curvados alrededor de un nucleo
    disco(img, (cx, 32 + y0), 3, ROJO if boca else (120, 34, 30, 255))
    disco(img, (cx, 32 + y0), 1, ROJO_VIVO if boca else ROJO)
    for k in range(4):
        y = 25 + k * 4 + y0
        ancho = 9 - k
        trazo(img, (cx - 1, y), (cx - ancho, y + 3), 1, HUESO)
        trazo(img, (cx + 1, y), (cx + ancho, y + 3), 1, HUESO)

    # Hombros y brazos que llegan al suelo. brazo = (dx, dy) de la mano.
    hombro_i = (cx - 9, 23 + y0)
    hombro_d = (cx + 9, 23 + y0)
    barra(img, hombro_i, hombro_d, 4, HUESO)
    for hombro, lado, (dx, dy) in ((hombro_i, -1, brazo_izq), (hombro_d, 1, brazo_der)):
        codo = (hombro[0] + lado * 6 + dx // 2, hombro[1] + 18 + dy // 2)
        mano = (hombro[0] + lado * 8 + dx, hombro[1] + 38 + dy)
        trazo(img, hombro, codo, 2, HUESO)
        trazo(img, codo, mano, 2, HUESO_OSC)
        # Dedos: tres garras
        for g in (-2, 0, 2):
            trazo(img, mano, (mano[0] + g + lado, mano[1] + 4), 1, HUESO_OSC)

    # El craneo es un monitor agrietado, ladeado
    for y in range(4 + y0, 20 + y0):
        trazo(img, (cx - 9, y), (cx + 9, y), 1, CHASIS)
    for y in range(6 + y0, 18 + y0):
        trazo(img, (cx - 7, y), (cx + 7, y), 1, CHASIS_OSC)
    for y in range(7 + y0, 17 + y0):
        trazo(img, (cx - 6, y), (cx + 6, y), 1, pantalla)
    # Dos cuencas (lectura de calavera) y una linea de barrido
    for dx in (-3, 3):
        disco(img, (cx + dx, 11 + y0), 1.4, CHASIS_OSC)
        punto(img, cx + dx, 11 + y0, ojo)
    trazo(img, (cx - 6, 14 + y0), (cx + 6, 14 + y0), 1, ojo if boca else pantalla)
    # Grietas segun el dano (fases)
    if grieta >= 1:
        trazo(img, (cx - 6, 7 + y0), (cx - 1, 13 + y0), 1, CHASIS_OSC)
    if grieta >= 2:
        trazo(img, (cx + 6, 8 + y0), (cx + 2, 16 + y0), 1, CHASIS_OSC)
        trazo(img, (cx + 4, 0 + y0), (cx + 5, 4 + y0), 1, CABLE_LUZ)
    # Antenas como cuernos
    trazo(img, (cx - 7, 4 + y0), (cx - 11, 0), 1, HUESO_OSC)
    trazo(img, (cx + 7, 4 + y0), (cx + 10, 0), 1, HUESO_OSC)

    canto(img, (150, 104, 76, 255))
    return img


def jefe_quieto():
    return [_jefe(bote=0), _jefe(bote=1)]


def jefe_andar():
    return [_jefe(paso=-3, brazo_izq=(2, -2), brazo_der=(-2, 0)),
            _jefe(paso=0, bote=1),
            _jefe(paso=3, brazo_izq=(-2, 0), brazo_der=(2, -2)),
            _jefe(paso=0, bote=1)]


def jefe_preparar():
    # Se echa atras con los brazos en alto: es la telegrafia de todos sus golpes
    roja = (110, 32, 28, 255)
    return [_jefe(inclinacion=-2, brazo_izq=(-4, -30), brazo_der=(4, -30), pantalla=roja, ojo=ROJO_VIVO),
            _jefe(inclinacion=-3, brazo_izq=(-6, -32), brazo_der=(6, -32), pantalla=roja, ojo=ROJO_VIVO, bote=1)]


def jefe_golpe():
    roja = (150, 40, 32, 255)
    return [_jefe(inclinacion=3, brazo_izq=(10, 2), brazo_der=(14, 2), pantalla=roja, ojo=ROJO_VIVO, boca=True),
            _jefe(inclinacion=4, brazo_izq=(12, 4), brazo_der=(16, 4), pantalla=roja, ojo=ROJO_VIVO, boca=True)]


def jefe_rayo():
    return [_jefe(inclinacion=1, brazo_izq=(-8, -10), brazo_der=(8, -10), pantalla=FOSFORO_VIVO, ojo=(255, 255, 255, 255), boca=True),
            _jefe(inclinacion=1, brazo_izq=(-9, -11), brazo_der=(9, -11), pantalla=(230, 255, 236, 255), ojo=(255, 255, 255, 255), boca=True, bote=1)]


def jefe_aturdido():
    gris = (40, 54, 44, 255)
    return [_jefe(inclinacion=4, brazo_izq=(4, 6), brazo_der=(6, 6), pantalla=gris, ojo=(60, 80, 66, 255), bote=2),
            _jefe(inclinacion=5, brazo_izq=(5, 7), brazo_der=(7, 7), pantalla=gris, ojo=(60, 80, 66, 255), bote=3)]


def jefe_herido2():
    return [_jefe(grieta=1), _jefe(grieta=1, bote=1)]


def jefe_herido3():
    return [_jefe(grieta=2, pantalla=(150, 60, 48, 255), ojo=ROJO_VIVO),
            _jefe(grieta=2, pantalla=(120, 44, 36, 255), ojo=ROJO_VIVO, bote=1)]


JEFE_ORDEN = [
    ("quieto", 2.0, True, jefe_quieto),
    ("andar", 6.0, True, jefe_andar),
    ("preparar", 8.0, True, jefe_preparar),
    ("golpe", 10.0, False, jefe_golpe),
    ("rayo", 14.0, True, jefe_rayo),
    ("aturdido", 3.0, True, jefe_aturdido),
    ("quieto_f2", 2.0, True, jefe_herido2),
    ("quieto_f3", 3.0, True, jefe_herido3),
]


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


def _frames(orden, ancho, alto, hoja, destino):
    # Mismo formato que generar_sprite_frames.py: un AtlasTexture por celda.
    import generar_sprite_frames as gsf
    texto, _ = gsf.construir(orden, ancho, alto, hoja)
    io.open(destino, "w", encoding="utf-8", newline="\n").write(texto)
    print("  %s" % os.path.relpath(destino, JUEGO))


if __name__ == "__main__":
    filas_t = [fn() for _n, _f, _b, fn in TORRETA_ORDEN]
    _guardar(_hoja(filas_t, TORRETA, TORRETA), "torreta.png")
    _guardar(proyectil_enemigo(), "proyectiles", "enemigo.png")
    _guardar(plataforma_fragil(), "props", "plataforma_fragil.png")
    _guardar(compuerta(), "props", "compuerta.png")
    _guardar(origen(), "props", "origen.png")
    filas_j = [fn() for _n, _f, _b, fn in JEFE_ORDEN]
    _guardar(_hoja(filas_j, JEFE_W, JEFE_H), "custodio.png")
    _frames(TORRETA_ORDEN, TORRETA, TORRETA, "res://art/placeholder/torreta.png",
            os.path.join(JUEGO, "actors", "enemies", "torreta_frames.tres"))
    os.makedirs(os.path.join(JUEGO, "actors", "bosses"), exist_ok=True)
    _frames(JEFE_ORDEN, JEFE_W, JEFE_H, "res://art/placeholder/custodio.png",
            os.path.join(JUEGO, "actors", "bosses", "custodio_frames.tres"))
    if "--contacto" in sys.argv:
        ruta = os.path.join(AQUI, "..", "capturas", "hoja_jefe.png")
        pixel.contacto(filas_j, escala=5, columnas=4).save(ruta)
        print("hoja de contacto -> capturas/hoja_jefe.png")
