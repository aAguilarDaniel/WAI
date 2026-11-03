# -*- coding: utf-8 -*-
"""Audio de los niveles 5-6 y del jefe secreto.

Uso:  python herramientas/generar_audio_secreto.py

Mismas primitivas que generar_audio.py. Placeholder: la musica del Reflejo se
cambia en el recurso `musica` del nodo Arena de levels/secreto/nivel_secreto.tscn.
"""
import math
import random

from generar_audio import TASA, _guardar, _marcar_bucle, _ruido, _sobre


def musica_secreta(segundos=16.0):
    """La sala del Reflejo: la musica del juego al reves. Un solo pulso lento,
    un acorde que no resuelve y la melodia del menu tocada hacia atras. Lo que
    suena familiar y no deberia."""
    n = int(segundos * TASA)
    rnd = random.Random(1969)
    salida = [0.0] * n
    # Acorde: La menor con la novena y el tritono, muy grave.
    for frec, amp in ((55.0, 0.12), (65.4, 0.08), (77.8, 0.07), (123.5, 0.04)):
        for i in range(n):
            t = i / float(TASA)
            salida[i] += math.sin(math.tau * frec * t) * amp * (0.7 + 0.3 * math.sin(t * 0.4))
    # Pulso: un latido cada 0.8 s (75 por minuto), doble.
    latido = 0.8
    for k in range(int(segundos / latido)):
        for desfase, amp in ((0.0, 0.5), (0.18, 0.32)):
            inicio = int((k * latido + desfase) * TASA)
            largo = int(0.25 * TASA)
            env = _sobre(largo, 0.003, 10.0)
            for i in range(largo):
                if inicio + i >= n:
                    break
                t = i / float(TASA)
                salida[inicio + i] += math.sin(math.tau * (70.0 - 30.0 * t) * t) * env[i] * amp
    # Melodia invertida: notas con ataque lento y corte seco (un sonido "al reves").
    notas = [329.6, 293.7, 261.6, 246.9, 220.0, 246.9, 261.6, 207.7]
    paso = segundos / len(notas)
    for k, frec in enumerate(notas):
        inicio = int(k * paso * TASA)
        largo = int(paso * 0.9 * TASA)
        for i in range(largo):
            if inicio + i >= n:
                break
            t = i / float(largo)
            env = t ** 2.5
            salida[inicio + i] += math.sin(math.tau * frec * (i / float(TASA))) * env * 0.08
    # Estatica de CRT por debajo
    estatica = _ruido(n, rnd, suavizado=3)
    for i in range(n):
        salida[i] += estatica[i] * 0.025
    pico = max(abs(v) for v in salida) or 1.0
    return [v / pico * 0.8 for v in salida]


def zumbido_dron():
    """El dron apunta: un zumbido de aspas que sube."""
    n = int(0.6 * TASA)
    salida = []
    for i in range(n):
        t = i / float(TASA)
        frec = 180.0 + 220.0 * t
        aspa = 1.0 if math.sin(math.tau * 38.0 * t) > 0 else 0.6
        salida.append(math.copysign(1.0, math.sin(math.tau * frec * t)) * 0.18 * aspa * min(1.0, t * 6.0))
    return salida


def prensa():
    """Metal contra metal: golpe seco con anillo."""
    n = int(0.6 * TASA)
    rnd = random.Random(51)
    env = _sobre(n, 0.001, 9.0)
    salida = []
    for i in range(n):
        t = i / float(TASA)
        anillo = math.sin(math.tau * 310.0 * t) * 0.3 + math.sin(math.tau * 777.0 * t) * 0.15
        grave = math.sin(math.tau * (80.0 * math.exp(-t * 8.0) + 40.0) * t) * 0.6
        salida.append((grave + anillo + rnd.uniform(-1, 1) * 0.2) * env[i])
    return salida


if __name__ == "__main__":
    print("Musica (en bucle):")
    _marcar_bucle(_guardar("musica_secreta.wav", musica_secreta(), bucle=True))
    print("Efectos:")
    _guardar("zumbido_dron.wav", zumbido_dron())
    _guardar("prensa.wav", prensa())
