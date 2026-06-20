shader_type canvas_item;

// Output colors — source_color so Prefix.color values read correctly
uniform vec4 color_1 : source_color = vec4(1.0);
uniform vec4 color_2 : source_color = vec4(1.0);

// Key colors (raw markers in the source art) — plain vec4 so they compare
// in the same space as the texture sample. Defaults match your sprite.
uniform vec4 key_1 = vec4(0.38824, 0.60784, 1.0, 1.0); // blue  (99,155,255) -> color_1
uniform vec4 key_2 = vec4(1.0, 1.0, 1.0, 1.0);          // white (255,255,255) -> color_2

void fragment() {
    vec4 src = texture(TEXTURE, UV);
    vec3 outc = src.rgb;
    if (src.a > 0.001) {
        float d1 = distance(src.rgb, key_1.rgb);
        float d2 = distance(src.rgb, key_2.rgb);
        outc = (d2 < d1) ? color_2.rgb : color_1.rgb;
    }
    COLOR = vec4(outc, src.a);
}