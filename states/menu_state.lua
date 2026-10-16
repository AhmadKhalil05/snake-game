local Input = require("input")
local Theme = require("theme")

local MenuState = {}
MenuState.__index = MenuState

function MenuState:new(manager, context)
    local state = setmetatable({manager = manager, context = context, time = 0}, MenuState)
    state.input = Input:new()
    local start = function()
        if context and context.audio then
            context.audio:playStart()
        end
        manager:switch("playing")
    end
    state.input:bind("return", start)
    state.input:bind("kpenter", start)
    state.input:bind("space", start)
    state.input:bind("m", function()
        if context and context.audio then
            context.audio:toggleMute()
        end
    end)
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
        if self.context and self.context.audio then
            self.context.audio:playStart()
        end
        self.manager:switch("playing")
    end
end

function MenuState:drawSnakePreview()
    local graphics = love.graphics
    local fonts = self.context.fonts
    local startX, startY = 220, 314
    local cell = 32
    local total = 8

    Theme.panel(168, 252, 464, 136, 18, Theme.colors.violet, 0.94)
    graphics.setFont(fonts.tiny or fonts.small)
    graphics.setColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 0.9)
    graphics.print("CYBER PROTOCOL // SIGNAL PATH", 190, 268)
    graphics.setColor(Theme.colors.cyan[1], Theme.colors.cyan[2], Theme.colors.cyan[3], 0.75)
    graphics.printf("STATUS: ONLINE", 475, 268, 135, "right")

    -- Animated curving snake preview
    local points = {}
    for i = 1, total do
        local wave = math.sin(self.time * 4.2 + (i * 0.75)) * 14
        local px = startX + (i - 1) * cell
        local py = startY + wave
        table.insert(points, {x = px, y = py})
    end

    -- Draw connecting laser bridges between preview segments
    graphics.setColor(Theme.colors.mint[1], Theme.colors.mint[2], Theme.colors.mint[3], 0.75)
    graphics.setLineWidth(14)
    for i = 1, total - 1 do
        graphics.line(points[i].x, points[i].y, points[i + 1].x, points[i + 1].y)
    end

    -- Laser central conduit
    graphics.setColor(Theme.colors.cyan[1], Theme.colors.cyan[2], Theme.colors.cyan[3], 0.95)
    graphics.setLineWidth(2.5)
    for i = 1, total - 1 do
        graphics.line(points[i].x, points[i].y, points[i + 1].x, points[i + 1].y)
    end

    -- Draw nodes
    for i = 1, total do
        local depth = (i - 1) / (total - 1)
        local isHead = (i == total)
        local color = isHead and Theme.colors.mint or Theme.mix(Theme.colors.green, Theme.colors.violet, depth * 0.75)
        local pt = points[i]
        local radius = isHead and 11 or (10 - depth * 3)

        Theme.glowCircle(pt.x, pt.y, radius * 1.5, color, isHead and 0.25 or 0.08, 3)
        graphics.setColor(color[1], color[2], color[3], 1)
        graphics.circle("fill", pt.x, pt.y, radius)
        graphics.setColor(1, 1, 1, 0.45)
        graphics.circle("fill", pt.x - 2, pt.y - 2, radius * 0.35)
    end

    -- Head headlights and eyes
    local head = points[total]
    graphics.setColor(0.01, 0.05, 0.05, 1)
    graphics.circle("fill", head.x + 3, head.y - 4, 2.5)
    graphics.circle("fill", head.x + 3, head.y + 4, 2.5)
    graphics.setColor(0.1, 0.95, 1.0, 0.95)
    graphics.circle("fill", head.x + 4, head.y - 4, 1.3)
    graphics.circle("fill", head.x + 4, head.y + 4, 1.3)

    -- Food target orb with orbiting particles
    local foodX, foodY = 530, 320 + math.sin(self.time * 2.5) * 6
    local pulse = Theme.pulse(self.time, 5.0)
    Theme.glowCircle(foodX, foodY, 18 + pulse * 6, Theme.colors.pink, 0.16, 5)
    graphics.setColor(Theme.colors.orange[1], Theme.colors.orange[2], Theme.colors.orange[3], 1)
    graphics.circle("fill", foodX, foodY, 8.5)
    graphics.setColor(1, 0.94, 0.75, 0.95)
    graphics.circle("fill", foodX - 2, foodY - 2, 3.5)

    -- Mini orbit
    local ox = foodX + math.cos(self.time * 4) * 14
    local oy = foodY + math.sin(self.time * 4) * 14
    graphics.setColor(Theme.colors.cyan[1], Theme.colors.cyan[2], Theme.colors.cyan[3], 0.9)
    graphics.circle("fill", ox, oy, 1.8)

    graphics.setLineWidth(1)
    graphics.setColor(1, 1, 1, 1)
end

function MenuState:draw()
    local graphics = love.graphics
    local fonts = self.context.fonts
    Theme.drawBackground(self.time, self.context.stars, 800, 640)

    Theme.badge(324, 52, 152, "ARCADE CYBER PROTOCOL", fonts.tiny or fonts.small, Theme.colors.cyan)
    graphics.setFont(fonts.title)
    graphics.setColor(Theme.colors.mint[1], Theme.colors.mint[2], Theme.colors.mint[3], 1)
    graphics.printf("SNAKE", 0, 88, 800, "center")
    graphics.setFont(fonts.heading)
    graphics.setColor(Theme.colors.violet[1], Theme.colors.violet[2], Theme.colors.violet[3], 0.95)
    graphics.printf("NEON RUNNER", 0, 156, 800, "center")
    graphics.setFont(fonts.body)
    graphics.setColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 1)
    graphics.printf("Master the cyber grid. Chain combos. Dominate the leaderboard.", 0, 194, 800, "center")

    Theme.panel(618, 46, 126, 62, 12, Theme.colors.orange, 0.95)
    graphics.setFont(fonts.tiny or fonts.small)
    graphics.setColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 1)
    graphics.printf("BEST RECORD", 618, 57, 126, "center")
    graphics.setFont(fonts.number)
    graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], 1)
    graphics.printf(tostring(self.best), 618, 74, 126, "center")

    self:drawSnakePreview()

    local pulse = Theme.pulse(self.time, 2.2)
    Theme.glowRect(238, 407, 324, 62, 14, Theme.colors.mint, 0.12 + pulse * 0.08, 5)
    graphics.setColor(Theme.colors.mint[1], Theme.colors.mint[2], Theme.colors.mint[3], 1)
    graphics.rectangle("fill", 238, 407, 324, 62, 14, 14)
    graphics.setColor(0.012, 0.07, 0.05, 1)
    graphics.setFont(fonts.body)
    graphics.printf("START RUN", 238, 428, 324, "center")
    graphics.setColor(0.84, 1, 0.93, 0.55)
    graphics.setLineWidth(1)
    graphics.rectangle("line", 238.5, 407.5, 323, 61, 14, 14)

    Theme.keycap(215, 497, "ENTER", fonts.small, 52)
    graphics.setFont(fonts.small)
    graphics.setColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 1)
    graphics.print("start", 273, 502)
    Theme.keycap(325, 497, "WASD", fonts.small, 48)
    graphics.print("move", 379, 502)
    Theme.keycap(432, 497, "P", fonts.small, 25)
    graphics.print("pause", 463, 502)
    Theme.keycap(520, 497, "M", fonts.small, 25)
    graphics.print("audio", 551, 502)

    graphics.setFont(fonts.tiny or fonts.small)
    graphics.setColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 0.88)
    graphics.printf("Press Enter, Space, or tap START RUN  //  Touch arrows supported on mobile", 0, 546, 800, "center")
    graphics.setColor(Theme.colors.cyan[1], Theme.colors.cyan[2], Theme.colors.cyan[3], 0.68)
    graphics.printf("ESC closes the game  //  F5 reloads telemetry", 0, 573, 800, "center")
    graphics.setColor(Theme.colors.line[1], Theme.colors.line[2], Theme.colors.line[3], 0.72)
    graphics.line(118, 604, 682, 604)
    graphics.setColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 0.72)
    graphics.printf("NEON RUNNER // ADVANCED ARCADE SIMULATION", 0, 614, 800, "center")
    graphics.setColor(1, 1, 1, 1)
end

return MenuState
