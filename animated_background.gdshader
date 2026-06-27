shader_type canvas_item;

uniform vec4 color_dark : source_color = vec4(0.12, 0.16, 0.28, 1.0); // Corporate dark blue
uniform vec4 color_light : source_color = vec4(0.18, 0.28, 0.45, 1.0); // Corporate light blue

uniform float speed = 0.3;
uniform float pixel_scale = 4.0;      // Pixel size
uniform float blob_scale = 10.0;      // Blob size (higher = smaller blobs)

// A mathematical noise generator (No external texture needed!)
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(
        mix(a, b, u.x),
        mix(c, d, u.x),
        u.y
    );
}

void fragment() {
    // Pixelate the UV coordinates
    vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
    vec2 pixel_uv = floor(UV * res / pixel_scale) * pixel_scale / res;

    // Scroll over time
    vec2 moving_uv = pixel_uv + vec2(TIME * speed * 0.1, TIME * speed * 0.15);

    // Blob size is now independent from pixel size
    float n = noise(moving_uv * blob_scale);
    n += noise(moving_uv * blob_scale * 2.0) * 0.5;

    // Hard cut into blobs
    float final_shape = step(0.6, n);

    // Apply colors
    COLOR = mix(color_dark, color_light, final_shape);
}