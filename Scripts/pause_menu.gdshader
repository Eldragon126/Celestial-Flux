shader_type canvas_item;

uniform int lineas = 255;             
uniform float velocidad = 2.0;      
uniform float ondulacion = 0.19;     
uniform float frecuencia = 5.0;   
uniform vec4 color_a : source_color = vec4(0.1, 0.5, 0.8, 0.2);
uniform vec4 color_b : source_color = vec4(0.1, 0.1, 0.2, 0.2);

// Add this uniform to receive unscaled time from GDScript
uniform float real_time; 

void fragment() {
    vec2 uv = UV;
    
    float id_linea = floor(uv.y * float(lineas));
    float sentido = (mod(id_linea, 2.0) == 0.0) ? 1.0 : -1.0;
    
    // Changed TIME to real_time here:
    float desfase_gusano = sin(uv.y * frecuencia + real_time * velocidad) * ondulacion;
    
    // And changed TIME to real_time here:
    float movimiento_h = (real_time * velocidad * 0.2) * sentido;
    uv.x += movimiento_h + (desfase_gusano * sentido);
    
    float patron = step(0.5, fract(uv.x * 2.0));
    
    vec3 color_final = mix(color_a.rgb, color_b.rgb, patron);
    float alpha_final = mix(color_a.a, color_b.a, patron);
    
    float borde = sin(fract(uv.y * float(lineas)) * PI);
    
    alpha_final *= smoothstep(0.0, 0.1, borde); 
    
    COLOR = vec4(color_final, alpha_final * COLOR.a);
}