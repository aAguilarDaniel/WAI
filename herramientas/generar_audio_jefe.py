# -*- coding: utf-8 -*-
"""Audio del tramo final: la musica del Custodio y los efectos nuevos.

Uso:  python herramientas/generar_audio_jefe.py

Usa las mismas primitivas que generar_audio.py (libreria estandar, sin samples).
Va en un archivo aparte para no regenerar el resto del audio al tocar esto.
Placeholder como todo lo demas: la musica de verdad la ponen ustedes cambiando
el recurso `musica` de la ArenaJefe, sin tocar codigo.
"""
import math
import random

from generar_audio import TASA, _bucle, _guardar, _marcar_bucle, _ruido, _sobre

BPM = 138.0
NEGRA = 60.0 / BPM


def musica_jefe(compases=8):
    """Bucle de combate: bombo y chapa metalica a 138, un dron desafinado en
    tritono y un arpegio de onda cuadrada que se desafina como cinta gastada
    (ARTE.md §7). Ominoso antes que epico: es una catedral, no un estadio."""
    n = int(compases * 4 * NEGRA * TASA)
    rnd = random.Random(2077)
    salida = [0.0] * n

    # Dron: La grave contra Re# (tritono), desafinados entre si.
    for frec, amp in ((55.0, 0.14), (55.4, 0.10), (77.8, 0.08), (110.3, 0.04)):
        for i in range(n):
            t = i / float(TASA)
            sierra = 2.0 * ((frec * t) % 1.0) - 1.0
            salida[i] += sierra * amp * (0.8 + 0.2 * math.sin(t * 0.7))

    # Bombo en 1 y 3; en el ultimo compas de cada cuatro, doble.
    tiempos = int(compases * 4)
    for b in range(tiempos):
        golpes = []
        if b % 2 == 0:
            golpes.append(b * NEGRA)
        if b % 16 in (14, 15):
            golpes.append(b * NEGRA + NEGRA * 0.5)
        for inicio_s in golpes:
            inicio = int(inicio_s * TASA)
            largo = int(0.35 * TASA)
            env = _sobre(largo, 0.002, 9.0)
            for i in range(largo):
                if inicio + i >= n:
                    break
                t = i / float(TASA)
                frec = 120.0 * math.exp(-t * 18.0) + 42.0
                salida[inicio + i] += math.sin(math.tau * frec * t) * env[i] * 0.55

    # Chapa en 2 y 4: ruido con un anillo metalico.
    for b in range(1, tiempos, 2):
        inicio = int(b * NEGRA * TASA)
        largo = int(0.22 * TASA)
        env = _sobre(largo, 0.001, 14.0)
        for i in range(largo):
            if inicio + i >= n:
                break
            t = i / float(TASA)
            anillo = math.sin(math.tau * 1730.0 * t) * 0.25 + math.sin(math.tau * 2410.0 * t) * 0.15
            salida[inicio + i] += (rnd.uniform(-1.0, 1.0) * 0.5 + anillo) * env[i] * 0.32

    # Arpegio en corcheas: La, Do, Mi, Re#. La cinta lo desafina despacio.
    notas = [220.0, 261.6, 329.6, 311.1, 220.0, 261.6, 349.2, 311.1]
    corchea = NEGRA / 2.0
    for k in range(int(compases * 8)):
        frec = notas[k % len(notas)] * (0.5 if (k // 16) % 2 else 1.0)
        inicio = int(k * corchea * TASA)
        largo = int(corchea * 0.8 * TASA)
        env = _sobre(largo, 0.004, 5.0)
        for i in range(largo):
            if inicio + i >= n:
                break
            t = (inicio + i) / float(TASA)
            desafino = 1.0 + 0.006 * math.sin(t * 1.3)
            cuadrada = 1.0 if math.sin(math.tau * frec * desafino * t) > 0 else -1.0
            salida[inicio + i] += cuadrada * env[i] * 0.07

    pico = max(abs(v) for v in salida) or 1.0
    return [v / pico * 0.85 for v in salida]


def rugido():
    """El Custodio despierta o cambia de fase: un barrido grave con ruido rasposo."""
    n = int(1.4 * TASA)
    rnd = random.Random(41)
    env = _sobre(n, 0.08, 2.4)
    raspa = _ruido(n, rnd, suavizado=6)
    salida = []
    for i in range(n):
        t = i / float(TASA)
        frec = 70.0 + 40.0 * math.sin(t * 9.0) * math.exp(-t)
        tono = math.sin(math.tau * frec * t) + 0.5 * math.sin(math.tau * frec * 1.5 * t)
        salida.append((tono * 0.35 + raspa[i] * 0.5) * env[i])
    return salida


def pisoton():
    """Golpe al suelo: grave enorme y escombro."""
    n = int(0.9 * TASA)
    rnd = random.Random(42)
    env = _sobre(n, 0.002, 5.0)
    escombro = _ruido(n, rnd, suavizado=12)
    salida = []
    for i in range(n):
        t = i / float(TASA)
        frec = 90.0 * math.exp(-t * 6.0) + 30.0
        salida.append((math.sin(math.tau * frec * t) * 0.8 + escombro[i] * 0.45) * env[i])
    return salida


def rayo_carga():
    """El aviso del rayo: un tono que sube. Tiene que oirse aunque no se mire."""
    n = int(0.9 * TASA)
    salida = []
    for i in range(n):
        t = i / float(TASA)
        frec = 300.0 + 900.0 * (t / 0.9) ** 2
        salida.append(math.sin(math.tau * frec * t) * 0.22 * (t / 0.9))
    return salida


def rayo():
    """La descarga: zumbido saturado."""
    n = int(0.6 * TASA)
    rnd = random.Random(43)
    env = _sobre(n, 0.003, 2.5)
    salida = []
    for i in range(n):
        t = i / float(TASA)
        zum = math.copysign(1.0, math.sin(math.tau * 180.0 * t)) * 0.3
        salida.append((zum + rnd.uniform(-1, 1) * 0.25) * env[i])
    return salida


def disparo_torreta():
    """Disparo seco con un silbido corto."""
    n = int(0.25 * TASA)
    rnd = random.Random(44)
    env = _sobre(n, 0.001, 12.0)
    salida = []
    for i in range(n):
        t = i / float(TASA)
        frec = 900.0 - 2400.0 * t
        salida.append((math.sin(math.tau * frec * t) * 0.4 + rnd.uniform(-1, 1) * 0.3) * env[i])
    return salida


def derrumbe():
    """Metal que cede: crujido y caida de escombro."""
    n = int(0.7 * TASA)
    rnd = random.Random(45)
    env = _sobre(n, 0.01, 4.0)
    salida = []
    for i in range(n):
        crujido = rnd.uniform(-1, 1) if rnd.random() < 0.06 else 0.0
        salida.append((crujido * 0.6 + rnd.uniform(-1, 1) * 0.15) * env[i])
    return salida


if __name__ == "__main__":
    print("Musica (en bucle):")
    _marcar_bucle(_guardar("musica_jefe.wav", musica_jefe(), bucle=True))
    print("Efectos:")
    _guardar("rugido.wav", rugido())
    _guardar("pisoton.wav", pisoton())
    _guardar("rayo_carga.wav", rayo_carga())
    _guardar("rayo.wav", rayo())
    _guardar("disparo_torreta.wav", disparo_torreta())
    _guardar("derrumbe.wav", derrumbe())
