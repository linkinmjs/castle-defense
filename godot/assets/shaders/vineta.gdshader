// Vineta de la batalla: bordes apenas oscuros siempre, y un pulso rojo pegado
// al borde cuando el healer recibe un golpe. Lo maneja scripts/ui/vineta.gd.
//
// No lee la pantalla: pinta un degrade encima y listo. Asi cuesta lo mismo en
// web (GL Compatibility) que en escritorio, y no depende del color del
// ColorRect, que queda transparente.
shader_type canvas_item;

// Cuanto se oscurecen los bordes: 0 nada, 1 las esquinas en negro.
uniform float intensidad : hint_range(0.0, 1.0) = 0.35;
// El pulso de dano, de 0 a 1. Vineta lo sube con cada golpe y lo apaga sola.
uniform float dano : hint_range(0.0, 1.0) = 0.0;
// Color del pulso. Su alfa es cuanto tapa el borde mismo con el pulso entero:
// el golpe se tiene que ver, pero no puede esconder lo que viene.
uniform vec4 color_dano : source_color = vec4(0.85, 0.08, 0.06, 0.5);
// Hasta donde entra el rojo con el pulso entero, en altos de pantalla desde el
// borde (0.15 son ~110 px a 720p). Al apagarse se va retirando hacia el borde.
uniform float ancho_dano : hint_range(0.0, 0.5) = 0.15;

// Redondeo de las esquinas del rojo, en altos de pantalla. Apenas mas que el
// ancho: con mas, las esquinas se llenan de rojo mucho mas adentro que los
// bordes.
const float RADIO = 0.2;

// Cuanto adentro de la pantalla esta el punto, en altos de pantalla: 0 en el
// borde y 0.5 en el centro. Se mide igual desde los cuatro lados, asi la franja
// roja tiene el mismo ancho arriba que a los costados; las esquinas van
// redondeadas, y cerca de ellas da negativo (mas borde que el borde).
float desde_el_borde(vec2 uv, float aspecto) {
	vec2 medio = vec2(0.5 * aspecto, 0.5);
	vec2 q = abs((uv - 0.5) * vec2(aspecto, 1.0)) - medio + RADIO;
	return RADIO - length(max(q, 0.0)) - min(max(q.x, q.y), 0.0);
}

void fragment() {
	// La sombra sigue la forma de la pantalla: 0 en el centro, 1 en el medio de
	// cada borde, 1.41 en las esquinas. En 16:9 es un ovalo ancho, que oscurece
	// sobre todo las esquinas.
	float d = length((UV - 0.5) * 2.0);
	float oscuro = smoothstep(0.55, 1.45, d) * intensidad;

	float pulso = clamp(dano, 0.0, 1.0);
	float aspecto = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float ancho = max(ancho_dano * (0.5 + 0.5 * pulso), 0.001);
	float rojo = (1.0 - smoothstep(0.0, ancho, desde_el_borde(UV, aspecto)))
			* pulso * color_dano.a;

	// El rojo va encima de la sombra. Las dos capas en una sola: el alfa que
	// dejan entre las dos, y el color que hace falta para que se vea lo mismo.
	float alfa = 1.0 - (1.0 - oscuro) * (1.0 - rojo);
	vec3 color = alfa > 0.0001 ? color_dano.rgb * (rojo / alfa) : vec3(0.0);
	COLOR = vec4(color, alfa);
}
