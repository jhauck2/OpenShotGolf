shader_type spatial;
render_mode cull_disabled;
uniform sampler2D uv_offset_texture : hint_default_black;
uniform vec2 uv_offset_scale = vec2(-0.2,-0.1);
uniform vec2 time_scale = vec2(0.3, 0.0);
uniform float face_distortion = 0.5;

uniform vec4 flag_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);


void vertex(){
	vec2 base_uv_offset = UV * uv_offset_scale;
	base_uv_offset += TIME * time_scale;
	
	float noise = texture(uv_offset_texture, base_uv_offset).r;
	float texture_based_offset = noise * 2.0 - 1.0;
	texture_based_offset *= UV.x;
	VERTEX.y += noise;
	VERTEX.z += texture_based_offset * face_distortion;
	VERTEX.x += texture_based_offset * -face_distortion;
}

void fragment(){
    ALBEDO = flag_color.rgb;
}