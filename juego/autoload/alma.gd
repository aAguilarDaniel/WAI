# Eje Humanidad <-> Máquina. Autoload global "Alma".
# Guarda el valor del eje y avisa por señal cuando se cruza un umbral. No toca UI
# ni escenas: son ellas las que se suscriben (CLAUDE.md §3.1).
extends Node

## Las tres rutas posibles. El jugador nunca ve este valor como número ni barra.
enum Ruta { MAQUINA, AMBIGUO, HUMANO }

## Umbrales de CLAUDE.md §3.1. Entre ellos, la ruta es AMBIGUO.
const UMBRAL_HUMANO: float = 0.4
const UMBRAL_MAQUINA: float = -0.4

## Ninguna acción individual puede mover el eje más que esto (CLAUDE.md §3.1).
const CAMBIO_MAXIMO: float = 0.03

## Empujón humano por terminar una zona sin matar a nadie.
const PESO_ZONA_PACIFICA: float = 0.015

## Palanca de calibración. Con los pesos del documento (±0.01 a ±0.03) hacen falta
## entre 13 y 40 muertes para cruzar un umbral. En una demo de 10-15 minutos eso
## puede no pasar nunca, y entonces las tres tipografías del diario no se ven.
## Subir esto hace visible el sistema sin retocar cada .tres.
##
## CALIBRADO a 2.5 con el nivel 1 ya cerrado (9 enemigos, 3 armas recogibles):
##   - matar a los 9 con el tubo de metal (+0.02) da +0.45 -> cruza a HUMANO
##   - matarlos con plasma (-0.02) o radiación (-0.03) da entre -0.45 y -0.67
##     -> cruza a MÁQUINA
##   - pasar sin matar deja el eje en 0 -> AMBIGUO
## Es decir: las tres rutas y las tres tipografías del diario son alcanzables
## dentro de una sola partida del nivel 1, que es lo que hacía falta para poder
## enseñar el mecanismo central del juego sin las herramientas de captura.
const ESCALA: float = 2.5

## La emite Alma al pasar de una ruta a otra. Se suscriben diario, shader y audio.
signal umbral_cruzado(ruta_anterior: Ruta, ruta_nueva: Ruta)

## Solo para el indicador de depuración de F3. La UI del juego NO debe usarla.
signal valor_cambiado(valor_nuevo: float)

## Valor del eje en [-1.0, 1.0]. -1.0 máquina total, +1.0 humano total.
var _valor: float = 0.0
var _ruta: Ruta = Ruta.AMBIGUO

func valor() -> float:
	return _valor

func ruta_actual() -> Ruta:
	return _ruta

## Aplica el peso de una acción. Lo llama ComponenteArma al matar, y nadie más.
func registrar(peso: float) -> void:
	if is_zero_approx(peso):
		return
	var aplicado: float = clampf(peso * ESCALA, -CAMBIO_MAXIMO, CAMBIO_MAXIMO)
	_fijar(_valor + aplicado)

## Terminar una zona sin matar a nadie empuja hacia lo humano (CLAUDE.md §3.1).
func registrar_zona_pacifica() -> void:
	_fijar(_valor + PESO_ZONA_PACIFICA * ESCALA)

## Restaura el eje al cargar una partida. No emite umbral_cruzado: no hubo decisión.
func cargar(valor_guardado: float) -> void:
	_valor = clampf(valor_guardado, -1.0, 1.0)
	_ruta = _calcular_ruta(_valor)
	valor_cambiado.emit(_valor)

## SOLO para las herramientas de captura del trailer (tools/captura.tscn). Pone el
## eje en un valor exacto y emite umbral_cruzado, para poder filmar un plano de la
## ruta maquina o humana sin jugar las 14 muertes que hacen falta hoy.
## El juego NUNCA llama a esto: el eje solo se mueve por registrar() y
## registrar_zona_pacifica(). Si aparece una llamada fuera de tools/, es un error.
func forzar(valor: float) -> void:
	_fijar(valor)

func nombre_ruta(ruta: Ruta) -> String:
	match ruta:
		Ruta.MAQUINA:
			return "máquina"
		Ruta.HUMANO:
			return "humano"
		_:
			return "ambiguo"

func _fijar(valor_nuevo: float) -> void:
	var anterior: Ruta = _ruta
	_valor = clampf(valor_nuevo, -1.0, 1.0)
	valor_cambiado.emit(_valor)
	_ruta = _calcular_ruta(_valor)
	if _ruta != anterior:
		umbral_cruzado.emit(anterior, _ruta)

func _calcular_ruta(valor_eje: float) -> Ruta:
	if valor_eje >= UMBRAL_HUMANO:
		return Ruta.HUMANO
	if valor_eje <= UMBRAL_MAQUINA:
		return Ruta.MAQUINA
	return Ruta.AMBIGUO
