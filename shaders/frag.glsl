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

out vec4 FragColor;

in vec3 Normal;
in vec3 FragPos;
in vec3 ViewVector;
in vec2 uv;
in vec4 shad[1];

uniform vec2 tiling;
uniform vec3 lightDirection;
uniform vec3 lightColor;
uniform vec3 viewPos;
uniform float smoothness;
uniform float ambientStrength;
uniform sampler2D normalMap;
uniform bool useNormalMap;
uniform sampler2D specularMap;
uniform bool useSpecularMap;
uniform vec4 p3d_ColorScale;
uniform sampler2D p3d_Texture0;


mat3 cotangent_frame(vec3 N, vec3 p, vec2 uv) {
    vec3 dp1 = dFdx(p);
    vec3 dp2 = dFdy(p);
    vec2 duv1 = dFdx(uv);
    vec2 duv2 = dFdy(uv);

    vec3 dp2perp = cross(dp2, N);
    vec3 dp1perp = cross(N, dp1);
    vec3 T = dp2perp * duv1.x + dp1perp * duv2.x;
    vec3 B = dp2perp * duv1.y + dp1perp * duv2.y;

    float invmax = inversesqrt( max( dot(T, T), dot(B, B)));
    return mat3(-T * invmax, B * invmax, N);
}

vec3 perturb_normal(vec3 N, vec3 V, vec2 texcoord)
{
    vec3 map = texture2D(normalMap, texcoord).xyz;
    map = map * 2. - 1.;
    map.y = -map.y;
    mat3 TBN = cotangent_frame( N, -V, texcoord );
    return normalize(TBN * map);
}


void main() {
    vec2 tuv = uv * tiling;

    // ambient
    vec3 ambient = ambientStrength * lightColor;

    // diffuse
    vec3 norm = normalize(Normal);
    if (useNormalMap) norm = perturb_normal(norm, ViewVector, tuv);

    //vec3 lightDir = normalize(lightDirection - FragPos);
    vec3 lightDir = normalize(-lightDirection);
    float diffuseStrength = max(dot(norm, lightDir), 0.0);
    vec3 diffuse = diffuseStrength * lightColor;

    // specular
    vec3 specMap = vec3(0.5);
    if (useSpecularMap) specMap = texture2D(specularMap, tuv).xyz;

    vec3 viewDir = normalize(viewPos - FragPos);
    vec3 reflectDir = reflect(-lightDir, norm);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), smoothness);
    vec3 specular = spec * lightColor * specMap;

    //shadows
    float shadowValue = textureProj(p3d_LightSource[0].shadowMap, shad[0]);

    FragColor = vec4(ambient + (diffuse + specular) * shadowValue, 1.0) * texture2D(p3d_Texture0, tuv) * p3d_ColorScale;
}
