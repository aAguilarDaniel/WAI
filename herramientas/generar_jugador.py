# -*- coding: utf-8 -*-
"""Genera el spritesheet animado del protagonista de Who Am I.

Sustituye al GradientTexture2D de 16x24 que habia en actors/player/jugador.tscn.
No es pixel art dibujado a mano: es una figura ARTICULADA rasterizada. Cada frame
es una pose de esqueleto (cadera, torso, dos brazos, dos piernas, cabeza) que se
dibuja con trazos gruesos y se recorta con luz de canto por el borde derecho,
que es como ARTE.md 3 pide que se lea el personaje: en silueta, a contraluz.

Sirve para que las mecanicas se ENTIENDAN al verlas -- rodar tiene que leerse
como tirarse, dar una voltereta y levantarse, no como un rectangulo deslizando.
El refinado a mano se hace encima en Aseprite: la rejilla y los nombres de
animacion ya son los definitivos (art/PLACEHOLDERS.md).

Uso:  python herramientas/generar_jugador.py [--contacto]

  --contacto  ademas escribe capturas/hoja_jugador.png, la hoja de contacto a 6x
              para revisar las poses de un vistazo sin abrir Godot.

La rejilla es de 24x24 por celda, UNA FILA POR ANIMACION, en el orden de ORDEN.
El .tres de SpriteFrames lo escribe herramientas/generar_sprite_frames.py leyendo
ese mismo orden, asi que anadir una animacion es anadirla aqui y volver a correr
los dos scripts.
"""
import math
import os
import sys

from PIL import Image

import pixel
from pixel import barra, canto, disco, extremo, lienzo, trazo

CELDA = 24
RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "juego", "art")
DESTINO = os.path.join(RAIZ, "placeholder", "jugador.png")

# --- Paleta. Polo humano de ARTE.md 1: el cuerpo es casi negro calido y la unica
# luz es la brasa del fondo, que le recorta el canto derecho. ---
CUERPO = (17, 13, 17, 255)
ATRAS = (34, 26, 31, 255)      # miembros del lado lejano: 1 tono mas claro para
                               # que el brazo y la pierna de atras se separen
METAL = (74, 68, 66, 255)      # el tubo de metal, en el ataque
CANTO = (96, 72, 54, 255)
CANTO_CAB = (158, 110, 64, 255)

# --- Medidas del esqueleto, para un personaje de 24 px de alto ---
CX = 12.0          # centro de la celda
CADERA_Y = 15.0    # cadera a 8 px del suelo; el suelo es la fila 23
TORSO = 9.0        # cadera -> cuello
MUSLO = 4.0
PANTORRILLA = 4.0
BRAZO = 4.0
ANTEBRAZO = 4.0
R_CABEZA = 2.4
ANCHO_TORSO = 7


# ---------------------------------------------------------------- esqueleto ---

def _miembro(img, origen, a1, a2, l1, l2, grosor, color, giro):
    """Cadena de dos huesos. Devuelve el punto final (mano o tobillo).

    `giro` es la inclinacion del torso: los miembros cuelgan del cuerpo, asi que
    rotan con el. Las poses acrobaticas la anulan con "mundo": ahi es mas facil
    pensar en angulos absolutos que relativos al tronco.
    """
    codo = extremo(origen, giro + a1, l1)
    fin = extremo(codo, giro + a1 + a2, l2)
    trazo(img, origen, codo, grosor, color)
    trazo(img, codo, fin, grosor, color)
    return fin


def _pie(img, tobillo, sentido, color):
    """Munon de 3 px hacia delante. Sin pie la pierna termina en punta y la
    figura pierde el apoyo: es el detalle que hace que se lea de pie."""
    trazo(img, tobillo, (tobillo[0] + 2.5 * sentido, tobillo[1]), 2, color)


def figura(pose):
    """Rasteriza una pose en una celda de 24x24."""
    img = lienzo(CELDA, CELDA)

    inc = pose.get("inclinacion", 0.0)
    giro = 0.0 if pose.get("mundo") else -inc
    cadera = pose.get("cadera", (CX, CADERA_Y))
    largo_torso = pose.get("torso", TORSO)

    cuello = extremo(cadera, 180.0 - inc, largo_torso)
    hombro = extremo(cuello, -inc, 1.2)
    dc = pose.get("cabeza", (0.0, 0.0))
    centro_cabeza = extremo(cuello, 180.0 - inc, R_CABEZA + 1.2)
    centro_cabeza = (centro_cabeza[0] + dc[0], centro_cabeza[1] + dc[1])

    pierna_atras = pose.get("pierna_atras", (0.0, 0.0))
    pierna_frente = pose.get("pierna_frente", (0.0, 0.0))
    brazo_atras = pose.get("brazo_atras", (6.0, 14.0))
    brazo_frente = pose.get("brazo_frente", (6.0, 14.0))
    con_pies = pose.get("pies", True)

    # Fondo -> frente. El orden es lo que da la profundidad sin sombrear nada.
    tobillo = _miembro(img, cadera, pierna_atras[0], pierna_atras[1],
                       MUSLO, PANTORRILLA, 3, ATRAS, giro)
    if con_pies:
        _pie(img, tobillo, 1, ATRAS)
    _miembro(img, hombro, brazo_atras[0], brazo_atras[1],
             BRAZO, ANTEBRAZO, 2, ATRAS, giro)

    barra(img, cadera, cuello, ANCHO_TORSO, CUERPO)
    trazo(img, cuello, centro_cabeza, 2, CUERPO)   # el cuello: sin el, sombrero
    disco(img, centro_cabeza, R_CABEZA, CUERPO)

    tobillo = _miembro(img, cadera, pierna_frente[0], pierna_frente[1],
                       MUSLO, PANTORRILLA, 3, CUERPO, giro)
    if con_pies:
        _pie(img, tobillo, 1, CUERPO)
    mano = _miembro(img, hombro, brazo_frente[0], brazo_frente[1],
                    BRAZO, ANTEBRAZO, 2, CUERPO, giro)

    if pose.get("arma") is not None:
        largo = pose.get("arma_largo", 9.0)
        trazo(img, extremo(mano, pose["arma"] + 180.0, 2.0),
              extremo(mano, pose["arma"], largo), 2, METAL)

    canto(img, CANTO, CANTO_CAB, int(centro_cabeza[1] + R_CABEZA))
    return img


# -------------------------------------------------------------- animaciones ---

def anim_quieto():
    """Respiracion lenta. Nada mas: un idle que se mueve mucho distrae."""
    cuadros = []
    for torso, hombro in ((9.0, 6.0), (9.0, 6.0), (10.0, 4.0), (10.0, 5.0)):
        cuadros.append(figura({
            "torso": torso,
            "inclinacion": 2.0,
            "brazo_atras": (hombro - 2.0, 16.0),
            "brazo_frente": (hombro, 14.0),
            "pierna_atras": (-4.0, 0.0),
            "pierna_frente": (4.0, 0.0),
        }))
    return cuadros


def _ciclo_paso(n, amplitud, rodilla, lean, brazo, codo, bote, torso=TORSO):
    """Ciclo de piernas. La rodilla se dobla cuando la pierna pasa por vertical
    (max(0, cos)), que es el momento en que el pie tiene que despegar del suelo.
    Los brazos van en contrafase con su pierna: sin eso el paso parece un salto."""
    cuadros = []
    for i in range(n):
        th = 2.0 * math.pi * i / n
        s, c = math.sin(th), math.cos(th)
        cuadros.append(figura({
            "cadera": (CX, CADERA_Y - bote * math.cos(2.0 * th)),
            "torso": torso,
            "inclinacion": lean,
            "pierna_frente": (amplitud * s, -rodilla * max(0.0, c)),
            "pierna_atras": (-amplitud * s, -rodilla * max(0.0, -c)),
            "brazo_frente": (-brazo * s, codo),
            "brazo_atras": (brazo * s, codo),
        }))
    return cuadros


def anim_caminar():
    return _ciclo_paso(8, amplitud=25.0, rodilla=44.0, lean=4.0,
                       brazo=34.0, codo=18.0, bote=0.9)


def anim_correr():
    """Mismo ciclo con el volumen subido: mas zancada, mas tronco echado hacia
    delante y el codo cerrado a 80 grados, que es lo que distingue correr de
    caminar rapido."""
    return _ciclo_paso(8, amplitud=46.0, rodilla=78.0, lean=16.0,
                       brazo=40.0, codo=80.0, bote=1.6, torso=8.5)


def anim_saltar():
    return [
        # Impulso: se hunde antes de despegar. Sin este frame el salto no pesa.
        figura({"cadera": (CX, CADERA_Y + 2.0), "torso": 8.0, "inclinacion": 16.0,
                "pierna_atras": (-16.0, -52.0), "pierna_frente": (10.0, -58.0),
                "brazo_atras": (-58.0, 24.0), "brazo_frente": (-48.0, 20.0)}),
        # Extension: todo el cuerpo estirado hacia arriba.
        figura({"cadera": (CX, CADERA_Y), "torso": 9.5, "inclinacion": 6.0,
                "pierna_atras": (-30.0, -18.0), "pierna_frente": (12.0, -12.0),
                "brazo_atras": (128.0, -18.0), "brazo_frente": (142.0, -22.0)}),
        # Sostenido: rodilla adelantada, la otra pierna colgando. Se queda aqui
        # todo lo que dure la subida.
        figura({"cadera": (CX, CADERA_Y), "torso": 9.0, "inclinacion": -4.0,
                "pierna_atras": (-22.0, -44.0), "pierna_frente": (30.0, -72.0),
                "brazo_atras": (140.0, -30.0), "brazo_frente": (158.0, -26.0)}),
    ]


def anim_caer():
    return [
        # Sostenido: piernas abiertas, tronco echado atras, brazos por encima de
        # la cabeza. Nada de esto se puede hacer de pie, y por eso se lee.
        figura({"cadera": (CX, CADERA_Y - 0.5), "torso": 9.0, "inclinacion": -16.0,
                "mundo": True,
                "pierna_atras": (-52.0, -10.0), "pierna_frente": (40.0, -36.0),
                "brazo_atras": (166.0, -30.0), "brazo_frente": (-172.0, 26.0)}),
        # Anticipacion de aterrizaje: las piernas ya buscan el suelo y los brazos
        # bajan a los lados. Es el frame que avisa de que va a tocar.
        figura({"cadera": (CX, CADERA_Y), "torso": 9.0, "inclinacion": 8.0,
                "mundo": True,
                "pierna_atras": (-26.0, 16.0), "pierna_frente": (24.0, 12.0),
                "brazo_atras": (118.0, 40.0), "brazo_frente": (140.0, 34.0)}),
    ]


def anim_agachado():
    """14 px de alto, que es lo que mide la colision al agacharse (jugador.gd,
    ajustar_forma). Si la silueta fuera mas alta, el jugador creeria que no cabe."""
    cuadros = []
    for dy in (0.0, 0.4):
        cuadros.append(figura({
            "cadera": (CX - 1.0, 19.6 + dy), "torso": 5.2, "inclinacion": 24.0,
            "pierna_atras": (58.0, -116.0), "pierna_frente": (66.0, -128.0),
            "brazo_atras": (26.0, 46.0), "brazo_frente": (34.0, 40.0),
        }))
    return cuadros


def _apoyar(img, suelo=23):
    """Baja la celda hasta que su pixel opaco mas bajo cae en `suelo`.

    Cada giro del ovillo tiene una silueta distinta, asi que su borde inferior
    no cae solo en el mismo sitio: sin esto la bola sube y baja mientras rueda
    y parece que rebota. Rodar es un desplazamiento raso, no un salto.
    """
    bajo = None
    for y in range(img.height):
        for x in range(img.width):
            if img.getpixel((x, y))[3] > 0:
                bajo = y
    if bajo is None or bajo == suelo:
        return img
    movida = lienzo(img.width, img.height)
    movida.paste(img, (0, suelo - bajo))
    return movida


def _reducir3(grande):
    """Baja de 72x72 a 24x24 por mayoria de bloque. Un bloque 3x3 sale opaco si
    al menos 4 de sus 9 pixeles lo estan, y toma el color que mas se repite: sin
    eso el ovillo adelgaza en cada giro."""
    chico = lienzo(CELDA, CELDA)
    for y in range(CELDA):
        for x in range(CELDA):
            cuenta = {}
            opacos = 0
            for dy in range(3):
                for dx in range(3):
                    c = grande.getpixel((x * 3 + dx, y * 3 + dy))
                    if c[3] < 128:
                        continue
                    opacos += 1
                    cuenta[c] = cuenta.get(c, 0) + 1
            if opacos >= 4:
                chico.putpixel((x, y), max(cuenta, key=cuenta.get))
    return chico


def _bola():
    """El cuerpo hecho un ovillo, en su orientacion de partida, dibujado a 3x.

    A proposito NO es un circulo: lleva la cabeza metida entre las rodillas y un
    pie asomando. Un circulo perfecto rotado no se ve rotar, y entonces la
    voltereta no se lee.
    """
    img = lienzo(CELDA * 3, CELDA * 3)
    barra(img, (27.0, 60.0), (42.0, 43.5), 27, CUERPO)   # tronco enroscado
    disco(img, (29.4, 46.2), 11.7, ATRAS)                # rodillas contra el pecho
    disco(img, (43.8, 55.8), 9.0, CUERPO)                # cabeza metida
    trazo(img, (40.5, 46.5), (28.5, 58.5), 9, ATRAS)     # brazos abrazando las piernas
    trazo(img, (22.8, 46.2), (14.4, 51.6), 6, ATRAS)     # un pie asomando del ovillo
    return img


def anim_rodar():
    """Tirarse, dar la voltereta y levantarse, en 6 frames.

    La duracion la fija duracion_rodar del jugador (0.30 s), asi que el animador
    escala la velocidad para que entre justa: la voltereta termina exactamente
    cuando terminan los i-frames y el personaje se pone de pie.

    Los cuatro frames del medio son la MISMA bola rotada 72 grados cada vez, en
    sentido horario. La luz de canto se aplica DESPUES de rotar: la brasa del
    fondo no gira con el, y es eso lo que hace que el giro se vea.
    """
    cuadros = []

    # 1. Se tira: el tronco se pica hacia delante, las manos buscan el suelo y
    # las piernas salen despedidas hacia atras y arriba. Ya no toca el suelo.
    cuadros.append(figura({
        "cadera": (10.0, 16.5), "torso": 9.0, "inclinacion": 60.0, "mundo": True,
        "pierna_atras": (-118.0, 26.0), "pierna_frente": (-138.0, 30.0),
        "brazo_atras": (36.0, 16.0), "brazo_frente": (24.0, 12.0),
        "pies": False,
    }))

    # 2-5. La voltereta.
    bola = _bola()
    for i in range(1, 5):
        girada = bola.rotate(-72.0 * i, resample=Image.NEAREST, center=(34.5, 52.5))
        girada = _apoyar(_reducir3(girada))
        canto(girada, CANTO)
        cuadros.append(girada)

    # 6. Se levanta: una rodilla en el suelo, la mano apoyada, el tronco subiendo.
    cuadros.append(figura({
        "cadera": (11.0, 18.0), "torso": 8.5, "inclinacion": 34.0, "mundo": True,
        "pierna_atras": (52.0, -128.0), "pierna_frente": (-28.0, 34.0),
        "brazo_atras": (150.0, 20.0), "brazo_frente": (52.0, 26.0),
    }))
    return cuadros


def anim_atacar():
    """Las tres fases de estado_atacar.gd, con el tubo de metal dibujado.

    El arma se ve en TODOS los frames y cambia de angulo: es lo unico que hace
    legible que esto es un golpe y no un tropiezo. El frame 2 es el de extension
    maxima y coincide con la ventana en que la hitbox existe de verdad.
    """
    return [
        # Anticipacion: el arma sube por detras, el peso se va al pie de atras.
        figura({"cadera": (CX - 1.0, CADERA_Y), "torso": 9.0, "inclinacion": -14.0,
                "mundo": True,
                "pierna_atras": (-24.0, 20.0), "pierna_frente": (22.0, -12.0),
                "brazo_atras": (-40.0, 30.0), "brazo_frente": (-146.0, 34.0),
                "arma": -146.0, "arma_largo": 8.0}),
        # Activo: extension completa hacia delante. El alcance se ve.
        figura({"cadera": (CX - 1.0, CADERA_Y), "torso": 9.0, "inclinacion": 18.0,
                "mundo": True,
                "pierna_atras": (-44.0, 16.0), "pierna_frente": (36.0, -18.0),
                "brazo_atras": (-58.0, 26.0), "brazo_frente": (86.0, 4.0),
                "arma": 92.0, "arma_largo": 10.0}),
        # Seguimiento: el tubo baja. La inercia del golpe.
        figura({"cadera": (CX - 1.0, CADERA_Y), "torso": 9.0, "inclinacion": 22.0,
                "mundo": True,
                "pierna_atras": (-40.0, 14.0), "pierna_frente": (32.0, -14.0),
                "brazo_atras": (-46.0, 26.0), "brazo_frente": (104.0, 16.0),
                "arma": 126.0, "arma_largo": 9.0}),
        # Recuperacion: el arma vuelve y el cuerpo se endereza. No puede atacar.
        figura({"cadera": (CX, CADERA_Y), "torso": 9.0, "inclinacion": 6.0,
                "mundo": True,
                "pierna_atras": (-16.0, 8.0), "pierna_frente": (14.0, -6.0),
                "brazo_atras": (-20.0, 22.0), "brazo_frente": (48.0, 30.0),
                "arma": 56.0, "arma_largo": 9.0}),
    ]


def anim_herido():
    return [
        # El impacto llega de delante: la cabeza se va hacia atras y los brazos
        # salen despedidos. El cuerpo se despega del suelo.
        figura({"cadera": (CX + 1.0, CADERA_Y - 1.0), "torso": 9.0,
                "inclinacion": -30.0, "mundo": True,
                "pierna_atras": (-34.0, 26.0), "pierna_frente": (26.0, -46.0),
                "brazo_atras": (128.0, 30.0), "brazo_frente": (150.0, 26.0)}),
        # Recomponiendose, todavia sin control.
        figura({"cadera": (CX + 0.5, CADERA_Y), "torso": 9.0,
                "inclinacion": -14.0, "mundo": True,
                "pierna_atras": (-22.0, 12.0), "pierna_frente": (18.0, -18.0),
                "brazo_atras": (58.0, 34.0), "brazo_frente": (88.0, 30.0)}),
    ]


def anim_sentado():
    """La postura de TV Buddha (ARTE.md 4): de perfil, piernas cruzadas, quieto.

    Reemplaza al placeholder de jugador.gd que solo achataba el sprite. Que sea
    reconocible como "sentado en el suelo" es la mitad de la cita: la otra mitad
    la pone el cable, que ya existe.
    """
    cuadros = []
    for dy in (0.0, 0.5):
        img = lienzo(CELDA, CELDA)
        cadera = (9.5, 20.5 + dy)
        cuello = (11.0, 13.2 + dy)
        centro_cabeza = (11.6, 9.6 + dy)

        # Las piernas primero y en el tono de atras: la de mas lejos, tumbada.
        trazo(img, (9.0, 21.8), (16.0, 21.4), 3, ATRAS)
        # La cercana cruza por encima, con la rodilla levantada hacia delante.
        # Esa rodilla que sobresale es TODA la lectura de "piernas cruzadas".
        trazo(img, (9.5, 21.5), (16.5, 19.6), 4, CUERPO)
        trazo(img, (16.5, 19.6), (11.5, 22.3), 3, CUERPO)

        barra(img, cadera, cuello, 7, CUERPO)          # tronco vertical
        trazo(img, cuello, centro_cabeza, 2, CUERPO)   # cuello
        disco(img, centro_cabeza, R_CABEZA, CUERPO)
        # El brazo cae del hombro y descansa sobre la rodilla: cierra la figura
        # y evita que el tronco parezca un poste clavado en un monton.
        trazo(img, (11.2, 14.6 + dy), (13.6, 18.2), 2, CUERPO)
        trazo(img, (13.6, 18.2), (16.0, 19.8), 2, CUERPO)

        canto(img, CANTO, CANTO_CAB, int(centro_cabeza[1] + R_CABEZA))
        cuadros.append(img)
    return cuadros


# El orden de las filas de la hoja. generar_sprite_frames.py lee esta lista, asi
# que cambiarla aqui cambia el .tres sin tocar nada mas.
# (nombre, fps, bucle) -- el nombre coincide en minusculas con el nodo de estado
# de actors/player/estados/, que es lo que permite engancharlos sin casos especiales.
ORDEN = [
    ("quieto", 6.0, True, anim_quieto),
    ("caminar", 10.0, True, anim_caminar),
    ("correr", 12.0, True, anim_correr),
    ("saltar", 12.0, False, anim_saltar),
    ("caer", 8.0, False, anim_caer),
    ("agachado", 6.0, True, anim_agachado),
    ("rodar", 20.0, False, anim_rodar),
    ("atacar", 13.0, False, anim_atacar),
    ("herido", 9.0, False, anim_herido),
    ("sentado", 5.0, True, anim_sentado),
]


def construir():
    filas = [(nombre, fps, bucle, fn()) for nombre, fps, bucle, fn in ORDEN]
    columnas = max(len(f[3]) for f in filas)
    hoja = lienzo(columnas * CELDA, len(filas) * CELDA)
    for y, fila in enumerate(filas):
        for x, celda in enumerate(fila[3]):
            hoja.paste(celda, (x * CELDA, y * CELDA))
    return hoja, filas


if __name__ == "__main__":
    hoja, filas = construir()
    os.makedirs(os.path.dirname(DESTINO), exist_ok=True)
    hoja.save(DESTINO)
    print("jugador.png  %dx%d  (%d animaciones)" % (hoja.width, hoja.height, len(filas)))
    for nombre, fps, bucle, cuadros in filas:
        print("  %-9s %d frames  %.0f fps  %s"
              % (nombre, len(cuadros), fps, "bucle" if bucle else "una vez"))

    if "--contacto" in sys.argv:
        ruta = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            "..", "capturas", "hoja_jugador.png")
        pixel.contacto([f[3] for f in filas], suelo=23).save(ruta)
        print("hoja de contacto -> capturas/hoja_jugador.png")
