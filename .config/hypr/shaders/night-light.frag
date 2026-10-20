#version 300 es

precision mediump float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    pixColor.b *= 0.75;
    pixColor.g *= 0.95;
    fragColor = pixColor;
}
