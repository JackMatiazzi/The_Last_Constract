shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

// a imagem da camera do outro portal, lida pela posicao na tela: o veu vira uma janela
uniform sampler2D view : source_color, filter_linear;
uniform vec4 tint : source_color = vec4(0.35, 0.15, 0.75, 1.0);
instance uniform bool linked = false;

void fragment() {
	float from_center = distance(UV, vec2(0.5)) * 2.0;
	if (from_center > 1.0) {
		discard;
	}
	float rim = smoothstep(0.7, 1.0, from_center);
	if (linked) {
		ALBEDO = mix(texture(view, SCREEN_UV).rgb, tint.rgb, rim * 0.8);
		ALPHA = 1.0;
	} else {
		ALBEDO = tint.rgb;
		ALPHA = 0.45;
	}
}
