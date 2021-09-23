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
        self.sun = DirectionalLight(shadows = shadows)
        self.sun.look_at(direction)
        LitLightList[0] = Vec4(color.x, color.y, color.z, 1)
        LitLightList[1] = Vec4(direction.x, direction.y, direction.z, intensity)
    
    def setIntensity(self, intensity = 1):
        LitLightList[1].w = intensity
    
    def setColor(self, color = Vec3(1)):
        LitLightList[0].xyz = color
    
    def setDirection(self, direction = Vec3(-1)):
        LitLightList[1].xyz = direction
        
    def toggleShadows(self):
        self.sun.shadows = not self.sun.shadows


class LitPointLight():
    def __init__(self, position = Vec3(0), color = Vec3(1), range = 20, intensity = 1):
        self.listIndex = len(LitLightList)
        self.position = position
        self.color = color
        self.range = range
        self.intensity = intensity
        LitLightList.append(Vec4(color.x, color.y, color.z, range))
        LitLightList.append(Vec4(position.x, position.y, position.z, intensity))
    
    def setIntensity(self, intensity = 1):
        self.intensity = intensity
        LitLightList[self.listIndex + 1].w = intensity
    
    def setRange(self, range = 20):
        self.range = range
        LitLightList[self.listIndex].w = range
    
    def setPosition(self, position = Vec3(0)):
        self.position = position
        LitLightList[self.listIndex + 1].xyz = position
    
    def setColor(self, color = Vec3(1)):
        self.color = color
        LitLightList[self.listIndex].xyz = color


if __name__ == "__main__":
    app = Ursina()

    Texture.default_filtering = 'mipmap'
    texture = Texture("textures/rocks_diff.jpg")
    specTexture = Texture("textures/rocks_spec.jpg")
    normTexture = Texture("textures/rocks_norm.exr")

    ground = LitObject(model = "plane", scale = 10, texture = texture, specularMap = specTexture, normalMap = normTexture)
    cube = LitObject(model = "cube", position = (0, 0.5, 3), texture = "white_cube", specularMap = None, normalMap = None)

    sun = LitDirectionalLight(direction = Vec3(-1, -0.2, -0.5))

    pointLight = LitPointLight(position = Vec3(3, 1.5, 0), intensity = 2)
    pointLight2 = LitPointLight(position = Vec3(-3, 1, 0), color = Vec3(1, 0, 1))

    EditorCamera(rotation = (20, 0, 0))

    iTime = 0

    def update():
        global iTime
        iTime += time.dt

        pointLight2.setPosition(Vec3(-3, 1, sin(iTime) * 2))

    
    app.run()
