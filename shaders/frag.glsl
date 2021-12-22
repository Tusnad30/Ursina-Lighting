#version 140

// advanced shadow options
const bool smoothShadows = true;
const float blurStrength = 0.12;

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

out vec4 fragColor;

in vec3 normal;
in vec3 fragPos;
in vec3 viewVector;
in vec2 uv;
in vec4 shad[1];

uniform vec2 tiling;
uniform vec2 lightsArrayLength;
uniform vec4[502] lightsArray;
uniform vec4[450] spotArray;
uniform float smoothness;
uniform float ambientStrength;
uniform sampler2D normalMap;
uniform sampler2D specularMap;
uniform bool water;
uniform float time;
uniform samplerCube cubemap;
uniform float cubemapIntensity;

uniform vec4 p3d_ColorScale;
uniform sampler2D p3d_Texture0;
uniform mat4 p3d_ViewMatrixInverse;


mat3 calTBN(vec3 N, vec3 p, vec2 uv) {
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

vec3 calNorm(vec3 N, vec3 V, vec2 texcoord)
{
    vec3 map = texture2D(normalMap, texcoord).xyz;
    map = map * 2. - 1.;
    map.y = -map.y;
    mat3 TBN = calTBN( N, -V, texcoord );
    return normalize(TBN * map);
}

vec3 calWater(vec3 N, vec3 V, vec2 texcoord)
{
    vec3 h1 = texture2D(normalMap, texcoord + time * 0.02).rgb;
    h1 = h1 * 2. - 1.;
    h1.y = -h1.y;

    vec3 h2 = texture2D(normalMap, texcoord * 0.75 + vec2(time * -0.01, 0)).rgb;
    h2 = h2 * 2. - 1.;
    h2.y = -h2.y;

    vec3 h3 = texture2D(normalMap, texcoord * 0.5 + vec2(0, time * -0.015)).rgb;
    h3 = h3 * 2. - 1.;
    h3.y = -h3.y;

    mat3 TBN = calTBN(N, -V, texcoord);
    return normalize(TBN * (h1 + h2 + h3));
}

float textureProjSoft(sampler2DShadow tex, vec4 uv, float bias, float blur)
{
    float result = textureProj(tex, uv, bias);
    result += textureProj(tex, vec4(uv.xy + vec2( -0.326212, -0.405805)*blur, uv.z-bias, uv.w));
    result += textureProj(tex, vec4(uv.xy + vec2(-0.840144, -0.073580)*blur, uv.z-bias, uv.w));
    result += textureProj(tex, vec4(uv.xy + vec2(-0.695914, 0.457137)*blur, uv.z-bias, uv.w));
    result += textureProj(tex, vec4(uv.xy + vec2(-0.203345, 0.620716)*blur, uv.z-bias, uv.w));
    result += textureProj(tex, vec4(uv.xy + vec2(0.962340, -0.194983)*blur, uv.z-bias, uv.w));
    result += textureProj(tex, vec4(uv.xy + vec2(0.473434, -0.480026)*blur, uv.z-bias, uv.w));
    result += textureProj(tex, vec4(uv.xy + vec2(0.519456, 0.767022)*blur, uv.z-bias, uv.w));
    result += textureProj(tex, vec4(uv.xy + vec2(0.185461, -0.893124)*blur, uv.z-bias, uv.w));
    result += textureProj(tex, vec4(uv.xy + vec2(0.507431, 0.064425)*blur, uv.z-bias, uv.w));
    result += textureProj(tex, vec4(uv.xy + vec2(0.896420, 0.412458)*blur, uv.z-bias, uv.w));
    result += textureProj(tex, vec4(uv.xy + vec2(-0.321940, -0.932615)*blur, uv.z-bias, uv.w));
    result += textureProj(tex, vec4(uv.xy + vec2(-0.791559, -0.597705)*blur, uv.z-bias, uv.w));
    return result / 13.0;
}    


void main() {
    // vars
    vec2 tuv = uv * tiling;
    vec3 specular = vec3(0);
    vec3 diffuse = vec3(0);
    vec3 viewPos = p3d_ViewMatrixInverse[3].xyz;

    // ambient
    float ambient = ambientStrength;

    // maps
    vec3 norm = normalize(normal);
    if (water == false) norm = calNorm(norm, viewVector, tuv);
    if (water == true) norm = calWater(norm, viewVector, tuv);

    vec3 specMap = vec3(0.5);
    specMap = texture2D(specularMap, tuv).xyz;

    // loop though each point light
    for (int i = 0; i < lightsArrayLength.x / 2; i++) {
        // current light data
        vec3 lightPosition = lightsArray[i * 2 + 1].xyz;
        vec3 lightColor = lightsArray[i * 2].xyz;
        float range = lightsArray[i * 2].w;
        float intensity = lightsArray[i * 2 + 1].w;

        // diffuse
        vec3 lightDir = normalize(lightPosition - fragPos);
        if (i == 0) lightDir = normalize(-lightPosition);

        float diffuseStrength = max(dot(norm, lightDir), 0.0);
        vec3 ldiffuse = diffuseStrength * lightColor;

        // specular
        vec3 viewDir = normalize(viewPos - fragPos);
        vec3 reflectDir = reflect(-lightDir, norm);
        float spec = pow(max(dot(viewDir, reflectDir), 0.0), smoothness);
        vec3 lspecular = spec * lightColor * specMap;

        //shadows
        float shadowValue = 0.0;
        if (smoothShadows)
            shadowValue = textureProjSoft(p3d_LightSource[0].shadowMap, shad[0], 0.0, blurStrength * 0.01);
        if (smoothShadows == false)
            shadowValue = textureProj(p3d_LightSource[0].shadowMap, shad[0]);

        // attenuation
        float distance = length(lightPosition - fragPos);
        float attenuation = (1.0 / (1.0 + distance * distance * (1.0 / range))) * intensity;

        if (!(i == 0)) {
            ldiffuse *= attenuation;
            lspecular *= attenuation;
        }
        // apply shadows
        if (i == 0) {
            ldiffuse *= intensity;
            lspecular *= intensity;
            ldiffuse *= shadowValue;
            lspecular *= shadowValue;
        }

        diffuse += ldiffuse;
        specular += lspecular;
    }

    // loop through each spotlight
    for (int i = 0; i < lightsArrayLength.y / 3; i++) {
        // current light data
        vec3 lightPosition = spotArray[i * 3 + 1].xyz;
        vec3 lightColor = spotArray[i * 3].xyz;
        float range = spotArray[i * 3].w;
        float intensity = spotArray[i * 3 + 1].w;
        vec3 lightDirection = spotArray[i * 3 + 2].xyz;
        float lightCutOff = spotArray[i * 3 + 2].w;


        // check if lighting inside spotlight cone
        vec3 lightDir = normalize(lightPosition - fragPos);
        float theta = dot(lightDir, normalize(-lightDirection));

        if (theta > lightCutOff) {
            // diffuse
            float diffuseStrength = max(dot(norm, lightDir), 0.0);
            vec3 ldiffuse = diffuseStrength * lightColor;

            // specular
            vec3 viewDir = normalize(viewPos - fragPos);
            vec3 reflectDir = reflect(-lightDir, norm);
            float spec = pow(max(dot(viewDir, reflectDir), 0.0), smoothness);
            vec3 lspecular = spec * lightColor * specMap;

            // attenuation
            float distance = length(lightPosition - fragPos);
            float attenuation = (1.0 / (1.0 + distance * distance * (1.0 / range))) * intensity * min(1.0, (theta - lightCutOff) * 100.0);

            ldiffuse *= attenuation;
            lspecular *= attenuation;

            diffuse += ldiffuse;
            specular += lspecular;
        }
    }

    //cubemap
    vec3 I = normalize(fragPos - viewPos);
    vec3 R = reflect(I, norm);
    vec3 cubemapR = texture(cubemap, R).rgb * (cubemapIntensity * specMap.x);

    vec3 result = (ambient + diffuse) * (1.0 - cubemapIntensity * specMap.x) + cubemapR + specular;

    fragColor = vec4(result, 1.0) * texture2D(p3d_Texture0, tuv) * p3d_ColorScale;
}
