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

    -- Observer pattern: gameplay emits events; this state decides audio and visual feedback.
    state.events:subscribe("food_eaten", function(data)
        local combo = data.combo or 1
        if combo > 1 then
            state.notice = "COMBO x" .. combo .. "  //  STREAK ACTIVE"
        else
            state.notice = "+1  //  LENGTH " .. data.length
        end
        state.noticeTime = 1.45

        if state.context and state.context.audio then
            state.context.audio:playEat(combo)
        end

        if state.game then
            local x, y = state.game:cellCenter(data.position)
            local burstColor = combo > 2 and Theme.colors.gold or (combo > 1 and Theme.colors.cyan or Theme.colors.mint)
            state.effects:burst(x, y, burstColor, 14 + math.min(12, combo * 3), 105 + combo * 10)
            state.effects:addTrail(x, y, burstColor, 22)

            local popText = combo > 1 and ("x" .. combo .. " COMBO!") or "+1"
            state.effects:popup(x, y - 6, popText, burstColor, combo > 1 and 1.25 or 1.0)
            state.shake = math.min(0.24, 0.10 + combo * 0.025)
        end
    end)

    state.events:subscribe("game_over", function(data)
        if state.context and state.context.audio then
            state.context.audio:playDie()
        end
        if state.game then
            local head = state.game.entity:getComponent("position")
            local x, y = state.game:cellCenter(head)
            local shockColor = data.reason == "self" and Theme.colors.violet or Theme.colors.danger
            state.effects:shockwave(x, y, shockColor)
            state.effects:burst(x, y, shockColor, 24, 140)
            state.shake = 0.38
        end
    end)

    state.events:subscribe("game_won", function()
        if state.context and state.context.audio then
            state.context.audio:playStart()
        end
        if state.game then
            local head = state.game.entity:getComponent("position")
            local x, y = state.game:cellCenter(head)
            state.effects:burst(x, y, Theme.colors.gold, 36, 175)
            state.effects:shockwave(x, y, Theme.colors.gold)
            state.shake = 0.25
        end
    end)

    local directions = {
        up = {0, -1}, down = {0, 1}, left = {-1, 0}, right = {1, 0},
        w = {0, -1}, s = {0, 1}, a = {-1, 0}, d = {1, 0}
    }
    for key, direction in pairs(directions) do
        local dx, dy = direction[1], direction[2]
        state.input:bind(key, function()
            local changed = state.game:changeDirection(dx, dy)
            if changed and state.context and state.context.audio then
                state.context.audio:playTurn()
            end
        end)
    end
    state.input:bind("r", function() state:enter() end)
    state.input:bind("p", function() state.game:togglePause() end)
    state.input:bind("escape", function() manager:switch("menu") end)
    state.input:bind("m", function()
        if state.context and state.context.audio then
            state.context.audio:toggleMute()
        end
    end)

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
    if self.context and self.context.audio then
        self.context.audio:playStart()
    end
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

function PlayingState:mousepressed(x, y, button)
    if not self.game then return end
    if self.game.gameOver or self.game.won then
        self:enter()
        return
    end
    if self.game.paused then
        self.game.paused = false
        return
    end

    local head = self.game.entity:getComponent("position")
    if head then
        local hx, hy = self.game:cellCenter(head)
        local dx = x - hx
        local dy = y - hy
        local changed = false
        if math.abs(dx) > math.abs(dy) then
            if dx > 0 then
                changed = self.game:changeDirection(1, 0)
            else
                changed = self.game:changeDirection(-1, 0)
            end
        else
            if dy > 0 then
                changed = self.game:changeDirection(0, 1)
            else
                changed = self.game:changeDirection(0, -1)
            end
        end
        if changed and self.context and self.context.audio then
            self.context.audio:playTurn()
        end
    end
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
    graphics.setColor(Theme.colors.cyan[1], Theme.colors.cyan[2], Theme.colors.cyan[3], 0.88)
    graphics.print("// NEON RUNNER", 42, 56)

    -- Dynamic Status Badge or Combo Bar
    if game.combo > 1 and game.comboTimer > 0 then
        local progress = game.comboTimer / game.comboMaxTime
        Theme.badge(41, 76, 124, "COMBO x" .. game.combo .. " !", fonts.tiny or fonts.small, Theme.colors.gold)
        -- Mini combo countdown bar
        graphics.setColor(Theme.colors.gold[1], Theme.colors.gold[2], Theme.colors.gold[3], 0.75)
        graphics.rectangle("fill", 42, 103, 122 * progress, 3, 2, 2)
    else
        Theme.badge(41, 76, 124, "LIVE GRID", fonts.tiny or fonts.small, Theme.colors.violet)
    end

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
    Theme.panel(40, 611, 720, 22, 8, Theme.colors.line, 0.85)
    graphics.setFont(fonts.tiny or fonts.small)
    graphics.setColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 0.96)
    graphics.print("MOVE", 50, 616)
    Theme.keycap(86, 611, "ARROWS", fonts.tiny or fonts.small, 52)
    graphics.print("or WASD", 144, 616)
    Theme.keycap(236, 611, "P", fonts.tiny or fonts.small, 23)
    graphics.print("PAUSE", 264, 616)
    Theme.keycap(340, 611, "R", fonts.tiny or fonts.small, 23)
    graphics.print("RESTART", 368, 616)
    Theme.keycap(456, 611, "M", fonts.tiny or fonts.small, 23)
    local muted = self.context.audio and self.context.audio.muted
    graphics.print(muted and "UNMUTE" or "MUTE", 484, 616)
    Theme.keycap(562, 611, "ESC", fonts.tiny or fonts.small, 34)
    graphics.print("MENU", 601, 616)
    graphics.setColor(Theme.colors.cyan[1], Theme.colors.cyan[2], Theme.colors.cyan[3], 0.72)
    graphics.printf("F5 RELOAD", 650, 616, 100, "right")
end

function PlayingState:drawOverlay()
    local graphics = love.graphics
    local fonts = self.context.fonts
    local game = self.game
    if not game.gameOver and not game.paused then
        return
    end

    graphics.setColor(0.006, 0.012, 0.030, 0.78)
    graphics.rectangle("fill", 33, 109, 734, 494, 12, 12)

    local isNewRecord = (game.score == game.best and game.score > 0)
    local accent = game.paused and Theme.colors.cyan
        or (game.won and Theme.colors.gold
            or (isNewRecord and Theme.colors.gold or Theme.colors.danger))

    Theme.panel(170, 225, 460, 260, 20, accent)

    local badgeText = game.paused and "RUN PAUSED"
        or (isNewRecord and "NEW RECORD ACHIEVED!"
            or (game.won and "GRID MASTERED" or "ROUND COMPLETE"))
    Theme.badge(290, 245, 220, badgeText, fonts.tiny or fonts.small, accent)

    local title = game.paused and "PAUSED" or (game.won and "GRID CLEARED" or "RUN ENDED")
    graphics.setFont(fonts.display or fonts.heading)
    graphics.setColor(accent[1], accent[2], accent[3], 1)
    graphics.printf(title, 170, 288, 460, "center")

    graphics.setFont(fonts.body)
    graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], 1)
    local statsText = "SCORE " .. game.score .. "   //   BEST " .. game.best .. "   //   STREAK x" .. game.maxCombo
    graphics.printf(statsText, 170, 338, 460, "center")

    graphics.setFont(fonts.small)
    graphics.setColor(Theme.colors.muted[1], Theme.colors.muted[2], Theme.colors.muted[3], 1)
    local reason = game.reason == "wall" and "Vector exited the containment boundary."
        or (game.reason == "self" and "Energy path collided with own trail."
        or (game.won and "Complete cyberspace synchronization." or "Telemetry standing by."))
    graphics.printf(reason, 170, 376, 460, "center")

    if game.paused then
        Theme.keycap(250, 424, "P", fonts.small, 29)
        graphics.printf("resume", 282, 429, 72, "left")
        Theme.keycap(394, 424, "R", fonts.small, 29)
        graphics.printf("new run", 426, 429, 75, "left")
    else
        Theme.keycap(255, 424, "R", fonts.small, 29)
        graphics.printf("new run", 287, 429, 75, "left")
        Theme.keycap(420, 424, "ESC", fonts.small, 38)
        graphics.printf("menu", 462, 429, 58, "left")
    end
end

function PlayingState:draw()
    local graphics = love.graphics
    Theme.drawBackground(self.time, self.context.stars, 800, 640)
    self:drawHeader()

    local jitter = self.shake * self.shake * 15
    local offsetX = math.sin(self.time * 105) * jitter
    local offsetY = math.cos(self.time * 142) * jitter
    graphics.push()
    graphics.translate(offsetX, offsetY)
    self.game:draw(self.time)
    self.effects:draw(self.context.fonts.small)
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
