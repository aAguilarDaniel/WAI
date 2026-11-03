# -*- coding: utf-8 -*-
"""Genera el audio provisional de Who Am I: un ambiente en bucle y los efectos.

Es sintesis por codigo con la libreria estandar (wave + array), igual que el
resto de placeholders del proyecto: nada de samples descargados, nada de
licencias que revisar. ARTE.md §7 pide deterioro de cinta y electronica de los
90 como base; esto es la version pobre de eso, suficiente para que la demo no
suene a nada y para que se pueda cambiar por audio de verdad sin tocar codigo.

Uso:  python herramientas/generar_audio.py

Sale en juego/audio/. Los dos que van en bucle llevan su .import escrito por
este mismo script: Godot importa los .wav sin bucle por defecto, y un ambiente
que se corta a los 22 segundos y no vuelve es peor que no tener ambiente.
"""
import array
import math
import os
import random
import wave

TASA = 22050            # de sobra para esto y ocupa la mitad
RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "juego", "audio")


def _guardar(nombre, muestras, bucle=False):
    """Escribe un WAV mono de 16 bits."""
    os.makedirs(RAIZ, exist_ok=True)
    ruta = os.path.join(RAIZ, nombre)
    datos = array.array("h")
    for v in muestras:
        datos.append(max(-32767, min(32767, int(v * 32767.0))))
    f = wave.open(ruta, "wb")
    f.setnchannels(1)
    f.setsampwidth(2)
    f.setframerate(TASA)
    f.writeframes(datos.tobytes())
    f.close()
    print("  %-26s %5.2f s%s" % (nombre, len(muestras) / float(TASA),
                                 "  (bucle)" if bucle else ""))
    return ruta


def _sobre(n, ataque, caida, sostenido=0.0):
    """Envolvente pobre: ataque lineal, caida exponencial."""
    env = []
    na = max(1, int(ataque * TASA))
    for i in range(n):
        if i < na:
            env.append(i / float(na))
        else:
            t = (i - na) / float(max(1, n - na))
            env.append((1.0 - sostenido) * math.exp(-t * caida) + sostenido * (1.0 - t))
    return env


def _ruido(n, rnd, suavizado=0):
    """Ruido blanco, opcionalmente pasado por una media movil (paso bajo pobre)."""
    crudo = [rnd.uniform(-1.0, 1.0) for _ in range(n)]
    if suavizado <= 1:
        return crudo
    salida = []
    acumulado = 0.0
    cola = []
    for v in crudo:
        cola.append(v)
        acumulado += v
        if len(cola) > suavizado:
            acumulado -= cola.pop(0)
        salida.append(acumulado / len(cola))
    return salida


def _bucle(muestras, cruce=1.0):
    """Cruza el final con el principio para que el bucle no de un chasquido."""
    n = int(cruce * TASA)
    if n * 2 >= len(muestras):
        return muestras
    salida = list(muestras)
    for i in range(n):
        t = i / float(n)
        salida[i] = salida[i] * t + muestras[len(muestras) - n + i] * (1.0 - t)
    return salida[:len(muestras) - n]


# ---------- Ambiente ----------

def ambiente(segundos=24.0):
    """Zumbido de instalacion: dos drones graves batiendo, viento filtrado y
    algun golpe metalico lejano. Sostiene el nivel entero, asi que no lleva nada
    con altura definida: en cuanto tiene nota, cansa a los dos minutos."""
    n = int(segundos * TASA)
    rnd = random.Random(1974)
    salida = [0.0] * n

    # Drones. Las frecuencias estan desafinadas entre si a proposito: el batido
    # lento es lo que hace que suene a maquina y no a organo.
    for frec, amp in ((41.0, 0.16), (41.7, 0.13), (61.5, 0.07), (82.3, 0.045)):
        fase = rnd.uniform(0, math.tau)
        for i in range(n):
            t = i / float(TASA)
            respira = 0.75 + 0.25 * math.sin(t * 0.11 + fase)
            salida[i] += math.sin(math.tau * frec * t + fase) * amp * respira

    # Viento: ruido muy filtrado con el volumen ondulando.
    viento = _ruido(n, rnd, suavizado=160)
    for i in range(n):
        t = i / float(TASA)
        onda = 0.5 + 0.5 * math.sin(t * 0.19 + 1.3) * math.sin(t * 0.07)
        salida[i] += viento[i] * 0.55 * onda

    # Cinco golpes metalicos lejanos, repartidos sin ritmo.
    for _ in range(5):
        inicio = rnd.randrange(0, n - TASA)
        largo = int(rnd.uniform(0.25, 0.7) * TASA)
        frec = rnd.uniform(180.0, 420.0)
        env = _sobre(largo, 0.002, 7.0)
        for i in range(largo):
            if inicio + i >= n:
                break
            t = i / float(TASA)
            golpe_lejano = (math.sin(math.tau * frec * t)
                            + 0.4 * math.sin(math.tau * frec * 2.7 * t))
            salida[inicio + i] += golpe_lejano * env[i] * 0.06

    return _bucle(salida, cruce=1.5)


# ---------- Efectos ----------

def salto():
    """Golpe de aire corto y ascendente. No es un 'boing': el personaje pesa."""
    n = int(0.16 * TASA)
    rnd = random.Random(2)
    env = _sobre(n, 0.004, 9.0)
    ruido = _ruido(n, rnd, suavizado=6)
    salida = []
    for i in range(n):
        t = i / float(TASA)
        frec = 190.0 + 260.0 * (i / float(n))
        salida.append((math.sin(math.tau * frec * t) * 0.35 + ruido[i] * 0.5) * env[i] * 0.5)
    return salida


def aterrizar():
    """Impacto grave con cola de polvo."""
    n = int(0.30 * TASA)
    rnd = random.Random(3)
    env = _sobre(n, 0.001, 11.0)
    ruido = _ruido(n, rnd, suavizado=14)
    salida = []
    for i in range(n):
        t = i / float(TASA)
        frec = 120.0 - 60.0 * (i / float(n))
        salida.append((math.sin(math.tau * frec * t) * 0.6 + ruido[i] * 0.45) * env[i] * 0.6)
    return salida


def golpe():
    """Metal contra chapa. Corto, seco y con cuerpo: es el sonido que vende que
    el ataque conecto."""
    n = int(0.22 * TASA)
    rnd = random.Random(4)
    env = _sobre(n, 0.001, 16.0)
    ruido = _ruido(n, rnd, suavizado=3)
    salida = []
    for i in range(n):
        t = i / float(TASA)
        cuerpo = (math.sin(math.tau * 310.0 * t)
                  + 0.6 * math.sin(math.tau * 470.0 * t)
                  + 0.3 * math.sin(math.tau * 940.0 * t))
        salida.append((cuerpo * 0.28 + ruido[i] * 0.55) * env[i] * 0.7)
    return salida


def dano():
    """Recibir. Grave, sucio y descendente: tiene que dar mas miedo que acertar."""
    n = int(0.38 * TASA)
    rnd = random.Random(5)
    env = _sobre(n, 0.002, 8.0)
    ruido = _ruido(n, rnd, suavizado=8)
    salida = []
    for i in range(n):
        t = i / float(TASA)
        frec = 220.0 * math.exp(-t * 5.0) + 70.0
        cuerpo = math.sin(math.tau * frec * t)
        # Distorsion dura: lo que separa "me han dado" de "he tocado algo".
        cuerpo = max(-0.7, min(0.7, cuerpo * 2.2))
        salida.append((cuerpo * 0.45 + ruido[i] * 0.4) * env[i] * 0.75)
    return salida


def rotura():
    """Una maquina que revienta: chispazo, tubo que se apaga y chatarra."""
    n = int(0.55 * TASA)
    rnd = random.Random(6)
    env = _sobre(n, 0.001, 6.0)
    ruido = _ruido(n, rnd, suavizado=2)
    salida = []
    for i in range(n):
        t = i / float(TASA)
        # El tubo cayendo de tono: la pantalla que se apaga.
        tubo = math.sin(math.tau * (700.0 * math.exp(-t * 6.0) + 90.0) * t)
        salida.append((tubo * 0.35 + ruido[i] * 0.6) * env[i] * 0.7)
    # Chatarra: tres golpecitos secos despues del chispazo.
    for retardo in (0.16, 0.27, 0.41):
        inicio = int(retardo * TASA)
        largo = int(0.06 * TASA)
        e = _sobre(largo, 0.001, 18.0)
        for i in range(largo):
            if inicio + i >= n:
                break
            t = i / float(TASA)
            salida[inicio + i] += math.sin(math.tau * rnd.uniform(400, 900) * t) * e[i] * 0.22
    return salida


def recoger():
    """Dos notas hacia arriba. Es el unico sonido amable del juego."""
    n = int(0.34 * TASA)
    salida = [0.0] * n
    for k, frec in enumerate((523.0, 784.0)):
        inicio = int(k * 0.09 * TASA)
        largo = n - inicio
        env = _sobre(largo, 0.005, 7.0)
        for i in range(largo):
            t = i / float(TASA)
            salida[inicio + i] += (math.sin(math.tau * frec * t) * 0.5
                                   + math.sin(math.tau * frec * 2.0 * t) * 0.12) * env[i] * 0.30
    return salida


def zumbido(segundos=3.0):
    """El tubo del CRT. Es lo unico que se oye durante la escena de TV Buddha
    (CLAUDE.md §3.4), asi que tiene que aguantar en bucle sin cansar."""
    n = int(segundos * TASA)
    rnd = random.Random(7)
    ruido = _ruido(n, rnd, suavizado=40)
    salida = []
    for i in range(n):
        t = i / float(TASA)
        # 50 Hz de red y su armonico: el zumbido de un transformador.
        red = math.sin(math.tau * 50.0 * t) * 0.22 + math.sin(math.tau * 100.0 * t) * 0.12
        # El silbido agudo del flyback.
        agudo = math.sin(math.tau * 8000.0 * t) * 0.03
        salida.append(red + agudo + ruido[i] * 0.06)
    return _bucle(salida, cruce=0.4)


def menu_mover():
    n = int(0.07 * TASA)
    env = _sobre(n, 0.001, 14.0)
    return [math.sin(math.tau * 880.0 * (i / float(TASA))) * env[i] * 0.22 for i in range(n)]


def menu_aceptar():
    n = int(0.26 * TASA)
    salida = [0.0] * n
    for k, frec in enumerate((330.0, 494.0)):
        inicio = int(k * 0.07 * TASA)
        largo = n - inicio
        env = _sobre(largo, 0.003, 8.0)
        for i in range(largo):
            t = i / float(TASA)
            salida[inicio + i] += math.sin(math.tau * frec * t) * env[i] * 0.28
    return salida


def ambiente_interior(segundos=20.0):
    """La nave de servidores del nivel 2. Mas cerca y mas electrico que el
    exterior: la red de 50 Hz y sus armonicos, el soplido de los ventiladores y
    reles que saltan sueltos. Sin viento: aqui dentro no corre el aire."""
    n = int(segundos * TASA)
    rnd = random.Random(2006)
    salida = [0.0] * n
    for frec, amp in ((50.0, 0.10), (100.0, 0.07), (150.3, 0.03), (33.0, 0.12), (33.4, 0.10)):
        fase = rnd.uniform(0, math.tau)
        for i in range(n):
            t = i / float(TASA)
            salida[i] += math.sin(math.tau * frec * t + fase) * amp
    # Ventiladores: ruido de banda media que late muy despacio.
    soplido = _ruido(n, rnd, suavizado=12)
    for i in range(n):
        t = i / float(TASA)
        salida[i] += soplido[i] * 0.10 * (0.8 + 0.2 * math.sin(t * 0.5))
    # Reles: chasquidos secos y lejanos.
    for _ in range(14):
        inicio = rnd.randrange(0, n - 2000)
        env = _sobre(600, 0.0005, 30.0)
        for i in range(600):
            salida[inicio + i] += rnd.uniform(-1.0, 1.0) * env[i] * 0.12
    return _bucle(salida, cruce=1.2)


def arco():
    """Descarga del arco electrico: zumbido de 120 Hz cortado con chasquidos."""
    n = int(0.55 * TASA)
    rnd = random.Random(31)
    env = _sobre(n, 0.004, 3.5)
    salida = []
    for i in range(n):
        t = i / float(TASA)
        zumbido_red = math.copysign(1.0, math.sin(math.tau * 120.0 * t)) * 0.18
        chasquido = rnd.uniform(-1.0, 1.0) * (0.55 if rnd.random() < 0.08 else 0.12)
        salida.append((zumbido_red + chasquido) * env[i])
    return salida


def aviso_arco():
    """El aviso: un chisporroteo que crece. Es la telegrafia del arco, tiene que
    oirse antes de que haga dano."""
    n = int(0.5 * TASA)
    rnd = random.Random(32)
    salida = []
    for i in range(n):
        t = i / float(n)
        chispa = rnd.uniform(-1.0, 1.0) if rnd.random() < 0.02 + t * 0.12 else 0.0
        salida.append(chispa * (0.15 + t * 0.35))
    return salida


def puerta():
    """Cruzar al siguiente nivel: un golpe grave y un siseo que se apaga."""
    n = int(1.1 * TASA)
    rnd = random.Random(33)
    env = _sobre(n, 0.01, 4.0)
    siseo = _ruido(n, rnd, suavizado=30)
    salida = []
    for i in range(n):
        t = i / float(TASA)
        grave = math.sin(math.tau * (55.0 - t * 18.0) * t) * 0.45
        salida.append((grave + siseo[i] * 0.3) * env[i])
    return salida


def _marcar_bucle(ruta):
    """Escribe el .import del WAV con loop_mode = 1 (hacia adelante)."""
    contenido = (
        '[remap]\n\n'
        'importer="wav"\n'
        'type="AudioStreamWAV"\n\n'
        '[deps]\n\n'
        'source_file="res://audio/%s"\n\n'
        '[params]\n\n'
        'force/8_bit=false\n'
        'force/mono=false\n'
        'force/max_rate=false\n'
        'force/max_rate_hz=44100\n'
        'edit/trim=false\n'
        'edit/normalize=false\n'
        'edit/loop_mode=1\n'
        'edit/loop_begin=0\n'
        'edit/loop_end=-1\n'
        'compress/mode=0\n'
    ) % os.path.basename(ruta)
    # Conserva el uid que Godot ya le asigno: si se pierde, Godot inventa otro y
    # cualquier escena que apunte al sonido por uid queda apuntando a nada.
    if os.path.exists(ruta + ".import"):
        for linea in open(ruta + ".import", encoding="utf-8"):
            if linea.startswith("uid="):
                contenido = contenido.replace('type="AudioStreamWAV"\n',
                                              'type="AudioStreamWAV"\n' + linea, 1)
                break
    f = open(ruta + ".import", "w", encoding="utf-8")
    f.write(contenido)
    f.close()


if __name__ == "__main__":
    print("Ambiente (en bucle):")
    _marcar_bucle(_guardar("ambiente.wav", ambiente(), bucle=True))
    _marcar_bucle(_guardar("crt_zumbido.wav", zumbido(), bucle=True))
    _marcar_bucle(_guardar("ambiente_interior.wav", ambiente_interior(), bucle=True))
    print("Efectos:")
    _guardar("salto.wav", salto())
    _guardar("aterrizar.wav", aterrizar())
    _guardar("golpe.wav", golpe())
    _guardar("dano.wav", dano())
    _guardar("rotura.wav", rotura())
    _guardar("recoger.wav", recoger())
    _guardar("menu_mover.wav", menu_mover())
    _guardar("menu_aceptar.wav", menu_aceptar())
    _guardar("arco.wav", arco())
    _guardar("aviso_arco.wav", aviso_arco())
    _guardar("puerta.wav", puerta())
