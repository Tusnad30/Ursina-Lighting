from ursina import *
import numpy as np

vert, frag = open("shaders/vert.glsl", "r"), open("shaders/frag.glsl", "r")
LitShader = Shader(language = Shader.GLSL, vertex = vert.read(), fragment = frag.read())
vert.close()
frag.close()

# list containing all light data
LitLightList = [Vec4(1), Vec4(0)]
LitSpotList = [Vec4(1), Vec4(0), Vec4(0)]

LitTime = 0

class LitInit(Entity):
    def __init__(self):
        super().__init__(
            model = None
        )
    
    def update(self):
        global LitTime
        LitTime += time.dt


class LitObject(Entity):
    def __init__(self, model = 'plane', scale = 1, position = (0, 0, 0), rotation = (0, 0, 0), texture = None, collider = None,
                 color = rgb(255, 255, 255), tiling = Vec2(1), lightDirection = Vec3(0), lightColor = Vec3(1),
                 smoothness = 128, ambientStrength = 0.1, normalMap = None, specularMap = None, water = False, cubemap = "textures/cubemap_#.jpg", cubemapIntensity = 0.5,
                 onUpdate = lambda self: None, **kwargs):
        super().__init__(
            shader = LitShader,
            model = model,
            collider = collider,
            position = position,
            rotation = rotation,
            scale = scale,
            texture = texture,
            color = color,
        )

        for key, value in kwargs.items():
            setattr(self, key, value)
        
        if normalMap == None: normalMap = Texture("textures/default_norm.png")
        if specularMap == None: specularMap = Texture("textures/default_spec.png")
        if water:
            normalMap = Texture("textures/water_norm.png")
            smoothness = 512
        
        cubemaps = loader.loadCubeMap(cubemap)

        self.set_shader_input("tiling", tiling)
        self.set_shader_input("smoothness", smoothness)
        self.set_shader_input("ambientStrength", ambientStrength)
        self.set_shader_input("normalMap", normalMap)
        self.set_shader_input("specularMap", specularMap)
        self.set_shader_input("water", water)
        self.set_shader_input("cubemap", cubemaps)
        self.set_shader_input("cubemapIntensity", cubemapIntensity)
        self.onUpdate = onUpdate
    
    def update(self):
        self.set_shader_input("lightsArray", LitLightList)
        self.set_shader_input("lightsArrayLength", Vec2(len(LitLightList), len(LitSpotList)))
        self.set_shader_input("spotArray", LitSpotList)
        self.set_shader_input("time", LitTime)
        self.onUpdate(self)


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


class LitSpotLight():
    def __init__(self, position = Vec3(0), color = Vec3(1), range = 20, intensity = 1, direction = Vec3(0), angle = 30):
        self.listIndex = len(LitSpotList)
        self.position = position
        self.color = color
        self.range = range
        self.intensity = intensity
        self.direction = direction
        self.angle = angle
        LitSpotList.append(Vec4(color.x, color.y, color.z, range))
        LitSpotList.append(Vec4(position.x, position.y, position.z, intensity))
        LitSpotList.append(Vec4(direction.x, direction.y, direction.z, np.cos(np.radians(angle))))

    def setIntensity(self, intensity = 1):
        self.intensity = intensity
        LitSpotList[self.listIndex + 1].w = intensity
    
    def setRange(self, range = 20):
        self.range = range
        LitSpotList[self.listIndex].w = range
    
    def setPosition(self, position = Vec3(0)):
        self.position = position
        LitSpotList[self.listIndex + 1].xyz = position
    
    def setColor(self, color = Vec3(1)):
        self.color = color
        LitSpotList[self.listIndex].xyz = color

    def setDirection(self, direction = Vec3(0)):
        self.direction = direction
        LitSpotList[self.listIndex + 2].xyz = direction

    def setAngle(self, angle = 30):
        self.angle = angle
        LitSpotList[self.listIndex + 2].w = np.cos(np.radians(angle))



if __name__ == "__main__":
    app = Ursina()
    
    # IMPORTANT !!!
    lit = LitInit()
    # IMPORTANT !!!

    # load textures
    Texture.default_filtering = 'mipmap'
    texture = Texture("textures/rocks_diff.jpg")
    specTexture = Texture("textures/rocks_spec.jpg")
    normTexture = Texture("textures/rocks_norm.exr")
    skyboxTexture = Texture("textures/skybox.jpg")

    #skybox
    skybox = Sky(model = "sphere", double_sided = True, texture = skyboxTexture, rotation = (0, 90, 0))

    # objects
    ground = LitObject(model = "plane", scale = 10, texture = texture, specularMap = specTexture, normalMap = normTexture, ambientStrength = 0.5)
    cube = LitObject(model = "cube", position = (0, 0.5, 1), texture = "white_cube", specularMap = None, normalMap = None, ambientStrength = 0.5)
    water = LitObject(position = (0, -0.1, 1), scale = 50, water = True, cubemapIntensity = 0.75, ambientStrength = 0.5)

    # lights
    sun = LitDirectionalLight(direction = Vec3(0.5, -0.6, 1))
    pointLight = LitPointLight(position = Vec3(-3, 1, 0), color = rgb(255, 0, 255))
    spotLight = LitSpotLight(position = Vec3(0, 3, 0), direction = Vec3(0.5, -1, -1))

    # player
    player = EditorCamera(rotation = (20, 0, 0))
    camera.fov = 80

    iTime = 0
    # make lights move
    def update():
        global iTime
        iTime += time.dt

        pointLight.setPosition(Vec3(-3, 1, sin(iTime) * 2))
        spotLight.setDirection(Vec3(sin(iTime * 0.5), -1, -1))

    app.run()
