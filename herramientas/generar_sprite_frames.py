# -*- coding: utf-8 -*-
"""Escribe los .tres de SpriteFrames a partir de las hojas generadas.

Lee las listas ORDEN de generar_jugador.py y generar_props.py, asi que las hojas
y los recursos NO se pueden desincronizar: si se anade una animacion alli, aqui
sale sola.

Uso:  python herramientas/generar_sprite_frames.py

Genera un SpriteFrames con una AtlasTexture por celda. Van como recursos externos
y no incrustados en las escenas para que se puedan abrir y retocar en el editor
sin tocar el .tscn (art/PLACEHOLDERS.md).
"""
import io
import os

import generar_jugador as gj
import generar_props as gp

AQUI = os.path.dirname(os.path.abspath(__file__))
JUEGO = os.path.join(AQUI, "..", "juego")

# (orden, celda, hoja en res://, .tres de destino)
RECURSOS = [
    (gj.ORDEN, gj.CELDA, gj.CELDA, "res://art/placeholder/jugador.png",
     os.path.join(JUEGO, "actors", "player", "jugador_frames.tres")),
    (gp.ENEMIGO_ORDEN, gp.ENEMIGO_W, gp.ENEMIGO_H, "res://art/placeholder/enemigo.png",
     os.path.join(JUEGO, "actors", "enemies", "enemigo_frames.tres")),
]


def construir(orden, ancho, alto, RUTA_HOJA):
    filas = [(nombre, fps, bucle, fn()) for nombre, fps, bucle, fn in orden]

    atlas = []
    animaciones = []
    for y, (nombre, fps, bucle, cuadros) in enumerate(filas):
        refs = []
        for x in range(len(cuadros)):
            ident = "%s_%d" % (nombre, x)
            atlas.append((ident, x * ancho, y * alto))
            refs.append('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % ident)
        animaciones.append(
            '{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}'
            % (", ".join(refs), "true" if bucle else "false", nombre, fps))

    partes = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]\n'
              % (len(atlas) + 2)]
    partes.append('[ext_resource type="Texture2D" path="%s" id="1_hoja"]\n'
                  % RUTA_HOJA)
    for ident, x, y in atlas:
        partes.append('[sub_resource type="AtlasTexture" id="%s"]\n'
                      'atlas = ExtResource("1_hoja")\n'
                      'region = Rect2(%d, %d, %d, %d)\n'
                      % (ident, x, y, ancho, alto))
    partes.append("[resource]\nanimations = [%s]\n" % ", ".join(animaciones))
    return "\n".join(partes), filas


if __name__ == "__main__":
    for orden, ancho, alto, hoja, destino in RECURSOS:
        texto, filas = construir(orden, ancho, alto, hoja)
        io.open(destino, "w", encoding="utf-8", newline="\n").write(texto)
        total = sum(len(f[3]) for f in filas)
        print("%-22s %d animaciones, %d frames"
              % (os.path.basename(destino), len(filas), total))
