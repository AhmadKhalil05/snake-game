# كامل كود Snake: Neon Runner

انسخ كل بلوك إلى الملف المكتوب فوقه داخل مجلد المشروع. ملفات states تبقى داخل مجلد states.

## `conf.lua`

```lua
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

```

## `effects.lua`

```lua
-- Small reusable particle system. It has no gameplay authority: it only draws feedback.
local Theme = require("theme")

local Effects = {}
Effects.__index = Effects

function Effects:new(random)
    return setmetatable({particles = {}, rings = {}, random = random or math.random}, Effects)
end

function Effects:clear()
    self.particles = {}
    self.rings = {}
end

function Effects:burst(x, y, color, count, strength)
    color = color or Theme.colors.mint
    count = count or 12
    strength = strength or 90
    for index = 1, count do
        local angle = (index / count) * math.pi * 2 + self.random() * 0.34
        local speed = strength * (0.50 + self.random() * 0.70)
        table.insert(self.particles, {
            x = x, y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = 0.42 + self.random() * 0.26,
            maxLife = 0.68,
            size = 1.4 + self.random() * 2.6,
            color = color
        })
    end
    table.insert(self.rings, {
        x = x, y = y, radius = 4, maxRadius = 33,
        life = 0.42, maxLife = 0.42, color = color
    })
end

function Effects:shockwave(x, y, color)
    table.insert(self.rings, {
        x = x, y = y, radius = 15, maxRadius = 165,
        life = 0.55, maxLife = 0.55, color = color or Theme.colors.danger
    })
end

function Effects:update(dt)
    for index = #self.particles, 1, -1 do
        local particle = self.particles[index]
        particle.life = particle.life - dt
        if particle.life <= 0 then
            table.remove(self.particles, index)
        else
            particle.x = particle.x + particle.vx * dt
            particle.y = particle.y + particle.vy * dt
            particle.vx = particle.vx * (1 - math.min(dt * 3.2, 0.92))
            particle.vy = particle.vy * (1 - math.min(dt * 3.2, 0.92)) + 11 * dt
        end
    end

    for index = #self.rings, 1, -1 do
        local ring = self.rings[index]
        ring.life = ring.life - dt
        if ring.life <= 0 then
            table.remove(self.rings, index)
        else
            local progress = 1 - ring.life / ring.maxLife
            ring.radius = 4 + (ring.maxRadius - 4) * progress
        end
    end
end

function Effects:draw()
    local graphics = love.graphics
    for index = 1, #self.rings do
        local ring = self.rings[index]
        local alpha = math.max(0, ring.life / ring.maxLife)
        graphics.setColor(ring.color[1], ring.color[2], ring.color[3], alpha * 0.42)
        graphics.setLineWidth(2)
        graphics.circle("line", ring.x, ring.y, ring.radius)
    end

    for index = 1, #self.particles do
        local particle = self.particles[index]
        local alpha = math.max(0, particle.life / particle.maxLife)
        graphics.setColor(particle.color[1], particle.color[2], particle.color[3], alpha)
        graphics.circle("fill", particle.x, particle.y, particle.size * (0.55 + alpha * 0.45))
    end
end

return Effects

```

## `entity.lua`

```lua
local Entity = {}
Entity.__index = Entity

function Entity:new()
    return setmetatable({components = {}}, Entity)
end

function Entity:addComponent(name, component)
    assert(type(name) == "string", "Component names must be strings")
    assert(component ~= nil, "A component cannot be nil")
    self.components[name] = component
    return self
end

function Entity:getComponent(name)
    return self.components[name]
end

function Entity:hasComponent(name)
    return self.components[name] ~= nil
end

return Entity

```

## `events.lua`

```lua
local Events = {}
Events.__index = Events

function Events:new()
    return setmetatable({listeners = {}}, Events)
end

-- Observer pattern: subscribers react without being coupled to SnakeGame.
function Events:subscribe(event, callback)
    assert(type(callback) == "function", "An event listener must be a function")
    local listeners = self.listeners[event]
    if not listeners then
        listeners = {}
        self.listeners[event] = listeners
    end
    table.insert(listeners, callback)
end

function Events:emit(event, data)
    local listeners = self.listeners[event] or {}
    for i = 1, #listeners do
        listeners[i](data)
    end
end

return Events

```

## `gamestate.lua`

```lua
local GameState = {}
GameState.__index = GameState

function GameState:new(context)
    local manager = setmetatable({states = {}, current = nil}, GameState)
    manager.states.menu = require("states.menu_state"):new(manager, context)
    manager.states.playing = require("states.game_state"):new(manager, context)
    manager:switch("menu")
    return manager
end

function GameState:switch(newState)
    assert(self.states[newState], "Unknown game state: " .. tostring(newState))

    local previous = self.states[self.current]
    if previous and previous.exit then
        previous:exit()
    end

    self.current = newState
    local current = self.states[newState]
    if current.enter then
        current:enter()
    end
end

function GameState:update(dt)
    self.states[self.current]:update(dt)
end

function GameState:draw()
    self.states[self.current]:draw()
end

function GameState:keypressed(key)
    local current = self.states[self.current]
    if current.keypressed then
        current:keypressed(key)
    end
end

function GameState:mousepressed(x, y, button)
    local current = self.states[self.current]
    if current.mousepressed then
        current:mousepressed(x, y, button)
    end
end

return GameState

```

## `highscore.lua`

```lua
local HighScore = {}
HighScore.__index = HighScore

-- Parse a small string rather than putting Lua 5.4 syntax in a LuaJIT module.
-- Standard LOVE uses LuaJIT, so it cannot parse highscore54.lua directly.
local compile = loadstring or load
local supportsClose = compile("local file <close> = nil") ~= nil
local native54 = supportsClose and require("highscore54") or nil

local function hasLoveFilesystem()
    return love and love.filesystem and love.filesystem.getSaveDirectory
end

local function validScore(value)
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge
        or number == -math.huge or number < 0 then
        return 0
    end
    return math.floor(number)
end

function HighScore:new(filename)
    return setmetatable({filename = filename or "scores/highscore.txt"}, HighScore)
end

function HighScore:_path()
    if hasLoveFilesystem() then
        return love.filesystem.getSaveDirectory() .. "/" .. self.filename
    end
    return self.filename
end

function HighScore:load()
    local content
    if native54 then
        local ok, result = pcall(native54.load, self:_path())
        if ok then
            content = result
        end
    elseif hasLoveFilesystem() then
        -- The web runtime needs an existence check before reading a new save.
        if love.filesystem.getInfo(self.filename) then
            content = love.filesystem.read(self.filename)
        end
    else
        local file = io.open(self.filename, "r")
        if file then
            content = file:read("*a")
            file:close()
        end
    end
    return validScore(content)
end

function HighScore:save(score)
    score = validScore(score)

    if hasLoveFilesystem() then
        local directory = self.filename:match("^(.*)/[^/]+$")
        if directory and not love.filesystem.createDirectory(directory) then
            return nil, "Could not create the score directory"
        end
    end

    if native54 then
        local ok, result, message = pcall(native54.save, self:_path(), score)
        if not ok then
            return nil, result
        end
        return result, message
    end

    if hasLoveFilesystem() then
        -- Compatibility backend: LOVE handles opening and closing the file.
        return love.filesystem.write(self.filename, tostring(score) .. "\n")
    end

    local file, openError = io.open(self:_path(), "w")
    if not file then
        return nil, openError
    end
    local written, writeError = file:write(tostring(score), "\n")
    local closed, closeError = file:close()
    if not written then
        return nil, writeError
    end
    if not closed then
        return nil, closeError
    end
    return true
end

function HighScore:usesNativeClose()
    return supportsClose
end

return HighScore

```

## `highscore54.lua`

```lua
-- Native Lua 5.4 implementation of the assignment's modern Lua feature.
-- <close> closes a file when its scope ends, including when an error occurs.
-- This module is only required by interpreters that support that syntax.
local HighScore54 = {}

function HighScore54.save(path, score)
    local file <close>, openError = io.open(path, "w")
    if not file then
        return nil, openError
    end

    local written, writeError = file:write(tostring(score), "\n")
    if not written then
        return nil, writeError
    end

    local flushed, flushError = file:flush()
    if not flushed then
        return nil, flushError
    end
    return true
end

function HighScore54.load(path)
    local file <close>, openError = io.open(path, "r")
    if not file then
        return nil, openError
    end
    return file:read("*a")
end

return HighScore54

```

## `input.lua`

```lua
local Input = {}
Input.__index = Input

function Input:new()
    return setmetatable({commands = {}}, Input)
end

-- Command pattern: a key selects a callable command.
function Input:bind(key, command)
    assert(type(command) == "function", "An input command must be a function")
    self.commands[key] = command
end

function Input:handleKey(key)
    local command = self.commands[key]
    if command then
        command()
        return true
    end
    return false
end

return Input

```

## `main.lua`

```lua
-- Entry point: LOVE owns the main loop; callbacks delegate to the state manager.
local GameState = require("gamestate")
local HighScore = require("highscore")
local Theme = require("theme")
local gameState

if not love then
    print("Run the graphical game with LOVE: love .")
    print("Run the Lua-only checks with: lua tests/run.lua")
    return
end

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.graphics.setBackgroundColor(Theme.colors.background[1], Theme.colors.background[2],
        Theme.colors.background[3])

    local context = {
        highScore = HighScore:new(),
        stars = Theme.createStars(88, 800, 640),
        fonts = {
            title = love.graphics.newFont(58),
            display = love.graphics.newFont(36),
            heading = love.graphics.newFont(26),
            body = love.graphics.newFont(18),
            small = love.graphics.newFont(13),
            tiny = love.graphics.newFont(11),
            number = love.graphics.newFont(28)
        }
    }
    gameState = GameState:new(context)
end

function love.update(dt)
    gameState:update(dt)
end

function love.draw()
    gameState:draw()
end

function love.keypressed(key)
    if key == "f5" then
        love.event.quit("restart")
        return
    end
    gameState:keypressed(key)
end

function love.mousepressed(x, y, button)
    gameState:mousepressed(x, y, button)
end

function love.focus(focused)
    -- Pause when switching apps so the snake does not hit a wall unattended.
    if not focused and gameState and gameState.current == "playing" then
        local game = gameState.states.playing.game
        if game and not game.gameOver then
            game.paused = true
        end
    end
end

```

## `snake_game.lua`

```lua
local Vector2 = require("vector2")
local Entity = require("entity")
local Events = require("events")
local HighScore = require("highscore")
local Theme = require("theme")

local SnakeGame = {}
SnakeGame.__index = SnakeGame

function SnakeGame:new(options)
    options = options or {}
    local game = setmetatable({}, SnakeGame)

    game.columns = options.columns or 36
    game.rows = options.rows or 24
    game.originX = options.originX or 40
    game.originY = options.originY or 116
    assert(game.columns >= 2 and game.rows >= 1, "The board is too small")

    game.events = options.events or Events:new()
    game.highScoreStore = options.highScore or HighScore:new()
    game.random = options.random
        or (love and love.math and love.math.random)
        or math.random

    game.score = 0
    game.best = game.highScoreStore:load()
    game.gameOver = false
    game.won = false
    game.paused = false
    game.reason = nil
    game.saveError = nil
    game.visualTime = 0

    local headX = math.floor(game.columns / 2)
    local headY = math.floor(game.rows / 2)
    local initialLength = math.min(options.initialLength or 3, headX + 1)
    assert(initialLength >= 1, "The snake must have at least one segment")
    game.snake = {}
    for i = 0, initialLength - 1 do
        table.insert(game.snake, Vector2:new(headX - i, headY))
    end

    game.entity = Entity:new()
    game.entity:addComponent("position", game.snake[1])
    game.entity:addComponent("movement", {
        dx = 1, dy = 0,
        nextDx = 1, nextDy = 0,
        timer = 0,
        interval = options.interval or 0.16
    })
    game.entity:addComponent("renderer", {
        size = options.cellSize or 20,
        color = {0.10, 0.64, 0.42},
        tailColor = {0.12, 0.34, 0.42},
        headColor = {0.40, 1.00, 0.67}
    })
    assert(game.entity:getComponent("movement").interval > 0,
        "Movement interval must be positive")

    game:spawnFood()
    return game
end

function SnakeGame:cellCenter(position)
    local size = self.entity:getComponent("renderer").size
    return self.originX + (position.x + 0.5) * size,
        self.originY + (position.y + 0.5) * size
end

function SnakeGame:spawnFood()
    local occupied = {}
    for i = 1, #self.snake do
        local segment = self.snake[i]
        occupied[segment.y * self.columns + segment.x] = true
    end

    -- Choose from empty cells. This also terminates when the whole board is full.
    local emptyCells = {}
    for y = 0, self.rows - 1 do
        for x = 0, self.columns - 1 do
            if not occupied[y * self.columns + x] then
                table.insert(emptyCells, Vector2:new(x, y))
            end
        end
    end

    if #emptyCells == 0 then
        self.food = nil
        self.won = true
        self.gameOver = true
        self.reason = "board_complete"
        self.events:emit("game_won", {score = self.score, best = self.best})
        return
    end

    self.food = emptyCells[self.random(1, #emptyCells)]
end

function SnakeGame:_saveBest()
    local newRecord = self.score > self.best
    if newRecord then
        self.best = self.score
    end
    if newRecord or self.saveError then
        local saved, message = self.highScoreStore:save(self.best)
        self.saveError = not saved and (message or "Could not save the score") or nil
    end
end

function SnakeGame:_finish(reason)
    self.gameOver = true
    self.reason = reason
    self:_saveBest()
    self.events:emit("game_over", {
        score = self.score, best = self.best, reason = reason
    })
end

function SnakeGame:changeDirection(dx, dy)
    if self.gameOver then
        return false
    end
    local cardinal = (dx == 1 and dy == 0) or (dx == -1 and dy == 0)
        or (dx == 0 and dy == 1) or (dx == 0 and dy == -1)
    if not cardinal then
        return false
    end

    local movement = self.entity:getComponent("movement")
    -- Compare with the last actual move, not another queued key press.
    -- This prevents a right -> up -> left reversal within one movement tick.
    if dx == -movement.dx and dy == -movement.dy then
        return false
    end
    movement.nextDx = dx
    movement.nextDy = dy
    return true
end

function SnakeGame:_step()
    local movement = self.entity:getComponent("movement")
    movement.dx = movement.nextDx
    movement.dy = movement.nextDy

    local position = self.entity:getComponent("position")
    local nextHead = position + Vector2:new(movement.dx, movement.dy)
    local eating = self.food ~= nil and nextHead == self.food

    if nextHead.x < 0 or nextHead.x >= self.columns
        or nextHead.y < 0 or nextHead.y >= self.rows then
        self:_finish("wall")
        return
    end

    -- When not growing, the tail vacates its cell during this same step.
    local lastOccupied = eating and #self.snake or (#self.snake - 1)
    for i = 1, lastOccupied do
        if nextHead == self.snake[i] then
            self:_finish("self")
            return
        end
    end

    table.insert(self.snake, 1, nextHead)
    self.entity:addComponent("position", nextHead)

    if eating then
        self.score = self.score + 1
        self:_saveBest()
        self.events:emit("food_eaten", {
            score = self.score,
            length = #self.snake,
            position = nextHead
        })
        self:spawnFood()
    else
        table.remove(self.snake)
    end
end

function SnakeGame:update(dt)
    if dt > 0 then
        self.visualTime = self.visualTime + dt
    end
    if self.gameOver or self.paused or dt <= 0 then
        return
    end

    local movement = self.entity:getComponent("movement")
    movement.timer = movement.timer + dt
    -- Allow tiny floating-point rounding errors at an exact tick boundary.
    while movement.timer + 1e-9 >= movement.interval and not self.gameOver do
        movement.timer = math.max(0, movement.timer - movement.interval)
        self:_step()
    end
end

function SnakeGame:togglePause()
    if not self.gameOver then
        self.paused = not self.paused
    end
end

function SnakeGame:draw(time)
    local graphics = love.graphics
    local renderer = self.entity:getComponent("renderer")
    local cellSize = renderer.size
    local boardWidth = self.columns * cellSize
    local boardHeight = self.rows * cellSize
    time = time or self.visualTime

    -- Framed board with a soft cyan halo.
    Theme.glowRect(self.originX - 8, self.originY - 8,
        boardWidth + 16, boardHeight + 16, 13, Theme.colors.cyan, 0.075, 5)
    graphics.setColor(0.012, 0.024, 0.049, 0.98)
    graphics.rectangle("fill", self.originX - 7, self.originY - 7,
        boardWidth + 14, boardHeight + 14, 12, 12)
    graphics.setColor(0.075, 0.12, 0.19, 1)
    graphics.rectangle("fill", self.originX, self.originY, boardWidth, boardHeight, 6, 6)

    -- The grid is deliberately quiet so the snake and food stay dominant.
    graphics.setLineWidth(1)
    for x = 1, self.columns - 1 do
        local pixelX = self.originX + x * cellSize
        local major = x % 6 == 0
        graphics.setColor(0.18, 0.38, 0.50, major and 0.18 or 0.075)
        graphics.line(pixelX, self.originY, pixelX, self.originY + boardHeight)
    end
    for y = 1, self.rows - 1 do
        local pixelY = self.originY + y * cellSize
        local major = y % 6 == 0
        graphics.setColor(0.18, 0.38, 0.50, major and 0.18 or 0.075)
        graphics.line(self.originX, pixelY, self.originX + boardWidth, pixelY)
    end

    -- Corner indicators make the board read as a neon terminal panel.
    local corner = 23
    graphics.setColor(Theme.colors.cyan[1], Theme.colors.cyan[2], Theme.colors.cyan[3], 0.82)
    graphics.line(self.originX - 7, self.originY + corner, self.originX - 7, self.originY - 1)
    graphics.line(self.originX - 7, self.originY - 7, self.originX + corner, self.originY - 7)
    graphics.line(self.originX + boardWidth - corner, self.originY - 7,
        self.originX + boardWidth + 7, self.originY - 7)
    graphics.line(self.originX + boardWidth + 7, self.originY - 7,
        self.originX + boardWidth + 7, self.originY + corner)
    graphics.line(self.originX - 7, self.originY + boardHeight - corner,
        self.originX - 7, self.originY + boardHeight + 7)
    graphics.line(self.originX - 7, self.originY + boardHeight + 7,
        self.originX + corner, self.originY + boardHeight + 7)
    graphics.line(self.originX + boardWidth - corner, self.originY + boardHeight + 7,
        self.originX + boardWidth + 7, self.originY + boardHeight + 7)
    graphics.line(self.originX + boardWidth + 7, self.originY + boardHeight + 7,
        self.originX + boardWidth + 7, self.originY + boardHeight - corner)

    if self.food then
        local foodX, foodY = self:cellCenter(self.food)
        local pulse = Theme.pulse(time, 5.4)
        Theme.glowCircle(foodX, foodY, cellSize * (0.54 + pulse * 0.14),
            Theme.colors.pink, 0.09 + pulse * 0.045, 5)
        graphics.setColor(Theme.colors.orange[1], Theme.colors.orange[2], Theme.colors.orange[3], 1)
        graphics.circle("fill", foodX, foodY, cellSize * (0.24 + pulse * 0.025))
        graphics.setColor(1, 0.90, 0.65, 0.95)
        graphics.circle("fill", foodX - cellSize * 0.075, foodY - cellSize * 0.085, cellSize * 0.068)
        graphics.setColor(Theme.colors.pink[1], Theme.colors.pink[2], Theme.colors.pink[3], 0.9)
        graphics.setLineWidth(1.5)
        graphics.circle("line", foodX, foodY, cellSize * (0.32 + pulse * 0.045))
    end

    local totalSegments = math.max(1, #self.snake - 1)
    for i = #self.snake, 1, -1 do
        local segment = self.snake[i]
        local depth = (i - 1) / totalSegments
        local color = i == 1 and renderer.headColor
            or Theme.mix(renderer.color, renderer.tailColor, depth * 0.70)
        local x = self.originX + segment.x * cellSize
        local y = self.originY + segment.y * cellSize
        local padding = i == 1 and 1.5 or 2.2
        local segmentSize = cellSize - padding * 2

        if i <= 16 then
            Theme.glowRect(x + padding, y + padding, segmentSize, segmentSize, 6,
                color, i == 1 and 0.17 or 0.055, 3)
        end
        graphics.setColor(color[1], color[2], color[3], 1)
        graphics.rectangle("fill", x + padding, y + padding, segmentSize, segmentSize, 5, 5)
        graphics.setColor(0.82, 1.0, 0.92, i == 1 and 0.58 or 0.20)
        graphics.rectangle("line", x + padding + 0.5, y + padding + 0.5,
            segmentSize - 1, segmentSize - 1, 4, 4)
        graphics.setColor(1, 1, 1, i == 1 and 0.19 or 0.075)
        graphics.rectangle("fill", x + padding + 3, y + padding + 3,
            math.max(2, segmentSize - 7), 2, 2, 2)
    end

    -- Two directional eyes make the head feel alive without a sprite asset.
    local head = self.entity:getComponent("position")
    local movement = self.entity:getComponent("movement")
    local headX, headY = self:cellCenter(head)
    local forward = cellSize * 0.17
    local sideways = cellSize * 0.18
    local eyeBaseX = headX + movement.dx * forward
    local eyeBaseY = headY + movement.dy * forward
    graphics.setColor(0.015, 0.055, 0.06, 1)
    graphics.circle("fill", eyeBaseX - movement.dy * sideways, eyeBaseY + movement.dx * sideways, 2.25)
    graphics.circle("fill", eyeBaseX + movement.dy * sideways, eyeBaseY - movement.dx * sideways, 2.25)
    graphics.setColor(0.80, 1, 0.95, 0.9)
    graphics.circle("fill", eyeBaseX - movement.dy * sideways - movement.dx * 0.5,
        eyeBaseY + movement.dx * sideways - movement.dy * 0.5, 0.65)
    graphics.circle("fill", eyeBaseX + movement.dy * sideways - movement.dx * 0.5,
        eyeBaseY - movement.dx * sideways - movement.dy * 0.5, 0.65)

    graphics.setColor(Theme.colors.cyan[1], Theme.colors.cyan[2], Theme.colors.cyan[3], 0.62)
    graphics.setLineWidth(1)
    graphics.rectangle("line", self.originX - 0.5, self.originY - 0.5,
        boardWidth + 1, boardHeight + 1, 6, 6)
    graphics.setColor(1, 1, 1, 1)
end

return SnakeGame

```

## `theme.lua`

```lua
-- Central visual system: colors and drawing helpers for the Neon Arcade look.
-- Keeping it separate lets gameplay code stay focused on rules and collision.
local Theme = {}
Theme.__index = Theme

Theme.colors = {
    background = {0.018, 0.027, 0.055},
    backgroundTop = {0.038, 0.057, 0.115},
    surface = {0.055, 0.082, 0.145},
    surfaceBright = {0.082, 0.121, 0.205},
    line = {0.18, 0.30, 0.43},
    text = {0.90, 0.96, 1.00},
    muted = {0.50, 0.63, 0.76},
    cyan = {0.22, 0.91, 1.00},
    mint = {0.36, 1.00, 0.67},
    green = {0.13, 0.72, 0.43},
    violet = {0.63, 0.43, 1.00},
    pink = {1.00, 0.32, 0.58},
    orange = {1.00, 0.65, 0.22},
    danger = {1.00, 0.31, 0.38},
    black = {0.006, 0.010, 0.024}
}

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

function Theme.new()
    return setmetatable({}, Theme)
end

function Theme.mix(a, b, amount)
    local t = clamp(amount, 0, 1)
    return {
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
        a[3] + (b[3] - a[3]) * t
    }
end

function Theme.setColor(color, alpha)
    love.graphics.setColor(color[1], color[2], color[3], alpha or 1)
end

function Theme.pulse(time, speed, phase)
    return (math.sin(time * speed + (phase or 0)) + 1) * 0.5
end

function Theme.createStars(count, width, height)
    local stars = {}
    -- Deterministic values make the background stable without touching game RNG.
    for index = 1, count do
        local seed = index * 37.719
        local fractionX = (math.sin(seed * 1.71) + 1) * 0.5
        local fractionY = (math.sin(seed * 2.37 + 1.2) + 1) * 0.5
        stars[index] = {
            x = fractionX * width,
            y = fractionY * height,
            radius = 0.45 + ((math.sin(seed * 3.91) + 1) * 0.5) * 1.15,
            speed = 0.35 + ((math.sin(seed * 4.81) + 1) * 0.5) * 1.1,
            phase = seed
        }
    end
    return stars
end

function Theme.drawBackground(time, stars, width, height)
    local graphics = love.graphics
    width, height = width or 800, height or 640

    graphics.clear(Theme.colors.background[1], Theme.colors.background[2],
        Theme.colors.background[3], 1)

    -- Layered translucent bands imitate a deep arcade-gradient without assets.
    for band = 0, 12 do
        local t = band / 12
        local color = Theme.mix(Theme.colors.backgroundTop, Theme.colors.background, t)
        graphics.setColor(color[1], color[2], color[3], 1)
        graphics.rectangle("fill", 0, band * height / 13, width, height / 13 + 1)
    end

    -- Soft neon halos behind the play field.
    local glow = Theme.pulse(time, 0.65)
    Theme.glowCircle(width * 0.16, height * 0.18, 126 + glow * 15,
        Theme.colors.violet, 0.055, 5)
    Theme.glowCircle(width * 0.86, height * 0.77, 174 - glow * 12,
        Theme.colors.cyan, 0.045, 6)

    for index = 1, #(stars or {}) do
        local star = stars[index]
        local twinkle = 0.30 + Theme.pulse(time, star.speed, star.phase) * 0.55
        graphics.setColor(0.54, 0.82, 1.0, twinkle)
        graphics.circle("fill", star.x, star.y, star.radius)
    end

    -- Very subtle scan-lines make the background feel like an arcade display.
    graphics.setColor(0.18, 0.34, 0.55, 0.045)
    for y = 8, height, 8 do
        graphics.line(0, y, width, y)
    end
end

function Theme.glowCircle(x, y, radius, color, alpha, layers)
    local graphics = love.graphics
    layers = layers or 4
    for layer = layers, 1, -1 do
        local progress = layer / layers
        graphics.setColor(color[1], color[2], color[3], (alpha or 0.1) * (1 - progress * 0.48))
        graphics.circle("fill", x, y, radius * (0.54 + progress * 0.60))
    end
end

function Theme.glowRect(x, y, width, height, radius, color, alpha, layers)
    local graphics = love.graphics
    layers = layers or 4
    for layer = layers, 1, -1 do
        local expand = layer * 2
        local layerAlpha = (alpha or 0.12) * (1 - (layer - 1) / (layers + 1))
        graphics.setColor(color[1], color[2], color[3], layerAlpha)
        graphics.rectangle("fill", x - expand, y - expand, width + expand * 2,
            height + expand * 2, radius + expand, radius + expand)
    end
end

function Theme.panel(x, y, width, height, radius, accent, alpha)
    local graphics = love.graphics
    accent = accent or Theme.colors.cyan
    alpha = alpha or 1
    Theme.glowRect(x, y, width, height, radius, accent, 0.045 * alpha, 4)
    graphics.setColor(Theme.colors.surface[1], Theme.colors.surface[2], Theme.colors.surface[3], 0.94 * alpha)
    graphics.rectangle("fill", x, y, width, height, radius, radius)
    graphics.setColor(Theme.colors.surfaceBright[1], Theme.colors.surfaceBright[2],
        Theme.colors.surfaceBright[3], 0.55 * alpha)
    graphics.rectangle("fill", x + 1, y + 1, width - 2, 2, radius, radius)
    graphics.setColor(accent[1], accent[2], accent[3], 0.45 * alpha)
    graphics.setLineWidth(1)
    graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1, radius, radius)
end

function Theme.badge(x, y, width, text, font, color)
    local graphics = love.graphics
    color = color or Theme.colors.cyan
    graphics.setFont(font)
    graphics.setColor(color[1], color[2], color[3], 0.16)
    graphics.rectangle("fill", x, y, width, 24, 12, 12)
    graphics.setColor(color[1], color[2], color[3], 0.65)
    graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, 23, 12, 12)
    graphics.setColor(color[1], color[2], color[3], 1)
    graphics.printf(text, x, y + 5, width, "center")
end

function Theme.keycap(x, y, text, font, width)
    local graphics = love.graphics
    width = width or 30
    graphics.setFont(font)
    graphics.setColor(0.10, 0.16, 0.25, 0.95)
    graphics.rectangle("fill", x, y, width, 22, 5, 5)
    graphics.setColor(0.29, 0.48, 0.66, 0.78)
    graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, 21, 5, 5)
    graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], 0.95)
    graphics.printf(text, x, y + 4, width, "center")
end

return Theme

```

## `vector2.lua`

```lua
local Vector2 = {}
Vector2.__index = Vector2

function Vector2:new(x, y)
    return setmetatable({x = x or 0, y = y or 0}, Vector2)
end

-- Metamethods let vectors use ordinary Lua operators.
function Vector2:__add(other)
    return Vector2:new(self.x + other.x, self.y + other.y)
end

function Vector2:__eq(other)
    return self.x == other.x and self.y == other.y
end

function Vector2:__tostring()
    return string.format("Vector2(%s, %s)", tostring(self.x), tostring(self.y))
end

return Vector2

```

## `states/menu_state.lua`

```lua
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

```

## `states/game_state.lua`

```lua
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

```

## `tests/run.lua`

```lua
-- Run from the project directory: lua tests/run.lua
-- Works with Lua 5.4 and LuaJIT. No test framework or window is required.
package.path = "./?.lua;./?/init.lua;" .. package.path

local Vector2 = require("vector2")
local Entity = require("entity")
local Input = require("input")
local Events = require("events")
local HighScore = require("highscore")
local SnakeGame = require("snake_game")

local passed, failed = 0, 0
local function check(name, test)
    local ok, message = pcall(test)
    if ok then
        passed = passed + 1
        print("PASS  " .. name)
    else
        failed = failed + 1
        print("FAIL  " .. name .. ": " .. tostring(message))
    end
end

local function memoryScore(best)
    return {
        best = best or 0,
        writes = 0,
        load = function(self) return self.best end,
        save = function(self, score)
            self.best = score
            self.writes = self.writes + 1
            return true
        end
    }
end

local function newGame(options)
    options = options or {}
    options.columns = options.columns or 12
    options.rows = options.rows or 8
    options.interval = options.interval or 0.125
    options.initialLength = options.initialLength or 1
    options.highScore = options.highScore or memoryScore()
    options.random = options.random or function(first) return first end
    return SnakeGame:new(options)
end

local function position(game, coordinates, dx, dy)
    game.snake = {}
    for i = 1, #coordinates do
        game.snake[i] = Vector2:new(coordinates[i][1], coordinates[i][2])
    end
    game.entity:addComponent("position", game.snake[1])
    local movement = game.entity:getComponent("movement")
    movement.dx, movement.dy = dx, dy
    movement.nextDx, movement.nextDy = dx, dy
    movement.timer = 0
    game.food = Vector2:new(game.columns - 1, game.rows - 1)
end

check("Vector2 addition returns the correct vector", function()
    local a = Vector2:new(2, 3)
    local result = a + Vector2:new(-1, 4)
    assert(result == Vector2:new(1, 7))
    assert(a == Vector2:new(2, 3))
end)

check("Vector2 equality compares both coordinates", function()
    assert(Vector2:new(2, 3) == Vector2:new(2, 3))
    assert(Vector2:new(2, 3) ~= Vector2:new(2, 4))
end)

check("Vector2 tostring is readable", function()
    assert(tostring(Vector2:new(2, -3)) == "Vector2(2, -3)")
end)

check("Entity stores, retrieves and detects components", function()
    local entity = Entity:new()
    local component = Vector2:new(4, 5)
    assert(not entity:hasComponent("position"))
    entity:addComponent("position", component)
    assert(entity:getComponent("position") == component)
    assert(entity:hasComponent("position"))
    assert(entity:getComponent("missing") == nil)
    entity:addComponent("enabled", false)
    assert(entity:hasComponent("enabled"))
end)

check("Input executes bound commands and ignores unknown keys", function()
    local input = Input:new()
    local calls = 0
    input:bind("up", function() calls = calls + 1 end)
    assert(input:handleKey("up"))
    assert(not input:handleKey("unknown"))
    assert(calls == 1)
end)

check("Events notify each subscriber with data", function()
    local events = Events:new()
    local total = 0
    events:subscribe("food_eaten", function(data) total = total + data.score end)
    events:subscribe("food_eaten", function(data) total = total + data.score end)
    events:emit("food_eaten", {score = 3})
    events:emit("unregistered", {})
    assert(total == 6)
end)

check("Event buses are independent", function()
    local a, b = Events:new(), Events:new()
    local calls = 0
    a:subscribe("test", function() calls = calls + 1 end)
    b:emit("test", {})
    assert(calls == 0)
end)

check("Snake uses all three required components", function()
    local game = newGame()
    assert(game.entity:hasComponent("position"))
    assert(game.entity:hasComponent("movement"))
    assert(game.entity:hasComponent("renderer"))
end)

check("Snake moves continuously without a key press", function()
    local game = newGame()
    local before = game.snake[1]
    game:update(0.125)
    assert(game.snake[1] == before + Vector2:new(1, 0))
    assert(#game.snake == 1)
end)

check("Partial frame times accumulate", function()
    local game = newGame()
    local before = game.snake[1]
    game:update(0.0625)
    assert(game.snake[1] == before)
    game:update(0.0625)
    assert(game.snake[1] == before + Vector2:new(1, 0))
end)

check("A slow frame still performs each movement tick", function()
    local game = newGame({interval = 0.16})
    local before = game.snake[1]
    game:update(0.48)
    assert(game.snake[1] == before + Vector2:new(3, 0))
end)

check("Immediate reversal is rejected", function()
    local game = newGame()
    assert(not game:changeDirection(-1, 0))
    assert(not game:changeDirection(1, 1))
    assert(game:changeDirection(0, -1))
end)

check("Rapid queued keys cannot reverse the actual direction", function()
    local game = newGame()
    local before = game.snake[1]
    assert(game:changeDirection(0, -1))
    assert(not game:changeDirection(-1, 0))
    game:update(0.125)
    assert(game.snake[1] == before + Vector2:new(0, -1))
    assert(not game:changeDirection(0, 1))
end)

check("Eating increases score and length and emits an event", function()
    local events = Events:new()
    local data
    events:subscribe("food_eaten", function(value) data = value end)
    local game = newGame({events = events})
    game.food = game.snake[1] + Vector2:new(1, 0)
    game:update(0.125)
    assert(game.score == 1 and #game.snake == 2)
    assert(data.score == 1 and data.length == 2)
    assert(game.highScoreStore.best == 1)
end)

check("An existing higher record is not overwritten", function()
    local store = memoryScore(20)
    local game = newGame({highScore = store})
    game.food = game.snake[1] + Vector2:new(1, 0)
    game:update(0.125)
    assert(game.score == 1 and game.best == 20 and store.writes == 0)
end)

check("Food stays in bounds and away from every segment", function()
    local game = newGame({initialLength = 3})
    position(game, {{0, 0}, {1, 0}, {2, 0}}, 1, 0)
    game:spawnFood()
    assert(game.food.x >= 0 and game.food.x < game.columns)
    assert(game.food.y >= 0 and game.food.y < game.rows)
    for i = 1, #game.snake do assert(game.food ~= game.snake[i]) end
end)

local wallCases = {
    left = {{0, 2}, -1, 0}, right = {{11, 2}, 1, 0},
    top = {{3, 0}, 0, -1}, bottom = {{3, 7}, 0, 1}
}
for name, fixture in pairs(wallCases) do
    check("Wall collision at " .. name, function()
        local game = newGame()
        position(game, {fixture[1]}, fixture[2], fixture[3])
        local before = game.snake[1]
        game:update(0.125)
        assert(game.gameOver and game.reason == "wall")
        assert(game.snake[1] == before)
    end)
end

check("Self collision ends the round before changing the body", function()
    local game = newGame()
    position(game, {{2, 2}, {2, 3}, {3, 3}, {3, 2}, {4, 2}}, 1, 0)
    game:update(0.125)
    assert(game.gameOver and game.reason == "self")
    assert(game.snake[1] == Vector2:new(2, 2) and #game.snake == 5)
end)

check("Moving into the vacating tail is legal", function()
    local game = newGame()
    position(game, {{2, 2}, {2, 3}, {3, 3}, {3, 2}}, 1, 0)
    game:update(0.125)
    assert(not game.gameOver)
    assert(game.snake[1] == Vector2:new(3, 2) and #game.snake == 4)
end)

check("A paused game does not move or accumulate elapsed time", function()
    local game = newGame()
    local before = game.snake[1]
    game:togglePause()
    game:update(5)
    assert(game.snake[1] == before)
    game:togglePause()
    game:update(0.125)
    assert(game.snake[1] == before + Vector2:new(1, 0))
end)

check("Movement stops after game over", function()
    local game = newGame()
    game.gameOver = true
    local before = game.snake[1]
    game:update(4)
    assert(game.snake[1] == before)
end)

check("Filling the board wins without a food-generation loop", function()
    local events = Events:new()
    local won = false
    events:subscribe("game_won", function() won = true end)
    local game = newGame({columns = 2, rows = 2, events = events})
    position(game, {{0, 0}, {0, 1}, {1, 1}}, 1, 0)
    game.food = Vector2:new(1, 0)
    game:update(0.125)
    assert(game.won and game.gameOver and won)
    assert(game.food == nil and #game.snake == 4 and game.score == 1)
end)

check("Storage errors do not crash a round", function()
    local store = memoryScore()
    store.save = function() return nil, "read-only storage" end
    local game = newGame({highScore = store})
    game.food = game.snake[1] + Vector2:new(1, 0)
    game:update(0.125)
    assert(game.score == 1 and game.saveError == "read-only storage")
end)

check("A missing high-score file loads as zero", function()
    local path = os.tmpname()
    os.remove(path)
    assert(HighScore:new(path):load() == 0)
end)

check("A high score survives saving and a new store instance", function()
    local path = os.tmpname()
    assert(HighScore:new(path):save(17))
    assert(HighScore:new(path):load() == 17)
    os.remove(path)
end)

check("Malformed and negative score files are ignored", function()
    local path = os.tmpname()
    local values = {"not a score", "-4", "inf", "nan", ""}
    for i = 1, #values do
        local file = assert(io.open(path, "w"))
        file:write(values[i])
        file:close()
        assert(HighScore:new(path):load() == 0)
    end
    os.remove(path)
end)

check("An unwritable path reports a save failure", function()
    local path = os.tmpname()
    os.remove(path)
    local saved, message = HighScore:new(path .. "/missing/score.txt"):save(10)
    assert(not saved and message)
end)

if HighScore:new():usesNativeClose() then
    check("Lua 5.4 <close> closes the file even when writing throws", function()
        local backend = require("highscore54")
        local originalOpen = io.open
        local closed = false
        io.open = function()
            return setmetatable({
                write = function() error("forced write error") end
            }, {__close = function() closed = true end})
        end
        local ok = pcall(backend.save, "unused", 12)
        io.open = originalOpen
        assert(not ok and closed)
    end)
end

if not HighScore:new():usesNativeClose() then
    check("A fresh browser save is checked before it is read", function()
        local originalLove = love
        local exists, reads = false, 0
        love = {filesystem = {
            getSaveDirectory = function() return "/browser" end,
            getInfo = function() return exists and {type = "file"} or nil end,
            read = function()
                assert(exists, "Missing browser files must not be read")
                reads = reads + 1
                return "19\n"
            end
        }}
        local ok, message = pcall(function()
            assert(HighScore:new():load() == 0 and reads == 0)
            exists = true
            assert(HighScore:new():load() == 19 and reads == 1)
        end)
        love = originalLove
        assert(ok, message)
    end)
end

check("Menu, playing, commands, restart and observer UI work together", function()
    local originalLove = love
    local drawCalls = 0
    local function draw() drawCalls = drawCalls + 1 end
    love = {
        graphics = {
            setColor = draw, setFont = draw, print = draw, printf = draw,
            rectangle = draw, circle = draw, line = draw, setLineWidth = draw,
            clear = draw, push = draw, pop = draw, translate = draw
        },
        event = {quit = function() end}
    }
    local manager = require("gamestate"):new({
        highScore = memoryScore(),
        fonts = {title = {}, heading = {}, body = {}, small = {}, number = {}}
    })
    assert(manager.current == "menu")
    manager:draw()
    manager:keypressed("return")
    assert(manager.current == "playing")
    local state = manager.states.playing
    state.game.food = state.game.snake[1] + Vector2:new(1, 0)
    manager:update(0.16)
    assert(state.game.score == 1 and state.noticeTime > 0)
    manager:draw()
    manager:keypressed("p")
    assert(state.game.paused)
    manager:draw()
    manager:keypressed("r")
    assert(state.game.score == 0 and state.game.best == 1 and not state.game.paused)
    manager:keypressed("up")
    assert(state.game.entity:getComponent("movement").nextDy == -1)
    manager:keypressed("escape")
    assert(manager.current == "menu" and manager.states.menu.best == 1)
    manager:mousepressed(400, 435, 1)
    assert(manager.current == "playing")
    assert(drawCalls > 0)
    love = originalLove
end)

print(string.format("RESULT: %d passed, %d failed (%s)", passed, failed, _VERSION))
local results = {passed = passed, failed = failed, version = _VERSION}
assert(failed == 0, "Some checks failed")
return results

```

