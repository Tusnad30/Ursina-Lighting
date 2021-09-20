from operator import pos
from ursina import *


vert, frag = open("shaders/vert.glsl", "r"), open("shaders/frag.glsl", "r")
LitShader = Shader(language = Shader.GLSL, vertex = vert.read(), fragment = frag.read())
vert.close()
frag.close()


class LitObject(Entity):
    def __init__(self, model = 'plane', scale = 1, position = (0, 0, 0), rotation = (0, 0, 0), texture = 'white_cube', color = rgb(255, 255, 255), tiling = Vec2(1), lightDirection = Vec3(0), lightColor = Vec3(1), smoothness = 128, ambientStrength = 0.1, useNormalMap = True, normalMap = None, useSpecularMap = True, specularMap = None):
        super().__init__(
            shader = LitShader,
            model = model,
            position = position,
            rotation = rotation,
            scale = scale,
            texture = texture,
            color = color
        )

        self.set_shader_input("tiling", tiling)
        self.set_shader_input("lightDirection", lightDirection)
        self.set_shader_input("lightColor", lightColor)
        self.set_shader_input("smoothness", smoothness)
        self.set_shader_input("ambientStrength", ambientStrength)
        self.set_shader_input("useNormalMap", useNormalMap)
        self.set_shader_input("normalMap", normalMap)
        self.set_shader_input("useSpecularMap", useSpecularMap)
        self.set_shader_input("specularMap", specularMap)
    
    def update(self):
        self.set_shader_input("viewPos", camera.world_position)

if __name__ == "__main__":
    sunDirection = Vec3(-1, -0.2, -0.5)

    app = Ursina()

    Texture.default_filtering = 'mipmap'
    gtexture = Texture("textures/rocks_diff.jpg")
    gspecTexture = Texture("textures/rocks_spec.jpg")
    gnormTexture = Texture("textures/rocks_norm.exr")

    LitObject(model = "plane", scale = 10, texture = gtexture, lightDirection = sunDirection, specularMap = gspecTexture, normalMap = gnormTexture)
    LitObject(model = "cube", position = (0, 0.5, 3), texture = "white_cube", lightDirection = sunDirection, specularMap = gspecTexture, normalMap = gnormTexture, useSpecularMap = False, useNormalMap = False)

    EditorCamera(rotation = (20, 0, 0))

    sun = DirectionalLight()
    sun.look_at(sunDirection)

    window.borderless = False
    window.exit_button.enabled = False
    window.cog_button.enabled = False
    
    app.run()