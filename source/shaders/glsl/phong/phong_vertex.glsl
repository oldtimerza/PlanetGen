#version 410

layout (location = 0) in vec3 vertex_position_in;
layout (location = 1) in vec3 vertex_normal;

out vec3 position_v;
out vec3 normal_v;

out vec3 position_raw_v;
out vec3 normal_raw_v;

uniform mat4 matrix_mvp;
uniform mat4 matrix_m;

uniform float height_noise_strength;

uniform float normal_sample_distance;

#define PI 3.1415926538

//	Simplex 3D Noise 
//	by Ian McEwan, Ashima Arts
//
vec4 permute(vec4 x){return mod(((x*34.0)+1.0)*x, 289.0);}
vec4 taylorInvSqrt(vec4 r){return 1.79284291400159 - 0.85373472095314 * r;}

float snoise(vec3 v){ 
  const vec2  C = vec2(1.0/6.0, 1.0/3.0) ;
  const vec4  D = vec4(0.0, 0.5, 1.0, 2.0);

// First corner
  vec3 i  = floor(v + dot(v, C.yyy) );
  vec3 x0 =   v - i + dot(i, C.xxx) ;

// Other corners
  vec3 g = step(x0.yzx, x0.xyz);
  vec3 l = 1.0 - g;
  vec3 i1 = min( g.xyz, l.zxy );
  vec3 i2 = max( g.xyz, l.zxy );

  //  x0 = x0 - 0. + 0.0 * C 
  vec3 x1 = x0 - i1 + 1.0 * C.xxx;
  vec3 x2 = x0 - i2 + 2.0 * C.xxx;
  vec3 x3 = x0 - 1. + 3.0 * C.xxx;

// Permutations
  i = mod(i, 289.0 ); 
  vec4 p = permute( permute( permute( 
             i.z + vec4(0.0, i1.z, i2.z, 1.0 ))
           + i.y + vec4(0.0, i1.y, i2.y, 1.0 )) 
           + i.x + vec4(0.0, i1.x, i2.x, 1.0 ));

// Gradients
// ( N*N points uniformly over a square, mapped onto an octahedron.)
  float n_ = 1.0/7.0; // N=7
  vec3  ns = n_ * D.wyz - D.xzx;

  vec4 j = p - 49.0 * floor(p * ns.z *ns.z);  //  mod(p,N*N)

  vec4 x_ = floor(j * ns.z);
  vec4 y_ = floor(j - 7.0 * x_ );    // mod(j,N)

  vec4 x = x_ *ns.x + ns.yyyy;
  vec4 y = y_ *ns.x + ns.yyyy;
  vec4 h = 1.0 - abs(x) - abs(y);

  vec4 b0 = vec4( x.xy, y.xy );
  vec4 b1 = vec4( x.zw, y.zw );

  vec4 s0 = floor(b0)*2.0 + 1.0;
  vec4 s1 = floor(b1)*2.0 + 1.0;
  vec4 sh = -step(h, vec4(0.0));

  vec4 a0 = b0.xzyw + s0.xzyw*sh.xxyy ;
  vec4 a1 = b1.xzyw + s1.xzyw*sh.zzww ;

  vec3 p0 = vec3(a0.xy,h.x);
  vec3 p1 = vec3(a0.zw,h.y);
  vec3 p2 = vec3(a1.xy,h.z);
  vec3 p3 = vec3(a1.zw,h.w);

//Normalise gradients
  vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
  p0 *= norm.x;
  p1 *= norm.y;
  p2 *= norm.z;
  p3 *= norm.w;

// Mix final noise value
  vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
  m = m * m;
  return 42.0 * dot( m*m, vec4( dot(p0,x0), dot(p1,x1), 
                                dot(p2,x2), dot(p3,x3) ) );
}

vec3 point_height(vec3 unit_sphere_vector) {
    vec3 position = normalize(unit_sphere_vector);
    position = position + (position * height_noise_strength * snoise(unit_sphere_vector));
    return position;
}

float atan2(in float y, in float x)
{
    bool s = (abs(x) > abs(y));
    return mix(PI/2.0 - atan(x,y), atan(y,x), s);
}

void main()
{
    float radius = 1.0f;
    float inclination = atan2(sqrt((vertex_position_in.x * vertex_position_in.x) + (vertex_position_in.z * vertex_position_in.z)), vertex_position_in.y);
    float azimuth = atan2(vertex_position_in.z, vertex_position_in.x);

    float sample_incl_top = max(0.0f, inclination - normal_sample_distance);
    float sample_incl_bottom = min(PI, inclination + normal_sample_distance);

    float sample_azi_left = azimuth - normal_sample_distance;
    float sample_azi_right = azimuth + normal_sample_distance;

    vec3 sample_top = point_height(vec3(radius * cos(azimuth) * sin(sample_incl_top), radius * cos(sample_incl_top), radius * sin(azimuth) * sin(sample_incl_top)));
    vec3 sample_bottom = point_height(vec3(radius * cos(azimuth) * sin(sample_incl_bottom), radius * cos(sample_incl_bottom), radius * sin(azimuth) * sin(sample_incl_bottom)));
    vec3 sample_left = point_height(vec3(radius * cos(sample_azi_left) * sin(inclination), radius * cos(inclination), radius * sin(sample_azi_left) * sin(inclination)));
    vec3 sample_right = point_height(vec3(radius * cos(sample_azi_right) * sin(inclination), radius * cos(inclination), radius * sin(sample_azi_right) * sin(inclination)));

    vec3 normal_sample_top_left = cross(sample_left - vertex_position_in, sample_top - vertex_position_in);
    vec3 normal_sample_top_right = cross(sample_top - vertex_position_in, sample_right - vertex_position_in);
    vec3 normal_sample_bottom_left = cross(sample_bottom - vertex_position_in, sample_left - vertex_position_in);
    vec3 normal_sample_bottom_right = cross(sample_right - vertex_position_in, sample_bottom - vertex_position_in);

    vec3 normal_average = (normal_sample_top_left + normal_sample_top_right + normal_sample_bottom_left + normal_sample_bottom_right)/4.0f;

    vec3 vertex_position = point_height(vertex_position_in);

    position_raw_v = vertex_position;
    normal_raw_v = normalize(normal_average);

    position_v = (matrix_m * vec4(vertex_position, 1.0f)).xyz;
    normal_v = normalize(matrix_m * vec4(normal_raw_v, 0.0f)).xyz;
    gl_Position = matrix_mvp * vec4(vertex_position, 1.0f);
}