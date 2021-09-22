from ursina import *

vert, frag = open("shaders/vert.glsl", "r"), open("shaders/frag.glsl", "r")
LitShader = Shader(language = Shader.GLSL, vertex = vert.read(), fragment = frag.read())
vert.close()
frag.close()

# list containing all lights, each light has 2 Vector4
LitLightList = [Vec4(1), Vec4(0)]

class LitObject(Entity):
    def __init__(self, model = 'plane', scale = 1, position = (0, 0, 0), rotation = (0, 0, 0), texture = 'white_cube', color = rgb(255, 255, 255), tiling = Vec2(1), lightDirection = Vec3(0), lightColor = Vec3(1), smoothness = 128, ambientStrength = 0.1, normalMap = None, specularMap = None, **kwargs):
        super().__init__(
            shader = LitShader,
            model = model,
            position = position,
            rotation = rotation,
            scale = scale,
            texture = texture,
            color = color,
        )

        for key, value in kwargs.items():
            setattr(self, key, value)

        defaultNormal = Texture("textures/default_norm.png")
        defaultSpecular = Texture("textures/default_spec.png")
        
        if normalMap == None: normalMap = defaultNormal
        if specularMap == None: specularMap = defaultSpecular

        self.set_shader_input("tiling", tiling)
        self.set_shader_input("smoothness", smoothness)
        self.set_shader_input("ambientStrength", ambientStrength)
        self.set_shader_input("normalMap", normalMap)
        self.set_shader_input("specularMap", specularMap)
    
    def update(self):
        self.set_shader_input("viewPos", camera.world_position)
        self.set_shader_input("lightsArray", LitLightList)
        self.set_shader_input("lightsArrayLength", len(LitLightList))


class LitDirectionalLight():
    def __init__(self, direction = Vec3(0), color = Vec3(1), intensity = 1, shadows = True):
        sun = DirectionalLight(shadows = shadows)
        sun.look_at(direction)
        LitLightList[0] = Vec4(color.x, color.y, color.z, 1)
        LitLightList[1] = Vec4(direction.x, direction.y, direction.z, intensity)
    
    def setIntensity(self, intensity = 1):
        LitLightList[1].w = intensity


class LitPointLight():
    def __init__(self, position = Vec3(0), color = Vec3(1), range = 20, intensity = 1):
        self.listIndex = len(LitLightList)
        LitLightList.append(Vec4(color.x, color.y, color.z, range))
        LitLightList.append(Vec4(position.x, position.y, position.z, intensity))
    
    def setIntensity(self, intensity = 1):
        LitLightList[self.listIndex + 1].w = intensity
    
    def setRange(self, range = 20):
        LitLightList[self.listIndex].w = range


if __name__ == "__main__":
    app = Ursina()

    Texture.default_filtering = 'mipmap'
    gtexture = Texture("textures/rocks_diff.jpg")
    gspecTexture = Texture("textures/rocks_spec.jpg")
    gnormTexture = Texture("textures/rocks_norm.exr")

    ground = LitObject(model = "plane", scale = 10, texture = gtexture, specularMap = gspecTexture, normalMap = gnormTexture)
    cube = LitObject(model = "cube", position = (0, 0.5, 3), texture = "white_cube", specularMap = None, normalMap = None)

    sun = LitDirectionalLight(direction = Vec3(-1, -0.2, -0.5))

    pointLight = LitPointLight(position = Vec3(3, 1.5, 0), intensity = 2)
    pointLight2 = LitPointLight(position = Vec3(-3, 1, 0), color = Vec3(1, 0, 1))

    EditorCamera(rotation = (20, 0, 0))
    
    app.run()