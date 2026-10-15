function love.conf(t)
    t.identity = "snake_lua_assignment"
    t.version = "11.5"
    t.window.title = "Snake: Neon Runner | Lua Assignment"
    t.window.width = 800
    t.window.height = 640
    t.window.resizable = false
    t.window.vsync = 1
    t.window.highdpi = false

    -- This project uses procedural shapes only; no audio or physics assets are required.
    t.modules.audio = false
    t.modules.physics = false
    t.modules.joystick = false
end
