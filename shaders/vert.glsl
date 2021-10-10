#version 140

uniform struct {
    vec4 position;
    vec3 color;
    vec3 attenuation;
    vec3 spotDirection;
    float spotCosCutoff;
    float spotExponent;
    sampler2DShadow shadowMap;
    mat4 shadowViewMatrix;
} p3d_LightSource[1];

in vec4 p3d_Vertex;
in vec3 p3d_Normal;
in vec2 p3d_MultiTexCoord0;

out vec3 fragPos;
out vec3 normal;
out vec3 viewVector;
out vec2 uv;
out vec4 shad[1];

uniform mat4 p3d_ModelMatrix;
uniform mat4 p3d_ViewMatrix;
uniform mat4 p3d_ProjectionMatrix;
uniform mat4 p3d_ModelViewMatrix;
uniform mat4 p3d_ViewMatrixInverse;

void main() {
    fragPos = vec3(p3d_ModelMatrix * vec4(p3d_Vertex.xyz, 1.0));
    normal = inverse(transpose(mat3(p3d_ModelMatrix))) * p3d_Normal;
    uv = p3d_MultiTexCoord0;
    viewVector = p3d_ViewMatrixInverse[3].xyz - p3d_Vertex.xyz;
    
    shad[0] = p3d_LightSource[0].shadowViewMatrix * vec4(vec3(p3d_ModelViewMatrix * p3d_Vertex), 1);

    gl_Position = p3d_ProjectionMatrix * p3d_ViewMatrix * vec4(fragPos, 1.0);
}