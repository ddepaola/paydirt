shader_type canvas_item;

uniform float threshold : hint_range(0.0, 1.0) = 0.85;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    float white = max(max(color.r, color.g), color.b);
    if (white > threshold && color.a > 0.5) {
        color.a = 0.0;
    }
    COLOR = color;
}
