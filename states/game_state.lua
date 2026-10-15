local SnakeGame = require("snake_game")
local Input = require("input")
local Events = require("events")
local Effects = require("effects")
local Theme = require("theme")

local PlayingState = {}
PlayingState.__index = PlayingState

function PlayingState:new(manager, context)
    local state = setmetatable({manager = manager, context = context}, PlayingState)
    state.input = Input:new()
    state.events = Events:new()
    state.effects = Effects:new()
    state.time = 0
    state.notice = ""
    state.noticeTime = 0
    state.shake = 0

    -- Observer pattern: gameplay emits events; this state decides how they look.
    state.events:subscribe("food_eaten", function(data)
        state.notice = "+1  //  LENGTH " .. data.length
        state.noticeTime = 1.35
        if state.game then
            local x, y = state.game:cellCenter(data.position)
            state.effects:burst(x, y, Theme.colors.mint, 16, 105)
            state.shake = 0.12
        end
    end)
    state.events:subscribe("game_over", function(data)
        if state.game then
            local head = state.game.entity:getComponent("position")
            local x, y = state.game:cellCenter(head)
            state.effects:shockwave(x, y,
                data.reason == "self" and Theme.colors.violet or Theme.colors.danger)
            state.shake = 0.34
        end
    end)
    state.events:subscribe("game_won", function()
        if state.game then
            local head = state.game.entity:getComponent("position")
            local x, y = state.game:cellCenter(head)
            state.effects:burst(x, y, Theme.colors.orange, 30, 155)
            state.effects:shockwave(x, y, Theme.colors.orange)
            state.shake = 0.20
        end
    end)

    local directions = {
        up = {0, -1}, down = {0, 1}, left = {-1, 0}, right = {1, 0},
        w = {0, -1}, s = {0, 1}, a = {-1, 0}, d = {1, 0}
    }
    for key, direction in pairs(directions) do
        local dx, dy = direction[1], direction[2]
        state.input:bind(key, function() state.game:changeDirection(dx, dy) end)
    end
    state.input:bind("r", function() state:enter() end)
    state.input:bind("p", function() state.game:togglePause() end)
    state.input:bind("escape", function() manager:switch("menu") end)
    return state
end

function PlayingState:enter()
    self.notice = "SYSTEM READY"
    self.noticeTime = 1.0
    self.shake = 0
    self.effects:clear()
    self.game = SnakeGame:new({
        highScore = self.context.highScore,
        events = self.events
    })
end

function PlayingState:update(dt)
    self.time = self.time + math.max(0, dt)
    self.game:update(dt)
    self.effects:update(dt)
    self.noticeTime = math.max(0, self.noticeTime - dt)
    self.shake = math.max(0, self.shake - dt * 1.8)
end

function PlayingState:keypressed(key)
    self.input:handleKey(key)
end

local function drawStat(fonts, label, value, x, color)
    local graphics = love.graphics
    Theme.panel(x, 22, 126, 62, 10, color)
    graphics.setFont(fonts.tiny or fonts.small)
    graphics.setColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 0.92)
    graphics.printf(label, x, 33, 126, "center")
    graphics.setFont(fonts.number)
    graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], 1)
    graphics.printf(tostring(value), x, 50, 126, "center")
end

function PlayingState:drawHeader()
    local graphics = love.graphics
    local fonts = self.context.fonts
    local game = self.game

    graphics.setFont(fonts.heading)
    graphics.setColor(Theme.colors.mint[1], Theme.colors.mint[2], Theme.colors.mint[3], 1)
    graphics.print("SNAKE", 40, 24)
    graphics.setFont(fonts.tiny or fonts.small)
    graphics.setColor(Theme.colors.cyan[1], Theme.colors.cyan[2], Theme.colors.cyan[3], 0.84)
    graphics.print("// NEON RUNNER", 42, 56)
    Theme.badge(41, 76, 124, "LIVE GRID", fonts.tiny or fonts.small, Theme.colors.violet)

    drawStat(fonts, "SCORE", game.score, 344, Theme.colors.mint)
    drawStat(fonts, "BEST", game.best, 484, Theme.colors.cyan)
    drawStat(fonts, "LENGTH", #game.snake, 624, Theme.colors.violet)

    if self.noticeTime > 0 then
        local alpha = math.min(1, self.noticeTime * 1.9)
        graphics.setFont(fonts.tiny or fonts.small)
        graphics.setColor(Theme.colors.mint[1], Theme.colors.mint[2], Theme.colors.mint[3], alpha)
        graphics.printf(self.notice, 178, 92, 444, "center")
    end
end

function PlayingState:drawControls()
    local graphics = love.graphics
    local fonts = self.context.fonts
    Theme.panel(40, 611, 720, 22, 8, Theme.colors.line, 0.82)
    graphics.setFont(fonts.tiny or fonts.small)
    graphics.setColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 0.96)
    graphics.print("MOVE", 56, 616)
    Theme.keycap(94, 611, "↑↓←→", fonts.tiny or fonts.small, 48)
    graphics.print("or WASD", 149, 616)
    Theme.keycap(248, 611, "P", fonts.tiny or fonts.small, 23)
    graphics.print("PAUSE", 277, 616)
    Theme.keycap(364, 611, "R", fonts.tiny or fonts.small, 23)
    graphics.print("RESTART", 393, 616)
    Theme.keycap(494, 611, "ESC", fonts.tiny or fonts.small, 34)
    graphics.print("MENU", 534, 616)
    graphics.setColor(Theme.colors.cyan[1], Theme.colors.cyan[2], Theme.colors.cyan[3], 0.72)
    graphics.printf("F5  RELOAD", 617, 616, 124, "right")
end

function PlayingState:drawOverlay()
    local graphics = love.graphics
    local fonts = self.context.fonts
    local game = self.game
    if not game.gameOver and not game.paused then
        return
    end

    graphics.setColor(0.006, 0.012, 0.030, 0.73)
    graphics.rectangle("fill", 33, 109, 734, 494, 12, 12)

    local accent = game.paused and Theme.colors.cyan
        or (game.won and Theme.colors.orange or Theme.colors.danger)
    Theme.panel(177, 238, 446, 238, 18, accent)
    Theme.badge(314, 258, 172, game.paused and "RUN PAUSED" or "ROUND COMPLETE",
        fonts.tiny or fonts.small, accent)

    local title = game.paused and "PAUSED" or (game.won and "GRID CLEARED" or "RUN ENDED")
    graphics.setFont(fonts.display or fonts.heading)
    graphics.setColor(accent[1], accent[2], accent[3], 1)
    graphics.printf(title, 177, 302, 446, "center")

    graphics.setFont(fonts.body)
    graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], 1)
    graphics.printf("SCORE  " .. game.score .. "     //     BEST  " .. game.best,
        177, 351, 446, "center")

    graphics.setFont(fonts.small)
    graphics.setColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 1)
    local reason = game.reason == "wall" and "You reached the edge of the grid."
        or (game.reason == "self" and "You crossed your own trail."
        or (game.won and "Every cell has been claimed." or "The run is waiting."))
    graphics.printf(reason, 177, 385, 446, "center")

    if game.paused then
        Theme.keycap(250, 424, "P", fonts.small, 29)
        graphics.printf("resume", 282, 429, 72, "left")
        Theme.keycap(394, 424, "R", fonts.small, 29)
        graphics.printf("new run", 426, 429, 75, "left")
    else
        Theme.keycap(270, 424, "R", fonts.small, 29)
        graphics.printf("new run", 302, 429, 72, "left")
        Theme.keycap(437, 424, "ESC", fonts.small, 38)
        graphics.printf("menu", 479, 429, 58, "left")
    end
end

function PlayingState:draw()
    local graphics = love.graphics
    Theme.drawBackground(self.time, self.context.stars, 800, 640)
    self:drawHeader()

    local jitter = self.shake * self.shake * 14
    local offsetX = math.sin(self.time * 103) * jitter
    local offsetY = math.cos(self.time * 137) * jitter
    graphics.push()
    graphics.translate(offsetX, offsetY)
    self.game:draw(self.time)
    self.effects:draw()
    graphics.pop()

    self:drawControls()
    if self.game.saveError then
        graphics.setFont(self.context.fonts.tiny or self.context.fonts.small)
        graphics.setColor(Theme.colors.danger[1], Theme.colors.danger[2], Theme.colors.danger[3], 0.95)
        graphics.printf("Record could not be saved.", 420, 94, 320, "right")
    end
    self:drawOverlay()
    graphics.setColor(1, 1, 1, 1)
end

return PlayingState
