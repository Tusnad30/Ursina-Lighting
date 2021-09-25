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

out vec4 fragColor;

in vec3 normal;
in vec3 fragPos;
in vec3 viewVector;
in vec2 uv;
in vec4 shad[1];

uniform vec2 tiling;
uniform vec2 lightsArrayLength;
uniform vec4[552] lightsArray;
uniform vec4[450] spotArray;
uniform vec3 viewPos;
uniform float smoothness;
uniform float ambientStrength;
uniform sampler2D normalMap;
uniform sampler2D specularMap;

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
    // vars
    vec2 tuv = uv * tiling;
    vec3 specular = vec3(0);
    vec3 diffuse = vec3(0);

    // ambient
    float ambient = ambientStrength;

    // maps
    vec3 norm = normalize(normal);
    norm = perturb_normal(norm, viewVector, tuv);

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
        vec4 shadowCoord = shad[0];
        shadowCoord.z += 0.001;
        float shadowValue = textureProj(p3d_LightSource[0].shadowMap, shadowCoord);

        // attenuation
        float distance = length(lightPosition - fragPos);
        float attenuation = (1.0 / (1.0 + distance * distance * (1.0 / range))) * intensity;

        if (!(i == 0)) {
            ldiffuse *= attenuation;
            lspecular *= attenuation;

            ldiffuse = clamp(ldiffuse, ambient, 1000.0);
            lspecular = clamp(lspecular, ambient, 1000.0);
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
            float attenuation = (1.0 / (1.0 + distance * distance * (1.0 / range))) * intensity * min(1,(theta - lightCutOff) * 100);

            ldiffuse *= attenuation;
            lspecular *= attenuation;

            ldiffuse = clamp(ldiffuse, 0, 1000.0);
            lspecular = clamp(lspecular, 0, 1000.0);

            diffuse += ldiffuse;
            specular += lspecular;
        }
    }

    fragColor = vec4(ambient + diffuse + specular, 1.0) * texture2D(p3d_Texture0, tuv) * p3d_ColorScale;
}
