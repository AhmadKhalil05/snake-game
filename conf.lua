function love.conf(t)
    t.identity = "snake_lua_assignment"
    t.version = "11.5"
    t.window.title = "Snake: Neon Runner | Lua Assignment"
    t.window.width = 800
    t.window.height = 640
    t.window.resizable = false
    t.window.vsync = 1
    t.window.highdpi = false

    -- Keep audio enabled even without sound assets: love.js compatibility mode
    -- updates the OpenAL pool from Event::pump and needs it initialized.
    t.modules.audio = true
    t.modules.physics = false
    t.modules.joystick = false
end
