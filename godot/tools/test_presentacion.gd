extends PruebaBase
## Presentacion: en headless los efectos no hacen nada, que es lo que mantiene
## deterministas al resto de las pruebas. Y el hit-stop por dentro, lo que corre
## cuando hay pantalla: frena, no acumula y siempre devuelve la escala a 1.

## Ticks que se esperan con el hit-stop cortado, para ver que no aparece tarde.
const TICKS_DE_ESPERA := 10

var _reloj: SceneTreeTimer


func fase(numero: int) -> void:
	match numero:
		0:
			print("--- sin pantalla no hay efectos ---")
			_ok("activa() es false en headless", not Presentacion.activa())
			Presentacion.hit_stop(self)
			_ok("hit_stop() deja la escala del tiempo en 1", Engine.time_scale == 1.0)
			Presentacion.hit_stop(self, 0.5)
			_ok("tambien con una duracion larga", Engine.time_scale == 1.0)
			_ok("y no deja nada en curso", not Presentacion._hit_stop_en_curso)
			siguiente()
		1:
			if _ticks < TICKS_DE_ESPERA:
				return
			_ok("unos ticks despues sigue en 1", Engine.time_scale == 1.0)

			print("--- el hit-stop por dentro (lo que corre con pantalla) ---")
			Presentacion._frenar(self, 0.05)
			_igual("frena la escala a 0.05", Engine.time_scale, 0.05, 0.0001)
			_ok("queda en curso", Presentacion._hit_stop_en_curso)
			_reloj = Presentacion._reloj_hit_stop
			_ok("con su reloj guardado", _reloj != null)
			Presentacion._frenar(self, 0.03)
			_ok("un segundo golpe no abre otro reloj", Presentacion._reloj_hit_stop == _reloj)
			_igual("ni suma su duracion", _reloj.time_left, 0.05, 0.001)
			Presentacion._frenar(self, 0.2)
			_igual("uno mas largo lo estira hasta lo suyo, no mas", _reloj.time_left, 0.2, 0.001)
			_igual("la escala sigue en 0.05", Engine.time_scale, 0.05, 0.0001)
			siguiente()
		2:
			# Espera al reloj. Si no termina nunca, PruebaBase corta por limite.
			if Presentacion._hit_stop_en_curso:
				return
			# 0.2 s de reloj real son unos 12 ticks: muchos mas seria que el reloj
			# corrio con la escala puesta (0.2 / 0.05 = 4 s, unos 240 ticks).
			_ok("termina a tiempo, sin frenarse a si mismo (%d ticks)" % _ticks, _ticks < 60)
			_igual("al terminar la escala vuelve a 1", Engine.time_scale, 1.0, 0.000001)
			_ok("y no queda reloj guardado", Presentacion._reloj_hit_stop == null)
			siguiente()
		3:
			if _ticks < TICKS_DE_ESPERA:
				return
			_ok("sigue en 1 unos ticks despues", Engine.time_scale == 1.0)

			print("--- se puede volver a frenar despues ---")
			Presentacion._frenar(self, 0.05)
			_ok("otro golpe abre un reloj nuevo",
				Presentacion._hit_stop_en_curso and Presentacion._reloj_hit_stop != _reloj)
			siguiente()
		4:
			if Presentacion._hit_stop_en_curso:
				return
			_igual("y tambien lo suelta", Engine.time_scale, 1.0, 0.000001)
			terminar()
