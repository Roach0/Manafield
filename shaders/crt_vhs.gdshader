shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform float scanline_intensity : hint_range(0.0, 1.0) = 1.0;
uniform float scanline_count : hint_range(100.0, 1200.0) = 400.0;
uniform float brightness : hint_range(0.5, 2.0) = 1.4;
uniform float glow_amount : hint_range(0.0, 1.0) = 0.2;
uniform float glow_size : hint_range(0.0, 0.005) = 0.0012;
uniform bool enabled = true;

void fragment() {
    if (!enabled) {
        COLOR = texture(screen_texture, SCREEN_UV);
    } else {
        vec2 uv = SCREEN_UV;

        // Sharp, untouched image — no blur, no aberration
        vec3 col = texture(screen_texture, uv).rgb;

        // Very soft glow: blurred copy, bright areas only, added gently on top
        vec3 glow = vec3(0.0);
        glow += texture(screen_texture, uv + vec2(-glow_size, -glow_size)).rgb;
        glow += texture(screen_texture, uv + vec2( glow_size, -glow_size)).rgb;
        glow += texture(screen_texture, uv + vec2(-glow_size,  glow_size)).rgb;
        glow += texture(screen_texture, uv + vec2( glow_size,  glow_size)).rgb;
        glow *= 0.25;
        glow = max(glow - 0.6, vec3(0.0)) * 2.0;  // only the brightest part blooms
        col += glow * glow_amount;

        // Slight scanlines
        float line = 0.5 + 0.5 * sin(uv.y * scanline_count * 6.28318);
        col *= mix(1.0 - scanline_intensity, 1.0, line);

        // Brightness compensation
        col *= brightness;

        COLOR = vec4(col, 1.0);
    }
}