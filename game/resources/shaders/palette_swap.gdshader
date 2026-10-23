shader_type canvas_item;
// Swaps exact palette colors: each pixel matching from_colors[i] becomes to_colors[i].
// Both lists hold Endesga 32 colors only, so the result stays on the palette. Used for
// placeholder wizard portraits (Ember is the Frost sprite in warm colors) until A1 art.

const int MAX_SWAPS = 8;

uniform int swap_count : hint_range(0, 8) = 0;
uniform vec4 from_colors[MAX_SWAPS];
uniform vec4 to_colors[MAX_SWAPS];

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	for (int i = 0; i < MAX_SWAPS; i++) {
		if (i < swap_count && distance(color.rgb, from_colors[i].rgb) < 0.01) {
			color.rgb = to_colors[i].rgb;
		}
	}
	COLOR = color;
}
