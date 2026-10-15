local Input = require("input")
local Theme = require("theme")

local MenuState = {}
MenuState.__index = MenuState

function MenuState:new(manager, context)
    local state = setmetatable({manager = manager, context = context, time = 0}, MenuState)
    state.input = Input:new()
    local start = function() manager:switch("playing") end
    state.input:bind("return", start)
    state.input:bind("kpenter", start)
    state.input:bind("space", start)
    state.input:bind("escape", function()
        if love.system and love.system.getOS() == "Web" then return end
        love.event.quit()
    end)
    return state
end

function MenuState:enter()
    self.best = self.context.highScore:load()
end

function MenuState:update(dt)
    self.time = self.time + math.max(0, dt)
end

function MenuState:keypressed(key)
    self.input:handleKey(key)
end

function MenuState:mousepressed(x, y, button)
    if button == 1 and x >= 238 and x <= 562 and y >= 407 and y <= 469 then
        self.manager:switch("playing")
    end
end

function MenuState:drawSnakePreview()
    local graphics = love.graphics
    local fonts = self.context.fonts
    local startX, startY = 224, 310
    local cell = 31
    local curve = {0, 0, 1, 1, 1, 2, 2, 1}

    Theme.panel(168, 258, 464, 126, 18, Theme.colors.violet, 0.92)
    graphics.setFont(fonts.tiny or fonts.small)
    graphics.setColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 0.9)
    graphics.print("SIGNAL PATH", 190, 274)
    graphics.setColor(Theme.colors.cyan[1], Theme.colors.cyan[2], Theme.colors.cyan[3], 0.55)
    graphics.printf("01 / LIVE", 491, 274, 118, "right")

    for i = 1, #curve do
        local depth = (i - 1) / (#curve - 1)
        local color = i == #curve and Theme.colors.mint
            or Theme.mix(Theme.colors.green, Theme.colors.violet, depth * 0.48)
        local x = startX + (i - 1) * cell
        local y = startY + curve[i] * 16
        Theme.glowRect(x, y, 25, 25, 6, color, i == #curve and 0.15 or 0.05, 3)
        graphics.setColor(color[1], color[2], color[3], 1)
        graphics.rectangle("fill", x, y, 25, 25, 6, 6)
        graphics.setColor(1, 1, 1, i == #curve and 0.23 or 0.08)
        graphics.rectangle("fill", x + 4, y + 4, 17, 2, 2, 2)
    end

    local headX = startX + (#curve - 1) * cell + 16
    local headY = startY + curve[#curve] * 16 + 13
    graphics.setColor(0.01, 0.05, 0.05, 1)
    graphics.circle("fill", headX + 5, headY - 5, 2)
    graphics.circle("fill", headX + 5, headY + 5, 2)

    local foodX, foodY = 524, 337
    local pulse = Theme.pulse(self.time, 4.7)
    Theme.glowCircle(foodX, foodY, 15 + pulse * 4, Theme.colors.pink, 0.10, 4)
    graphics.setColor(Theme.colors.orange[1], Theme.colors.orange[2], Theme.colors.orange[3], 1)
    graphics.circle("fill", foodX, foodY, 8)
    graphics.setColor(1, 0.92, 0.70, 0.95)
    graphics.circle("fill", foodX - 2.5, foodY - 3, 2)
end

function MenuState:draw()
    local graphics = love.graphics
    local fonts = self.context.fonts
    Theme.drawBackground(self.time, self.context.stars, 800, 640)

    Theme.badge(324, 57, 152, "ARCADE PROTOCOL", fonts.tiny or fonts.small, Theme.colors.cyan)
    graphics.setFont(fonts.title)
    graphics.setColor(Theme.colors.mint[1], Theme.colors.mint[2], Theme.colors.mint[3], 1)
    graphics.printf("SNAKE", 0, 93, 800, "center")
    graphics.setFont(fonts.heading)
    graphics.setColor(Theme.colors.violet[1], Theme.colors.violet[2], Theme.colors.violet[3], 0.95)
    graphics.printf("NEON RUNNER", 0, 161, 800, "center")
    graphics.setFont(fonts.body)
    graphics.setColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 1)
    graphics.printf("Collect the pulse. Own the grid. Keep moving.", 0, 199, 800, "center")

    Theme.panel(618, 48, 126, 60, 12, Theme.colors.orange, 0.94)
    graphics.setFont(fonts.tiny or fonts.small)
    graphics.setColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 1)
    graphics.printf("BEST RECORD", 618, 59, 126, "center")
    graphics.setFont(fonts.number)
    graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], 1)
    graphics.printf(tostring(self.best), 618, 76, 126, "center")

    self:drawSnakePreview()

    local pulse = Theme.pulse(self.time, 2.0)
    Theme.glowRect(238, 407, 324, 62, 14, Theme.colors.mint, 0.11 + pulse * 0.05, 5)
    graphics.setColor(Theme.colors.mint[1], Theme.colors.mint[2], Theme.colors.mint[3], 1)
    graphics.rectangle("fill", 238, 407, 324, 62, 14, 14)
    graphics.setColor(0.012, 0.07, 0.05, 1)
    graphics.setFont(fonts.body)
    graphics.printf("START RUN", 238, 428, 324, "center")
    graphics.setColor(0.84, 1, 0.93, 0.48)
    graphics.rectangle("line", 238.5, 407.5, 323, 61, 14, 14)

    Theme.keycap(253, 497, "ENTER", fonts.small, 50)
    graphics.setFont(fonts.small)
    graphics.setColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 1)
    graphics.print("start", 309, 502)
    Theme.keycap(374, 497, "WASD", fonts.small, 48)
    graphics.print("move", 428, 502)
    Theme.keycap(506, 497, "P", fonts.small, 25)
    graphics.print("pause", 537, 502)

    graphics.setFont(fonts.tiny or fonts.small)
    graphics.setColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 0.85)
    graphics.printf("Press Enter, Space, or click START RUN", 0, 546, 800, "center")
    graphics.setColor(Theme.colors.cyan[1], Theme.colors.cyan[2], Theme.colors.cyan[3], 0.65)
    graphics.printf("ESC closes the game  //  F5 reloads saved source", 0, 573, 800, "center")
    graphics.setColor(Theme.colors.line[1], Theme.colors.line[2], Theme.colors.line[3], 0.72)
    graphics.line(118, 604, 682, 604)
    graphics.setColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 0.72)
    graphics.printf("LUA GAME PROGRAMMING ASSIGNMENT", 0, 614, 800, "center")
    graphics.setColor(1, 1, 1, 1)
end

return MenuState
